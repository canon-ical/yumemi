// yumemi framework/server ── cron の回し方(WGy、0.11.1)。式と仕事の表は app の生成物 `gen/shell.mjs` /
// `gen/cron_runtime.mjs` が `src/server.gleam` の `cron` から書く。

const system=[{phases:null,owner:'no_owner'}];

/**
 * 列挙の読み(`query`、`$1` = 起動時刻)の行ごとに Service を 1 回ずつ呼ぶ。行の `id` を Args の 1 つ目へ。
 * 列挙は snapshot なので、同時の編集で CAS に負けた行は飛ばし、後の行にも機会を残す。基盤の失敗は
 * 投げ直して、scheduled の起動を観測できるようにする。畳んだ子(folded)は同じ commit で書かれるので、
 * 成功のたびに sweep で送る(毎時の sweep が回復の道)。
 */
export async function eachDue({record,query,idKey,db,env,at,run,invoke,sweep,codec}) {
 const rows=await run(db,query,[at]);
 let done=0;
 for(const row of rows) {
  try {
   const args=new record.module.Args(codec.parse(idKey,row.id));
   const outcome=await invoke({record,args,db,env,resolved:null,clauses:system,at,seed:crypto.randomUUID()});
   if(outcome?.constructor?.name==='Accepted'||outcome?.constructor?.name==='Done') {
    done++;
    await sweep(db,env);
   }
  } catch(error) {
   if(error.message==='conflict'||error.code==='40001') continue;
   throw error;
  }
 }
 return done;
}

/** hook が作った Args で Service を 1 回呼ぶ。Done で終わらなければ投げる。 */
export async function hooked({record,args,db,env,at,invoke}) {
 const outcome=await invoke({record,args,db,env,resolved:null,clauses:system,at,seed:crypto.randomUUID()});
 if(outcome?.constructor?.name!=='Done') throw new Error(record.name.replaceAll('_',' ')+' did not complete');
 return outcome;
}
