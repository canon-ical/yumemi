// yumemi-idem(0.13)── 冪等キーを子の node で回す。`yumemi_idem_test_ffi.mjs` が `node test/yumemi_idem_check.mjs <which>`
// で走らせ、1 行 1 件の ok / NG を出す。
// `server`:入口(http の execute)と runtime を、取引の付いた偽の DB(一意の制約・commit の後に応答を捨てる形・並んだ 2 本)で回す。
// `client`:interactive の送りを偽の DOM で回す(キーを作る・保つ・捨てる、503 で失敗の After に移らない、file の欄は上げ直さない)。
// `purge`:cron の古い行の消し(保持期間の既定と env)。
const out = [];
const check = (name, ok, detail) => out.push((ok ? "ok " : "NG ") + name + (ok ? "" : " " + JSON.stringify(detail)));

// ── server ────────────────────────────────────────────────────────────────
async function server() {
  const { http } = await import("../build/dev/javascript/yumemi/yumemi/server/http.mjs");
  const { runtime } = await import("../build/dev/javascript/yumemi/yumemi/server/runtime.mjs");
  const step = await import("../build/dev/javascript/yumemi/yumemi/step.mjs");
  const verb = await import("../build/dev/javascript/yumemi/yumemi/verb.mjs");

  // 偽の DB。transaction は写しに当てて全部通れば入れ替える(1 文でも落ちれば何も残らない)
  const data = { notes: [], rejects: [], idem: new Map(), audit: 0 };
  const log = [];
  // verb/create_flaky の transaction を業務の一意の制約で落とす回数(★ の db_error が走らせ直す形)
  let flaky = 0;
  const clone = (d) => ({ notes: [...d.notes], rejects: [...d.rejects], idem: new Map(d.idem), audit: d.audit });
  const unique = () => Object.assign(new Error('duplicate key value violates unique constraint "idempotency_pkey"'), { code: "23505", constraint: "idempotency_pkey" });
  function exec(d, key, params) {
    switch (key) {
      case "framework/idempotency_find": {
        const row = d.idem.get(params[0] + "\u0000" + params[1]);
        // jsonb は driver が値に読む
        return row ? [{ request_hash: row.request_hash, result: JSON.parse(row.result) }] : [];
      }
      case "framework/idempotency_record":
        if (d.idem.has(params[0] + "\u0000" + params[1])) throw unique();
        d.idem.set(params[0] + "\u0000" + params[1], { request_hash: params[2], result: params[3], created_at: params[4] });
        return [];
      case "framework/idempotency_repair": {
        const row = d.idem.get(params[0] + "\u0000" + params[1]);
        if (row) row.result = params[2];
        return [];
      }
      case "verb/create_note": d.notes.push({ id: params[0], title: params[1] }); return [{ id: params[0], title: params[1] }];
      case "verb/create_flaky":
        if (flaky-- > 0) throw Object.assign(new Error("duplicate key"), { code: "23505", constraint: "note_title_key" });
        d.notes.push({ id: params[0], title: params[1] }); return [{ id: params[0], title: params[1] }];
      case "verb/create_ordered": {
        const order = d.notes.length + 1;
        d.notes.push({ id: params[0], title: params[1], order });
        return [{ id: params[0], title: params[1], order }];
      }
      case "verb/reject_note": d.rejects.push(params[0]); return [];
      case "framework/audit": d.audit++; return [];
    }
    throw new Error("unknown key " + key);
  }
  const outage = () => Object.assign(new Error("Server error (HTTP status 503): dleam: database unavailable"), { connector: "neon", status: 503 });
  // mode.drop:transaction は commit してから応答を捨て(DB に届かない 503)、その要求の後の文も届かない
  // mode.hold:最初の transaction を、次の transaction が commit するまで待たせる(並んだ 2 本)
  function database(mode = {}) {
    let down = false;
    return {
      async query(text, params, key) {
        log.push(key);
        if (down) throw outage();
        return exec(data, key, params);
      },
      async transaction(operations) {
        log.push("tx:" + operations.map((x) => x.key).join(","));
        if (down) throw outage();
        if (mode.hold) await mode.hold();
        const draft = clone(data);
        let results;
        try { results = operations.map((x) => exec(draft, x.key, x.params)); }
        finally { mode.after?.(); }
        Object.assign(data, draft);
        if (mode.drop) { down = true; throw outage(); }
        return results;
      },
    };
  }

  class NoteCreated { constructor(id, title, order) { this.id = id; this.title = title; if (order !== undefined) this.order = order; } }
  class Root { constructor(at, seed) { this.at = at; this.seed = seed; } }
  class Args { constructor(title) { this.title = title; } }
  const tagged = (tag) => ({ tag });
  const c = {
    tag: (value) => value?.tag,
    encode: (value) => (value && typeof value === "object" ? JSON.parse(JSON.stringify(value)) : value ?? null),
    parse: (_scalar, value) => value, text: (value) => value, checked: (value) => value,
    time: { datetime: (value) => value }, party: { parse: (value) => value },
  };
  const SQL = Object.fromEntries(["framework/idempotency_find", "framework/idempotency_record", "framework/idempotency_repair", "verb/create_note", "verb/create_flaky", "verb/create_ordered", "verb/reject_note", "framework/audit"].map((key) => [key, "-- " + key]));
  const create = (name, key) => ({ key, params: [["id"], ["f", "title", null]], created: ["note", "NoteCreated", name === "ordered" ? ["id", "title", "=order"] : ["id", "title"], "note_id"] });
  const stage = (name, input) => verb.staged((ctx) => ctx.stage(name, input));
  const logic = (verbName) => (_actor, _root, args) => {
    if (args.title === "") return step.fail(tagged("empty_title"));
    if (args.title === "reject") return step.reject(stage("reject_note", { title: args.title }), tagged("rejected"));
    return step.apply(stage(verbName, { title: args.title }), (created) => step.done(created));
  };
  const service = (name, effect, verbName) => ({ name, module: { effect: tagged(effect), service: { allow: [] }, Args, logic: logic(verbName) }, root: { Root } });
  const records = {
    note_create: service("note_create", "write", "create_note"),
    note_ordered: service("note_ordered", "write", "create_ordered"),
    note_flaky: service("note_flaky", "write", "create_flaky"),
    note_peek: service("note_peek", "read", "create_note"),
  };
  const rt = runtime({
    SQL, c, roots: {}, actors: {}, manualVerbs: { names: new Set() }, connectors: {}, connectorNames: {}, folds: {}, enqueues: {},
    boundaries: new Set(), relationDecoders: {}, phaseModules: {}, encoders: {}, carried: {}, reads: {}, subjects: [],
    verbs: { create_note: create("note", "verb/create_note"), create_flaky: create("note", "verb/create_flaky"), create_ordered: create("ordered", "verb/create_ordered"),
      reject_note: { key: "verb/reject_note", params: [["f", "title", null]] } },
    drafts: { note: { NoteCreated } },
  });
  class Ok { constructor(value) { this[0] = value; } }
  class Er { constructor(value) { this[0] = value; } }
  // ★ の db_error:業務の一意の制約で落ちた書きを、同じ要求の中で走らせ直す(取り合いに負けた側の受け)
  const hooks = {
    async db_error(s, error, x) {
      if (error.constraint !== "note_title_key") return undefined;
      return x.outcomeResponse(s, await x.invoke({ ...s, trace: [...s.trace] }));
    },
  };
  const h = http({ c, registry: [], attached: [], Ok, Error: Er, hosts: {}, runtime: rt, roles: {}, ports: {}, accepted: {}, args: {}, hooks });

  let seeds = 0;
  async function post({ service = "note_create", title, key, party = "party-a", db = database() }) {
    const headers = new Headers({ "content-type": "application/json" });
    if (key !== undefined) headers.set("idempotency-key", key);
    const request = new Request("https://api.test/api/notes", { method: "POST", headers, body: JSON.stringify({ title }) });
    const record = records[service];
    const s = { request, env: {}, db, trace: [], setCookies: [], record, args: new Args(title), rawArgs: { title },
      resolved: party ? { party } : null, clauses: [], at: "2026-10-13T00:00:00.000Z", seed: "seed-" + ++seeds };
    const response = await h.execute(s);
    return { status: response.status, body: await response.text(), replayed: response.headers.get("idempotency-replayed") === "true" };
  }
  const rows = () => data.notes.length;
  const reset = () => { data.notes.length = 0; data.rejects.length = 0; data.idem.clear(); data.audit = 0; log.length = 0; };

  // (a) 同じキー・同じ本文の 2 回:行が 1 つ、応答が同じ
  const first = await post({ title: "hello", key: "k-1" });
  const tx = log.find((x) => x.startsWith("tx:"));
  check("a: the record goes first in the write's transaction", tx?.startsWith("tx:framework/idempotency_record,verb/create_note,"), tx);
  const second = await post({ title: "hello", key: "k-1" });
  check("a: the first answers 200 with the created note", first.status === 200 && JSON.parse(first.body).title === "hello", first);
  check("a: the second answers the same status and body", second.status === first.status && second.body === first.body, [first, second]);
  check("a: the second is marked replayed, the first is not", second.replayed && !first.replayed, [first.replayed, second.replayed]);
  check("a: one row", rows() === 1, data.notes);
  check("a: the second ran no transaction", log.filter((x) => x.startsWith("tx:")).length === 1, log);
  const stored = JSON.parse([...data.idem.values()][0].result);
  check("a: the record holds the response's status and body only", JSON.stringify(Object.keys(stored).sort()) === '["body","status","type"]' && stored.body === first.body, stored);

  // (b) 同じキー・違う本文は 409、行は増えない
  const other = await post({ title: "changed", key: "k-1" });
  check("b: same key, other body: 409 idempotency_conflict", other.status === 409 && JSON.parse(other.body).code === "idempotency_conflict", other);
  check("b: no new row", rows() === 1, data.notes);

  // (c) キー無しは今のまま:2 回で 2 行、引きも記録も無い
  reset();
  await post({ title: "plain" });
  await post({ title: "plain" });
  check("c: without a key two posts make two rows", rows() === 2, data.notes);
  check("c: without a key nothing reads or writes the idempotency table", !log.some((x) => x.includes("idempotency")), log);

  // (d) commit の後に応答を捨てた(DB に届かない 503)要求の再投稿は 1 件
  reset();
  const lost = await post({ title: "lost", key: "k-lost", db: database({ drop: true }) });
  check("d: the lost response is 503 upstream_unavailable", lost.status === 503 && JSON.parse(lost.body).code === "upstream_unavailable", lost);
  check("d: the write did commit", rows() === 1, data.notes);
  const retry = await post({ title: "lost", key: "k-lost" });
  check("d: the retry answers 200 with the committed note", retry.status === 200 && JSON.parse(retry.body).id === data.notes[0].id && retry.replayed, retry);
  check("d: still one row", rows() === 1, data.notes);

  // 並んで来た 2 本:1 本目の transaction を 2 本目の commit まで待たせる。1 本目は一意の制約で落ち、2 本目の応答を返す
  reset();
  let release;
  const held = new Promise((resolve) => { release = resolve; });
  const slow = post({ title: "race", key: "k-race", db: database({ hold: () => held }) });
  await new Promise((resolve) => setTimeout(resolve, 0));
  const fast = await post({ title: "race", key: "k-race", db: database({ after: () => release() }) });
  const late = await slow;
  const raced = log.filter((x) => x.startsWith("tx:framework/idempotency_record")).length;
  check("race: both ran their transaction, the held one fell on the unique key and read again", raced === 2 && log.at(-1) === "framework/idempotency_find", log);
  check("race: one row", rows() === 1, data.notes);
  check("race: both answer 200 with the same body", fast.status === 200 && late.status === 200 && late.body === fast.body && late.replayed, [fast, late]);

  // party で引く:同じキーを別の party が送っても他人の記録は返らない
  reset();
  const mine = await post({ title: "mine", key: "k-shared", party: "party-a" });
  const theirs = await post({ title: "mine", key: "k-shared", party: "party-b" });
  check("party: another party with the same key gets its own write", !theirs.replayed && theirs.status === 200 && JSON.parse(theirs.body).id !== JSON.parse(mine.body).id && rows() === 2, [mine, theirs]);

  // 業務の失敗(書き無し)は記録しない。断り(断りの verb を書く)は断りの応答を記録し、再投稿で断りの行は増えない
  reset();
  const empty = await post({ title: "", key: "k-empty" });
  check("fail: a business failure without a write answers 422 and records nothing", empty.status === 422 && data.idem.size === 0, [empty, data.idem.size]);
  const refused = await post({ title: "reject", key: "k-reject" });
  const refusedAgain = await post({ title: "reject", key: "k-reject" });
  check("reject: the refusal is recorded in its own transaction", log.some((x) => x === "tx:framework/idempotency_record,verb/reject_note,framework/audit,framework/audit,framework/audit,framework/audit,framework/audit,framework/audit"), log.filter((x) => x.startsWith("tx:")));
  check("reject: the retry answers the same 422 and writes no second refusal", refused.status === 422 && refusedAgain.body === refused.body && refusedAgain.replayed && data.rejects.length === 1, [refused, refusedAgain, data.rejects]);

  // DB が RETURNING で埋めた欄(order)は、記録を transaction の後に直す
  reset();
  await post({ title: "x" });
  const ordered = await post({ service: "note_ordered", title: "ordered", key: "k-order" });
  const orderedAgain = await post({ service: "note_ordered", title: "ordered", key: "k-order" });
  check("order: the answer carries the database's order", JSON.parse(ordered.body).order === 2, ordered);
  check("order: the record is repaired after the transaction", log.includes("framework/idempotency_repair") && orderedAgain.body === ordered.body, [log, orderedAgain]);

  // 読みの Service はキーを見ない、形の外れたキーは 400
  reset();
  await post({ service: "note_peek", title: "peek", key: "k-read" });
  check("read: a read Service ignores the key", !log.some((x) => x.includes("idempotency")), log);
  const bad = await post({ title: "bad", key: "x".repeat(256) });
  check("key: a malformed key is 400 on idempotency_key", bad.status === 400 && JSON.parse(bad.body).field === "idempotency_key" && rows() === 1, bad);

  // 匿名(party も browser も無い)は 1 つの枠で引く
  reset();
  const anon = await post({ title: "anon", key: "k-anon", party: null });
  const anonAgain = await post({ title: "anon", key: "k-anon", party: null });
  check("anonymous: replays within the anonymous party", anonAgain.replayed && anonAgain.body === anon.body && [...data.idem.keys()][0] === "anonymous\u0000k-anon", [...data.idem.keys()]);

  // ★ の db_error が落ちた書きを走らせ直す:取り消された 1 本目の記録の代わりに、走らせ直した書きの transaction が記録を持つ
  reset();
  flaky = 1;
  const rerun = await post({ service: "note_flaky", title: "rerun", key: "k-rerun" });
  const rerunAgain = await post({ service: "note_flaky", title: "rerun", key: "k-rerun" });
  check("rerun: the hook's second run records in its own transaction, the retry is replayed", rerun.status === 200 && data.idem.has("party-a\u0000k-rerun") && rerunAgain.replayed && rerunAgain.body === rerun.body && rows() === 1, [rerun, rerunAgain, log.filter((x) => x.startsWith("tx:"))]);
}

// ── client ────────────────────────────────────────────────────────────────
async function client() {
  globalThis.window = globalThis;
  const store = new Map();
  globalThis.sessionStorage = { getItem: (k) => store.get(k) ?? null, setItem: (k, v) => store.set(k, v), removeItem: (k) => store.delete(k) };
  globalThis.location = new URL("https://www.example/notes");
  const replies = [];
  const sent = [];
  globalThis.fetch = async (url, init) => {
    sent.push({ url, method: init?.method, key: init?.headers?.["idempotency-key"] ?? null, body: init?.body });
    const reply = replies.shift() ?? { status: 200, value: {} };
    if (reply.throws) throw new TypeError("Failed to fetch");
    return { ok: reply.status < 300, status: reply.status, json: async () => reply.value };
  };
  const defined = {};
  globalThis.customElements = { get: (tag) => defined[tag], define: (tag, constructor) => { defined[tag] = constructor; } };
  globalThis.HTMLElement = class {
    constructor() { this.attrs = {}; }
    getAttribute(name) { return this.attrs[name] ?? null; }
    setAttribute(name, value) { this.attrs[name] = value; }
    removeAttribute(name) { delete this.attrs[name]; }
    attachInternals() { return null; }
    querySelectorAll() { return []; }
    get localName() { return "probe-note"; }
  };
  globalThis.HTMLSelectElement = class {};
  globalThis.HTMLButtonElement = class {};
  globalThis.HTMLButtonElement.prototype.commandForElement = null;
  globalThis.document = { activeElement: null, addEventListener() {} };
  const { start } = await import("../src/yumemi/front/interactive.mjs");
  const went = [];
  const reload = { then: "reload", notice: null };
  start({
    components: {
      "probe-note": {
        services: {
          note_create: { method: "POST", path: "/api/notes", read: false, upload: false, accepted: false, entry: false, args: [{ name: "title", wire: "text", blob: false }], refused: [], slots: {}, ok: reload, error: reload },
          note_list: { method: "GET", path: "/api/notes", read: true, upload: false, accepted: false, entry: false, args: [{ name: "title", wire: "text", blob: false }], refused: [], slots: {}, ok: { then: "stay" }, error: { then: "stay" } },
        },
      },
    },
    go: () => {},
    reload: () => went.push("reload"),
  });
  const Component = defined["probe-note"];
  const element = new Component();
  const field = { name: "note_create.title", type: "text", value: "draft 1", disabled: false, checkValidity: () => true };
  const button = (service) => ({ name: "", type: "submit", getAttribute: (name) => (name === "data-yumemi-send" ? service : null) });
  const form = { elements: [field, button("note_create")], querySelector: () => null, contains: () => false };
  const submit = (service = "note_create") => element.yumemiSubmit({ submitter: button(service) }, form, Component.yumemiSpec);
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

  replies.push({ status: 503, value: { code: "upstream_unavailable", connector: "neon" } });
  await submit();
  check("a write carries an Idempotency-Key (UUID)", uuid.test(sent[0]?.key ?? ""), sent[0]);
  check("503: the error After (reload) is not followed, the input stays", went.length === 0 && field.value === "draft 1", went);
  replies.push({ throws: true });
  await submit();
  check("network failure: the retry carries the same key", sent[1]?.key === sent[0].key, sent.map((x) => x.key));
  check("network failure: the error After is not followed", went.length === 0, went);
  replies.push({ status: 200, value: { id: "n1" } });
  await submit();
  check("the next retry of the same input still carries the same key", sent[2]?.key === sent[0].key, sent.map((x) => x.key));
  check("success: the ok After is followed", went.length === 1, went);
  await submit();
  check("after success the same input gets a new key", sent[3]?.key && sent[3].key !== sent[0].key, sent.map((x) => x.key));
  replies.push({ status: 503, value: { code: "upstream_unavailable" } });
  field.value = "draft 2";
  await submit();
  const kept = sent[4]?.key;
  field.value = "draft 3";
  await submit();
  check("a changed input after a 503 gets a new key", kept && sent[5]?.key && sent[5].key !== kept, sent.map((x) => x.key));
  replies.push({ status: 422, value: { code: "empty_title" } });
  await submit();
  replies.push({ status: 200, value: {} });
  await submit();
  check("a 4xx answer drops the key (the next send is a new key)", sent[6]?.key && sent[7]?.key && sent[7].key !== sent[6].key, sent.map((x) => x.key));
  const before = sent.length;
  form.elements = [{ ...field, name: "note_list.title" }, button("note_list")];
  await submit("note_list");
  check("a read send carries no key", sent.length === before + 1 && sent[before].key === null, sent[before]);

  // file の欄がある書き:上げた File の key を保ち、再送では上げ直さない(上げ口は上げるたびに新しい key を返す)
  let blobs = 0;
  const upload = () => replies.push({ status: 200, value: { key: `blob/${++blobs}` } });
  Component.yumemiSpec.services.note_create.args.push({ name: "image", wire: "text", blob: true });
  const photo = new File(["photo"], "photo.png", { type: "image/png" });
  const fileField = { name: "note_create.image", type: "file", files: [photo], disabled: false, checkValidity: () => true };
  form.elements = [{ ...field, value: "with file" }, fileField, button("note_create")];
  const writes = () => sent.filter((x) => x.url === "/api/notes");
  const uploads = () => sent.filter((x) => x.url === "/api/blobs").length;
  upload();
  replies.push({ status: 503, value: { code: "upstream_unavailable" } });
  await submit();
  const lost = writes().at(-1);
  const written = writes().length;
  await submit();
  const retried = writes().at(-1);
  check("file: the retry after a 503 does not upload the File again", uploads() === 1, sent.map((x) => x.url));
  check("file: the retry carries the same Args and the same key", writes().length === written + 1 && retried.body === lost.body && retried.key === lost.key && JSON.parse(lost.body).image === "blob/1", [lost, retried]);
  upload();
  await submit();
  check("file: after an answer the File is uploaded again (new Args, new key)", uploads() === 2 && writes().at(-1).key !== lost.key && JSON.parse(writes().at(-1).body).image === "blob/2", sent.map((x) => x.url));
  upload();
  replies.push({ status: 503, value: { code: "upstream_unavailable" } });
  await submit();
  const kept2 = writes().at(-1);
  fileField.files = [new File(["other"], "other.png", { type: "image/png" })];
  upload();
  await submit();
  check("file: another File after a 503 is uploaded and gets a new key", uploads() === 4 && writes().at(-1).key !== kept2.key && JSON.parse(writes().at(-1).body).image === "blob/4", sent.map((x) => x.url));
}

// ── purge ─────────────────────────────────────────────────────────────────
async function purge() {
  const { purgeIdempotency } = await import("../build/dev/javascript/yumemi/yumemi/server/cron.mjs");
  const calls = [];
  const run = async (_db, key, params) => { calls.push([key, ...params]); return []; };
  await purgeIdempotency({ db: null, env: {}, run, at: "2026-10-13T12:00:00.000Z" });
  await purgeIdempotency({ db: null, env: { IDEMPOTENCY_RETENTION_HOURS: "1" }, run, at: "2026-10-13T12:00:00.000Z" });
  await purgeIdempotency({ db: null, env: { IDEMPOTENCY_RETENTION_HOURS: "0" }, run, at: "2026-10-13T12:00:00.000Z" });
  check("purge: the default keeps 24 hours", JSON.stringify(calls[0]) === '["framework/idempotency_sweep","2026-10-12T12:00:00.000Z"]', calls[0]);
  check("purge: IDEMPOTENCY_RETENTION_HOURS changes the window", calls[1]?.[1] === "2026-10-13T11:00:00.000Z", calls[1]);
  check("purge: a non-positive value falls back to 24 hours", calls[2]?.[1] === "2026-10-12T12:00:00.000Z", calls[2]);
}

const [which] = process.argv.slice(2);
try {
  if (which === "server") await server();
  else if (which === "client") await client();
  else if (which === "purge") await purge();
} catch (error) {
  out.push("NG threw " + (error?.stack ?? error));
}
console.log(out.join("\n"));
