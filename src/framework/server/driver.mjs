// yumemi framework/server ── Neon HTTP の transport(WGy、0.11.1)。app の生成物(`gen/shell.mjs` ほか)が
// `database(env, observe)` を呼ぶ。date(oid 1082)は文字列のまま返す。DB の外の失敗は connector='neon' / 503。
import { neon, types as pgTypes } from '@neondatabase/serverless';
const transport=error=>{if(!/^[0-9A-Z]{5}$/.test(error.code??''))Object.assign(error,{connector:'neon',status:503});throw error;};
const types={getTypeParser(oid,format){if(Number(oid)===1082)return value=>value;return pgTypes.getTypeParser(oid,format);}};
export function database(env,observe=()=>{}) {
 if(!env.DATABASE_URL) throw new Error('DATABASE_URL is missing');
 const sql=neon(env.DATABASE_URL);
 return {
  async query(text,params,key) { const start=performance.now();try{return await sql.query(text,params,{types});}catch(error){transport(error);}finally{observe({kind:'read',key,statements:1,ms:performance.now()-start});} },
  async transaction(operations) {
   if(!operations.length) return [];
   const start=performance.now();
   try {return await sql.transaction(operations.map(x=>sql.query(x.sql,x.params,{types})));}catch(error){transport(error);}
   finally {observe({kind:'transaction',statements:operations.length,ms:performance.now()-start});}
  }
 };
}
