// yumemi-live-1(0.15)── 合図の器・札・socket の口を workerd で回す。`yumemi_live_test_ffi.mjs` が
// `node test/yumemi_live_check.mjs` で走らせ、1 行 1 件の ok / NG を出す。
// `yumemi_live_worker.mjs` を root の esbuild で束ね、root の workerd(devDependencies)に DO の namespace(`YumemiLive`)・
// 鍵・host の binding を付けて載せ、node の WebSocket と HTTP で叩く。workerd の log(stderr)も読む。
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { createServer, request as httpRequest } from 'node:http';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = [];
const check = (name, ok, detail) => out.push((ok ? 'ok ' : 'NG ') + name + (ok ? '' : ' ' + JSON.stringify(detail)));
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const KEY = 'test-live-key-0123456789abcdef0123456789abcdef';

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
  const port = await freePort();
  const host = '127.0.0.1:' + port;
  writeFileSync(join(dir, 'config.capnp'), `using Workerd = import "/workerd/workerd.capnp";
const config :Workerd.Config = (
  services = [(name = "api", worker = .api)],
  sockets = [(name = "http", address = "${host}", http = (), service = "api")],
);
const api :Workerd.Worker = (
  modules = [(name = "worker.js", esModule = embed "worker.js")],
  compatibilityDate = "2026-09-01",
  durableObjectNamespaces = [(className = "YumemiLive", uniqueKey = "yumemi-live-test")],
  durableObjectStorage = (inMemory = void),
  bindings = [
    (name = "YUMEMI_LIVE", durableObjectNamespace = (className = "YumemiLive")),
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
  }
}

async function run({ base, origin, logs }) {
  const call = (method, path, { session, env, body, originHeader = origin } = {}) => {
    const headers = { 'content-type': 'application/json' };
    if (session) headers.cookie = 'session=' + session;
    if (env) headers['x-test-env'] = env;
    if (originHeader) headers.origin = originHeader;
    return fetch(base + path, { method, headers, body: body ? JSON.stringify(body) : undefined });
  };
  const read = (id, session, env) => call('GET', '/api/notes/' + id, { session, env });
  const edit = async (id, title, session, env) => {
    const started = Date.now();
    const response = await call('PUT', '/api/notes/' + id, { session, env, body: { title } });
    return { status: response.status, body: await response.text(), ms: Date.now() - started };
  };
  const tokenOf = async (id, session, env) => (await read(id, session, env)).headers.get('x-yumemi-live');
  const socketUrl = (token) => base.replace('http', 'ws') + '/api/_yumemi/live' + (token === undefined ? '' : '?token=' + encodeURIComponent(token));
  // 開けた socket。届いた字を貯める
  function open(token, { session, originHeader = origin } = {}) {
    return new Promise((resolve) => {
      const headers = {};
      if (session) headers.cookie = 'session=' + session;
      if (originHeader) headers.origin = originHeader;
      const ws = new WebSocket(socketUrl(token), { headers });
      const messages = [];
      ws.onmessage = (event) => messages.push(String(event.data));
      ws.onopen = () => resolve({ open: true, ws, messages });
      ws.onerror = () => resolve({ open: false });
    });
  }
  // 拒否の status と本文(WebSocket の API は status を見せないので、HTTP で upgrade を求める)
  function refusal(token, { session, originHeader = origin, upgrade = true } = {}) {
    return new Promise((resolve, reject) => {
      const url = new URL(socketUrl(token).replace('ws', 'http'));
      const headers = {};
      if (upgrade) Object.assign(headers, { connection: 'Upgrade', upgrade: 'websocket', 'sec-websocket-version': '13', 'sec-websocket-key': 'dGhlIHNhbXBsZSBub25jZQ==' });
      if (session) headers.cookie = 'session=' + session;
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
  async function forge(value) {
    const payload = Buffer.from(JSON.stringify(value)).toString('base64url');
    const signature = Buffer.from(await crypto.subtle.sign('HMAC', key, encoder.encode('yumemi-live/1\n' + payload))).toString('base64url');
    return payload + '.' + signature;
  }
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
  const failedWrite = await call('PUT', '/api/notes/n1', { session: 'sa', body: { title: 'refuse' } });
  check('token: a write answer carries no token', failedWrite.headers.get('x-yumemi-live') === null, failedWrite.status);
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
      const ws = await open(value, options);
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

  for (const ws of [a1, c1, a2]) ws.ws.close();
}

main().then(
  () => { process.stdout.write(out.join('\n') + '\n'); },
  (error) => { process.stdout.write(out.join('\n') + '\nNG run ' + (error?.stack ?? error) + '\n'); },
);
