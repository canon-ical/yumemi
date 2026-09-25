// yumemi framework/server ── 宣言の制約(WGy、0.11.1)。
// `validateWho` は registry の読み込み時に Service の allow を検める。`foldable` は**生成器が生成時に**
// Service の source を読んで registry の `folded` に焼くための判定で、実行時には呼ばない。
// 子の payload に使ってよいのは commit の値・Args・root(`it.<欄>`、commit の前に確定している)だけ(WGy で root を足した)。
export function validateWho(clauses) {
 const names=clauses.map(c=>c.who.constructor.name);
 if(names.includes('System')&&names.some(x=>x!=='System'))throw new Error('System must not be mixed with human Who');
}
export function foldable(source,kinds) {
 if(/\bstep\.read\s*\(/m.test(source))return false;
 const commit=/use\s+(\w+)\s*<-\s*step\.commit\(/m.exec(source);
 if(!commit)return false;
 const functionStart=Math.max(source.lastIndexOf('\nfn ',commit.index),source.lastIndexOf('\npub fn ',commit.index))+1;
 const start=functionStart>0?functionStart:0;
 const open=source.indexOf('{',start);
 if(open<0)return false;
 let block=0,close=open;
 for(;close<source.length;close++){
  if(source[close]==='{')block++;
  if(source[close]==='}'&&!--block)break;
 }
 if(block)return false;
 const functionSource=source.slice(start,close+1);
 const found=/use\s+(\w+)\s*<-\s*step\.commit\(/m.exec(functionSource);
 if(!found)return false;
 let depth=1,end=found.index+found[0].length;
 for(;end<functionSource.length&&depth;end++){if(functionSource[end]==='(')depth++;if(functionSource[end]===')')depth--;}
 const tail=functionSource.slice(end),calls=[...tail.matchAll(/use\s+_\s*<-\s*step\.call_write\(queue\.(\w+)\(([\s\S]*?)\)\)/g)];
 if(!calls.length||new Set(calls.map(x=>x[1])).size!==calls.length)return false;
 if(calls.length!==kinds.length||calls.some(x=>!kinds.includes(x[1])))return false;
 if(calls.some(x=>x[2].split(',').map(x=>x.trim()).filter(Boolean).some(x=>!new RegExp('^(?:(?:'+found[1]+'|args)\\.[a-z_]+|it(?:\\.[a-z_]+)+)$').test(x))))return false;
 const remainder=tail.replace(/use\s+_\s*<-\s*step\.call_write\(queue\.(\w+)\(([\s\S]*?)\)\)/g,'').replace(/\s/g,'');
 return /^step\.done\([^)]*\)\}*$/.test(remainder);
}
