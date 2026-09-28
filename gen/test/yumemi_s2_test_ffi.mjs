import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

// 子の node で ES module を走らせ、標準出力を返す(gleeunit の test は同期なので、非同期の検査は子に閉じる)
function node(code) {
  const result = spawnSync(process.execPath, ["--input-type=module", "-e", code], {
    cwd: process.cwd(),
    encoding: "utf8",
    timeout: 60000,
  });
  return `${result.stdout}${result.stderr ? `\nSTDERR ${result.stderr}` : ""}`.trim();
}

const server = (file) => JSON.stringify(path.resolve("build/dev/javascript/yumemi/framework/server", file));

// 偽の DB。行は Map に持ち、outbox_claim は 1 回の同期の区間で条件を読んで sent_at を進める(行の鍵の直列化と同じ)。
// 他の文は await を挟み、重なった sweep の順を混ぜる。transaction は全部か無しか(FAIL の文があれば何も書かない)。
const fake = `
import { registerHooks } from "node:module";
registerHooks({
  resolve(specifier, context, next) {
    if (specifier === "cloudflare:workers")
      return { url: "data:text/javascript,export class DurableObject {} export class WorkerEntrypoint {}", shortCircuit: true };
    return next(specifier, context);
  },
});
const { SQL } = await import(${JSON.stringify(path.resolve("fixtures/article/src/gen/sql.mjs"))});
const tick = () => new Promise((resolve) => setTimeout(resolve, 0));
const HOUR = 3600 * 1000;
const makeDb = () => {
  const rows = new Map();
  const log = [];
  const insert = (id, kind) => rows.set(id, { id, kind, payload: { id }, sent_at: null, done_at: null });
  const apply = (text, params, key) => {
    log.push(key);
    if (text === "FAIL" || params?.includes("FAIL")) throw Object.assign(new Error("conflict"), { code: "P0001" });
    if (key === "framework/outbox_sweep")
      return [...rows.values()]
        .filter((r) => r.done_at === null && params[0].includes(r.kind) && (r.sent_at === null || r.sent_at < Date.now() - HOUR))
        .map((r) => ({ id: r.id, kind: r.kind, payload: r.payload }));
    if (key === "framework/outbox_claim") {
      const r = rows.get(params[0]);
      if (!r || r.done_at !== null || !(r.sent_at === null || r.sent_at < Date.now() - HOUR)) return [];
      r.sent_at = Date.now();
      return [{ id: r.id }];
    }
    if (key === "framework/outbox_sent") { const r = rows.get(params[0]); if (r && r.done_at === null) r.sent_at = Date.now(); return []; }
    if (/insert\\s+into\\s+framework\\.outbox/i.test(text)) { insert(params[0], params[1]); return [{ id: params[0] }]; }
    return [];
  };
  return {
    rows, log, insert,
    async query(text, params, key) { await tick(); return apply(text, params, key); },
    async transaction(operations) {
      await tick();
      if (operations.some((x) => x.sql === "FAIL")) throw Object.assign(new Error("conflict"), { code: "P0001" });
      return operations.map((x) => apply(x.sql, x.params, x.key));
    },
  };
};
const makeEnv = () => {
  const sent = [];
  return { sent, OUTBOX: { async send(body) { await tick(); sent.push(body.id); } } };
};
const check = (name, ok, got) => console.log((ok ? "ok " : "NG ") + name + (ok ? "" : " " + JSON.stringify(got)));
`;

// 0.11.6 ── fetch の口:outbox へ INSERT を commit した要求は status によらず sweep、書きの無い要求・rollback は sweep しない
export function fetch_sweeps() {
  return node(`${fake}
const { handlers } = await import(${server("worker.mjs")});
// 手書きの SQL(musearch の verb/notice_link と同じ形)と、生成の outbox_parent / outbox_child
const manual = "-- S-4b: 知らせを積む\\nWITH noticed AS (SELECT 1) INSERT INTO framework.outbox(id,kind,payload,parent_event_id,created_at)\\nVALUES($1,$2,'{}'::jsonb,NULL,now());";
const run = async (dispatch) => {
  const db = makeDb();
  let sweeps = 0;
  const pending = [];
  const worker = handlers({
    dispatch,
    database: () => db,
    observe: () => {},
    sweep: async (raw) => { sweeps++; if (raw !== db) throw new Error("sweep got the wrapped db"); },
    consume: async () => {},
  });
  let status = null, thrown = null;
  try { status = (await worker.fetch(new Request("https://api.example/x"), {}, { waitUntil: (p) => pending.push(p) })).status; }
  catch (error) { thrown = error.message; }
  await Promise.all(pending);
  return { status, thrown, sweeps, rows: db.rows.size };
};
let r = await run(async ({ db }) => { await db.query(manual, ["m1", "muse_notify"], "verb/notice_link"); return new Response(null, { status: 200 }); });
check("manual SQL outbox row + 200 sweeps once", r.status === 200 && r.sweeps === 1 && r.rows === 1, r);
r = await run(async ({ db }) => {
  await db.transaction([{ key: "article_publish/verb", sql: "UPDATE app.article SET x=1", params: [] },
    { key: "framework/outbox_child", sql: SQL["framework/outbox_child"] ?? "INSERT INTO framework.outbox(id,kind) VALUES($1,$2)", params: ["g1", "article_notify"] }]);
  return new Response(null, { status: 200 });
});
check("generated outbox row + 200 (hook rewrote 202) sweeps once", r.status === 200 && r.sweeps === 1 && r.rows === 1, r);
r = await run(async ({ db }) => { await db.query(manual, ["e1", "muse_notify"], "verb/notice_link"); return new Response(null, { status: 500 }); });
check("committed outbox row + 500 still sweeps", r.status === 500 && r.sweeps === 1, r);
r = await run(async ({ db }) => { await db.query(manual, ["t1", "muse_notify"], "verb/notice_link"); throw new Error("after commit"); });
check("committed outbox row + thrown dispatch still sweeps", r.thrown === "after commit" && r.sweeps === 1, r);
r = await run(async ({ db }) => { await db.query("SELECT id FROM app.article WHERE id=$1", ["a"], "article_read/root"); return new Response("{}", { status: 200 }); });
check("read-only GET does not sweep", r.status === 200 && r.sweeps === 0, r);
r = await run(async ({ db }) => { await db.query("UPDATE app.article SET title=$1 -- INSERT INTO framework.outbox", ["t"], "article_edit/verb"); await db.query("SELECT 'INSERT INTO framework.outbox'", [], "x"); return new Response(null, { status: 200 }); });
check("write without outbox (comment / literal only) does not sweep", r.sweeps === 0, r);
r = await run(async () => new Response(null, { status: 202 }));
check("202 sweeps as before", r.status === 202 && r.sweeps === 1, r);
r = await run(async ({ db }) => {
  try { await db.transaction([{ key: "framework/outbox_child", sql: "INSERT INTO framework.outbox(id,kind) VALUES($1,$2)", params: ["r1", "muse_notify"] }, { key: "verb/cas", sql: "FAIL", params: [] }]); }
  catch { return new Response(null, { status: 409 }); }
  return new Response(null, { status: 200 });
});
check("rolled back outbox insert does not sweep", r.status === 409 && r.sweeps === 0 && r.rows === 0, r);
r = await run(async ({ db }) => { await db.query(manual, ["FAIL", "muse_notify"], "verb/notice_link").catch(() => {}); return new Response(null, { status: 400 }); });
check("failed outbox statement does not sweep", r.status === 400 && r.sweeps === 0 && r.rows === 0, r);
`);
}

// 0.11.6 ── sweep:重なった 2 本の sweep で各行は 1 回だけ送られる。claim の無い 0.11.5 の sweep は同じ偽の DB で 2 回送る
export function concurrent_sweeps() {
  return node(`${fake}
const { outbox } = await import(${server("outbox.mjs")});
const runtime = { run: (db, key, params) => db.query(SQL[key], params, key) };
const queue = outbox({ kinds: ["muse_notify", "article_notify"], ids: {}, consumers: {}, registry: {}, codec: {}, runtime });
const fill = (db) => { for (const id of ["a", "b", "c", "d"]) db.insert(id, "muse_notify"); db.insert("z", "other_kind"); };
let db = makeDb(), env = makeEnv();
fill(db);
const counts = await Promise.all([queue.sweep(db, env), queue.sweep(db, env), queue.sweep(db, env)]);
const tally = (ids) => ids.reduce((m, id) => ({ ...m, [id]: (m[id] ?? 0) + 1 }), {});
check("three overlapping sweeps send each row once", JSON.stringify(tally(env.sent)) === JSON.stringify({ a: 1, b: 1, c: 1, d: 1 }), tally(env.sent));
check("sweep counts add up to the rows", counts.reduce((a, b) => a + b, 0) === 4, counts);
check("unregistered kind is not sent", !env.sent.includes("z"), env.sent);
check("claim is the generated statement", /UPDATE framework\\.outbox SET sent_at=now\\(\\) WHERE id=\\$1/.test(SQL["framework/outbox_claim"]), SQL["framework/outbox_claim"]);
const before = env.sent.length;
await queue.sweep(db, env);
check("a later sweep sends nothing new", env.sent.length === before, env.sent);
// 1 時間を過ぎた送り済みの行(送りが落ちた)は、次の sweep が 1 回だけ送り直す
db.rows.get("a").sent_at = Date.now() - 2 * 3600 * 1000;
await Promise.all([queue.sweep(db, env), queue.sweep(db, env)]);
check("stale sent row is resent once", env.sent.filter((id) => id === "a").length === 2 && env.sent.length === before + 1, env.sent);
// 0.11.5 の sweep(送ってから outbox_sent)を同じ偽の DB で重ねると 2 回送る ── この test が重なりを作れている証
const old = async (db, env) => {
  const rows = await runtime.run(db, "framework/outbox_sweep", [["muse_notify"]]);
  for (const row of rows) { await env.OUTBOX.send({ id: row.id }); await runtime.run(db, "framework/outbox_sent", [row.id]); }
};
db = makeDb(); env = makeEnv(); fill(db);
await Promise.all([old(db, env), old(db, env)]);
check("0.11.5 sweep without claim double-sends here", env.sent.length === 8, env.sent);
`);
}

export function write(dir, file, text) {
  const target = path.join(dir, file);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, text);
}
