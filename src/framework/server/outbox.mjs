// yumemi framework/server ── outbox の送り(sweep)と受け(consume)(WGy、0.11.1)。
// 0.11.6:sweep は行を送る前に `framework/outbox_claim`(条件付き UPDATE)で取る。重なった sweep は同じ行を
// 取れず、送らない。`recording(db)` は要求の中で outbox へ INSERT する文が commit されたかを数える(fetch の口が使う)。
import { strip } from './read_retry.mjs';

// outbox へ INSERT する文か(生成の outbox_parent / outbox_child も、手書きの SQL の `WITH … INSERT` も)。
// 注釈と文字列の中の字は数えない。引用識別子(`"framework"."outbox"`)は見ない
const insertsOutbox=text=>/\binsert\s+into\s+framework\s*\.\s*outbox\b/i.test(strip(text??''));

/**
 * db を包み、outbox へ INSERT する文が成功で返ったか(commit されたか)を `wrote()` で返す。
 * 失敗した文・rollback した transaction は数えない。読みしか無い要求では何も足さない(文の字を見るだけ)。
 */
export function recording(db) {
 let wrote=false;
 const tracked=Object.assign(Object.create(db),{
  async query(text,params,key) { const rows=await db.query(text,params,key); if(insertsOutbox(text)) wrote=true; return rows; },
  async transaction(operations) { const result=await db.transaction(operations); if(operations.some(x=>insertsOutbox(x.sql))) wrote=true; return result; },
 });
 return {db:tracked,wrote:()=>wrote};
}

// 表(kind の集合・id の codec・consumer の対応)は app の生成物 `gen/queue_runtime.mjs` が渡す。
//
// - `kinds`: 送る kind の名(`framework/outbox_sweep` の `$1`)
// - `ids`: kind -> { id: <scalar の名>, versioned?: true }。versioned は Args が (id, version)、それ以外は (id, event)
// - `consumers`: kind -> { base, module, root, actor, party?, field }。root の 1 文を持たない consumer は、
//   base の Service の root を読み、`field` の Entity と相だけを写して自分の Root を作る。`party` は借りた root を
//   読む session の party(app の `server.roots` の `QueueParty`)。無ければ party 無しで読む
// - `registry`(byName)/ `codec` / `runtime`(run・invoke・loadRoot・makeContext・step)は app の生成物の
//   module 名前空間。生成物どうしが循環して import するので、中身は呼ばれた時に読む
export function outbox({ kinds, ids, consumers, registry, codec, runtime }) {
 const run=(...args)=>runtime.run(...args);
 async function sweep(db,env) {
  const rows=await run(db,'framework/outbox_sweep',[kinds]);
  let sent=0;
  for(const row of rows) {
   // 送る前に sent_at を進める。先に取った sweep があれば 0 行で、この sweep は送らない
   const claimed=await run(db,'framework/outbox_claim',[row.id]);
   if(!claimed?.length) continue;
   await env.OUTBOX.send({id:row.id});
   sent++;
  }
  return sent;
 }
 async function consume(message,db,env,connectors) {
  const row=(await run(db,'framework/outbox_get',[message.id]))[0];
  const { invoke, loadRoot, makeContext, step } = runtime;
  const byName = registry.byName;
  const id_codec=ids[row?.kind];
  if(!row||!id_codec) return;
  const consumer=consumers[row.kind];
  const record=consumer
   ? {...byName[consumer.base],name:row.kind,module:consumer.module,root:consumer.root,fields:['id','event'],folded:null}
   : byName[row.kind];
  const payload=row.payload;
  if(!payload||typeof payload.id!=='string') throw new Error('invalid outbox payload');
  const id=codec.parse(id_codec.id,payload.id);
  let args;
  if(id_codec.versioned) {
   if(!Number.isInteger(payload.version)) throw new Error('invalid outbox payload');
   args=new record.module.Args(id,payload.version);
  } else args=new record.module.Args(id,codec.parse('event_id',row.id));
  if(consumer) {
   const baseRecord=byName[consumer.base];
   const resolved=consumer.party?{party:consumer.party}:null;
   const state={record:baseRecord,args,db,env,connectors,resolved,clauses:[{phases:null,owner:'no_owner'}],at:new Date().toISOString(),seed:crypto.randomUUID(),eventId:row.id};
   await loadRoot(state);
   const loaded=state.root;
   state.record=record;
   state.root=new record.root.Root(loaded[consumer.field],loaded.phase,loaded.at,loaded.seed);
   state.actor=consumer.actor();
   const context=makeContext(state);
   return step.interpret(record.module.logic(state.actor,state.root,args),context);
  }
  await invoke({record,args,db,env,connectors,resolved:null,clauses:[{phases:null,owner:'no_owner'}],at:new Date().toISOString(),seed:crypto.randomUUID(),eventId:row.id});
 }
 return { sweep, consume };
}
