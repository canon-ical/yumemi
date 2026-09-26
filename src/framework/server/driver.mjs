// yumemi framework/server ── Neon HTTP の transport(WGy、0.11.1)。app の生成物(`gen/shell.mjs` ほか)が
// `database(env, observe)` を呼ぶ。date(oid 1082)は文字列のまま返す。DB の外の失敗は connector='neon' / 503。
// 読みだけの文(`read_retry.readOnly`)は 1 回を `DATABASE_READ_TIMEOUT_MS`(既定 10000)で切り、DB の外の失敗なら 1 回やり直す。
// DB の外の失敗は本文を log に 1 行ずつ出す(書きも)。書きの文と transaction はやり直さず、timeout も付けない(0.11.4、H10)。
import { neon, types as pgTypes } from '@neondatabase/serverless';
import { defaultReadTimeoutMs, failureLine, readOnly, readWithRetry, transient } from './read_retry.mjs';
const transport=error=>{if(!/^[0-9A-Z]{5}$/.test(error.code??''))Object.assign(error,{connector:'neon',status:503});throw error;};
// 書き(やり直さない)の DB の外の失敗も本文を 1 行出す
const logged=(key,start,error,kind)=>{if(transient(error))console.error(failureLine(key,1,performance.now()-start,error,kind));return error;};
const types={getTypeParser(oid,format){if(Number(oid)===1082)return value=>value;return pgTypes.getTypeParser(oid,format);}};
export function database(env,observe=()=>{}) {
 if(!env.DATABASE_URL) throw new Error('DATABASE_URL is missing');
 const sql=neon(env.DATABASE_URL);
 const timeoutMs=Number(env.DATABASE_READ_TIMEOUT_MS)>0?Number(env.DATABASE_READ_TIMEOUT_MS):defaultReadTimeoutMs;
 const once=(text,params)=>sql.query(text,params,{types});
 const read=(text,params,key)=>readWithRetry(signal=>sql.query(text,params,{types,fetchOptions:{signal}}),{key,timeoutMs});
 return {
  async query(text,params,key) { const start=performance.now();const reading=readOnly(text);try{return await (reading?read(text,params,key):once(text,params));}catch(error){transport(reading?error:logged(key,start,error,'write'));}finally{observe({kind:'read',key,statements:1,ms:performance.now()-start});} },
  async transaction(operations) {
   if(!operations.length) return [];
   const start=performance.now();
   try {return await sql.transaction(operations.map(x=>sql.query(x.sql,x.params,{types})));}catch(error){transport(logged(operations.map(x=>x.key).filter(Boolean).join(',')||null,start,error,'transaction'));}
   finally {observe({kind:'transaction',statements:operations.length,ms:performance.now()-start});}
  }
 };
}
