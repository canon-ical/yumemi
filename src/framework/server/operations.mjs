// yumemi framework/server ── connector / verb / reads が ctx に渡す 4 つの口(WGy、0.11.1)。
// 生成の `gen/connector/*.gleam` と `gen/reads/*.gleam` が FFI で呼ぶ。実体は runtime の makeContext が持つ。
export const stage = (ctx, name, input) => ctx.stage(name, input);
export const read = (ctx, name, input) => ctx.read(name, input);
export const call = (ctx, name, input) => ctx.call(name, input);
export const enqueue = (ctx, kind, input) => ctx.enqueue(kind, input);
