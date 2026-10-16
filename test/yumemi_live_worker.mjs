// yumemi-live-1(0.15)── workerd で回す試験用の api の Worker。`yumemi_live_check.mjs` が esbuild で束ねて workerd に載せる。
// 入口(http の検査 1〜10)・runtime・Cloudflare の adapter(`handlers` と DO `YumemiLive`)は framework の本物で、app の
// 表(registry・root・verb)と DB だけが偽物(module の中の Map)。
// 題材:note の 2 件。n1 は party-a と party-c が読み書きでき、n2 は party-a だけ。party-b はどちらも読めない(root の
// 1 文が持ち主で絞る = 404)。session の cookie は `session=sa|sb|sc`。
// 試験の切り替え:header `x-test-env` で env を替える(`nobinding` / `nokey` / `shortkey` / `broken` / `slow` / `throws`)。
import { http } from '../build/dev/javascript/yumemi/yumemi/server/http.mjs';
import { runtime } from '../build/dev/javascript/yumemi/yumemi/server/runtime.mjs';
import { handlers, YumemiLive } from '../build/dev/javascript/yumemi/yumemi/server/worker.mjs';
import * as step from '../build/dev/javascript/yumemi/yumemi/step.mjs';
import * as verb from '../build/dev/javascript/yumemi/yumemi/verb.mjs';

export { YumemiLive };

const notes = new Map([
  ['n1', { id: 'n1', title: 'secret-title-1', owners: ['party-a', 'party-c'] }],
  ['n2', { id: 'n2', title: 'secret-title-2', owners: ['party-a'] }],
]);
// 断り(`step.reject`)が書いた行
const rejects = [];
const sessions = { sa: 'party-a', sb: 'party-b', sc: 'party-c' };
// 合図の器の呼び(`slow` / `broken` / `throws` の偽の binding が数える)
const calls = { slow: 0, broken: 0, throws: 0 };

function exec(key, params) {
  switch (key) {
    case 'note/root': {
      const note = notes.get(params[0]);
      return note && note.owners.includes(params[1]) ? [{ id: note.id, title: note.title }] : [];
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
const service = (effect, Args, logic) => ({ effect: tagged(effect), service: { allow }, Args, logic, requires: [] });
const registry = [
  { name: 'note_read', module: service('read', ReadArgs, (_a, _r, args) => step.done({ id: args.id })), root: { Root }, method: 'GET', path: '/api/notes/:id', fields: ['id'], args: [['id', ['text']]] },
  { name: 'note_edit', module: service('write', EditArgs, (_a, _r, args) => {
    if (args.title === 'refuse') return step.fail(tagged('refused'));
    // 断りの verb だけを書く(書きの transaction は commit するが、応答は業務の失敗)
    if (args.title === 'reject') return step.reject(verb.staged((ctx) => ctx.stage('reject_note', { id: args.id })), tagged('rejected'));
    return step.apply(verb.staged((ctx) => ctx.stage('edit_note', { id: args.id, title: args.title })), () => step.done({ id: args.id }));
  }), root: { Root }, method: 'PUT', path: '/api/notes/:id', fields: ['id', 'title'], args: [['id', ['text']], ['title', ['text']]] },
];
// 生成の registry の `live` と同じ形
const live = { note_read: ['note', 'id'], note_edit: ['note', 'id'] };
const roots = { note_read: { sql: 'note/root', params: ['arg:id', 'party'], values: [] }, note_edit: { sql: 'note/root', params: ['arg:id', 'party'], values: [] } };
const SQL = { 'note/root': '-- root', 'verb/edit_note': '-- edit', 'verb/reject_note': '-- reject', 'framework/audit': '-- audit' };
const rt = runtime({
  SQL, c, roots, actors: {}, manualVerbs: { names: new Set() }, connectors: {}, connectorNames: {}, folds: {}, enqueues: {},
  boundaries: new Set(), relationDecoders: {}, phaseModules: {}, encoders: {}, carried: {}, reads: {}, subjects: [],
  verbs: { edit_note: { key: 'verb/edit_note', params: [['f', 'id', null], ['f', 'title', null]] }, reject_note: { key: 'verb/reject_note', params: [['f', 'id', null]] } }, drafts: {},
});
rt.resolveSession = async (_db, id) => (sessions[id] ? { id, party: sessions[id] } : null);
class Ok { constructor(value) { this[0] = value; } }
class Er { constructor(value) { this[0] = value; } }
const h = http({ c, registry, live, attached: [], Ok, Error: Er, hosts: { www: 'WWW_HOST' }, runtime: rt, roles: {}, ports: {}, accepted: {},
  args: {}, hooks: {}, phaseGates: {}, entryCredential: () => tagged('session') });
const entries = [{ name: 'www', hosts: ['WwwHost'], prefix: '/api', admit: tagged('anyone'), subject: tagged('any_subject'), services: tagged('all') }];

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
function testEnv(env, mode) {
  const fake = (publish) => ({ idFromName: (name) => name, get: () => ({ publish, fetch: () => new Response(null, { status: 500 }) }) });
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
  }
  return env;
}

export default {
  async fetch(request, env, execution) {
    const url = new URL(request.url);
    if (url.pathname === '/_test/state') return Response.json({ notes: [...notes.values()], calls, rejects });
    return worker.fetch(request, testEnv(env, request.headers.get('x-test-env')), execution);
  },
};
