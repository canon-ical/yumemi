// yumemi framework/server ── Cloudflare の adapter(WGy、0.11.1)。app の生成物 `gen/shell.mjs` が
// fetch / queue の口と、AppSystem(service binding の RPC)、Durable Object の class をここから作る。
// cron の式ごとの分岐(scheduled)は `src/server.gleam` の `cron` から生成物に書く。
import { DurableObject, WorkerEntrypoint } from 'cloudflare:workers';

/** fetch と queue。fetch が 202 を返したら outbox を送る(同じ invocation の waitUntil)。 */
export function handlers({ dispatch, database, observe, sweep, consume }) {
 let invocation=0;
 return {
  async fetch(request,env,execution) {
   const db=database(env,observe);
   const response=await dispatch({request,env,db,invocation:++invocation});
   if(response.status===202) execution.waitUntil(sweep(db,env));
   return response;
  },
  async queue(batch,env) {
   const db=database(env,observe);
   for(const message of batch.messages) {
    try {await consume(message.body,db,env);message.ack();}
    catch {message.retry();}
   }
  },
 };
}

/** auth の Worker が service binding で呼ぶ口(session の発行・失効・読み)。 */
export function appSystem({ database, observe, issueSession, revokeParty, resolveSession, run }) {
 return class AppSystem extends WorkerEntrypoint {
  async session(party,expires_at,credential_version) {return issueSession(database(this.env,observe),party,expires_at,credential_version);}
  async revoke(party,floor) {return revokeParty(database(this.env,observe),party,floor);}
  async revoke_session(id) {await run(database(this.env,observe),'framework/session_revoke',[id]);}
  async session_read(id) {
   const value=await resolveSession(database(this.env,observe),id,new Date().toISOString());
   return value?{party:value.party}:null;
  }
 };
}

/** Durable Object の class。実装は ★ の adapter が持ち、`methods` の名だけを RPC として外へ出す。 */
const adapterOf=Symbol('adapter');
export function durableObject(Adapter, methods) {
 class Object_ extends DurableObject {
  constructor(ctx,env) { super(ctx,env); Object.defineProperty(this,adapterOf,{value:new Adapter(ctx,env)}); }
 }
 for(const name of methods) {
  Object.defineProperty(Object_.prototype,name,{value(...args){return this[adapterOf][name](...args);},writable:true,configurable:true});
 }
 return Object_;
}
