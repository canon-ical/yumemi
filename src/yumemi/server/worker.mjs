// yumemi yumemi/server ── Cloudflare の adapter(WGy、0.11.1)。app の生成物 `gen/shell.mjs` が
// fetch / queue の口と、AppSystem(service binding の RPC)、Durable Object の class をここから作る。
// cron の式ごとの分岐(scheduled)は `src/server.gleam` の `cron` から生成物に書く。
// 合図の器 `YumemiLive`(0.15)も生成の `shell.mjs` が export する(binding `YUMEMI_LIVE` を足した app だけが使う)。
import { DurableObject, WorkerEntrypoint } from 'cloudflare:workers';
import { recording } from './outbox.mjs';
import { expHeader, partyHeader } from './live.mjs';

/**
 * fetch と queue。fetch が 202 を返したか、outbox へ INSERT する文を commit したら(status によらず、
 * 生成の書きも手書きの SQL も)、outbox を送る(同じ invocation の waitUntil)。書きの無い要求では送らない。
 */
export function handlers({ dispatch, database, observe, sweep, consume }) {
 let invocation=0;
 return {
  async fetch(request,env,execution) {
   const db=database(env,observe);
   const writes=recording(db);
   let response;
   try {response=await dispatch({request,env,db:writes.db,invocation:++invocation,execution});}
   finally {if(response?.status===202||writes.wrote()) execution.waitUntil(sweep(db,env));}
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

/**
 * 合図の器(0.15)。宛先(`<entity>:<id>`)ごとに 1 つ(`idFromName`)。値を storage に持たず(使うのは alarm だけ)、
 * Hibernation WebSocket で繋がっている socket を持つ。`fetch` は socket の受けで、入口の socket の口が札(署名・
 * Origin・party)を確かめた後の内部の要求だけが来る。要求の `x-yumemi-live-exp`(札の期限、秒)と party を socket の
 * attachment に持ち、期限の無い・過ぎた要求は 403。期限の来た socket は alarm が閉じる(close code 4001 `expired`)。
 * `publish()` は期限の内の socket に `1` の 1 語を送り(期限の過ぎた socket には送らず閉じる)、送った数を返す。
 * ping には pong を runtime が返す(DO を起こさない)。socket から来た他の字は読まない。
 */
export class YumemiLive extends DurableObject {
 constructor(ctx,env) {
  super(ctx,env);
  ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair('ping','pong'));
 }
 async fetch(request) {
  if((request.headers.get('upgrade')??'').toLowerCase()!=='websocket') return new Response(null,{status:426});
  const raw=request.headers.get(expHeader)??'';
  const exp=/^[1-9][0-9]{0,15}$/.test(raw)?Number(raw):NaN;
  if(!Number.isSafeInteger(exp)||exp*1000<=Date.now()) return new Response(null,{status:403});
  const [client,server]=Object.values(new WebSocketPair());
  this.ctx.acceptWebSocket(server);
  server.serializeAttachment({exp,party:request.headers.get(partyHeader)});
  await this.schedule(exp*1000);
  return new Response(null,{status:101,webSocket:client});
 }
 // 次の alarm を `at`(ms)より遅くしない
 async schedule(at) {
  const current=await this.ctx.storage.getAlarm();
  if(current===null||at<current) await this.ctx.storage.setAlarm(at);
 }
 // 期限が過ぎたか(attachment の無い socket も過ぎたと見る)
 expired(socket,now) {
  let exp;
  try { exp=socket.deserializeAttachment()?.exp; } catch {}
  return !Number.isSafeInteger(exp)||exp*1000<=now;
 }
 close(socket) { try { socket.close(4001,'expired'); } catch {} }
 publish() {
  const now=Date.now();
  let sent=0;
  for(const socket of this.ctx.getWebSockets()) {
   if(this.expired(socket,now)) { this.close(socket); continue; }
   try { socket.send('1'); sent++; } catch {}
  }
  return sent;
 }
 // 期限の来た socket を閉じ、残りの一番早い期限に次の alarm を置く
 async alarm() {
  const now=Date.now();
  let next=null;
  for(const socket of this.ctx.getWebSockets()) {
   if(this.expired(socket,now)) { this.close(socket); continue; }
   const at=socket.deserializeAttachment().exp*1000;
   if(next===null||at<next) next=at;
  }
  if(next!==null) await this.ctx.storage.setAlarm(next);
 }
 webSocketMessage() {}
 webSocketClose(socket) { try { socket.close(); } catch {} }
 webSocketError(socket) { try { socket.close(); } catch {} }
}
