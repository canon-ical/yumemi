// astra の Range(1,10) ordered-create 再現の写し。
// 判定は「再現しない = P0-10 が消えた」。lock SQL を同じ transaction で先に打つ。
import fs from "node:fs";
import assert from "node:assert/strict";
import pg from "/home/yumemism/yumemism_repo/musearch/app/node_modules/pg/lib/index.js";

const out = process.env.RELATION_OUT;
if (!out) throw new Error("RELATION_OUT is required");
const config = {
  host: process.env.PGHOST ?? "127.0.0.1",
  port: Number(process.env.PGPORT ?? 55432),
  user: process.env.PGUSER ?? "yumemism",
  database: process.env.PGDATABASE ?? "postgres",
};
const schema = "gate2c_range_repro";
const db = new pg.Client(config);
const read = (name) =>
  fs
    .readFileSync(`${out}/db/queries/verb/${name}.sql`, "utf8")
    .replaceAll("app.", `${schema}.`)
    .replaceAll("framework.require_rows", `${schema}.require_rows`);
const create = read("create_photo");
const lock = read("create_photo_lock");
const parent = "00000000-0000-0000-0000-000000000001";

try {
  await db.connect();
  await db.query(`
    DROP SCHEMA IF EXISTS ${schema} CASCADE;
    CREATE SCHEMA ${schema};
    CREATE FUNCTION ${schema}.require_rows(bigint,text) RETURNS bigint
      LANGUAGE sql AS 'SELECT $1';
    CREATE TABLE ${schema}.album(id uuid PRIMARY KEY);
    CREATE TABLE ${schema}.photo(
      id uuid PRIMARY KEY,album_id uuid,shelf_id uuid,caption text,
      "order" integer NOT NULL CHECK ("order" BETWEEN 1 AND 10)
    );
    INSERT INTO ${schema}.album VALUES ('${parent}');
  `);
  await db.query("BEGIN");
  await db.query(lock, [parent]);
  const result = await db.query(create, [
    "00000000-0000-0000-0000-000000000002",
    parent,
    null,
    "first",
  ]);
  await db.query("COMMIT");
  assert.equal(result.rows.length, 1);
  assert.equal(result.rows[0].order, 1);
  console.log("P0-10 no reproduction: Range(1,10) first order is 1", JSON.stringify(result.rows));
  console.log("P0-10 order-range astra direction: no reproduction = PASS");
} finally {
  await db.query("ROLLBACK").catch(() => {});
  await db.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`).catch(() => {});
  await db.end();
}
