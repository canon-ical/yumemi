// yumemi-live-1(0.14)── 合図の器・札・socket の口を workerd で回す。`yumemi_live_test_ffi.mjs` が
// `node test/yumemi_live_check.mjs` で走らせ、1 行 1 件の ok / NG を出す。
// `yumemi_live_worker.mjs` を root の esbuild で束ね、root の workerd(devDependencies)に DO の namespace(`YumemiLive`)・
// 鍵・host の binding を付けて載せ、node の WebSocket と HTTP で叩く。workerd の log(stderr)も読む。
import { spawn } from 'node:child_process';
import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { createServer, request as httpRequest } from 'node:http';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = [];
const check = (name, ok, detail) => out.push((ok ? 'ok ' : 'NG ') + name + (ok ? '' : ' ' + JSON.stringify(detail)));
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const KEY = 'test-live-key-0123456789abcdef0123456789abcdef';
// `yumemi_live_worker.mjs` の NEW_KEY と同じ(鍵の差し替えの試験)
const NEW_KEY = 'test-live-key-new-fedcba9876543210fedcba9876543210';

async function freePort() {
  const server = createServer();
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  await new Promise((resolve) => server.close(resolve));
  return port;
}

async function main() {
  const dir = join(root, 'build', 'live-workerd');
  mkdirSync(dir, { recursive: true });
  const esbuild = await import(join(root, 'node_modules', 'esbuild', 'lib', 'main.js'));
  await esbuild.build({
    entryPoints: [join(root, 'test', 'yumemi_live_worker.mjs')], bundle: true, format: 'esm', platform: 'neutral',
    external: ['cloudflare:workers'], outfile: join(dir, 'worker.js'), logLevel: 'silent',
  });
  // DO の storage は手元の dir(alarm を使う。workerd 2026-09-15 は inMemory の storage で alarm が鳴ると落ちる)
  const storage = join(dir, 'do');
  rmSync(storage, { recursive: true, force: true });
  mkdirSync(storage, { recursive: true });
  const port = await freePort();
  const host = '127.0.0.1:' + port;
  writeFileSync(join(dir, 'config.capnp'), `using Workerd = import "/workerd/workerd.capnp";
const config :Workerd.Config = (
  services = [(name = "api", worker = .api), (name = "do", disk = (path = "${storage}", writable = true))],
  sockets = [(name = "http", address = "${host}", http = (), service = "api")],
);
const api :Workerd.Worker = (
  modules = [(name = "worker.js", esModule = embed "worker.js")],
  compatibilityDate = "2026-09-01",
  durableObjectNamespaces = [(className = "YumemiLive", uniqueKey = "yumemi-live-test"), (className = "YumemiLiveNoAlarm", uniqueKey = "yumemi-live-noalarm")],
  durableObjectStorage = (localDisk = "do"),
  bindings = [
    (name = "YUMEMI_LIVE", durableObjectNamespace = (className = "YumemiLive")),
    (name = "YUMEMI_LIVE_NOALARM", durableObjectNamespace = (className = "YumemiLiveNoAlarm")),
    (name = "YUMEMI_LIVE_KEY", text = "${KEY}"),
    (name = "WWW_HOST", text = "${host}"),
    (name = "COOKIE_DOMAIN", text = "127.0.0.1"),
  ],
);
`);
  const logs = [];
  const workerd = spawn(join(root, 'node_modules', '.bin', 'workerd'), ['serve', join(dir, 'config.capnp'), '--verbose'], { stdio: ['ignore', 'pipe', 'pipe'] });
  workerd.stdout.on('data', (chunk) => logs.push(String(chunk)));
  workerd.stderr.on('data', (chunk) => logs.push(String(chunk)));
  const base = 'http://' + host;
  const origin = 'https://' + host;
  try {
    for (let i = 0; ; i++) {
      try { await fetch(base + '/_test/state'); break; } catch { if (i > 100) throw new Error('workerd did not start: ' + logs.join('')); await sleep(100); }
    }
    await run({ base, origin, logs });
  } finally {
    workerd.kill();
    // workerd の log は build の下に残す(NG の読み解き用)
    writeFileSync(join(dir, 'workerd.log'), logs.join(''));
  }
}

async function run({ base, origin, logs }) {
  // `browser` は browser の署名 cookie の値、`extra` は他の header
  const cookieOf = (session, browser) => [session && 'session=' + session, browser && 'yb=' + browser].filter(Boolean).join('; ');
  const call = (method, path, { session, browser, env, body, originHeader = origin, extra = {} } = {}) => {
    const headers = { 'content-type': 'application/json', ...extra };
    if (session || browser) headers.cookie = cookieOf(session, browser);
    if (env) headers['x-test-env'] = env;
    if (originHeader) headers.origin = originHeader;
    return fetch(base + path, { method, headers, body: body ? JSON.stringify(body) : undefined });
  };
  const read = (id, session, env) => call('GET', '/api/notes/' + id, { session, env });
  const edit = async (id, title, session, env) => {
    const started = Date.now();
    const response = await call('PUT', '/api/notes/' + id, { session, env, body: { title } });
    return { status: response.status, body: await response.text(), ms: Date.now() - started, token: response.headers.get('x-yumemi-live') };
  };
  const tokenOf = async (id, session, env) => (await read(id, session, env)).headers.get('x-yumemi-live');
  const socketUrl = (token) => base.replace('http', 'ws') + '/api/_yumemi/live' + (token === undefined ? '' : '?token=' + encodeURIComponent(token));
  // 開けた socket。届いた字を貯める
  // 開けた socket。届いた字を貯め、閉じられたら `closed` に close code
  function open(token, { session, browser, env, originHeader = origin, extra = {} } = {}) {
    return new Promise((resolve) => {
      const headers = { ...extra };
      if (session || browser) headers.cookie = cookieOf(session, browser);
      if (env) headers['x-test-env'] = env;
      if (originHeader) headers.origin = originHeader;
      const ws = new WebSocket(socketUrl(token), { headers });
      const messages = [];
      const opened = { open: true, ws, messages, closed: null };
      ws.onmessage = (event) => messages.push(String(event.data));
      ws.onclose = (event) => { opened.closed = event.code; };
      ws.onopen = () => resolve(opened);
      ws.onerror = () => resolve({ open: false });
    });
  }
  // 拒否の status と本文(WebSocket の API は status を見せないので、HTTP で upgrade を求める)
  function refusal(token, { session, browser, env, originHeader = origin, upgrade = true, extra = {} } = {}) {
    return new Promise((resolve, reject) => {
      const url = new URL(socketUrl(token).replace('ws', 'http'));
      const headers = { ...extra };
      if (upgrade) Object.assign(headers, { connection: 'Upgrade', upgrade: 'websocket', 'sec-websocket-version': '13', 'sec-websocket-key': 'dGhlIHNhbXBsZSBub25jZQ==' });
      if (session || browser) headers.cookie = cookieOf(session, browser);
      if (env) headers['x-test-env'] = env;
      if (originHeader) headers.origin = originHeader;
      const req = httpRequest(url, { headers });
      req.on('response', (response) => { let body = ''; response.on('data', (x) => { body += x; }); response.on('end', () => resolve({ status: response.status ?? response.statusCode, body })); });
      req.on('upgrade', (response, socket) => { socket.destroy(); resolve({ status: 101 }); });
      req.on('error', reject);
      req.end();
    });
  }
  const until = async (fn, ms = 2000) => { const end = Date.now() + ms; while (Date.now() < end) { if (fn()) return true; await sleep(20); } return fn(); };
  const decode = (token) => JSON.parse(Buffer.from(token.split('.')[0], 'base64url').toString());
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey('raw', encoder.encode(KEY), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const newKey = await crypto.subtle.importKey('raw', encoder.encode(NEW_KEY), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  async function forge(value, signer = key) {
    const payload = Buffer.from(JSON.stringify(value)).toString('base64url');
    const signature = Buffer.from(await crypto.subtle.sign('HMAC', signer, encoder.encode('yumemi-live/1\n' + payload))).toString('base64url');
    return payload + '.' + signature;
  }
  // 札の署名がその鍵のものか
  const signedBy = async (token, signer) => token.split('.')[1] === Buffer.from(await crypto.subtle.sign('HMAC', signer, encoder.encode('yumemi-live/1\n' + token.split('.')[0]))).toString('base64url');
  const browserCookie = async (id) => (await fetch(base + '/_test/browser?id=' + id)).text();
  const refusedLines = () => logs.join('').split('\n').filter((line) => line.includes('"yumemi":"live.refused"'));
  const lastReason = async (before) => { await until(() => refusedLines().length > before, 1000); const line = refusedLines()[before]; return line ? JSON.parse(line.slice(line.indexOf('{'))).reason : null; };

  // ── 札 ──
  const first = await read('n1', 'sa');
  const token = first.headers.get('x-yumemi-live');
  check('token: a read that passed carries x-yumemi-live', first.status === 200 && typeof token === 'string', [first.status, token]);
  const payload = decode(token);
  const now = Math.floor(Date.now() / 1000);
  check('token: the payload is the destination, the party and an expiry one hour out', payload.to === 'note:n1' && payload.party === 'party-a' && Math.abs(payload.exp - (now + 3600)) <= 5 && Object.keys(payload).sort().join() === 'exp,party,to', payload);
  check('token: holds no value of the Entity', !token.includes('secret') && !JSON.stringify(payload).includes('secret-title'), payload);
  const denied = await read('n1', 'sb');
  check('token: a party that cannot read gets 404 and no token', denied.status === 404 && denied.headers.get('x-yumemi-live') === null, [denied.status, denied.headers.get('x-yumemi-live')]);
  const noBinding = await read('n1', 'sa', 'nobinding');
  check('token: no YUMEMI_LIVE binding, no token', noBinding.status === 200 && noBinding.headers.get('x-yumemi-live') === null, noBinding.status);
  let lines = logs.join('').split('\n').filter((line) => line.includes('live.key_missing')).length;
  const noKey = await read('n1', 'sa', 'nokey');
  const shortKey = await read('n1', 'sa', 'shortkey');
  check('token: no key or a short key, no token and the read still answers 200', noKey.status === 200 && shortKey.status === 200 && noKey.headers.get('x-yumemi-live') === null && shortKey.headers.get('x-yumemi-live') === null, [noKey.status, shortKey.status]);
  await until(() => logs.join('').split('\n').filter((line) => line.includes('live.key_missing')).length >= lines + 2, 1000);
  const keyLines = logs.join('').split('\n').filter((line) => line.includes('live.key_missing')).slice(lines);
  check('token: a missing key is one log line each, with the binding name and the reason', keyLines.length === 2 && keyLines[0].includes('"binding":"YUMEMI_LIVE_KEY"') && keyLines[0].includes('"reason":"absent"') && keyLines[1].includes('"reason":"short"'), keyLines);

  // ── socket の口 ──
  const a1 = await open(token, { session: 'sa' });
  check('socket: the reader with its token opens', a1.open, null);
  const upgraded = await refusal(token, { session: 'sa' });
  check('socket: the same over raw HTTP answers 101', upgraded.status === 101, upgraded);
  const cases = [
    ['another party with the reader\'s token', token, { session: 'sb' }, 'party'],
    ['no session with the reader\'s token', token, {}, 'party'],
    ['another Origin', token, { session: 'sa', originHeader: 'https://evil.example' }, 'origin'],
    ['no Origin', token, { session: 'sa', originHeader: null }, 'origin'],
    ['an expired token', await forge({ to: 'note:n1', party: 'party-a', exp: now - 1 }), { session: 'sa' }, 'expired'],
    ['a token whose party was changed', Buffer.from(JSON.stringify({ ...payload, party: 'party-b' })).toString('base64url') + '.' + token.split('.')[1], { session: 'sb' }, 'signature'],
    ['a token whose destination was changed', Buffer.from(JSON.stringify({ ...payload, to: 'note:n2' })).toString('base64url') + '.' + token.split('.')[1], { session: 'sa' }, 'signature'],
    ['a token signed with another key', await (async () => { const other = await crypto.subtle.importKey('raw', encoder.encode('another-key-0123456789abcdef0123456789'), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']); const p = token.split('.')[0]; return p + '.' + Buffer.from(await crypto.subtle.sign('HMAC', other, encoder.encode('yumemi-live/1\n' + p))).toString('base64url'); })(), { session: 'sa' }, 'signature'],
    ['no token', undefined, { session: 'sa' }, 'token'],
    ['a malformed token', 'abc', { session: 'sa' }, 'token'],
    ['no upgrade', token, { session: 'sa', upgrade: false }, 'upgrade'],
  ];
  for (const [label, value, options, reason] of cases) {
    const before = refusedLines().length;
    const result = await refusal(value, options);
    const logged = await lastReason(before);
    check('socket: ' + label + ' is 403 (reason ' + reason + ')', result.status === 403 && logged === reason, [result.status, logged]);
    if (options.upgrade !== false) {
      // WebSocket の試みも拒否の行を 1 つ出す。次の件の行と取り違えないよう、その行が来るまで待つ
      const lines = refusedLines().length;
      const ws = await open(value, options);
      await until(() => refusedLines().length > lines, 1000);
      check('socket: ' + label + ' cannot open a WebSocket', !ws.open, null);
      if (ws.open) ws.ws.close();
    }
  }
  for (const [label, env, reason] of [['no binding', 'nobinding', 'binding'], ['no key', 'nokey', 'key']]) {
    const before = refusedLines().length;
    const result = await new Promise((resolve) => {
      const url = new URL(socketUrl(token).replace('ws', 'http'));
      const req = httpRequest(url, { headers: { connection: 'Upgrade', upgrade: 'websocket', 'sec-websocket-version': '13', 'sec-websocket-key': 'dGhlIHNhbXBsZSBub25jZQ==', cookie: 'session=sa', origin, 'x-test-env': env } });
      req.on('response', (response) => resolve(response.statusCode));
      req.on('upgrade', (_r, socket) => { socket.destroy(); resolve(101); });
      req.end();
    });
    check('socket: ' + label + ' is 403 (reason ' + reason + ')', result === 403 && await lastReason(before) === reason, result);
  }
  const allRefused = refusedLines();
  check('socket: refusal lines hold neither the token, the key nor the destination', allRefused.length > 0 && allRefused.every((line) => !line.includes(token.split('.')[1]) && !line.includes(token.split('.')[0]) && !line.includes(KEY) && !line.includes('note:')), allRefused.slice(0, 3));

  // ── 合図 ──
  const tokenC = await tokenOf('n1', 'sc');
  const c1 = await open(tokenC, { session: 'sc' });
  const a2 = await open(await tokenOf('n2', 'sa'), { session: 'sa' });
  check('signal: a second reader (party-c) and a reader of another note open', c1.open && a2.open, null);
  const written = await edit('n1', 'changed-by-c', 'sc');
  check('signal: the write answers 200', written.status === 200, written);
  const arrived = await until(() => a1.messages.length >= 1 && c1.messages.length >= 1);
  check('signal: every socket on note:n1 gets it (the writer\'s own page too)', arrived, [a1.messages, c1.messages]);
  check('signal: the signal is the one word 1, no body, no diff, no value', a1.messages.every((m) => m === '1') && c1.messages.every((m) => m === '1') && a1.messages.length === 1, [a1.messages, c1.messages]);
  await sleep(300);
  check('signal: a socket on note:n2 gets nothing', a2.messages.length === 0, a2.messages);
  a1.messages.length = 0; c1.messages.length = 0;
  const refused = await edit('n1', 'refuse', 'sc');
  await sleep(500);
  check('signal: a business failure (nothing committed) sends nothing', refused.status === 422 && a1.messages.length === 0, [refused.status, a1.messages]);
  const rejected = await edit('n1', 'reject', 'sc');
  await sleep(500);
  const rejectRows = (await (await fetch(base + '/_test/state')).json()).rejects;
  check('signal: a refusal that wrote its own row (step.reject) sends nothing', rejected.status === 422 && rejectRows.length === 1 && a1.messages.length === 0, [rejected.status, rejectRows, a1.messages]);
  const outsider = await edit('n1', 'outsider', 'sb');
  await sleep(500);
  check('signal: a write refused by the root (404) sends nothing', outsider.status === 404 && a1.messages.length === 0, [outsider.status, a1.messages]);
  a1.ws.send('ping');
  check('signal: ping is answered pong by the auto response', await until(() => a1.messages.includes('pong'), 1500), a1.messages);
  a1.messages.length = 0;

  // ── 合図が書きの応答を変えない ──
  const baseline = await edit('n1', 'same', 'sc');
  check('token: a write that passed (200) carries no token', baseline.status === 200 && baseline.token === null, [baseline.status, baseline.token]);
  await until(() => a1.messages.length >= 1);
  a1.messages.length = 0;
  for (const env of ['nobinding', 'nokey', 'broken', 'throws', 'slow']) {
    const result = await edit('n1', 'same', 'sc', env);
    check('write: with ' + env + ' the answer is the same status and body', result.status === baseline.status && result.body === baseline.body, [result, baseline]);
    if (env === 'slow') check('write: a publish that takes 3 seconds does not hold the answer', result.ms < 1500, result.ms);
  }
  await sleep(500);
  check('write: no binding or no key sends nothing', a1.messages.length === 0, a1.messages);
  await sleep(3000);
  const state = await (await fetch(base + '/_test/state')).json();
  check('write: the broken, throwing and slow bindings were called (the write did try)', state.calls.broken === 1 && state.calls.throws === 1 && state.calls.slow === 1, state.calls);
  const failedLines = logs.join('').split('\n').filter((line) => line.includes('"yumemi":"live.publish_failed"'));
  check('write: a failed publish is one log line each, without the destination', failedLines.length === 2 && failedLines.every((line) => !line.includes('note:') && !line.includes(KEY)), failedLines);
  check('write: the edit committed in every mode', state.notes.find((n) => n.id === 'n1').title === 'same', state.notes);

  await r2({ call, read, edit, tokenOf, socketUrl, open, refusal, until, decode, forge, signedBy, browserCookie, refusedLines, lastReason, logs, base, origin, a1, newKey });
  for (const ws of [a1, c1, a2]) ws.ws.close();
}

// r2(柏木のゲート 2 の P0-1・P1-2・P1-4・P1-5・P2-1)
async function r2({ call, read, edit, tokenOf, socketUrl, open, refusal, until, decode, forge, signedBy, browserCookie, refusedLines, lastReason, logs, base, origin, a1, newKey }) {
  const refusedAs = async (label, token, options, reason) => {
    const before = refusedLines().length;
    const result = await refusal(token, options);
    const logged = await lastReason(before);
    check(label + ' is 403 (reason ' + reason + ')', result.status === 403 && logged === reason, [result.status, logged]);
    const lines = refusedLines().length;
    const ws = await open(token, options);
    await until(() => refusedLines().length > lines, 1000);
    check(label + ' cannot open a WebSocket', !ws.open, null);
    if (ws.open) ws.ws.close();
  };

  // ── P0-1 張った socket は札の期限で閉じる ──
  const soon = await forge({ to: 'note:n1', party: 'party-a', exp: Math.floor(Date.now() / 1000) + 2 });
  const near = await open(soon, { session: 'sa' });
  // 同じ札の生の socket(close の frame の code を読む。workerd の手元は close の後も TCP を開けたままで、node の
  // WebSocket は CLOSING で止まり close の event も code も出ない)
  const raw = await new Promise((resolve) => {
    const req = httpRequest(new URL(socketUrl(soon).replace('ws', 'http')), { headers: { connection: 'Upgrade', upgrade: 'websocket', 'sec-websocket-version': '13', 'sec-websocket-key': 'dGhlIHNhbXBsZSBub25jZQ==', cookie: 'session=sa', origin } });
    req.on('upgrade', (_r, socket) => { const frames = []; socket.on('data', (d) => frames.push(d)); resolve({ socket, frames }); });
    req.on('response', () => resolve(null));
    req.end();
  });
  check('expiry: a token two seconds from its expiry opens', near.open && raw !== null, null);
  const closedAt = await until(() => near.ws.readyState >= 2, 5000);
  check('expiry: the socket is closed by the server at the expiry without any write', closedAt && near.messages.length === 0, [near.ws.readyState, near.messages]);
  await until(() => raw && Buffer.concat(raw.frames).includes(Buffer.from([0x88])), 2000);
  const frame = raw ? Buffer.concat(raw.frames) : Buffer.alloc(0);
  const at = frame.indexOf(0x88);
  check('expiry: the close frame is code 4001 "expired"', at >= 0 && frame.readUInt16BE(at + 2) === 4001 && frame.subarray(at + 4, at + 2 + (frame[at + 1] & 0x7f)).toString() === 'expired', frame.toString('hex'));
  raw?.socket.destroy();
  a1.messages.length = 0;
  near.messages.length = 0;
  const after = await edit('n1', 'after-expiry', 'sc');
  await until(() => a1.messages.length >= 1);
  await new Promise((resolve) => setTimeout(resolve, 300));
  check('expiry: a write after the expiry does not reach the expired socket (a live one gets it)', after.status === 200 && near.messages.length === 0 && a1.messages.length === 1, [after.status, near.messages, a1.messages]);
  a1.messages.length = 0;
  // alarm の無い器でも、期限の過ぎた socket に publish は送らず閉じる
  const late = await open(await forge({ to: 'note:n1', party: 'party-a', exp: Math.floor(Date.now() / 1000) + 2 }), { session: 'sa', env: 'noalarm' });
  const lateLive = await open(await forge({ to: 'note:n1', party: 'party-a', exp: Math.floor(Date.now() / 1000) + 600 }), { session: 'sa', env: 'noalarm' });
  await new Promise((resolve) => setTimeout(resolve, 3200));
  check('expiry: without the alarm the expired socket is still open before a write', late.open && lateLive.open && late.ws.readyState === 1, [late.open, late.ws?.readyState]);
  const lateWrite = await edit('n1', 'after-expiry-2', 'sc', 'noalarm');
  await until(() => lateLive.messages.length >= 1);
  await until(() => late.ws.readyState >= 2, 1000);
  check('expiry: publish() sends nothing to an expired socket and closes it (a live one gets 1)', lateWrite.status === 200 && late.messages.length === 0 && late.ws.readyState >= 2 && lateLive.messages.length === 1, [lateWrite.status, late.messages, late.ws.readyState, lateLive.messages]);
  for (const ws of [late, lateLive]) if (ws.open) ws.ws.close();
  a1.messages.length = 0;
  // DO の受けは期限の無い・過ぎた・形の違う内部の要求を断る
  const direct = async (query) => (await fetch(base + '/_test/do?' + query)).text();
  const nowSec = Math.floor(Date.now() / 1000);
  const directs = [await direct('upgrade'), await direct('upgrade&exp=' + (nowSec - 1)), await direct('upgrade&exp=abc'), await direct('exp=' + (nowSec + 60))];
  check('expiry: the object refuses an internal request without an expiry, past it or malformed (403), and without upgrade (426)', directs.join() === '403,403,403,426', directs);

  // ── P1-2 party の無い札は browser に結ぶ ──
  const idOne = 'b1'.repeat(16), idTwo = 'b2'.repeat(16);
  const b1 = await browserCookie(idOne), b2 = await browserCookie(idTwo);
  const anon = await call('GET', '/api/public/n3', { browser: b1 });
  const anonToken = anon.headers.get('x-yumemi-live');
  const anonPayload = anonToken ? decode(anonToken) : null;
  check('browser: an anonymous read with a browser cookie carries a token bound to the browser', anon.status === 200 && anonPayload?.party === null && typeof anonPayload?.browser === 'string' && anonPayload.to === 'note:n3', [anon.status, anonPayload]);
  check('browser: the token does not hold the browser id itself', anonToken && !anonToken.includes(idOne) && !JSON.stringify(anonPayload).includes(idOne), anonPayload);
  const bare = await call('GET', '/api/public/n3', {});
  check('browser: an anonymous read without a browser cookie answers 200 and carries no token', bare.status === 200 && bare.headers.get('x-yumemi-live') === null, [bare.status, bare.headers.get('x-yumemi-live')]);
  const anonSocket = await open(anonToken, { browser: b1 });
  check('browser: the same browser opens with its token', anonSocket.open, null);
  await refusedAs('browser: another browser with that token', anonToken, { browser: b2 }, 'browser');
  await refusedAs('browser: no browser cookie with that token', anonToken, {}, 'browser');
  await refusedAs('browser: a session (party-a) with that token', anonToken, { session: 'sa', browser: b1 }, 'party');
  await refusedAs('browser: a forged anonymous token without a browser mark', await forge({ to: 'note:n3', party: null, exp: Math.floor(Date.now() / 1000) + 600 }), {}, 'browser');
  if (anonSocket.open) anonSocket.ws.close();

  // ── 0.14.1 札は表に在る読みだけ(表に無い読みは header ごと無い)──
  const peek = await call('GET', '/api/peek/n1', { session: 'sa' });
  check('scope: a read not in the table answers 200 to its party and carries no token header', peek.status === 200 && !peek.headers.has('x-yumemi-live'), [peek.status, [...peek.headers.keys()]]);
  const open1 = await call('GET', '/api/open/n3', { browser: b1 });
  const open2 = await call('GET', '/api/open/n3', { session: 'sa', browser: b1 });
  check('scope: a public read not in the table carries no token, with or without a session', open1.status === 200 && open2.status === 200 && !open1.headers.has('x-yumemi-live') && !open2.headers.has('x-yumemi-live'), [open1.status, open2.status, open1.headers.get('x-yumemi-live'), open2.headers.get('x-yumemi-live')]);
  const listed = await read('n1', 'sa');
  const listedToken = listed.headers.get('x-yumemi-live');
  check('scope: the read in the table still carries a token bound to its party', listed.status === 200 && decode(listedToken ?? 'e30.x').party === 'party-a' && decode(listedToken ?? 'e30.x').to === 'note:n1', [listed.status, listedToken]);
  const listedSocket = await open(listedToken, { session: 'sa' });
  const peekWrite = await edit('n1', 'after-peek', 'sc');
  check('scope: a write under the same root still signals the socket opened with that token', listedSocket.open && peekWrite.status === 200 && await until(() => listedSocket.messages.includes('1')), [listedSocket.open, peekWrite.status, listedSocket.messages]);
  if (listedSocket.open) listedSocket.ws.close();

  // ── P1-4 鍵の差し替え(YUMEMI_LIVE_KEY_PREVIOUS)──
  const oldToken = await tokenOf('n1', 'sa');
  const rotatedRead = await read('n1', 'sa', 'rotated');
  const rotatedToken = rotatedRead.headers.get('x-yumemi-live');
  check('rotate: during the rotation a read gets a token under the current (new) key', rotatedRead.status === 200 && rotatedToken && await signedBy(rotatedToken, newKey), rotatedToken);
  const oldDuring = await open(oldToken, { session: 'sa', env: 'rotated' });
  check('rotate: a token under the previous key still opens during the rotation', oldDuring.open, null);
  const newDuring = await open(rotatedToken, { session: 'sa', env: 'rotated' });
  check('rotate: a token under the current key opens during the rotation', newDuring.open, null);
  for (const ws of [oldDuring, newDuring]) if (ws.open) ws.ws.close();
  await refusedAs('rotate: after the rotation (no previous key) the old token', oldToken, { session: 'sa', env: 'newonly' }, 'signature');
  await refusedAs('rotate: a token under the previous key with the previous key unset elsewhere (only the old key)', rotatedToken, { session: 'sa' }, 'signature');
  const lines = () => logs.join('').split('\n').filter((line) => line.includes('"binding":"YUMEMI_LIVE_KEY_PREVIOUS"'));
  const beforeShort = lines().length;
  await refusedAs('rotate: a short previous key is not used, the old token', oldToken, { session: 'sa', env: 'shortprevious' }, 'signature');
  await until(() => lines().length > beforeShort, 1000);
  check('rotate: a short previous key logs live.key_missing with its binding name', lines().slice(beforeShort).some((line) => line.includes('"reason":"short"') && line.includes('live.key_missing')), lines().slice(beforeShort));

  // ── P1-5 test の無い道 ──
  const bearer = { authorization: 'Bearer yk_good', 'x-test-host': 'ops.test' };
  const opsRead = await call('GET', '/api/ops/notes/n1', { extra: bearer, originHeader: null });
  check('apikey: a read on the API-key entrance answers 200 without a token', opsRead.status === 200 && opsRead.headers.get('x-yumemi-live') === null, [opsRead.status, opsRead.headers.get('x-yumemi-live')]);
  const opsSocket = await refusal(oldToken, { extra: bearer, originHeader: 'https://ops.test' });
  check('apikey: the API-key entrance has no socket (404, not 101)', opsSocket.status === 404, opsSocket);
  const hooked = { 'x-test-origin-hook': 'https://app.example' };
  const viaHook = await open(oldToken, { session: 'sa', originHeader: 'https://app.example', extra: hooked });
  check('origin hook: the Origin the app\'s origin hook returns opens', viaHook.open, null);
  if (viaHook.open) viaHook.ws.close();
  await refusedAs('origin hook: the entrance host when the hook names another Origin', oldToken, { session: 'sa', extra: hooked }, 'origin');
  a1.messages.length = 0;
  const thrown = await edit('n1', 'throw-after', 'sc');
  const signalled = await until(() => a1.messages.length >= 1);
  check('commit: a write that throws after its commit is a 5xx and still signals', thrown.status >= 500 && signalled && a1.messages.every((m) => m === '1'), [thrown.status, a1.messages]);
  a1.messages.length = 0;
  const sockThrows = await refusal(oldToken, { session: 'sa', env: 'sockthrows' });
  const sockState = (await (await fetch(base + '/_test/state')).json()).calls;
  check('socket: a Durable Object fetch that throws is 503 through the db_error hook, not 101', sockThrows.status === 503 && sockState.sockthrows === 1 && sockState.dbErrorLive === 1, [sockThrows, sockState]);
}

// 開いたままの socket が残っても終わる
main().then(
  () => { process.stdout.write(out.join('\n') + '\n', () => process.exit(0)); },
  (error) => { process.stdout.write(out.join('\n') + '\nNG run ' + (error?.stack ?? error) + '\n', () => process.exit(0)); },
);
