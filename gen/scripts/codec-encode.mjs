////`api/src/gen/codec.mjs` から写した値 encoder。本体一致は verify-encode-copy.mjs で検査する。

export function makeEncode({ Some, None, List }) {
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
  return encode;
}
