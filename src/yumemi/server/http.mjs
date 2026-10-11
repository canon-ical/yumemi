// yumemi yumemi/server ── HTTP の入口の検査 1〜10(WGy r3、0.11.1)。
// host → route → origin → browser → admit → resolve → subject → decode → judge → execute の段を持ち、
// 生成の `gen/entry/http.gleam` が段ごとに呼ぶ。名ごとの表は app の生成物 `gen/http_runtime.mjs` が渡す。
//
// spec の欄:
// - `registry` / `attached` / `c`(生成の codec)/ `runtime`(生成の runtime:resolveSession・resolveApiKey・
//   apiKeyHmac・invoke・run・step)/ `entryCredential`(yumemi/entry の credential)
// - `hosts`: 入口の名 -> env の変数名(`WWW_HOST`)
// - `args`: Service -> [[欄, 型の語彙]]。語彙は `decodeArg` を見よ
// - `modules`: 列挙の module の名 -> JS の module(構成子の和)
// - `phaseGates`: root を持たず、主体の相で絞る Service -> 通す相の名
// - `accepted`: Service -> Accepted の応答の欄の名(root の Entity)
// - `attached`: 口の名 -> ★ の実装(framework の session の口は機関が持つ)
// - `roles`: attached の口の名 -> 役の名の並び(`read_session` / `switch_subject` / `tail_path` と、種類を持つ
//   `declare:<kind>` / `needs_declared:<kind>`)。app の `src/server.gleam` の `attached_roles` から。framework は口の名を知らない
// - `browserCookie`: browser の署名 cookie(`{cookie,binding,maxAgeDays,declarations:[{kind,claim,maxAgeDays}]}`)か null。
//   payload の `id` がユニークの印、申告は種類ごとの `claim` の欄(申告の時刻)。`browser` の宣言から
// - `pageviews`: 入口の名 -> 数える口(`{only,fields,sink}`)。面の門の `pageview` から(0.12)。受け口は `<prefix>/_yumemi/pageviews`
// - `subjectFree`: 入口の主体の集合の検査を外す Service の名(`subject_free` の宣言から。主体を切り替える前に読む口)
// - `hooks`: ★ の業務の行(下の `hook(...)` の名)。どれも無くてよい
import * as framework_entry from '../entry.mjs';
import * as color from '../front/color.mjs';

export function http(spec) {
 const { c, registry, attached } = spec;
 const hook=(name)=>spec.hooks?.[name];
 const encoder=new TextEncoder();
 const cookieSeconds=30*86400;
 const bc=spec.browserCookie??null;
 const browserSeconds=(bc?.maxAgeDays??0)*86400;
 const roleOf=(name,role)=>(spec.roles?.[name]??[]).includes(role);
 // `declare:<kind>` / `needs_declared:<kind>` の種類の並び
 const roleKinds=(name,role)=>(spec.roles?.[name]??[]).filter(x=>x.startsWith(role+':')).map(x=>x.slice(role.length+1));
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
 // payload は `{id, <申告の claim>: 時刻, ..}`。`claims` は申告の claim の名 -> 時刻(印だけなら空)
 async function signBrowser(env,id,claims={}) {
  if(!bc) throw new Error('browser の宣言が無い');
  const payload=base64(encoder.encode(JSON.stringify({id,...claims})));
  return payload+'.'+base64(new Uint8Array(await crypto.subtle.sign('HMAC',await browserKey(env),encoder.encode(payload))));
 }
 // 署名が合い印(`id`)の形が正しければ `{id, claims, declared}`。`declared` は申告の種類 -> true で、申告の時刻が
 // その種類の `maxAgeDays` より古い・未来の申告は「申告なし」と読む(cookie が有効でも)。印は cookie の Max-Age が持つ
 async function verifyBrowser(env,raw,at) {
  if(!raw||!bc) return null;
  try {
   const [payload,signature,extra]=raw.split('.');
   if(extra!==undefined||!signature||!await crypto.subtle.verify('HMAC',await browserKey(env),bytes(signature),encoder.encode(payload))) return null;
   const value=JSON.parse(new TextDecoder().decode(bytes(payload)));
   if(!value||typeof value!=='object'||!/^[0-9a-f]{32}$/.test(value.id)) return null;
   const now=Date.parse(at),claims={},declared={};
   for(const d of bc.declarations??[]) {
    const time=typeof value[d.claim]==='string'?Date.parse(value[d.claim]):NaN;
    if(!Number.isFinite(time)||time>now) continue;
    claims[d.claim]=value[d.claim];
    if(now-time<=d.maxAgeDays*86400*1000) declared[d.kind]=true;
   }
   return {id:value.id,claims,declared};
  } catch { return null; }
 }
 const newBrowserId=()=>Array.from(crypto.getRandomValues(new Uint8Array(16)),v=>v.toString(16).padStart(2,'0')).join('');
 function browserSetCookie(s,signed) {
  return `${bc.cookie}=${signed}; Path=/; Domain=${s.env.COOKIE_DOMAIN}; HttpOnly; Secure; SameSite=Lax; Max-Age=${browserSeconds}`;
 }
 const declaredOf=s=>s.browser?.declared??{};
 const credentialOf=entry=>entry?(spec.entryCredential??framework_entry.credential)(entry):null;
 function isApiKeyEntry(entry) {
  const value=credentialOf(entry);
  return value!==null&&c.tag(value)==='api_key';
 }
 function apiKeyLimit(entry) {
  const value=credentialOf(entry);
  return Number(value?.per_minute??value?.[0]??0);
 }
 // `detail` は本文に足す欄(`declaration_missing` の `declaration`、`consent_missing` の `consent`)
 const fail=(message,status,field,detail)=>{throw Object.assign(new Error(message),{status,field,detail});};
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
 // GET の query から来た欄(0.11.2 H2)は綴りが文字列 ── `bool` は `true` / `false`、`float` は数の綴りを読む。
 // body(POST / PUT / DELETE の JSON)から来た欄は今までどおり JSON の型で読む。
 function queryRaw(type,raw) {
  if(typeof raw!=='string') return raw;
  const head=type[0]==='option'?type[1][0]:type[0];
  if(head==='bool') return raw==='true'?true:raw==='false'?false:raw;
  if(head==='float'&&/^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][-+]?[0-9]+)?$/.test(raw)) return Number(raw);
  return raw;
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
   case 'color': if(typeof raw!=='string') invalid(field); return c.checked(color.parse(raw),field);
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
   try { return decodeArg(type,s.queryKeys?.has(key)?queryRaw(type,raw[key]):raw[key],key,s); }
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
 const allowed=['not_found','forbidden','unauthorized','rate_limited','suspended','declaration_missing','consent_missing','invalid_argument','conflict'];
 function failure(s,error) {
  // 数える口の受け口は、どの段で落ちても本体無しの 202(送り手に理由を返さない)。想定外の失敗だけ log へ
  if(s.pageview) { pageviewLog(s,error); return emptyResponse(s,202); }
  if(error.connector) return response(s,{code:'upstream_unavailable',connector:error.connector},503);
  const custom=hook('failure')?.(s,error,{response});
  if(custom) return custom;
  // 業務の失敗(logic の Fail と同じ綴り、status 422 か 400)はその名で、それ以外の内部の失敗は unavailable
  // PostgreSQL の RAISE(P0001)の文言も業務の失敗の名
  const business=typeof error.message==='string'&&/^[a-z][a-z0-9_]*$/.test(error.message)&&(error.status===422||error.status===400||error.code==='P0001');
  const name=allowed.includes(error.message)||business?error.message:'unavailable';
  const detail=name==='declaration_missing'||name==='consent_missing'?(error.detail??{}):{};
  return response(s,{code:name,...(name==='invalid_argument'?{field:error.field??'body'}:{}),...detail},error.status??(name==='unavailable'?503:422));
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
  // 数える口の受け口(0.12):入口の prefix + `/_yumemi/pageviews` の POST。面の門が `pageview` を宣言した入口だけ
  const counted=spec.pageviews?.[s.entry.name];
  if(counted&&s.request.method==='POST'&&s.url.pathname===s.entry.prefix+'/_yumemi/pageviews') {
   s.pageview=counted;
   s.record={name:'_yumemi_pageviews',method:'POST',path:s.url.pathname,who:'anyone'};
   s.pathArgs={};
   return;
  }
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
  // 面を 2 つ以上・入口の全部でなく宣言した Service は、許す入口の集合(`entries`、0.11.5)の外で 403
  if(s.record?.entries&&!s.record.entries.includes(s.entry.name)) fail('forbidden',403);
  // Service routes are the only routes whose subject must match the entry's
  // declared subject set.  The attached session routes intentionally expose
  // the current session before a face switch.
  if(s.record?.module&&!(spec.subjectFree??[]).includes(s.record.name)&&s.resolved?.subject_kind&&c.tag(s.entry.subject)==='subjects'&&![...s.entry.subject[0]].some(x=>c.tag(x)===s.resolved.subject_kind)) fail('forbidden',403);
 });
 const decode=check('decode',8,async s=>{
  if(s.pageview) return;
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
  s.queryKeys=['POST','PUT','DELETE'].includes(s.request.method)?null:new Set([...s.url.searchParams.keys()].filter(key=>!(key in path)));
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
 // 要件(0.12):申告は browser の署名 cookie、同意は session の party の同意。`ConsentedFor` は対象を Args と突き合わせる。
 // 満たさない最初の要件を返す(全部満たせば null)。数える口の `ToService` も同じ関数で Service の要件を見る
 function unmetRequirement(s,module,args) {
  for(const req of module?.requires??[]) {
   const tag=c.tag(req);
   if(tag==='declared') { if(!declaredOf(s)[req.kind]) return {code:'declaration_missing',detail:{declaration:req.kind}}; continue; }
   const subject=tag==='consented_for'?req.subject(args):null;
   if(!(s.resolved?.consents??[]).some(x=>x.kind===req.kind&&(subject===null||x.subject===subject))) return {code:'consent_missing',detail:{consent:req.kind}};
  }
  return null;
 }
 const judge=check('judge',9,s=>{
  const resolved=s.resolved,who=new Set(['anyone']);
  if(s.pageview) return;
  hook('judge')?.(s,{fail});
  if(resolved) who.add('party');
  if(resolved?.subject_kind) { who.add('as_'+resolved.subject_kind); who.add(resolved.subject_kind); }
  const write=s.record.module?c.tag(s.record.module.effect)==='write':s.record.method!=='GET';
  const matched=s.record.module?[...s.record.module.service.allow].filter(x=>who.has(c.tag(x.who))):who.has(s.record.who)?[{who:s.record.who}]:[];
  if(!matched.length) fail('forbidden',403);
  const gate=spec.phaseGates[s.record.name];
  if(gate&&!gate.includes(resolved?.phase)) fail('forbidden',403);
  for(const kind of roleKinds(s.record.name,'needs_declared')) if(!declaredOf(s)[kind]) fail('declaration_missing',403,undefined,{declaration:kind});
  if(write&&resolved?.suspended) fail('suspended',403);
  if(write&&s.record.module&&hook('write_gate')?.(s,matched.map(x=>c.tag(x.who)))) fail('forbidden',403);
  const unmet=unmetRequirement(s,s.record.module,s.args);
  if(unmet) fail(unmet.code,403,undefined,unmet.detail);
  s.clauses=s.record.module?matched.map(x=>({phases:c.tag(x.at)==='any_phase'?null:[...x.at[0]].map(c.tag),owner:c.tag(x.owner)})):[];
 });
 async function execute(s) {
  s.trace.push('execute:10');
  try {
   if(s.pageview) return await pageview(s);
   const declares=roleKinds(s.record.name,'declare');
   if(declares.length) {
    // 申告を印の上の欄として焼く。印が無ければ作り、他の種類の申告の欄はそのまま残す
    const id=s.browser?.id??newBrowserId();
    const claims={...(s.browser?.claims??{})};
    const declared={...declaredOf(s)};
    for(const kind of declares) {
     const d=(bc?.declarations??[]).find(x=>x.kind===kind);
     if(!d) throw new Error('申告の種類が browser の宣言に無い: '+kind);
     claims[d.claim]=s.at;
     declared[kind]=true;
     await spec.runtime.run(s.db,'framework/browser',[id,s.at,kind]);
    }
    s.setCookies.push(browserSetCookie(s,await signBrowser(s.env,id,claims)));
    return response(s,{declared});
   }
   if(roleOf(s.record.name,'read_session')) {
    const r=s.resolved,declared=declaredOf(s);
    // 同意は party が持つ種類を全部返す(種類の名を framework は知らない)
    return response(s,r?{party:r.party,subject:r.subject_kind?{kind:r.subject_kind,id:r.subject_id,handle:r.handle,phase:r.phase}:null,subjects:r.subjects,consents:Object.fromEntries((r.consents??[]).map(x=>[x.kind,true])),suspended:r.suspended,declared}:{anonymous:true,declared});
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
 // ── 数える口の受け口(0.12)──────────────────────────────────────────────
 // 二重計数の 1〜6 のうち、ここが持つのは bot と監視(3)・先読み(4)と、欄の検査・数える条件・印の発行。
 // id の再送(2)・連打 60 件/分(5)・2 tab の同時(6)は器(`Store`)なら framework の SQL 関数が印の行ロックで持つ。
 // `ToService` の逃げ道は検査を通した event を app の Service へ渡す(2・5・6 は Service の側)。Service の `requires` は
 // ここで評価し、満たさない event は Service に届かない。句(`anyone` / `party`)の外も同じ。`phaseGates`・`suspended`・
 // hook の `judge` / `write_gate` は見ない。応答は常に 202
 const botAgent=/bot|crawl|spider|slurp|headless|lighthouse|monitor|uptime|pingdom|preview|facebookexternalhit|curl|wget|python-requests|go-http-client/i;
 const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
 function automated(request) {
  if(request.cf?.verifiedBotCategory) return true;
  if(/prefetch|prerender/i.test(request.headers.get('sec-purpose')??request.headers.get('purpose')??'')) return true;
  return botAgent.test(request.headers.get('user-agent')??'');
 }
 // 想定外の失敗(SQL・Service の例外・設定の不足)だけを log に出す。検査の段の拒否(`fail` の status を持つ)と、
 // Service の業務の失敗(PostgreSQL の RAISE、P0001)は数えない event として黙って落とす
 function pageviewLog(s,error) {
  if(error?.status!==undefined||error?.code==='P0001') return;
  console.error('yumemi pageview: event dropped',s.entry?.name??null,error);
 }
 const textField=(value,max)=>typeof value==='string'&&value.length>0&&value.length<=max?value:null;
 const pathField=value=>{const v=textField(value,2048);return v&&v.startsWith('/')&&!v.startsWith('//')&&!/[\\\u0000-\u001f]/.test(v)?v:null;};
 // 宣言した欄だけを取り出す。id は常に。形の外れた欄は落とし、必須の欄(id・kind・path)が外れたら null
 function pageviewEvent(config,raw) {
  if(!raw||typeof raw!=='object'||Array.isArray(raw)||typeof raw.id!=='string'||!uuid.test(raw.id)) return null;
  const event={id:raw.id};
  for(const field of config.fields) {
   switch(field.type) {
    case 'kind': if(!['initial','reload','spa'].includes(raw.kind)) return null; event.kind=raw.kind; break;
    case 'client_at': { const at=textField(raw.client_at,40); if(!at||!Number.isFinite(Date.parse(at))) return null; event.client_at=new Date(Date.parse(at)).toISOString(); break; }
    case 'path': { const path=pathField(raw.path); if(!path) return null; event.path=path; break; }
    case 'previous': if(typeof raw.prev==='string'&&uuid.test(raw.prev)) event.prev=raw.prev; break;
    case 'referrer': {
     if(event.prev||raw.prev) break;
     const path=pathField(raw.referrer_path);
     if(path) event.referrer_path=path;
     else if(typeof raw.referrer_host==='string'&&/^[a-z0-9.-]{1,253}(:[0-9]{1,5})?$/i.test(raw.referrer_host)) event.referrer_host=raw.referrer_host.toLowerCase();
     break;
    }
    case 'query': { const v=raw[field.name]; if(typeof v==='string'&&new RegExp('^[a-z0-9_]{1,'+field.max+'}$').test(v)) event[field.name]=v; break; }
   }
  }
  return event;
 }
 function pageviewOnly(s,config) {
  return config.only.every(when=>when.type==='declared'?declaredOf(s)[when.kind]===true:Boolean(s.resolved));
 }
 async function mintBrowser(s) {
  s.browser={id:newBrowserId(),claims:{},declared:{}};
  s.setCookies.push(browserSetCookie(s,await signBrowser(s.env,s.browser.id)));
 }
 async function pageview(s) {
  const config=s.pageview;
  if(automated(s.request)) return emptyResponse(s,202);
  let raw;
  try { raw=JSON.parse(await s.request.text()); } catch { return emptyResponse(s,202); }
  const event=pageviewEvent(config,raw);
  if(!event||!pageviewOnly(s,config)) return emptyResponse(s,202);
  try {
   if(config.sink.type==='service') await pageviewService(s,config.sink,event);
   else await pageviewStore(s,config,event);
  } catch(error) { pageviewLog(s,error); }
  return emptyResponse(s,202);
 }
 // 逃げ道 `ToService`:句と Service の `requires` を通った event だけを Service へ。印の cookie は Service が印を root に
 // 運ぶ(`Carried(.., "browser", ..)`)ときだけ、Service に届く event で焼く
 async function pageviewService(s,sink,event) {
  const record=registry.find(r=>r.name===sink.service);
  if(!record) throw new Error('数える口の Service が無い: '+sink.service);
  const passed={...s,record,queryKeys:null};
  passed.args=new record.module.Args(...decodeArgs(record,event,passed));
  passed.clauses=[...record.module.service.allow].filter(x=>['anyone','party'].includes(c.tag(x.who))&&(c.tag(x.who)==='anyone'||s.resolved))
   .map(x=>({phases:c.tag(x.at)==='any_phase'?null:[...x.at[0]].map(c.tag),owner:c.tag(x.owner)}));
  if(!passed.clauses.length||unmetRequirement(s,record.module,passed.args)) return;
  if(sink.browser&&bc&&!s.browser) { await mintBrowser(s); passed.browser=s.browser; }
  await spec.runtime.invoke(passed);
 }
 // 器 `Store`:印は器の行の単位なので、数える条件を満たした最初の event で印の無い browser に印だけの cookie を焼く
 async function pageviewStore(s,config,event) {
  const sink=config.sink;
  if(bc&&!s.browser) await mintBrowser(s);
  if(!s.browser) throw new Error('数える口の器 Store に browser の宣言が無い');
  let dims={},excluded=false;
  if(sink.resolve) {
   const record=registry.find(r=>r.name===sink.resolve);
   if(!record) throw new Error('数える口の resolve の Service が無い: '+sink.resolve);
   const passed={...s,record,queryKeys:null};
   passed.args=new record.module.Args(...decodeArgs(record,{path:event.path},passed));
   passed.clauses=[{phases:null,owner:'no_owner'}];
   const outcome=await spec.runtime.invoke(passed);
   if(outcome instanceof spec.runtime.step.Fail) return;
   const out=c.encode(outcome[0])??{};
   for(const name of sink.rollupBy) if(out[name]!==undefined&&out[name]!==null) dims[name]=String(out[name]);
   excluded=sink.excludeWhen.some(name=>out[name]===true);
  }
  const extra=Object.fromEntries(config.fields.filter(f=>f.type==='query'&&event[f.name]!==undefined).map(f=>[f.name,event[f.name]]));
  // 器の fields は Path を必ず持つ(第 37 条)ので path は event に在る
  await spec.runtime.run(s.db,'framework/pageview_record',[
   event.id,s.browser.id,s.entry.name,s.at,event.kind??'initial',event.path,event.prev??null,event.referrer_path??null,
   event.referrer_host??null,event.client_at??null,s.resolved?.party??null,JSON.stringify(extra),JSON.stringify(dims),excluded,
  ]);
 }
 return {sessionCookie,cookies,signBrowser,verifyBrowser,host,route,origin,browser,admit,resolve,subject,decode,judge,execute,apiEncode,
  logicFailureStatus:failureStatus,failure,response,emptyResponse,outcomeResponse};
}
