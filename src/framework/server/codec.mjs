// yumemi framework/server ── 行と値の間の写しの共通の口(WGy、0.11.1)。app の生成物 `gen/codec.mjs` が
// scalar の表(値型の module)と整数の値型の名を渡して作り、Entity ごとの decoder は生成物が書く。
export function codec({ scalar, integerKeys, Some, None, List, time }) {
 function checked(result, field='value') {
  if (!result.isOk()) throw Object.assign(new Error('invalid_argument'),{status:400,field});
  return result[0];
 }
 function parse(key, raw) {
  if (integerKeys.has(key) ? !Number.isInteger(raw) : typeof raw!=='string') throw Object.assign(new Error('invalid_argument'),{status:400,field:key});
  return checked(scalar[key].parse(raw),key);
 }
 const option = (value, f=x=>x) => value==null ? new None() : new Some(f(value));
 const unwrap = value => value instanceof None ? null : value instanceof Some ? unwrap(value[0]) : value;
 const text = value => value == null ? null : typeof value==='object' ? value.value ?? value.key ?? value : value;
 const tag = value => value.constructor.name.replace(/([a-z0-9])([A-Z])/g,'$1_$2').toLowerCase();
 function encode(value) {
  if (value==null || typeof value!=='object') return value;
  if (value instanceof None) return null;
  if (value instanceof Some) return encode(value[0]);
  if (value instanceof List) return [...value].map(encode);
  if (Array.isArray(value)) return value.map(encode);
  if ('value' in value && Object.keys(value).length===1) return encode(value.value);
  if ('key' in value && Object.keys(value).length===1) return encode(value.key);
  if (!Object.keys(value).length) return tag(value);
  return Object.fromEntries(Object.entries(value).map(([k,v])=>[k,encode(v)]));
 }
 function phase(module, raw) { const ctorName=String(raw).split('_').map(part=>part[0].toUpperCase()+part.slice(1)).join(''); const ctor=module[ctorName]; if(!ctor) throw new Error('invalid stored phase'); return new ctor(); }
 const timeText = raw => raw instanceof Date ? raw.toISOString() : raw;
 const dateText = raw => raw instanceof Date ? [raw.getFullYear(),String(raw.getMonth()+1).padStart(2,'0'),String(raw.getDate()).padStart(2,'0')].join('-') : String(raw);
 const cDate = raw => checked(time.date(dateText(raw).slice(0,10)));
 const cDatetime = raw => checked(time.datetime(String(timeText(raw))));
 const cTime = raw => checked(time.time(String(raw)));
 const list = (raw, f) => List.fromArray((typeof raw==='string'?JSON.parse(raw):(raw??[])).map(f));
 return { checked, parse, option, unwrap, text, tag, encode, phase, timeText, dateText, cDate, cDatetime, cTime, list };
}
