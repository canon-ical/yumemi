export function matches(raw, pattern) {
  return new RegExp(pattern, "u").test(raw);
}

export const codepoints = (raw) => Array.from(raw).length;

export function validInteger(raw, min, max) {
  if (!/^-?(?:0|[1-9][0-9]*)$/.test(raw)) return false;
  const n = Number(raw);
  return Number.isSafeInteger(n) && n >= min && n <= max;
}
export function validUrl(raw) {
  try { const u = new URL(raw); return ['http:', 'https:'].includes(u.protocol) && !!u.hostname && !u.username && !u.password; }
  catch { return false; }
}
