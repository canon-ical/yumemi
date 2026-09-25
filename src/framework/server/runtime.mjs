// yumemi framework/server ── Service を 1 回走らせる機関(WGy r3、0.11.1)。
// root を読み、actor を決め、logic の手順書(step)を ctx の上で解釈する。ctx は verb の stage、読み、関係、
// connector の call、commit(outbox)、enqueue、reject、finish を持つ。
//
// 名ごとの表は app の生成物 `gen/runtime.mjs` が渡す(`runtime(spec)`)。表は宣言から導いたもので、
// 手書きの SQL に依る行(手書きの verb・読み・connector の実装)は宣言した ★ hook を表に差す。
//
// spec の欄:
// - `SQL` / `c`(生成の codec)/ `step`(framework の step)
// - `roots`: service -> { sql, params, values }。params は root の SQL の穴(`-- root:` の契約)、values は
//   Root の欄の並び(`entity:<module>` / `phase:<module>` / `version` / `carried:<name>`、末尾の at と seed は機関が足す)
// - `actors`: service -> { kind: 'direct' | 'sum' | 'party' | 'system' | 'any', ... }
// - `verbs`: 生成の verb -> async (input, x) => { key, params, created?, before? }
// - `manualVerbs`: 手書きの verb の名の集合と ★ hook(`stage(name, input, x)`)
// - `reads`: `<service>/<name>` -> { key, params(input, x), decode(rows, x) } または { hook }
// - `connectors`: 口の名 -> async (input, x)(★ の実装)。`state.connectors[name]` が在ればそちらが勝つ
// - `folds`: kind -> (carry, root) => payload。`enqueues`: kind -> (input) => payload
// - `boundaries`: commit が解釈の境だけの Service(受け手へ送り終えてから outbox を閉じる consumer)
// - `relationDecoders`: Entity の module -> decoder
// - `subjects`: session の主体になる Entity の module(作った行の party が session の party なら session に結ぶ)
// - `connectorNames`: 口の名 -> 診断に出す connector の名
// - `apiKeyLabel` / `claimLabel`: HMAC の label(★ の const)
import * as step from '../step.mjs';
import { value as secretValue } from '../secret_ffi.mjs';
import { encrypt as seal } from '../sealed_ffi.mjs';

export function runtime(spec) {
 const { SQL, c } = spec;
 const statement=(key,params)=>({key,sql:SQL[key],params});
 const run=(db,key,params)=>db.query(SQL[key],params,key);

 async function transactionWithRetry(db,operations) {
  let attempt=0;
  while(true) {
   try { return await db.transaction(operations); }
   catch(error) {
    if(error?.code!=='40001'||attempt++>=2) throw error;
   }
  }
 }
 function relationCapability(db,state) {
  return async (relation,keys) => {
   // root の 1 文が矢印の先を畳んで持っていれば(`to_jsonb(..) AS <prop>`)、引き直さない
   const row=state?.row;
   const folded=row&&keys.length===1?row[relation.prop]:null;
   const decodeFolded=spec.relationDecoders[relation.target];
   if(folded!=null&&decodeFolded) {
    const value=typeof folded==='string'?JSON.parse(folded):folded;
    if(String(value?.id??'')===String(keys[0])) return [decodeFolded(value)];
   }
   const key=`${relation.service}/${relation.query}`;
   const sql=SQL[key];
   if(!sql) throw new Error(`generated SQL is missing: ${key}`);
   const decode=spec.relationDecoders[relation.target];
   if(!decode) throw new Error(`decoder is missing for target ${relation.target}`);
   const rows=await db.query(sql,[JSON.stringify(keys)],key);
   return rows.map(decode);
  };
 }
 async function seededId(seed, ordinal) {
  const bytes=new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(seed+':'+ordinal))).slice(0,16);
  bytes[6]=(bytes[6]&15)|64;bytes[8]=(bytes[8]&63)|128;
  const hex=Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join('');
  return [hex.slice(0,8),hex.slice(8,12),hex.slice(12,16),hex.slice(16,20),hex.slice(20)].join('-');
 }
 async function labeledHmac(env,label,plain) {
  const getter=env?.SECRET_HMAC?.get;
  if(typeof getter!=='function') throw new Error('HMAC key is missing');
  const raw=String(await getter());
  const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(raw),{name:'HMAC',hash:'SHA-256'},false,['sign']);
  const bytes=new Uint8Array(await crypto.subtle.sign('HMAC',key,new TextEncoder().encode(String(label)+String(plain))));
  return Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join('');
 }
 const apiKeyHmac=(env,plain)=>labeledHmac(env,spec.apiKeyLabel,plain);
 const claimHmac=(env,plain)=>labeledHmac(env,spec.claimLabel,plain);

 // ── session と API key(framework の SQL)──────────────────────────────
 async function resolveSession(db,id,at) {
  if(!id) return null;
  let rows=await run(db,'framework/session_resolve_staff',[id,at,true]);
  if(rows[0]?.retry) rows=await run(db,'framework/session_resolve_staff',[id,at,false]);
  const value=rows[0]??null;
  if(value?.subject_party && value.subject_party!==value.party) throw Object.assign(new Error('forbidden'),{status:403});
  return value;
 }
 async function resolveApiKey(db,digest,at) {
  if(typeof digest!=='string'||!digest) return null;
  const rows=await run(db,'framework/api_key_resolve',[digest,at]);
  return rows[0]??null;
 }
 async function issueSession(db,party,expiresAt,version) {
  if(typeof party!=='string'||!party||!Number.isInteger(version)||version<0||!Number.isFinite(Date.parse(expiresAt))) throw new Error('invalid session input');
  const id=Array.from(crypto.getRandomValues(new Uint8Array(16)),b=>b.toString(16).padStart(2,'0')).join('');
  return (await run(db,'framework/session_issue',[party,id,version,expiresAt]))[0]?.id??null;
 }
 async function revokeParty(db,party,floor) {
  if(!Number.isInteger(floor)||floor<0) throw new Error('invalid floor');
  const [row]=await run(db,'framework/credential_floor',[party,floor]);
  // The floor commits before this query starts. Never merge these transactions.
  await run(db,'framework/session_revoke_party',[party,row.version]);
  return row.version;
 }

 // ── connector の診断 ─────────────────────────────────────────────────
 function safeErrorKind(cause) {
  const name=typeof cause?.name==='string'?cause.name:'';
  return new Set(['AbortError','Error','TimeoutError','TypeError']).has(name)?name:'Error';
 }
 function safeStack(cause) {
  return String(cause?.stack??'').split('\n').slice(1).flatMap(line=>{
   const match=/^\s*at\s+(?:(.*?)\s+\()?((?:file|https?):[^)\s]+|[^)\s]+):(\d+):\d+\)?$/.exec(line);
   if(!match)return [];
   const fn=/^(?:async )?[A-Za-z_$][\w.$]*$/.test(match[1]??'')?match[1]:'<anonymous>';
   const base=match[2].split(/[?#]/,1)[0].split('/').at(-1);
   const file=/^[A-Za-z0-9_.-]+\.(?:mjs|cjs|js)$/.test(base)?base:'runtime';
   return [{function:fn,file,line:Number(match[3])}];
  }).slice(0,8);
 }
 function connectorFailureDiagnostic(name,cause) {
  const connector=spec.connectorNames?.[name]??name;
  const diagnostic={component:'connector_failure',connector,name:safeErrorKind(cause),frames:safeStack(cause)};
  const reason=/^([\w.]+) fetch failed \((\d{3})\)$/.exec(String(cause?.message??''));
  if(reason) { diagnostic.reason='http_status'; diagnostic.status=Number(reason[2]); }
  return diagnostic;
 }

 // ── actor ─────────────────────────────────────────────────────────────
 function subjectValue(resolved,kind) {
  if(resolved?.subject_kind!==kind) return null;
  const row=resolved?.[kind];
  return row?spec.relationDecoders[kind](row):null;
 }
 function actorFor(record,resolved,model) {
  const plan=spec.actors[record.name];
  // 表に無い record(test の fixture が registry に足す口)は主体を持たない値で通す
  if(!plan) return resolved?.party?{party:c.checked(c.party.parse(resolved.party))}:{};
  const party=()=>c.checked(c.party.parse(resolved?.party));
  switch(plan.kind) {
   case 'system': return new plan.module.SystemActor();
   case 'party': return new plan.module.PartyActor(party());
   case 'any': return new plan.module.AnyActor();
   case 'direct': {
    // 主体の admission は入口(http_runtime)の段。queue の consumer は actor を後から差す
    return subjectValue(resolved,plan.subject)??model??null;
   }
   case 'sum': {
    for(const [kind,ctor] of plan.variants) {
     const value=subjectValue(resolved,kind);
     if(value) return new plan.module[ctor](value);
    }
    if(plan.party&&resolved?.party) return new plan.module.AuthenticatedActor(party());
    if(plan.any) return new plan.module.AnyActor();
    return null;
   }
  }
  throw new Error('invalid actor plan: '+record.name);
 }

 // ── root ──────────────────────────────────────────────────────────────
 function rootParam(token,state) {
  const {args,resolved,clauses}=state;
  const [head,name,extra]=token.split(':');
  switch(head) {
   case 'clauses': return [JSON.stringify(clauses)];
   case 'party': return [resolved?.party??null];
   case 'subject': return [resolved?.subject_id??null];
   case 'arg': return [c.text(c.unwrap(args[name]))];
   case 'tag': return [c.tag(args[name])];
   case 'arg_or_subject': return [args[name]?c.text(c.unwrap(args[name])):resolved?.subject_id??null];
   case 'cursor': return spec.cursorArgs(c.unwrap(args[name]),extra);
   case 'fold': return [];
  }
  throw new Error('invalid root param: '+token);
 }
 function rootValue(token,state) {
  const {row,resolved}=state;
  const [head,name]=token.split(':');
  switch(head) {
   case 'entity': return spec.relationDecoders[name](row);
   case 'phase': return c.phase(spec.phaseModules[name],row.phase);
   case 'version': return Number(row.version??1);
   case 'carried': return spec.carried[name](state);
   case 'subject_entity': return spec.relationDecoders[name](resolved?.[name]??row);
  }
  throw new Error('invalid root value: '+token);
 }
 async function loadRoot(state) {
  const {record,resolved,db,at,seed}=state;
  const shape=spec.roots[record.name]??{sql:null,params:[],values:[]};
  let row=null;
  if(shape.sql) {
   const params=shape.params.flatMap(token=>rootParam(token,state));
   row=(await run(db,shape.sql,params))[0];
   if(!row) throw Object.assign(new Error('not_found'),{status:404});
  }
  state.row=row;
  // `fold:<読み>=<列>` ── root の 1 文が読みの行を畳んで持つ(その読みは引き直さない)
  state.folds=Object.fromEntries(shape.params.filter(token=>token.startsWith('fold:')).map(token=>token.slice(5).split('=')));
  const atValue=c.checked(c.time.datetime(at));
  const values=shape.values.map(token=>rootValue(token,{...state,row}));
  state.root=new record.root.Root(...values,atValue,seed);
  state.actor=actorFor(record,resolved,null);
  return state;
 }

 // ── 値の写し(表の語彙)──────────────────────────────────────────────
 // 穴へ: `enc` は codec の encode、値型に ★ の encoder(`encoders[<scalar>]`)が在ればそれを通す
 function encodeValue(value,scalar) {
  const raw=c.encode(value);
  const encoder=scalar&&spec.encoders?.[scalar];
  if(raw==null||!encoder) return raw;
  return encoder(raw);
 }
 // jsonb の穴。None は SQL の NULL(jsonb の null ではない)
 function json(value) {
  const raw=c.encode(value);
  return raw==null?null:JSON.stringify(raw);
 }
 // 行から: 読みの戻りの形(`out`)を解釈する
 function at(row,path) { return path?row?.[path]:row; }
 function decodeItem(item,row) {
  const [head,a,b]=item;
  switch(head) {
   case 'entity': {
    // 宣言から導けない decoder(chunk の Embedding ほか)の欄は値を持たない
    const decode=spec.relationDecoders[a];
    return decode?decode(at(row,b)):null;
   }
   case 'phase': return c.phase(spec.phaseModules[a],at(row,b).phase);
   case 'tuple': return a.map(part=>decodeItem(part,row));
   case 'children': return c.toList((typeof row?.[b]==='string'?JSON.parse(row[b]):(row?.[b]??[])).map(r=>decodeItem(a,r)));
   case 'number': return Number(row?.[a]??0);
   case 'int': return Number(row?.[a]);
   case 'bool': return Boolean(row?.[a]);
   case 'text': return String(row?.[a]);
   case 'sum': return c.phase(spec.phaseModules[a],row?.[b]);
   case 'value': return c.parse(a,spec.decoders?.[a]?spec.decoders[a](row?.[b]):row?.[b]);
   case 'option': return c.option(row?.[b]??null,()=>decodeItem(a,row));
  }
  throw new Error('invalid read shape: '+head);
 }
 function cursorText(keyset,row) {
  return btoa(JSON.stringify(keyset.columns.map(([column,kind])=>{
   const value=row[column];
   if(value==null) return null;
   if(kind==='timestamptz') return c.timeText(value);
   if(kind==='date') return c.dateText(value).slice(0,10);
   return value;
  })));
 }
 function decodeRows(out,rows,keyset) {
  const [head,item]=out;
  switch(head) {
   case 'list': return c.toList(rows.map(row=>decodeItem(item,row)));
   case 'option': return c.option(rows[0]??null,row=>decodeItem(item,row));
   case 'one': return decodeItem(item,rows[0]??{});
   case 'page': {
    const visible=rows.slice(0,keyset.size),last=visible.at(-1);
    const cursor=rows.length>keyset.size?c.checked(c.page.cursor(cursorText(keyset,last))):null;
    return new c.page.Page(c.toList(visible.map(row=>decodeItem(item,row))),c.option(cursor));
   }
  }
  throw new Error('invalid read out: '+head);
 }
 function cursorParams(raw,keyset) {
  const width=keyset.columns.length;
  if(raw==null) return keyset.uniform?Array(width).fill(null):[false,...Array(width).fill(null)];
  let parts;
  try {
   parts=JSON.parse(atob(c.text(c.unwrap(raw))));
   if(!Array.isArray(parts)||parts.length!==width) throw 0;
  } catch { throw Object.assign(new Error('invalid_argument'),{status:400,field:'cursor'}); }
  return keyset.uniform?parts:[true,...parts];
 }
 async function readParams(entry,input,state,x) {
  const values=entry.args.length===0?[]:entry.args.length===1?[input]:[...input];
  const params=[];
  for(const [index,[kind,scalar]] of entry.args.entries()) {
   const value=values[index];
   if(kind==='cursor') params.push(...cursorParams(c.unwrap(value),entry.keyset));
   else if(kind==='json') params.push(json(value));
   else if(kind==='secret') {
    // 秘密は平文で SQL に渡さない ── HMAC の像だけを穴へ、後の verb(同じ要求の中)は x.memo.secret で引く
    const digest=await x.claimHmac(secretValue(value));
    x.memo.secret=digest;
    params.push(digest);
   }
   else params.push(encodeValue(value,scalar));
  }
  for(const extra of entry.allow??[]) {
   if(extra==='clauses') params.push(JSON.stringify(state.clauses));
   if(extra==='party') params.push(state.resolved?.party??null);
   if(extra==='subject') params.push(state.resolved?.subject_id??null);
  }
  return params;
 }
 // verb: 表の穴の並び(`params`)を input から作る
 async function stageVerb(name,verb,input,x) {
  const values=verb.tuple?[...input]:[input];
  let id=null;
  const params=[];
  for(const [kind,a,b] of verb.params) {
   switch(kind) {
    case 'id': id=await x.nextId(); params.push(id); break;
    case 'a': params.push(encodeValue(values[a],b)); break;
    case 'f': params.push(encodeValue(input[a],b)); break;
    case 'at': params.push(x.at); break;
    case 'ja': params.push(json(values[a])); break;
    case 'jf': params.push(json(input[a])); break;
    case 'sealed': {
     const sealed=await seal(input[a],await x.env[b].get());
     x.memo.sealed={...x.memo.sealed,[a]:sealed};
     params.push(sealed.hex);
     break;
    }
    case 'sealed_key': params.push(x.memo.sealed?.[a]?.key_id); break;
    case 'from': case 'to': {
     const transition=verb.transitions[c.tag(values[a])];
     if(!transition) throw new Error('invalid transition: '+name);
     params.push(transition[kind==='from'?0:1]);
     break;
    }
    default: throw new Error('invalid verb param: '+kind);
   }
  }
  const out={key:verb.key,params};
  if(verb.before) out.before=verb.before.map(([key,tokens])=>({key,params:tokens.map(([kind,a,b])=>kind==='f'?encodeValue(input[a],b):encodeValue(values[a],b))}));
  if(verb.created) {
   const [module,ctor,fields,scalar]=verb.created;
   out.created=new spec.drafts[module][ctor](...fields.map(field=>field==='id'?c.parse(scalar,id):field==='=order'?c.parse('order',0):input[field]));
   if(spec.subjects?.includes(module)) { out.subject=id; out.party=c.text(input.party); }
  }
  return out;
 }

 // 読みの口は名だけを運ぶ。Service の表に無い名は、表の中で 1 本だけの名ならそれを引く
 function uniqueRead(name) {
  const found=Object.keys(spec.reads).filter(key=>key.endsWith('/'+name));
  return found.length===1?spec.reads[found[0]]:undefined;
 }
 // ── ctx ───────────────────────────────────────────────────────────────
 function makeContext(state) {
  const {record,db,root,at,seed}=state;
  const pending=[];
  let committed=Boolean(state.eventId);
  let ordinal=0;
  const x={c,state,at,seed,env:state.env,db,pending,statement,
   nextId:()=>seededId(seed,ordinal++),
   seededId,run:(key,params)=>run(db,key,params),
   apiKeyHmac:plain=>apiKeyHmac(state.env,plain),claimHmac:plain=>claimHmac(state.env,plain),
   memo:{}};
  const created=[];
  const ctx={pending,root,async stage(name,input) {
   if(spec.manualVerbs.names.has(name)) return spec.manualVerbs.stage(name,input,x);
   const verb=spec.verbs[name];
   if(!verb) throw new Error('unregistered verb: '+name);
   const out=await stageVerb(name,verb,input,x);
   for(const before of out.before??[]) pending.push(statement(before.key,before.params));
   const operation=statement(out.key,out.params);
   if(out.created!==undefined) { operation.created=out.created; created.push(out); }
   pending.push(operation);
   if(out.subject&&out.party===state.resolved?.party) ctx.onboard=out.subject;
   return out.created;
  },async read(name,input) {
   // 他の Service の読みの module を import した ★ は、その Service の表を引く(`readAliases`)
   const entry=[record.name,...(spec.readAliases?.[record.name]??[])].map(owner=>spec.reads[owner+'/'+name]).find(Boolean)??uniqueRead(name);
   if(!entry) throw new Error('unregistered read: '+record.name+'/'+name);
   if(entry.hook) return entry.hook(input,x);
   const folded=state.folds?.[name];
   if(folded&&state.row) {
    const raw=state.row[folded];
    const value=typeof raw==='string'&&/^[\[{]/.test(raw)?JSON.parse(raw):raw;
    const label=entry.out[0]==='one'?entry.out[1][1]:null;
    return decodeRows(entry.out,Array.isArray(value)?value:[{[label]:value}],entry.keyset);
   }
   const rows=await run(db,entry.key,await readParams(entry,input,state,x));
   return decodeRows(entry.out,rows,entry.keyset);
  },relation:relationCapability(db,state),async call(name,input) {
   try {
    if(state.connectors?.[name]) return await state.connectors[name](input);
    const connector=spec.connectors[name];
    if(!connector) throw new Error('unregistered connector');
    return await connector(input,x);
   } catch(cause) {
    const diagnostic=connectorFailureDiagnostic(name,cause);
    try { console.error(JSON.stringify(diagnostic)); } catch {}
    throw Object.assign(new Error('upstream_unavailable',{cause}),{status:503,connector:diagnostic.connector});
   }
  },async commit(carry) {
   if(spec.boundaries.has(record.name)) {
    // The commit is an interpreter boundary only.  Recipient RPCs must run
    // before the originating outbox row is marked done; Queue retry then
    // resumes the same event after a partial delivery failure.
    committed=true;
    return true;
   }
   const parent=crypto.randomUUID(),value=c.encode(carry),fold=record.folded;
   state.committedCarry=value;
   pending.push(statement('framework/outbox_parent',[parent,record.name+':1',JSON.stringify({service:record.name,carry:value,args:c.encode(state.args)}),state.eventId??null,at,!!fold]));
   if(fold) for(const kind of fold.kinds) {
    const payload=spec.folds[kind](value,root);
    pending.push(statement('framework/outbox_child',[crypto.randomUUID(),kind,JSON.stringify(payload),parent,at]));
   }
   await ctx.finish();
   committed=true;
   return false;
  },async enqueue(kind,input) {
   if(!committed) throw new Error('write connector before commit');
   const payload=spec.enqueues[kind](c.encode(input));
   await db.transaction([statement('framework/outbox_child',[crypto.randomUUID(),kind,JSON.stringify(payload),state.eventId,at])]);
  },async reject(stageRejected) {
   const isolated=makeContext({...state,eventId:null,seed:await seededId(state.seed,'reject')});
   try {await stageRejected(isolated);await isolated.finish();}
   catch(cause) {throw Object.assign(new Error('upstream_unavailable',{cause}),{status:503,connector:cause.connector??'neon'});}
  },async finish() {
   if(!pending.length&&!state.eventId) return;
   if(ctx.onboard) pending.push(statement('framework/session_onboard',[state.resolved.id,state.resolved.party,ctx.onboard]));
   if(state.eventId) pending.push(statement('framework/outbox_done',[state.eventId]));
   for(const stage of ['entry','resolve','decode','judge','execute','commit']) pending.push(statement('framework/audit',[seed,stage,record.name,state.resolved?.party??null,'ok',at]));
   const result=await transactionWithRetry(db,pending);
   for(let index=0;index<pending.length;index++) {
    const operation=pending[index],value=operation.created;
    if(!value) continue;
    const rows=Array.isArray(result?.[index])?result[index]:[];
    if(Array.isArray(value)) {
     const byId=new Map(rows.map(row=>[row.id,row]));
     for(const item of value) {
      const row=byId.get(c.text(item.id));
      if(row?.order!==undefined) item.order=c.parse('order',Number(row.order));
     }
    } else {
     const row=rows[0];
     const returned=operation.returned??created.find(entry=>entry.created===value)?.returned;
     if(returned) returned(value,row);
     else if(row?.order!==undefined&&'order' in value) value.order=c.parse('order',Number(row.order));
    }
   }
   pending.length=0;
  }};
  return ctx;
 }
 async function invoke(state) {
  await loadRoot(state);
  const context=makeContext(state);
  return step.interpret(state.record.module.logic(state.actor,state.root,state.args),context);
 }
 return {statement,run,step,seededId,labeledHmac,apiKeyHmac,claimHmac,resolveSession,resolveApiKey,issueSession,revokeParty,
  connectorFailureDiagnostic,actorFor,loadRoot,makeContext,invoke};
}
