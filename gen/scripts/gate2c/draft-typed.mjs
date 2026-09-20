// 柏木ゲート 2(3 回目、2026-09-20)の再現スクリプトの写し。原本は yumemi-gen-3/build/gate2c/evidence/draft-typed.mjs。
// 変えたのは接続先と生成物の在処だけ(環境変数 PGPORT / PGDATABASE / DRAFT_HARNESS / FLAG_OUT)── 経路と検査はそのまま。
// harness の 3 import は在処が環境変数なので dynamic import に書き換えた(順序・中身は同じ)。
import fs from 'node:fs';
import assert from 'node:assert/strict';
import pg from '/home/yumemism/yumemism_repo/musearch/app/node_modules/pg/lib/index.js';
const { operation } = await import(`${process.env.DRAFT_HARNESS}/build/dev/javascript/gate_draft/probe.mjs`);
const { stage } = await import(`${process.env.DRAFT_HARNESS}/build/dev/javascript/yumemi/framework/verb.mjs`);
const { ChunkCreated } = await import(`${process.env.DRAFT_HARNESS}/build/dev/javascript/gate_draft/gen/draft/chunk.mjs`);
const client=new pg.Client({host:process.env.PGHOST??'127.0.0.1',port:Number(process.env.PGPORT??55432),user:process.env.PGUSER??'yumemism',database:process.env.PGDATABASE??'gate2c_kashiwagi_3947'});
await client.connect();
try {
  await client.query('BEGIN');
  await client.query('CREATE SCHEMA gate2c_draft; CREATE TABLE gate2c_draft.chunk(a int,b int,c int,text text,PRIMARY KEY(a,b,c))');
  const sql=fs.readFileSync(`${process.env.FLAG_OUT}/db/queries/verb/create_chunk.sql`,'utf8').replaceAll('app.','gate2c_draft.');
  const value=await stage(operation(), {async stage(name,input){
    assert.equal(name,'create_chunk');
    assert.equal(input.constructor.name,'ChunkDraft');
    await client.query(sql,Object.values(input));
    return new ChunkCreated(input.a,input.b,input.c,input.text);
  }});
  const rows=(await client.query('SELECT * FROM gate2c_draft.chunk')).rows;
  assert.deepEqual(rows,[{a:11,b:7,c:1,text:'typed-composite-key'}]);
  console.log('P0-7 PASS: compiled Gleam ChunkDraft -> generated create_chunk -> framework verb.stage -> test PG adapter -> generated SQL:',JSON.stringify(rows));
  console.log('Created:',JSON.stringify(value));
  console.log('Adapter is audit-only; musearch runtime compatibility is not asserted.');
} finally {await client.query('ROLLBACK'); await client.end();}
