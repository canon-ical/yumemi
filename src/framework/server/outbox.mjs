// yumemi framework/server ── outbox の送り(sweep)と受け(consume)(WGy、0.11.1)。
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
  for(const row of rows) {
   await env.OUTBOX.send({id:row.id});
   await run(db,'framework/outbox_sent',[row.id]);
  }
  return rows.length;
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
