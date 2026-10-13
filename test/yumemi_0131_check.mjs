// yumemi-0131(0.13.1)── 内部の失敗の log を子の node で回す。`yumemi_0131_test_ffi.mjs` が `node test/yumemi_0131_check.mjs <which>`
// で走らせ、1 行 1 件の ok / NG を出す。
// `unavailable`:入口(http の execute)と runtime を偽の DB で回し、書きの transaction が一意の制約(23505)で落ちたときに
// 制約の名の付いた 1 行が log に出るか、応答は今までどおり 503 unavailable か、log を出さない形(★ の db_error が拾う・
// 業務の失敗・DB の外の失敗)を見る。
const out = [];
const check = (name, ok, detail) => out.push((ok ? "ok " : "NG ") + name + (ok ? "" : " " + JSON.stringify(detail)));

async function unavailable() {
  const { http } = await import("../build/dev/javascript/yumemi/yumemi/server/http.mjs");
  const { runtime } = await import("../build/dev/javascript/yumemi/yumemi/server/runtime.mjs");
  const step = await import("../build/dev/javascript/yumemi/yumemi/step.mjs");
  const verb = await import("../build/dev/javascript/yumemi/yumemi/verb.mjs");

  // 書きの transaction が投げるもの(要求ごとに替える)
  let failure = null;
  const database = () => ({
    async query() { return []; },
    async transaction(operations) {
      if (failure) throw failure();
      return operations.map((x) => (x.key === "verb/create_note" ? [{ id: x.params[0], title: x.params[1] }] : []));
    },
  });
  const unique = () => Object.assign(new Error('duplicate key value violates unique constraint "note_title_key"'),
    { code: "23505", constraint: "note_title_key", table: "note", detail: "Key (title)=(秘密の題) already exists." });
  const raised = () => Object.assign(new Error("title_taken"), { code: "P0001" });
  const outage = () => Object.assign(new Error("fetch failed"), { connector: "neon", status: 503 });
  const thrown = () => new TypeError("cannot read properties of undefined");

  class NoteCreated { constructor(id, title) { this.id = id; this.title = title; } }
  class Root { constructor(at, seed) { this.at = at; this.seed = seed; } }
  class Args { constructor(title) { this.title = title; } }
  const tagged = (tag) => ({ tag });
  const c = {
    tag: (value) => value?.tag,
    encode: (value) => (value && typeof value === "object" ? JSON.parse(JSON.stringify(value)) : value ?? null),
    parse: (_scalar, value) => value, text: (value) => value, checked: (value) => value,
    time: { datetime: (value) => value }, party: { parse: (value) => value },
  };
  const SQL = Object.fromEntries(["verb/create_note", "framework/audit"].map((key) => [key, "-- " + key]));
  const logic = (_actor, _root, args) =>
    step.apply(verb.staged((ctx) => ctx.stage("create_note", { title: args.title })), (created) => step.done(created));
  const record = { name: "note_create", module: { effect: tagged("write"), service: { allow: [] }, Args, logic }, root: { Root } };
  const rt = runtime({
    SQL, c, roots: {}, actors: {}, manualVerbs: { names: new Set() }, connectors: {}, connectorNames: {}, folds: {}, enqueues: {},
    boundaries: new Set(), relationDecoders: {}, phaseModules: {}, encoders: {}, carried: {}, reads: {}, subjects: [],
    verbs: { create_note: { key: "verb/create_note", params: [["id"], ["f", "title", null]], created: ["note", "NoteCreated", ["id", "title"], "note_id"] } },
    drafts: { note: { NoteCreated } },
  });
  class Ok { constructor(value) { this[0] = value; } }
  class Er { constructor(value) { this[0] = value; } }
  // ★ の db_error は `picked` の制約だけを拾う
  const hooks = {
    db_error(s, error, x) {
      if (error.constraint !== "picked") return undefined;
      return x.response(s, { code: "conflict" }, 409);
    },
  };
  const h = http({ c, registry: [], attached: [], Ok, Error: Er, hosts: {}, runtime: rt, roles: {}, ports: {}, accepted: {}, args: {}, hooks });

  let seeds = 0;
  async function post(make) {
    failure = make;
    const lines = [];
    const original = console.error;
    console.error = (...args) => lines.push(args.map(String).join(" "));
    try {
      const request = new Request("https://api.test/api/notes", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ title: "t" }) });
      const s = { request, env: {}, db: database(), trace: [], setCookies: [], record, args: new Args("t"), rawArgs: { title: "t" },
        resolved: { party: "party-a" }, clauses: [], at: "2026-10-13T00:00:00.000Z", seed: "seed-" + ++seeds };
      const response = await h.execute(s);
      return { status: response.status, body: await response.text(), lines };
    } finally {
      console.error = original;
    }
  }

  const ok = await post(null);
  check("ok: a write without failure answers 200 and logs nothing", ok.status === 200 && ok.lines.length === 0, ok);

  const dup = await post(unique);
  check("unique: the response stays 503 unavailable", dup.status === 503 && JSON.parse(dup.body).code === "unavailable", dup);
  const line = dup.lines.map((x) => { try { return JSON.parse(x); } catch { return null; } }).find((x) => x?.yumemi === "request.unavailable");
  check("unique: one log line names the constraint, the table and the SQLSTATE", dup.lines.length === 1 && line?.constraint === "note_title_key" && line?.table === "note" && line?.code === "23505" && line?.service === "note_create", dup.lines);
  check("unique: the log line leaves out the detail (the key's value)", !dup.lines.join("\n").includes("秘密の題"), dup.lines);

  const odd = await post(thrown);
  const oddLine = odd.lines.map((x) => { try { return JSON.parse(x); } catch { return null; } }).find((x) => x?.yumemi === "request.unavailable");
  check("thrown: a plain exception is 503 with its name and message in the log", odd.status === 503 && oddLine?.name === "TypeError" && oddLine?.message.includes("cannot read") && oddLine?.code === null, odd);

  const business = await post(raised);
  check("business: a RAISE (P0001) keeps its name and 422, no log", business.status === 422 && JSON.parse(business.body).code === "title_taken" && business.lines.length === 0, business);

  const down = await post(outage);
  check("connector: a failure outside the DB stays upstream_unavailable, no unavailable line", down.status === 503 && JSON.parse(down.body).code === "upstream_unavailable" && !down.lines.some((x) => x.includes("request.unavailable")), down);

  const picked = await post(() => Object.assign(new Error("dup"), { code: "23505", constraint: "picked" }));
  check("hook: the db_error hook's answer wins and logs nothing", picked.status === 409 && picked.lines.length === 0, picked);
}

const [which] = process.argv.slice(2);
try {
  if (which === "unavailable") await unavailable();
} catch (error) {
  out.push("NG threw " + (error?.stack ?? error));
}
console.log(out.join("\n"));
