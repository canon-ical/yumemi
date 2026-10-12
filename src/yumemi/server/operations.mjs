// yumemi yumemi/server ── connector / verb / reads が ctx に渡す口(WGy、0.11.1)。
// 生成の `gen/connector/*.gleam` と `gen/reads/*.gleam` が FFI で呼ぶ。実体は runtime の makeContext が持つ。
export const stage = (ctx, name, input) => ctx.stage(name, input);
export const read = (ctx, name, input) => ctx.read(name, input);
// 生成の読みの口(0.12.1)。名は今までどおり運び、持ち主の Service を 3 つ目に添える ── 他の Service の読みを同じ名で
// 2 本 import しても runtime が取り違えない。名だけで引く ctx(★ の Durable Object・test の偽の ctx)は 3 つ目を見ない
export const read_of = (ctx, owner, name, input) => ctx.read(name, input, owner);
export const call = (ctx, name, input) => ctx.call(name, input);
export const enqueue = (ctx, kind, input) => ctx.enqueue(kind, input);
