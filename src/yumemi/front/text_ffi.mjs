// yumemi yumemi/front ── 字の頭と尻(0.13.1)。gleam_stdlib の JS の `trim_end` は正規表現 `[空白]*$` で、字の中に
// 長い空白の連なりがあると長さの 2 乗かかる(3 万字の空白で 1 回 270 ms)。`string.length`・`string.drop_start` は
// 字(grapheme)を Intl.Segmenter で数え、`drop_start` は行の全部を UTF-8 に直す。行ごとに何度も呼ぶ所で、頭が ASCII
// の字下げや印なら code unit で数える(ASCII の字は 1 字が 1 grapheme。次の字が結合する字なら数えない)。

// stdlib の `unicode_whitespaces` と同じ集合
const spaces = new Set([0x20, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x85, 0x2028, 0x2029]);

export function trim_end(text) {
  let end = text.length;
  while (end > 0 && spaces.has(text.charCodeAt(end - 1))) end--;
  return end === text.length ? text : text.slice(0, end);
}

// 次の字が前の字に結合しうるか(U+0300 より前の字は結合しない)
const joins = (text, index) => index < text.length && text.charCodeAt(index) >= 0x300;

// 頭の空白(` `・タブ・VT・FF)の数。CR などそれ以外の空白が続くか、次の字が結合しうるなら -1(呼ぶ側が字で数える)。
export function ascii_indent(text) {
  let index = 0;
  for (; index < text.length; index++) {
    const code = text.charCodeAt(index);
    if (code === 0x20 || code === 0x09 || code === 0x0b || code === 0x0c) continue;
    if (spaces.has(code)) return -1;
    break;
  }
  return joins(text, index) ? -1 : index;
}

// 頭の `count` 字が CR でない ASCII で、次の字が結合しないか(そのとき頭の `count` 字は `count` grapheme)。
export function ascii_head(text, count) {
  if (count > text.length) return false;
  for (let index = 0; index < count; index++) {
    const code = text.charCodeAt(index);
    if (code >= 0x80 || code === 0x0d) return false;
  }
  return !joins(text, count);
}

export function drop_units(text, count) {
  return text.slice(count);
}
