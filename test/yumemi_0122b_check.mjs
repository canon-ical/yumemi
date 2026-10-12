// yumemi-0122b ── framework の runtime の 2 つの柵を子の node で回す。
// `auto`:`auto_key` の Entity の作る verb(生成の verb の表の 1 行を argv で受ける)を stage すると、key を runtime が
// 採番して INSERT の穴に渡し、作った値の key も同じ値になる。
// `size`:`Paged(size: Param(..))` の size が 1 未満なら、SQL を流す前に 400 `invalid_argument`(field は穴の名)。
// `yumemi_0122b_test_ffi.mjs` が `node test/yumemi_0122b_check.mjs <auto|size> <verb>` で走らせ、1 行 1 件の ok / NG を出す。
import { runtime } from "../build/dev/javascript/yumemi/yumemi/server/runtime.mjs";

const out = [];
const check = (name, ok, got) => out.push((ok ? "ok " : "NG ") + name + (ok ? "" : " " + JSON.stringify(got)));
const invalid = (field) => Object.assign(new Error("invalid_argument"), { status: 400, field });
const base = {
  roots: {}, actors: {}, verbs: {}, manualVerbs: { names: new Set() }, connectors: {}, connectorNames: {},
  folds: {}, enqueues: {}, boundaries: new Set(), relationDecoders: {}, phaseModules: {}, drafts: {}, subjects: [],
  encoders: {}, carried: {}, SQL: {}, reads: {},
};
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

async function auto(line) {
  // ` create_note:{key:..},` -> { create_note: {..} }
  const verbs = new Function(`return ({${line.trim().replace(/,$/, "")}});`)();
  const [name] = Object.keys(verbs);
  class NoteCreated { constructor(...fields) { this.fields = fields; } }
  // 生成の codec の `parse` と同じく、値の無い key は 400(field は scalar の名)
  const c = { parse: (scalar, value) => { if (value == null) throw invalid(scalar); return value; }, text: (v) => v, encode: (v) => v };
  const spec = { ...base, c, verbs, drafts: { note: { NoteCreated } } };
  const { makeContext } = runtime(spec);
  const ctx = makeContext({ record: { name: "note_create" }, db: {}, root: null, at: "2026-10-13T00:00:00.000Z", seed: "seed-1" });
  let created, error;
  try { created = await ctx.stage(name, { title: "t", body: "b", created_at: "2026-10-13T00:00:00.000Z" }); }
  catch (cause) { error = { message: cause.message, status: cause.status, field: cause.field }; }
  check("an auto_key create stages without invalid_argument", error === undefined, error);
  const [statement] = ctx.pending;
  const id = statement?.params?.[0];
  check("the key reaches the INSERT's first hole", typeof id === "string" && uuid.test(id), statement?.params);
  check("the created value carries the same key", id != null && created?.fields?.[0] === id, created?.fields);
  check("the rest of the created value is the draft", JSON.stringify(created?.fields?.slice(1)) === JSON.stringify(["t", "b", "2026-10-13T00:00:00.000Z"]), created?.fields);
  // 同じ seed なら同じ key(採番は seed と要求の中の順番だけで決まる。Queue の retry は seed を引き直すので、
  // retry で行が 1 つなのは outbox_done が同じ transaction に入るからで、この柵ではない)
  const again = makeContext({ record: { name: "note_create" }, db: {}, root: null, at: "2026-10-13T00:00:00.000Z", seed: "seed-1" });
  await again.stage(name, { title: "t", body: "b", created_at: "2026-10-13T00:00:00.000Z" }).catch(() => {});
  check("the same seed gives the same key", id != null && again.pending[0]?.params?.[0] === id, again.pending[0]?.params?.[0]);
}

async function size() {
  class Page { constructor(items, next) { this.items = items; this.next = next; } }
  const c = {
    toList: (items) => items, option: (value, f = (x) => x) => (value == null ? null : f(value)),
    unwrap: (value) => value, text: (value) => value, encode: (value) => value, checked: (value) => value,
    page: { Page, cursor: (raw) => raw },
  };
  const spec = {
    ...base, c,
    SQL: { "notes/sized": "-- LIMIT $1 + 1" },
    reads: {
      "notes/sized": { key: "notes/sized", args: [["enc"], ["cursor"]], allow: [], out: ["page", ["int", "n"]], keyset: { size: 20, sizeArg: 0, sizeField: "limit", uniform: true, columns: [["n", "value"]] } },
    },
  };
  const rows = Array.from({ length: 50 }, (_, i) => ({ n: i + 1 }));
  let queried = 0;
  const db = { async query(text, params) { queried++; return rows.slice(0, Math.max(params[0] + 1, 0)); } };
  const { makeContext } = runtime(spec);
  const ctx = makeContext({ record: { name: "notes" }, db, root: null, at: 0, seed: "s" });
  for (const size of [0, -1]) {
    let error;
    try { await ctx.read("sized", [size, null]); } catch (cause) { error = { message: cause.message, status: cause.status, field: cause.field }; }
    check(`size ${size}: 400 invalid_argument on the size's name`, error?.status === 400 && error?.message === "invalid_argument" && error?.field === "limit", error);
  }
  check("a size below 1 does not reach SQL", queried === 0, queried);
  const one = await ctx.read("sized", [1, null]);
  check("size 1: 1 item and next", one.items.length === 1 && one.next != null, [one.items.length, one.next]);
  // keyset に名の無い生成物(r1 の形)は field を `size` にする
  delete spec.reads["notes/sized"].keyset.sizeField;
  let error;
  try { await ctx.read("sized", [0, null]); } catch (cause) { error = { status: cause.status, field: cause.field }; }
  check("without sizeField the field is size", error?.status === 400 && error?.field === "size", error);
}

const [which, verb] = process.argv.slice(2);
if (which === "auto") await auto(verb);
else if (which === "size") await size();
else out.push("NG unknown check " + which);
console.log(out.join("\n"));
