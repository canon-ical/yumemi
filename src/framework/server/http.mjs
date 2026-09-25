// yumemi framework/server ── HTTP の入口の検査 1〜10(WGy r3、0.11.1)。
// host → route → origin → browser → admit → resolve → subject → decode → judge → execute の段を持ち、
// 生成の `gen/entry/http.gleam` が段ごとに呼ぶ。名ごとの表は app の生成物 `gen/http_runtime.mjs` が渡す。
//
// spec の欄:
// - `registry` / `attached` / `c`(生成の codec)/ `runtime`(生成の runtime:resolveSession・resolveApiKey・
//   apiKeyHmac・invoke・run・step)/ `entryCredential`(framework/entry の credential)
// - `hosts`: 入口の名 -> env の変数名(`WWW_HOST`)
// - `args`: Service -> [[欄, 型の語彙]]。語彙は `decodeArg` を見よ
// - `modules`: 列挙の module の名 -> JS の module(構成子の和)
// - `phaseGates`: root を持たず、主体の相で絞る Service -> 通す相の名
// - `accepted`: Service -> Accepted の応答の欄の名(root の Entity)
// - `attached`: 口の名 -> ★ の実装(framework の session の口は機関が持つ)
// - `roles`: attached の口の名 -> 役の名の並び(`declare_browser` / `read_session` / `switch_subject` /
//   `tail_path` / `needs_browser`)。app の `src/server.gleam` の `attached_roles` から。framework は口の名を知らない
// - `browserCookie`: 成人の申告を焼く署名 cookie(`{cookie,binding,claim,maxAgeDays}`)か null。`browser` の宣言から
// - `hooks`: ★ の業務の行(下の `hook(...)` の名)。どれも無くてよい
import * as framework_entry from '../entry.mjs';

export function http(spec) {
 const { c, registry, attached } = spec;
 const hook=(name)=>spec.hooks?.[name];
 const encoder=new TextEncoder();
 const cookieSeconds=30*86400;
 const bc=spec.browserCookie??null;
 const browserSeconds=(bc?.maxAgeDays??0)*86400;
 const roleOf=(name,role)=>(spec.roles?.[name]??[]).includes(role);
 const maxBlobBytes=20*1024*1024;
 function sessionCookie(id,env,clear=false) {
  return `session=${id}; Path=/; Domain=${env.COOKIE_DOMAIN}; HttpOnly; Secure; SameSite=Lax; Max-Age=${clear?0:cookieSeconds}`;
 }
 function cookies(header) {
  return Object.fromEntries((header??'').split(';').map(s=>s.trim()).filter(Boolean).map(s=>{const i=s.indexOf('=');return [s.slice(0,i),s.slice(i+1)];}));
 }
 const base64=bytes=>btoa(String.fromCharCode(...bytes)).replaceAll('+','-').replaceAll('/','_').replace(/=+$/,'');
 const bytes=raw=>Uint8Array.from(atob(raw.replaceAll('-','+').replaceAll('_','/')),x=>x.charCodeAt(0));
 async function browserKey(env) { const value=await env[bc.binding].get(); return crypto.subtle.importKey('raw',encoder.encode(value),{name:'HMAC',hash:'SHA-256'},false,['sign','verify']); }
 async function signBrowser(env,id,at) {
  if(!bc) throw new Error('browser の宣言が無い');
  const payload=base64(encoder.encode(JSON.stringify({id,[bc.claim]:at})));
  return payload+'.'+base64(new Uint8Array(await crypto.subtle.sign('HMAC',await browserKey(env),encoder.encode(payload))));
 }
 async function verifyBrowser(env,raw,at) {
  if(!raw||!bc) return null;
  try {
   const [payload,signature,extra]=raw.split('.');
   if(extra!==undefined||!signature||!await crypto.subtle.verify('HMAC',await browserKey(env),bytes(signature),encoder.encode(payload))) return null;
   const value=JSON.parse(new TextDecoder().decode(bytes(payload)));
   const declared=Date.parse(value[bc.claim]),now=Date.parse(at);
   if(!/^[0-9a-f]{32}$/.test(value.id)||!Number.isFinite(declared)||declared>now||now-declared>browserSeconds*1000) return null;
   return value;
  } catch { return null; }
 }
 const credentialOf=entry=>entry?(spec.entryCredential??framework_entry.credential)(entry):null;
 function isApiKeyEntry(entry) {
  const value=credentialOf(entry);
  return value!==null&&c.tag(value)==='api_key';
 }
 function apiKeyLimit(entry) {
  const value=credentialOf(entry);
  return Number(value?.per_minute??value?.[0]??0);
 }
 const fail=(message,status,field)=>{throw Object.assign(new Error(message),{status,field});};
 const invalid=field=>fail('invalid_argument',400,field);
 async function applyApiRateLimit(s) {
  const limit=apiKeyLimit(s.entry);
  if(!Number.isFinite(limit)||limit<=0) return;
  const binding=s.rateLimiter??s.env?.RATELIMITS??s.env?.API_RATE_LIMIT??s.env?.ratelimits;
  if(!binding||typeof binding.limit!=='function') return;
  let result;
  try { result=await binding.limit({key:s.apiKeyDigest}); }
  catch(error) { throw Object.assign(new Error('upstream_unavailable',{cause:error}),{status:503,connector:'rate_limit'}); }
  if(result===false||result?.success===false) fail('rate_limited',429);
 }

 // ── Args の decode(型の語彙)───────────────────────────────────────────
 // `['scalar', name]` 値型、`['int', name]` 整数の値型(query の数字の綴りも受ける)、`['bool']`、`['integer']`、
 // `['date' | 'datetime' | 'time']`、`['blob']`、`['cursor']`、`['enum', module, [値…]]`、`['option', 型]`、
 // `['list', 型]`、`['text']`(素の String)、`['key']`(Entity の鍵)、`['hook', 名]`(★ の decoder)
 function integerRaw(raw,field) {
  const value=typeof raw==='number'?raw:typeof raw==='string'&&/^-?(?:0|[1-9][0-9]*)$/.test(raw)?Number(raw):NaN;
  if(!Number.isSafeInteger(value)) invalid(field);
  return value;
 }
 function decodeArg(type,raw,field,s) {
  const [head,a,b]=type;
  switch(head) {
   case 'option': return raw===undefined||raw===null?new c.None():new c.Some(decodeArg(a,raw,field,s));
   case 'list': if(!Array.isArray(raw)) invalid(field); return c.toList(raw.map(item=>decodeArg(a,item,field,s)));
   case 'scalar': if(typeof raw!=='string') invalid(field); return c.parse(a,raw);
   case 'int': return c.checked(c.scalar[a].parse(integerRaw(raw,field)),field);
   case 'integer': return integerRaw(raw,field);
   case 'float': if(typeof raw!=='number') invalid(field); return raw;
   case 'bool': if(typeof raw!=='boolean') invalid(field); return raw;
   case 'text': if(typeof raw!=='string') invalid(field); return raw;
   case 'date': if(typeof raw!=='string') invalid(field); return c.checked(c.time.date(raw),field);
   case 'datetime': if(typeof raw!=='string') invalid(field); return c.checked(c.time.datetime(raw),field);
   case 'time': if(typeof raw!=='string') invalid(field); return c.checked(c.time.time(raw),field);
   case 'blob': if(typeof raw!=='string') invalid(field); return c.checked(c.blob.parse(raw),field);
   case 'cursor': if(typeof raw!=='string') invalid(field); return c.checked(c.page.cursor(raw),field);
   case 'key': if(typeof raw!=='string'||!raw) invalid(field); return c.er.key(raw);
   case 'enum': {
    if(typeof raw!=='string'||!b.includes(raw)) invalid(field);
    const name=raw.split('_').map(x=>x.slice(0,1).toUpperCase()+x.slice(1)).join('');
    const ctor=spec.modules[a]?.[name];
    if(typeof ctor!=='function') invalid(field);
    return new ctor();
   }
   case 'hook': {
    const decode=hook(a);
    if(!decode) throw new Error('arg decoder hook is missing: '+a);
    return decode(raw,{c,s,fail,invalid,decodeArg:(t,r)=>decodeArg(t,r,field,s)});
   }
  }
  throw new Error('invalid arg type: '+head);
 }
 function decodeArgs(record,raw,s) {
  // 表に無い record(test の fixture が registry に足す口)は欄の名の値型で読む
  const types=spec.args[record.name]??record.args??(record.fields??[]).map(key=>[key,c.scalar[key]?['scalar',key]:['text']]);
  const before=hook('args_before');
  if(before) before(record.name,raw,{c,s,fail,invalid});
  return types.map(([key,type])=>{
   try { return decodeArg(type,raw[key],key,s); }
   catch(error) { if(error.message==='invalid_argument') error.field=key; throw error; }
  });
 }

 // ── 応答 ──────────────────────────────────────────────────────────────
 function response(s,body,status=200) {
  const headers=new Headers({'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-control-path':s.trace.join(',')});
  if(status===401) headers.set('www-authenticate','Bearer');
  for(const cookie of s.setCookies) headers.append('set-cookie',cookie);
  if(s.env.ISOLATE_MARKER==='1') headers.set('x-isolate-marker',String(s.invocation??1));
  return new Response(JSON.stringify(body??null),{status,headers});
 }
 function emptyResponse(s,status=202) {
  const headers=new Headers({'cache-control':'no-store','x-control-path':s.trace.join(',')});
  for(const cookie of s.setCookies) headers.append('set-cookie',cookie);
  if(s.env.ISOLATE_MARKER==='1') headers.set('x-isolate-marker',String(s.invocation??1));
  return new Response(null,{status,headers});
 }
 function apiEncode(name,value) {
  const encoded=c.encode(value);
  return hook('api_encode')?.(name,encoded)??encoded;
 }
 function failureStatus(service,code) {
  return hook('failure_status')?.(service,code)??422;
 }
 const allowed=['not_found','forbidden','unauthorized','rate_limited','suspended','adult_declaration_missing','consent_missing','invalid_argument','conflict'];
 function failure(s,error) {
  if(error.connector) return response(s,{code:'upstream_unavailable',connector:error.connector},503);
  const custom=hook('failure')?.(s,error,{response});
  if(custom) return custom;
  // 業務の失敗(logic の Fail と同じ綴り、status 422 か 400)はその名で、それ以外の内部の失敗は unavailable
  // PostgreSQL の RAISE(P0001)の文言も業務の失敗の名
  const business=typeof error.message==='string'&&/^[a-z][a-z0-9_]*$/.test(error.message)&&(error.status===422||error.status===400||error.code==='P0001');
  const name=allowed.includes(error.message)||business?error.message:'unavailable';
  return response(s,{code:name,...(name==='invalid_argument'?{field:error.field??'body'}:{})},error.status??(name==='unavailable'?503:422));
 }
 function failed(s,outcome) {
  const code=c.tag(outcome[0]);
  const encoded=apiEncode(s.record.name,outcome[0]);
  return response(s,{...(typeof encoded==='object'&&encoded?encoded:{}),code},failureStatus(s.record.name,code));
 }
 function outcomeResponse(s,outcome) {
  const custom=hook('respond')?.(s,outcome,{response,emptyResponse,c});
  if(custom) return custom;
  if(outcome instanceof spec.runtime.step.Fail) return failed(s,outcome);
  if(outcome instanceof spec.runtime.step.Accepted) return response(s,{[spec.accepted[s.record.name]??'id']:c.text(s.args.id)},202);
  return response(s,apiEncode(s.record.name,outcome[0]));
 }

 const check=(stage,number,fn)=>async s=>{
  s.trace.push(stage+':'+number);
  try { await fn(s);return s.earlyResponse?new spec.Error(s.earlyResponse):new spec.Ok(s); } catch(error) {return new spec.Error(failure(s,error));}
 };
 async function host(input,entries) {
  const s={...input,entries:[...entries],trace:[],setCookies:[],at:input.at??new Date().toISOString(),seed:crypto.randomUUID()};
  return check('entry',1,s=>{
   s.url=new URL(s.request.url);
   const hostFor=value=>{
    const variable=spec.hosts[c.tag(value)];
    return variable?s.env[variable]:undefined;
   };
   s.hosts=s.entries.flatMap(e=>[...e.hosts].map(hostFor)).filter(Boolean);
   s.entry=s.entries.find(e=>[...e.hosts].map(hostFor).includes(s.url.host));
   if(!s.entry) fail('not_found',404);
   s.cookies=cookies(s.request.headers.get('cookie'));
  })(s);
 }
 const route=check('entry',2,s=>{
  const candidates=[...registry.filter(r=>!r.module||![...r.module.service.allow].some(x=>c.tag(x.who)==='system')),...attached]
   .sort((a,b)=>b.path.split('/').filter(x=>x&&!x.startsWith(':')).length-a.path.split('/').filter(x=>x&&!x.startsWith(':')).length);
  const targets=new Map([...registry,...attached].map(r=>[r.name,r]));
  const apiEntry=isApiKeyEntry(s.entry);
  for(const r of candidates) {
   if(apiEntry!==(r.credential==='api_key')) continue;
   const tail=roleOf(r.name,'tail_path');
   if(tail ? !['GET','HEAD'].includes(s.request.method) : r.method!==s.request.method) continue;
   if(c.tag(s.entry.services)==='read_only' && (r.module?c.tag(r.module.effect)!=='read':r.method!=='GET')) continue;
   const names=[];
   // `tail_path` の口は最後の穴が `/` を含む残り全部を取る(`/media/:key` -> `^/media/(.+)$`)
   const pattern='^'+r.path.replace(/:([a-z_]+)/g,(m,name,at,path)=>{names.push(name);return tail&&at+m.length===path.length?'(.+)':'([^/]+)';})+'$';
   const match=s.url.pathname.match(new RegExp(pattern));
   if(match) {
    if(hook('route_skip')?.(r,s)) continue;
    const target=r.target?targets.get(r.target):r;
    s.record=r.target?{...target,...r,name:target.name,routeName:r.name}:r;
    s.pathArgs=Object.fromEntries(names.map((n,i)=>[n,match[i+1]]));return;
   }
  }
  fail('not_found',404);
 });
 const origin=check('entry',3,s=>{
  if(isApiKeyEntry(s.entry)) return;
  const expected=hook('origin')?.(s);
  if(['POST','PUT','DELETE'].includes(s.request.method)) {
   if(expected) {
    if(s.request.headers.get('origin')!==expected) fail('forbidden',403);
   } else if(!s.hosts.map(h=>'https://'+h).includes(s.request.headers.get('origin'))) fail('forbidden',403);
  } else if(expected&&s.request.headers.get('origin')!==expected&&hook('origin_always')?.(s)) fail('forbidden',403);
 });
 const browser=check('resolve',4,async s=>{
  if(hook('early')?.(s)) {s.earlyResponse=emptyResponse(s,202);return;}
  s.browser=bc?await verifyBrowser(s.env,s.cookies[bc.cookie],s.at):null;
 });
 const admit=check('resolve',5,async s=>{
  if(isApiKeyEntry(s.entry)) {
   const authorization=s.request.headers.get('authorization')??'';
   const match=new RegExp('^Bearer ('+spec.apiKeyPattern+')$').exec(authorization);
   if(!match) fail('unauthorized',401);
   s.apiKeyDigest=await spec.runtime.apiKeyHmac(s.env,match[1]);
   await applyApiRateLimit(s);
   return;
  }
  if(!s.cookies.session&&c.tag(s.entry.admit)==='authenticated') fail('forbidden',403);
 });
 const resolve=check('resolve',6,async s=>{
  if(isApiKeyEntry(s.entry)) {
   s.resolved=await spec.runtime.resolveApiKey(s.db,s.apiKeyDigest,s.at);
   if(!s.resolved) fail('unauthorized',401);
   return;
  }
  s.resolved=await spec.runtime.resolveSession(s.db,s.cookies.session,s.at);
  if(s.cookies.session&&!s.resolved) s.setCookies.push(sessionCookie('',s.env,true));
  if(s.resolved?.extended) s.setCookies.push(sessionCookie(s.cookies.session,s.env));
  if(!s.resolved&&c.tag(s.entry.admit)==='authenticated') fail('forbidden',403);
 });
 const subject=check('resolve',7,s=>{
  if(s.record?.entry&&s.record.entry!==s.entry.name) fail('forbidden',403);
  // Service routes are the only routes whose subject must match the entry's
  // declared subject set.  The attached session routes intentionally expose
  // the current session before a face switch.
  if(s.record?.module&&s.resolved?.subject_kind&&c.tag(s.entry.subject)==='subjects'&&![...s.entry.subject[0]].some(x=>c.tag(x)===s.resolved.subject_kind)) fail('forbidden',403);
 });
 const decode=check('decode',8,async s=>{
  let body={};
  if(['POST','PUT','DELETE'].includes(s.request.method)) {
   const contentType=(s.request.headers.get('content-type')??'').split(';',1)[0].trim().toLowerCase();
   if(!s.record.module&&hook('raw_body')?.(s,contentType)) {
    const length=Number(s.request.headers.get('content-length'));
    if(Number.isFinite(length)&&length>maxBlobBytes) fail('invalid_argument',400,'body');
    let raw;
    try {raw=await s.request.arrayBuffer();} catch {fail('invalid_argument',400,'body');}
    if(raw.byteLength>maxBlobBytes) fail('invalid_argument',400,'body');
    s.blobRaw=raw;
    s.blobContentType=contentType;
    s.args={};
    return;
   }
   try {const raw=await s.request.text();body=raw?JSON.parse(raw):{};if(!body||typeof body!=='object'||Array.isArray(body)) throw 0;}
   catch {fail('invalid_argument',400,'body');}
  }
  let path;
  try {path=Object.fromEntries(Object.entries(s.pathArgs).map(([k,v])=>[k,decodeURIComponent(v)]));} catch {fail('invalid_argument',400,'path');}
  const raw={...Object.fromEntries(s.url.searchParams),...body,...path};
  if(!s.record.module) {
   if(roleOf(s.record.name,'switch_subject')) {
    const kinds=spec.subjects;
    if(!kinds.includes(raw.kind)) fail('invalid_argument',400,'kind');
    const declared=s.entry?.subject;
    const ok=c.tag(declared)==='any_subject'||(c.tag(declared)==='subjects'&&[...declared[0]].some(x=>c.tag(x)===raw.kind));
    if(!ok) fail('forbidden',403);
    c.parse(raw.kind+'_id',raw.id);
   }
   hook('attached_args')?.(s,raw,{c,fail});
   s.args=raw;return;
  }
  if(s.record.externalId) await hook('external_id')(s,raw,{c,fail,run:spec.runtime.run});
  s.args=new s.record.module.Args(...decodeArgs(s.record,raw,s));
 });
 const judge=check('judge',9,s=>{
  const resolved=s.resolved,who=new Set(['anyone']);
  hook('judge')?.(s,{fail});
  if(resolved) who.add('party');
  if(resolved?.subject_kind) { who.add('as_'+resolved.subject_kind); who.add(resolved.subject_kind); }
  const write=s.record.module?c.tag(s.record.module.effect)==='write':s.record.method!=='GET';
  const matched=s.record.module?[...s.record.module.service.allow].filter(x=>who.has(c.tag(x.who))):who.has(s.record.who)?[{who:s.record.who}]:[];
  if(!matched.length) fail('forbidden',403);
  const gate=spec.phaseGates[s.record.name];
  if(gate&&!gate.includes(resolved?.phase)) fail('forbidden',403);
  if(roleOf(s.record.name,'needs_browser')&&!s.browser) fail('adult_declaration_missing',403);
  if(write&&resolved?.suspended) fail('suspended',403);
  if(write&&s.record.module&&hook('write_gate')?.(s,matched.map(x=>c.tag(x.who)))) fail('forbidden',403);
  for(const req of s.record.module?.requires??[]) {
   const kind=c.tag(req);
   if(kind==='adult'&&!s.browser) fail('adult_declaration_missing',403);
   if(kind!=='adult'&&!(resolved?.consents??[]).some(x=>x.kind===kind&&(kind!=='identity'||x.subject===req.from(s.args)))) fail('consent_missing',403);
  }
  s.clauses=s.record.module?matched.map(x=>({phases:c.tag(x.at)==='any_phase'?null:[...x.at[0]].map(c.tag),owner:c.tag(x.owner)})):[];
 });
 async function execute(s) {
  s.trace.push('execute:10');
  try {
   if(roleOf(s.record.name,'declare_browser')) {
    const id=s.browser?.id??Array.from(crypto.getRandomValues(new Uint8Array(16)),v=>v.toString(16).padStart(2,'0')).join('');
    const signed=await signBrowser(s.env,id,s.at);
    await spec.runtime.run(s.db,'framework/browser',[id,s.at]);
    s.setCookies.push(`${bc.cookie}=${signed}; Path=/; Domain=${s.env.COOKIE_DOMAIN}; HttpOnly; Secure; SameSite=Lax; Max-Age=${browserSeconds}`);
    return response(s,{adult:true});
   }
   if(roleOf(s.record.name,'read_session')) {
    const r=s.resolved;
    return response(s,r?{party:r.party,subject:r.subject_kind?{kind:r.subject_kind,id:r.subject_id,handle:r.handle,phase:r.phase}:null,subjects:r.subjects,consents:{use:r.consents.some(x=>x.kind==='use'),handling:r.consents.some(x=>x.kind==='handling')},suspended:r.suspended,adult:!!s.browser}:{anonymous:true,adult:!!s.browser});
   }
   if(roleOf(s.record.name,'switch_subject')) {
    const rows=await spec.runtime.run(s.db,'framework/session_subject_staff',[s.resolved.id,s.resolved.party,s.args.kind,s.args.id]);
    if(!rows.length) fail('not_found',404);
    return response(s,{subject:{kind:rows[0].subject_kind,id:rows[0].subject_id}});
   }
   const port=spec.ports[s.record.name];
   if(port) return await port(s,{c,response,emptyResponse,fail,run:spec.runtime.run});
   if(hook('early')?.(s)) return emptyResponse(s,202);
   const outcome=await spec.runtime.invoke(s);
   return outcomeResponse(s,outcome);
  } catch(error) {
   const recovered=await hook('db_error')?.(s,error,{response,c,run:spec.runtime.run,invoke:spec.runtime.invoke,outcomeResponse});
   if(recovered) return recovered;
   return failure(s,error);
  }
 }
 return {sessionCookie,cookies,signBrowser,verifyBrowser,host,route,origin,browser,admit,resolve,subject,decode,judge,execute,apiEncode,
  logicFailureStatus:failureStatus,failure,response,emptyResponse,outcomeResponse};
}
