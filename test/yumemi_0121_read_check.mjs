// yumemi-0121 ── 他の Service の読みを同じ名で 2 本 import しても、runtime(`ctx.read`)が取り違えない。
// 生成の読みは `read_of(ctx, owner, name, input)` で名と持ち主を運ぶ。`yumemi_0121_test_ffi.mjs` が子の node で走らせ、
// 1 行 1 件の ok / NG を出す。runtime.mjs は生成の step.mjs を読むので、gleam build の出力から読む。
import { runtime } from "../build/dev/javascript/yumemi/yumemi/server/runtime.mjs";
import { read, read_of } from "../build/dev/javascript/yumemi/yumemi/server/operations.mjs";

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

const a = await read_of(ctx, "feed_a", "rows", 1);
const b = await read_of(ctx, "feed_b", "rows", 2);
check("read_of runs the owner's query (a)", a.label === "feed_a" && a.input === 1);
check("read_of runs the owner's query (b)", b.label === "feed_b" && b.input === 2);
const own = await read_of(ctx, "timeline", "own", 3);
check("read_of of the record's own query", own.label === "timeline");
// 添えの無い口(0.12.0 までの生成物・手書きの FFI)は今までどおり
check("bare read still reads the record's own table", (await read(ctx, "own", 4)).label === "timeline");
check("bare read still follows readAliases", (await read(ctx, "rows", 5)).label === "feed_b");
let missing = null;
try { await read_of(ctx, "feed_c", "nothing", 6); } catch (error) { missing = String(error?.message); }
check("unknown read names the owner", missing === "unregistered read: feed_c/nothing");
// 名だけで引く ctx(★ の Durable Object・test の偽の ctx)には名がそのまま届く
const seen = [];
await read_of({ read: (name, input) => { seen.push([name, input]); return null; } }, "feed_a", "rows", 7);
check("a name-only ctx gets the bare name", JSON.stringify(seen) === JSON.stringify([["rows", 7]]));

console.log(out.join("\n"));
