// 柏木ゲート 2(3 回目、2026-09-20)の再現スクリプトの写し。原本は yumemi-gen-3/build/gate2c/evidence/root-real.mjs。
// 変えたのは接続先と生成物の在処だけ(環境変数 PGPORT / PGDATABASE / ROOT_HARNESS)── 経路と検査はそのまま。
// harness の 3 import は在処が環境変数なので dynamic import に書き換えた(順序・中身は同じ)。
import assert from 'node:assert/strict';
import { decodeArticle } from '/home/yumemism/yumemism_repo/musearch/app/build/dev/javascript/musearch_app/gen/codec.mjs';
import { makeContext } from '/home/yumemism/yumemism_repo/musearch/app/build/dev/javascript/musearch_app/gen/runtime.mjs';
const { Root } = await import(`${process.env.ROOT_HARNESS}/build/dev/javascript/gate_root/gen/root/article_read.mjs`);
const { to_muse } = await import(`${process.env.ROOT_HARNESS}/build/dev/javascript/gate_root/gen/reads/article_read.mjs`);
const { interpret, fail } = await import(`${process.env.ROOT_HARNESS}/build/dev/javascript/yumemi/framework/step.mjs`);

const article = decodeArticle({
  id: '00000000-0000-0000-0000-000000000001',
  muse_id: '00000000-0000-0000-0000-000000000002',
  title: 'title', body: 'body', images: [], version: 7,
  slot: null, posted_on: null, publish_at: null,
});
const root = new Root(article, null, null, 'gate2c');
let databaseCalls = 0;
const context = makeContext({record:{name:'article_read'}, db:{query(){ databaseCalls++; throw new Error('unexpected query'); }}, root, at:'2026-09-20T00:00:00Z', seed:'gate2c'});
let received;
await interpret(to_muse(root, value => { received=value; return fail('captured'); }), context);
console.log(JSON.stringify({actual:received.constructor.name, fields:Object.keys(received), expected:'Muse', databaseCalls, sameAsHeld:received===article.muse}));
assert.equal(received, article.muse);
assert.equal(received.constructor.name, 'Held');
assert.equal(received.id, undefined);
console.log('P0-5 REPRODUCED: compiled generated read passes Held(Muse) to fn(Muse), without retrieval/decode');
