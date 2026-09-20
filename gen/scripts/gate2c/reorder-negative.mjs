// 柏木ゲート 2(3 回目、2026-09-20)の再現スクリプトの写し。原本は yumemi-gen-3/build/gate2c/evidence/reorder-negative.mjs。
// 変えたのは接続先と生成物の在処だけ(環境変数 PGPORT / PGDATABASE / ARTICLE_OUT)── 経路と検査はそのまま。
import fs from 'node:fs';
import assert from 'node:assert/strict';
import pg from '/home/yumemism/yumemism_repo/musearch/app/node_modules/pg/lib/index.js';
const client = new pg.Client({host:process.env.PGHOST??'127.0.0.1',port:Number(process.env.PGPORT??55432),user:process.env.PGUSER??'yumemism',database:process.env.PGDATABASE??'gate2c_kashiwagi_3947'});
await client.connect();
const read = name => fs.readFileSync(`${process.env.ARTICLE_OUT}/gen/sql/queries/verb/${name}.sql`,'utf8').replaceAll('app.', 'gate2c_reorder.').replaceAll('framework.require_rows','gate2c_reorder.require_rows');
try {
  await client.query(`CREATE SCHEMA gate2c_reorder;
    CREATE FUNCTION gate2c_reorder.require_rows(bigint,text) RETURNS bigint LANGUAGE sql AS 'SELECT $1';
    CREATE TABLE gate2c_reorder.article(slug text PRIMARY KEY,"order" integer,category_id text,UNIQUE(category_id,"order"));
    INSERT INTO gate2c_reorder.article VALUES('a',-1,'cat'),('b',-2,'cat');`);
  await client.query('BEGIN');
  let code;
  try {
    await client.query(read('reorder_articles_stage'), ['cat',JSON.stringify(['b','a'])]);
    await client.query(read('reorder_articles'), ['cat',JSON.stringify(['b','a'])]);
    await client.query('COMMIT');
  } catch (error) { code=error.code; console.log('negative input:',error.code,error.message); await client.query('ROLLBACK'); }
  console.log('persisted:',JSON.stringify((await client.query('SELECT * FROM gate2c_reorder.article ORDER BY slug')).rows));
  assert.equal(code,'23505');
  await client.query('TRUNCATE gate2c_reorder.article');
  await client.query('ALTER TABLE gate2c_reorder.article ADD CHECK ("order">=0)');
  await client.query(`INSERT INTO gate2c_reorder.article VALUES('a',0,'cat'),('b',1,'cat')`);
  await client.query('BEGIN');
  try { await client.query(read('reorder_articles_stage'), ['cat',JSON.stringify(['b','a'])]); }
  catch(error){ console.log('nonnegative CHECK:',error.code,error.message); assert.equal(error.code,'23514'); }
  await client.query('ROLLBACK');
  console.log('P0-3 REPRODUCED: negative staging collides with valid Int values and rejects nonnegative CHECK');
} finally { await client.query('DROP SCHEMA IF EXISTS gate2c_reorder CASCADE'); await client.end(); }
