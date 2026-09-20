// 柏木ゲート 2(3 回目、2026-09-20)の再現スクリプトの写し。原本は yumemi-gen-3/build/gate2c/evidence/reorder-concurrent.mjs。
// 変えたのは接続先と生成物の在処だけ(環境変数 PGPORT / PGDATABASE / ARTICLE_OUT)── 経路と検査はそのまま。
import fs from 'node:fs';
import assert from 'node:assert/strict';
import pg from '/home/yumemism/yumemism_repo/musearch/app/node_modules/pg/lib/index.js';
const config={host:process.env.PGHOST??'127.0.0.1',port:Number(process.env.PGPORT??55432),user:process.env.PGUSER??'yumemism',database:process.env.PGDATABASE??'gate2c_kashiwagi_3947'};
const [a,b,monitor]=[new pg.Client(config),new pg.Client(config),new pg.Client(config)];
await Promise.all([a.connect(),b.connect(),monitor.connect()]);
const read=name=>fs.readFileSync(`${process.env.ARTICLE_OUT}/db/queries/verb/${name}.sql`,'utf8').replaceAll('app.','gate2c_concurrent.').replaceAll('framework.require_rows','gate2c_concurrent.require_rows');
try {
 await monitor.query(`CREATE SCHEMA gate2c_concurrent;
 CREATE FUNCTION gate2c_concurrent.require_rows(bigint,text) RETURNS bigint LANGUAGE sql AS 'SELECT $1';
 CREATE TABLE gate2c_concurrent.article(slug text PRIMARY KEY,"order" int,category_id text,UNIQUE(category_id,"order"));
 INSERT INTO gate2c_concurrent.article VALUES('a',0,'cat'),('b',1,'cat');`);
 await a.query('BEGIN');await b.query('BEGIN');
 await a.query(read('reorder_articles_stage'),['cat','["b","a"]']);
 const pending=b.query(read('reorder_articles_stage'),['cat','["a","b"]']);
 let locked=false;
 for(let i=0;i<100;i++) {
  const states=await monitor.query('SELECT wait_event_type FROM pg_stat_activity WHERE pid=$1',[b.processID]);
  if(states.rows[0]?.wait_event_type==='Lock'){locked=true;break;}
  await new Promise(r=>setTimeout(r,10));
 }
 assert.equal(locked,true);
 await a.query(read('reorder_articles'),['cat','["b","a"]']);await a.query('COMMIT');
 await pending;
 await b.query(read('reorder_articles'),['cat','["a","b"]']);await b.query('COMMIT');
 const rows=(await monitor.query('SELECT slug,"order" FROM gate2c_concurrent.article ORDER BY slug')).rows;
 assert.deepEqual(rows,[{slug:'a',order:0},{slug:'b',order:1}]);
 console.log('same-scope concurrent transactions PASS; observed second transaction waiting on Lock;',JSON.stringify(rows));
} finally { await a.query('ROLLBACK');await b.query('ROLLBACK');await monitor.query('DROP SCHEMA IF EXISTS gate2c_concurrent CASCADE');await Promise.all([a.end(),b.end(),monitor.end()]); }
