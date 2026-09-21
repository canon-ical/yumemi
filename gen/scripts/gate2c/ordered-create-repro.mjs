// astra の ordered-create 再現の写し。
// 判定は「再現しない = P0-9 が消えた」。lock SQL を同じ transaction で先に打つ。
import fs from "node:fs";
import assert from "node:assert/strict";
import pg from "/home/yumemism/yumemism_repo/musearch/app/node_modules/pg/lib/index.js";

const out = process.env.ARTICLE_OUT;
if (!out) throw new Error("ARTICLE_OUT is required");
const config = {
  host: process.env.PGHOST ?? "127.0.0.1",
  port: Number(process.env.PGPORT ?? 55432),
  user: process.env.PGUSER ?? "yumemism",
  database: process.env.PGDATABASE ?? "postgres",
};
const schema = "gate2c_ordered_repro";
const [a, b, monitor] = [new pg.Client(config), new pg.Client(config), new pg.Client(config)];
const read = (name) =>
  fs
    .readFileSync(`${out}/db/queries/verb/${name}.sql`, "utf8")
    .replaceAll("app.", `${schema}.`)
    .replaceAll("framework.require_rows", `${schema}.require_rows`);
const single = read("create_article");
const singleLock = read("create_article_lock");
const many = read("create_articles");
const manyLock = read("create_articles_lock");
const at = "2026-09-21T00:00:00Z";
const item = (slug) => ({ slug, title: slug, body: "body", version: 1, category: "a" });

async function waitForLock() {
  for (let i = 0; i < 200; i += 1) {
    const state = await monitor.query(
      "SELECT wait_event_type FROM pg_stat_activity WHERE pid=$1",
      [b.processID],
    );
    if (state.rows[0]?.wait_event_type === "Lock") return true;
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  return false;
}

async function run(kind, unique) {
  await monitor.query(`TRUNCATE ${schema}.article`);
  await monitor.query(`ALTER TABLE ${schema}.article DROP CONSTRAINT IF EXISTS scope_order`);
  if (unique) {
    await monitor.query(
      `ALTER TABLE ${schema}.article ADD CONSTRAINT scope_order UNIQUE(category_id,"order")`,
    );
  }
  const create = kind === "single" ? single : many;
  const lock = kind === "single" ? singleLock : manyLock;
  const firstCreate = kind === "single"
    ? ["first", "first", "body", 1, "a", at]
    : [JSON.stringify([item("first")]), at];
  const secondCreate = kind === "single"
    ? ["second", "second", "body", 1, "a", at]
    : [JSON.stringify([item("second")]), at];
  const lockArgs = kind === "single" ? ["a"] : [JSON.stringify([item("lock")])];
  await a.query("BEGIN");
  await b.query("BEGIN");
  await a.query(lock, lockArgs);
  const pending = b.query(lock, lockArgs);
  assert.equal(await waitForLock(), true);
  await a.query(create, firstCreate);
  await a.query("COMMIT");
  await pending;
  await b.query(create, secondCreate);
  await b.query("COMMIT");
  const rows = (
    await monitor.query(`SELECT slug,"order" FROM ${schema}.article ORDER BY "order",slug`)
  ).rows;
  assert.deepEqual(rows, [
    { slug: "first", order: 0 },
    { slug: "second", order: 1 },
  ]);
  console.log(
    `P0-9 no reproduction: ${kind}, UNIQUE=${unique ? "on" : "off"}; lock-first result`,
    JSON.stringify(rows),
  );
}

try {
  await Promise.all([a.connect(), b.connect(), monitor.connect()]);
  await monitor.query(`
    DROP SCHEMA IF EXISTS ${schema} CASCADE;
    CREATE SCHEMA ${schema};
    CREATE FUNCTION ${schema}.require_rows(bigint,text) RETURNS bigint
      LANGUAGE plpgsql AS $$
      BEGIN
        IF $1=0 THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE=$2;
        END IF;
        RETURN $1;
      END $$;
    CREATE TABLE ${schema}.category(name text PRIMARY KEY);
    INSERT INTO ${schema}.category VALUES ('a');
    CREATE TABLE ${schema}.article(
      slug text PRIMARY KEY,title text NOT NULL,body text NOT NULL,
      version integer NOT NULL,"order" integer NOT NULL,
      category_id text NOT NULL,phase text NOT NULL,
      entered_draft timestamptz NOT NULL
    );
  `);
  for (const unique of [true, false]) {
    await run("single", unique);
    await run("many", unique);
  }
  console.log("P0-9 ordered-create astra direction: no reproduction = PASS");
} finally {
  await a.query("ROLLBACK").catch(() => {});
  await b.query("ROLLBACK").catch(() => {});
  await monitor.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`).catch(() => {});
  await Promise.all([a.end(), b.end(), monitor.end()]);
}
