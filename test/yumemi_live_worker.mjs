// yumemi-live-1(0.15)── workerd で回す試験用の api の Worker。`yumemi_live_check.mjs` が esbuild で束ねて workerd に載せる。
// 入口(http の検査 1〜10)・runtime・Cloudflare の adapter(`handlers` と DO `YumemiLive`)は framework の本物で、app の
// 表(registry・root・verb)と DB だけが偽物(module の中の Map)。
// 題材:note の 2 件。n1 は party-a と party-c が読み書きでき、n2 は party-a だけ。party-b はどちらも読めない(root の
// 1 文が持ち主で絞る = 404)。n3 は誰でも読める(`note_public`、session の無い読み)。session の cookie は
// `session=sa|sb|sc`、browser の署名 cookie は `yb=<GET /_test/browser?id=… の値>`。
// 入口:`www`(session、prefix `/api`)と `ops`(API key、同じ prefix、host は `OPS_HOST`、`Bearer yk_good` が party-a)。
// 試験の切り替え:header `x-test-env` で env を替える(`nobinding` / `nokey` / `shortkey` / `broken` / `slow` / `throws` /
// `sockthrows` / `rotated` / `newonly` / `shortprevious`)。header `x-test-host` で要求の host を替える(`ops` の入口)。
// header `x-test-origin-hook` が在れば ★ の `origin` hook がその値を返す。
import { http } from '../build/dev/javascript/yumemi/yumemi/server/http.mjs';
import { runtime } from '../build/dev/javascript/yumemi/yumemi/server/runtime.mjs';
import { handlers, YumemiLive } from '../build/dev/javascript/yumemi/yumemi/server/worker.mjs';
import * as step from '../build/dev/javascript/yumemi/yumemi/step.mjs';
import * as verb from '../build/dev/javascript/yumemi/yumemi/verb.mjs';

export { YumemiLive };
// alarm を置かない器(`publish()` が期限の過ぎた socket に送らないことを、alarm に先を越されずに見る。env `noalarm`)
export class YumemiLiveNoAlarm extends YumemiLive { async schedule() {} }

const notes = new Map([
  ['n1', { id: 'n1', title: 'secret-title-1', owners: ['party-a', 'party-c'] }],
  ['n2', { id: 'n2', title: 'secret-title-2', owners: ['party-a'] }],
  ['n3', { id: 'n3', title: 'public-title-3', owners: [], public: true }],
]);
// 断り(`step.reject`)が書いた行
const rejects = [];
const sessions = { sa: 'party-a', sb: 'party-b', sc: 'party-c' };
// 合図の器の呼び(`slow` / `broken` / `throws` の偽の binding が数える)
const calls = { slow: 0, broken: 0, throws: 0, sockthrows: 0, dbErrorLive: 0 };
// 鍵の差し替えの試験の今の鍵
const NEW_KEY = 'test-live-key-new-fedcba9876543210fedcba9876543210';

function exec(key, params) {
  switch (key) {
    case 'note/root': {
      const note = notes.get(params[0]);
      return note && note.owners.includes(params[1]) ? [{ id: note.id, title: note.title }] : [];
    }
    case 'note/public_root': {
      const note = notes.get(params[0]);
      return note?.public ? [{ id: note.id, title: note.title }] : [];
    }
    case 'verb/edit_note': { const note = notes.get(params[0]); if (note) note.title = params[1]; return []; }
    case 'verb/reject_note': rejects.push(params[0]); return [];
    case 'framework/audit': return [];
  }
  throw new Error('unknown key ' + key);
}
const database = () => ({
  async query(_text, params, key) { return exec(key, params); },
  async transaction(operations) { return operations.map((x) => exec(x.key, x.params)); },
});

const tagged = (tag) => ({ tag });
const c = {
  tag: (value) => value?.tag,
  encode: (value) => (value && typeof value === 'object' ? JSON.parse(JSON.stringify(value)) : value ?? null),
  parse: (_scalar, value) => value, text: (value) => value, checked: (value) => value, unwrap: (value) => value,
  time: { datetime: (value) => value }, party: { parse: (value) => value },
  scalar: {}, er: {}, toList: (x) => x,
};
class Root { constructor(at, seed) { this.at = at; this.seed = seed; } }
class ReadArgs { constructor(id) { this.id = id; } }
class EditArgs { constructor(id, title) { this.id = id; this.title = title; } }
const allow = [{ who: tagged('party'), at: tagged('any_phase'), owner: tagged('no_owner') }];
const anyone = [{ who: tagged('anyone'), at: tagged('any_phase'), owner: tagged('no_owner') }];
const service = (effect, Args, logic, rule = allow) => ({ effect: tagged(effect), service: { allow: rule }, Args, logic, requires: [] });
const registry = [
  { name: 'note_read', module: service('read', ReadArgs, (_a, _r, args) => step.done({ id: args.id })), root: { Root }, method: 'GET', path: '/api/notes/:id', fields: ['id'], args: [['id', ['text']]] },
  { name: 'note_edit', module: service('write', EditArgs, (_a, _r, args) => {
    if (args.title === 'refuse') return step.fail(tagged('refused'));
    // 断りの verb だけを書く(書きの transaction は commit するが、応答は業務の失敗)
    if (args.title === 'reject') return step.reject(verb.staged((ctx) => ctx.stage('reject_note', { id: args.id })), tagged('rejected'));
    // commit の後に投げる(応答の本文を作るところで落ちる)
    if (args.title === 'throw-after') return step.apply(verb.staged((ctx) => ctx.stage('edit_note', { id: args.id, title: args.title })), () => step.done({ id: args.id, toJSON() { throw new Error('after commit'); } }));
    return step.apply(verb.staged((ctx) => ctx.stage('edit_note', { id: args.id, title: args.title })), () => step.done({ id: args.id }));
  }), root: { Root }, method: 'PUT', path: '/api/notes/:id', fields: ['id', 'title'], args: [['id', ['text']], ['title', ['text']]] },
  { name: 'note_read_ops', credential: 'api_key', module: service('read', ReadArgs, (_a, _r, args) => step.done({ id: args.id })), root: { Root }, method: 'GET', path: '/api/ops/notes/:id', fields: ['id'], args: [['id', ['text']]] },
  { name: 'note_public', module: service('read', ReadArgs, (_a, _r, args) => step.done({ id: args.id }), anyone), root: { Root }, method: 'GET', path: '/api/public/:id', fields: ['id'], args: [['id', ['text']]] },
];
// 生成の registry の `live` と同じ形
const live = { note_read: ['note', 'id'], note_edit: ['note', 'id'], note_public: ['note', 'id'], note_read_ops: ['note', 'id'] };
const roots = { note_read: { sql: 'note/root', params: ['arg:id', 'party'], values: [] }, note_edit: { sql: 'note/root', params: ['arg:id', 'party'], values: [] }, note_public: { sql: 'note/public_root', params: ['arg:id'], values: [] }, note_read_ops: { sql: 'note/root', params: ['arg:id', 'party'], values: [] } };
const SQL = { 'note/root': '-- root', 'note/public_root': '-- public root', 'verb/edit_note': '-- edit', 'verb/reject_note': '-- reject', 'framework/audit': '-- audit' };
const rt = runtime({
  SQL, c, roots, actors: {}, manualVerbs: { names: new Set() }, connectors: {}, connectorNames: {}, folds: {}, enqueues: {},
  boundaries: new Set(), relationDecoders: {}, phaseModules: {}, encoders: {}, carried: {}, reads: {}, subjects: [],
  verbs: { edit_note: { key: 'verb/edit_note', params: [['f', 'id', null], ['f', 'title', null]] }, reject_note: { key: 'verb/reject_note', params: [['f', 'id', null]] } }, drafts: {},
});
rt.resolveSession = async (_db, id) => (sessions[id] ? { id, party: sessions[id] } : null);
rt.apiKeyHmac = async (_env, plain) => 'digest:' + plain;
rt.resolveApiKey = async (_db, digest) => (digest === 'digest:yk_good' ? { party: 'party-a' } : null);
class Ok { constructor(value) { this[0] = value; } }
class Er { constructor(value) { this[0] = value; } }
const hooks = {
  origin: (s) => s.request.headers.get('x-test-origin-hook') ?? undefined,
  db_error: (s) => { if (s.live) calls.dbErrorLive++; return undefined; },
};
const h = http({ c, registry, live, attached: [], Ok, Error: Er, hosts: { www: 'WWW_HOST', ops: 'OPS_HOST' }, runtime: rt, roles: {}, ports: {}, accepted: {},
  args: {}, hooks, phaseGates: {}, apiKeyPattern: 'yk_[a-z]+',
  browserCookie: { cookie: 'yb', binding: 'BROWSER_KEY', maxAgeDays: 30, declarations: [] },
  entryCredential: (entry) => tagged(entry.name === 'ops' ? 'api_key' : 'session') });
const entries = [
  { name: 'www', hosts: ['WwwHost'], prefix: '/api', admit: tagged('anyone'), subject: tagged('any_subject'), services: tagged('all') },
  { name: 'ops', hosts: ['OpsHost'], prefix: '/api', admit: tagged('anyone'), subject: tagged('any_subject'), services: tagged('all') },
];

async function dispatch(input) {
  let result = await h.host(input, entries);
  for (const stage of [h.route, h.origin, h.browser, h.admit, h.resolve, h.subject, h.decode, h.judge]) {
    if (result instanceof Er) return result[0];
    result = await stage(result[0]);
  }
  if (result instanceof Er) return result[0];
  return h.execute(result[0]);
}
const worker = handlers({ dispatch, database, observe: () => {}, sweep: async () => 0, consume: async () => {} });

// 試験の env。偽の binding は呼ばれた数を数える
function testEnv(base, mode) {
  const fake = (publish, fetch = () => new Response(null, { status: 500 })) => ({ idFromName: (name) => name, get: () => ({ publish, fetch }) });
  // browser の鍵は Secret Store の形(`.get()`)
  const env = { ...base, BROWSER_KEY: { get: async () => 'test-browser-key-0123456789abcdef0123456789' }, OPS_HOST: 'ops.test' };
  switch (mode) {
    case 'nobinding': { const { YUMEMI_LIVE, ...rest } = env; return rest; }
    case 'nokey': { const { YUMEMI_LIVE_KEY, ...rest } = env; return rest; }
    case 'shortkey': return { ...env, YUMEMI_LIVE_KEY: 'short' };
    // DO の publish が落ちる
    case 'broken': return { ...env, YUMEMI_LIVE: fake(async () => { calls.broken++; throw new Error('do down'); }) };
    // DO の publish が 3 秒かかる
    case 'slow': return { ...env, YUMEMI_LIVE: fake(async () => { calls.slow++; await new Promise((resolve) => setTimeout(resolve, 3000)); return 0; }) };
    // namespace の get が投げる
    case 'throws': return { ...env, YUMEMI_LIVE: { idFromName: () => { calls.throws++; throw new Error('namespace down'); }, get: () => { throw new Error('x'); } } };
    // DO の fetch(socket の受け)が投げる
    case 'sockthrows': return { ...env, YUMEMI_LIVE: fake(async () => 0, async () => { calls.sockthrows++; throw new Error('do fetch down'); }) };
    // 鍵の差し替えの途中(今の鍵が新しい鍵、前の鍵が元の鍵)・差し替えの後(新しい鍵だけ)・前の鍵が短い
    case 'rotated': return { ...env, YUMEMI_LIVE_KEY: NEW_KEY, YUMEMI_LIVE_KEY_PREVIOUS: env.YUMEMI_LIVE_KEY };
    case 'newonly': return { ...env, YUMEMI_LIVE_KEY: NEW_KEY };
    case 'noalarm': return { ...env, YUMEMI_LIVE: env.YUMEMI_LIVE_NOALARM };
    case 'shortprevious': return { ...env, YUMEMI_LIVE_KEY: NEW_KEY, YUMEMI_LIVE_KEY_PREVIOUS: 'short' };
  }
  return env;
}

export default {
  async fetch(request, env, execution) {
    const url = new URL(request.url);
    const current = testEnv(env, request.headers.get('x-test-env'));
    if (url.pathname === '/_test/state') return Response.json({ notes: [...notes.values()], calls, rejects });
    // DO の受けを入口を通さずに叩く(期限の無い・過ぎた内部の要求を断るか)
    if (url.pathname === '/_test/do') {
      const headers = new Headers(url.searchParams.has('upgrade') ? { upgrade: 'websocket' } : {});
      if (url.searchParams.has('exp')) headers.set('x-yumemi-live-exp', url.searchParams.get('exp'));
      const answer = await env.YUMEMI_LIVE.get(env.YUMEMI_LIVE.idFromName('note:direct')).fetch(new Request('https://yumemi-live.internal/socket', { headers }));
      return new Response(String(answer.status));
    }
    if (url.pathname === '/_test/browser') return new Response(await h.signBrowser(current, url.searchParams.get('id'), {}));
    const host = request.headers.get('x-test-host');
    if (host) { url.host = host; url.port = ''; request = new Request(url, request); }
    return worker.fetch(request, current, execution);
  },
};
