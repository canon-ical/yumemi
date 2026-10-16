// yumemi yumemi/server ── 他人の書きを画面に届ける合図の札と宛先(0.15、yumemi-live-1)。
// 合図の宛先は Service の root の Entity と、root の行の id の組(`<entity>:<id>`)。表は生成の `registry.mjs` の
// `live`(Service -> [Entity の名, root の行の id の列])で、★ は書かない。
//
// - 札:読みの Service が通ったとき(allow と root が通った = その Entity を今読めた)、宛先・party・期限(1 時間)を
//   Worker secret `YUMEMI_LIVE_KEY` の HMAC-SHA256 で包み、応答の header `x-yumemi-live` に付ける。形は
//   `<payload>.<署名>`(どちらも base64url)、payload は `{"to":"<entity>:<id>","party":<party か null>,"exp":<秒>}`。
//   署名は `yumemi-live/1\n<payload>` の HMAC。合図に載るのは 1 語だけで、札も合図も Entity の値を持たない
// - 合図:書きの Service の commit の後に、入口が `waitUntil` で DO `YumemiLive`(binding `YUMEMI_LIVE`、
//   `idFromName(<宛先>)`)の `publish()` を呼ぶ。応答は待たず、落ちても応答は変わらない(log に 1 行)
// - binding が無ければ札も合図も無い(live を使わない app)。binding が在って鍵が無い・短い・読めないときも札と合図は
//   無く、`live.key_missing` を 1 行出す(0.13.2 の `IDEMPOTENCY_HASH_KEY` と同じ形の鍵、黙って鍵無しに落ちない)
const keyName='YUMEMI_LIVE_KEY';
const bindingName='YUMEMI_LIVE';
// 鍵の最短の長さ(字)。短い鍵は総当たりで割れるので、無いのと同じに断る
const keyMin=32;
// 札の期限(秒)
export const ttlSeconds=3600;
// 札の header の名
export const header='x-yumemi-live';
const label='yumemi-live/1\n';
const encoder=new TextEncoder();
// 鍵の値 -> 取り込んだ鍵(の Promise)。isolate の中で使い回す。差し替えで増えすぎたら捨てる
const keys=new Map();

const base64=bytes=>btoa(String.fromCharCode(...bytes)).replaceAll('+','-').replaceAll('/','_').replace(/=+$/,'');
function unbase64(raw) {
 if(typeof raw!=='string'||!/^[A-Za-z0-9_-]+$/.test(raw)) return null;
 try { return Uint8Array.from(atob(raw.replaceAll('-','+').replaceAll('_','/')),x=>x.charCodeAt(0)); } catch { return null; }
}

/** binding `YUMEMI_LIVE` が在るか(DO の namespace の形)。 */
export function bound(env) {
 const ns=env?.[bindingName];
 return Boolean(ns)&&typeof ns.idFromName==='function'&&typeof ns.get==='function';
}

/** env の鍵。Secret Store の binding(`.get()` が字を返す)か、素の字の secret。`{key}` か `{missing}`。 */
export async function keyOf(env) {
 const binding=env?.[keyName];
 if(binding===undefined||binding===null||binding==='') return {missing:'absent'};
 let value;
 try { value=typeof binding==='string'?binding:typeof binding.get==='function'?await binding.get():undefined; }
 catch { return {missing:'unreadable'}; }
 if(value===null||value==='') return {missing:'absent'};
 if(typeof value!=='string') return {missing:'unreadable'};
 if(value.length<keyMin) return {missing:'short'};
 let key=keys.get(value);
 if(!key) {
  if(keys.size>=4) keys.clear();
  key=crypto.subtle.importKey('raw',encoder.encode(value),{name:'HMAC',hash:'SHA-256'},false,['sign','verify']);
  keys.set(value,key);
  key.catch(()=>keys.delete(value));
 }
 return {key:await key};
}

/** 鍵の不足を 1 行。binding の名と理由だけ(値は出さない)。 */
export function keyLog(reason,service) {
 try { console.error(JSON.stringify({yumemi:'live.key_missing',binding:keyName,reason,service:service??null})); } catch {}
}

/** 宛先 `<entity>:<id>`。表に無い Service・root の行が無い・id の無い行は null。 */
export function destination(table,service,row) {
 const entry=table?.[service];
 if(!entry||!row) return null;
 const [entity,column]=entry;
 const id=row[column];
 if(id===undefined||id===null||id==='') return null;
 return entity+':'+String(id);
}

/** 札を作る。`now` は秒。 */
export async function issue(key,to,party,now) {
 const payload=base64(encoder.encode(JSON.stringify({to,party:party??null,exp:now+ttlSeconds})));
 const signature=new Uint8Array(await crypto.subtle.sign('HMAC',key,encoder.encode(label+payload)));
 return payload+'.'+base64(signature);
}

/**
 * 札を確かめる。`{to}` か `{reason}`(`token` 形が違う・`signature` 署名が合わない・`expired` 期限切れ・
 * `party` session の party と違う)。`party` は socket の要求の session の party(無ければ null)、`now` は秒。
 */
export async function verify(key,token,party,now) {
 if(typeof token!=='string'||token.length>2048) return {reason:'token'};
 const parts=token.split('.');
 if(parts.length!==2) return {reason:'token'};
 const [payload,signed]=parts;
 const signature=unbase64(signed);
 if(!unbase64(payload)||!signature) return {reason:'token'};
 if(!await crypto.subtle.verify('HMAC',key,signature,encoder.encode(label+payload))) return {reason:'signature'};
 let value;
 try { value=JSON.parse(new TextDecoder().decode(unbase64(payload))); } catch { return {reason:'token'}; }
 if(!value||typeof value!=='object'||typeof value.to!=='string'||!Number.isSafeInteger(value.exp)) return {reason:'token'};
 if(value.exp<=now) return {reason:'expired'};
 if((value.party??null)!==(party??null)) return {reason:'party'};
 return {to:value.to};
}

/** 宛先の DO の stub。 */
export function stub(env,to) {
 const ns=env[bindingName];
 return ns.get(ns.idFromName(to));
}

/** 合図。鍵を確かめてから DO の `publish()` を呼ぶ。落ちても投げず、log に 1 行。 */
export async function publish(env,to,service) {
 try {
  const current=await keyOf(env);
  if(current.missing) { keyLog(current.missing,service); return; }
  await stub(env,to).publish();
 } catch(error) {
  try { console.error(JSON.stringify({yumemi:'live.publish_failed',service:service??null,name:error?.name??null})); } catch {}
 }
}
