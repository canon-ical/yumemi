// yumemi yumemi/front ── いま class を集めている所の規則(class 名 → CSS の字、足した順)を 1 つ持つ
// (0.12 段 C、sketch の stylesheet の代わり)。`sketch_css.collect` が頁を描く間だけ差し替える。
let rules = null;

export function add(name, css) {
  if (rules !== null && !rules.has(name)) rules.set(name, css);
}

export function start() {
  const previous = rules;
  rules = new Map();
  return previous;
}

export function finish(previous) {
  const css = rules === null ? "" : [...rules.values()].join("\n\n");
  rules = previous;
  return css;
}
