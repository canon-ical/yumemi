// yumemi-0121 ── 他の Service の読みを同じ名で 2 本 import しても、runtime(`ctx.read`)が取り違えない。
// `yumemi_0121_test_ffi.mjs` が子の node で走らせ、1 行 1 件の ok / NG を出す。
// runtime.mjs は生成の step.mjs を読むので、gleam build の出力から読む
import { runtime } from "../build/dev/javascript/yumemi/yumemi/server/runtime.mjs";

const out = [];
const check = (name, ok) => out.push((ok ? "ok " : "NG ") + name);
const hook = (label) => ({ hook: async (input) => ({ label, input }) });
const spec = {
  SQL: {}, c: {}, roots: {}, actors: {}, verbs: {}, manualVerbs: { names: new Set() }, connectors: {}, connectorNames: {},
  folds: {}, enqueues: {}, boundaries: new Set(), relationDecoders: {}, phaseModules: {}, drafts: {}, subjects: [],
  encoders: {}, carried: {},
  reads: { "feed_a/rows": hook("feed_a"), "feed_b/rows": hook("feed_b"), "timeline/own": hook("timeline") },
  // 0.12.0 の取り違え:timeline が feed_b・feed_a の順に import していると、名だけの `rows` は先の feed_b を引く
  readAliases: { timeline: ["feed_b", "feed_a"] },
};
const { makeContext } = runtime(spec);
const ctx = makeContext({ record: { name: "timeline" }, db: null, root: null, at: 0, seed: "s" });

const a = await ctx.read("feed_a/rows", 1);
const b = await ctx.read("feed_b/rows", 2);
check("qualified read runs its own service's query (a)", a.label === "feed_a" && a.input === 1);
check("qualified read runs its own service's query (b)", b.label === "feed_b" && b.input === 2);
const own = await ctx.read("timeline/own", 3);
check("qualified read of the record's own query", own.label === "timeline");
// 名だけの口(0.12.0 までの生成物・手書きの FFI)は今までどおり
const bare = await ctx.read("own", 4);
check("bare name still reads the record's own table", bare.label === "timeline");
const aliased = await ctx.read("rows", 5);
check("bare name still follows readAliases", aliased.label === "feed_b");
let missing = null;
try { await ctx.read("feed_c/rows", 6); } catch (error) { missing = String(error?.message); }
check("unknown qualified read names the key", missing === "unregistered read: feed_c/rows");

console.log(out.join("\n"));
