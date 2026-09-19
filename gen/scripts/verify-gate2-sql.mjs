#!/usr/bin/env node

import fs from "node:fs";
import { spawnSync } from "node:child_process";
import pg from "/home/yumemism/yumemism_repo/musearch/app/node_modules/pg/lib/index.js";
import { rootArrow } from "../../src/framework/io_ffi.mjs";
import { makeContext } from "/home/yumemism/yumemism_repo/musearch/app/build/dev/javascript/musearch_app/gen/runtime.mjs";

const [, , musearchOut, articleOut, flagOut] = process.argv;

if (!musearchOut || !articleOut || !flagOut) {
  console.error(
    "usage: verify-gate2-sql.mjs <musearch-out> <article-out> <flag-out>",
  );
  process.exit(2);
}

function readSql(out, relative) {
  return fs.readFileSync(`${out}/${relative}`, "utf8");
}

function psql(script) {
  const args = ["-X", "-At", "-v", "ON_ERROR_STOP=1"];
  const options = {
    PGHOST: "-h",
    PGPORT: "-p",
    PGUSER: "-U",
    PGDATABASE: "-d",
  };
  for (const name of Object.keys(options)) {
    if (process.env[name]) args.push(options[name], process.env[name]);
  }
  const result = spawnSync("psql", args, {
    input: script,
    encoding: "utf8",
  });
  if (result.status !== 0) {
    throw new Error(result.stderr || result.stdout || "psql failed");
  }
  return result.stdout;
}

function requireText(output, expected, label) {
  if (!output.includes(expected)) {
    throw new Error(`${label}: missing ${expected}\n${output}`);
  }
}

function gateDb() {
  return new pg.Client({
    host: process.env.PGHOST || "127.0.0.1",
    port: Number(process.env.PGPORT || 55432),
    user: process.env.PGUSER || "yumemism",
    database: process.env.PGDATABASE || "postgres",
  });
}

async function transaction(client, action) {
  await client.query("BEGIN");
  try {
    const result = await action();
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  }
}

function scopedSql(sql, appSchema, frameworkSchema = appSchema) {
  return sql
    .replaceAll("app.", `${appSchema}.`)
    .replaceAll("framework.require_rows", `${frameworkSchema}.require_rows`);
}

async function dropSchema(client, name) {
  await client.query(`DROP SCHEMA IF EXISTS ${name} CASCADE`);
}

const chunkSql = readSql(
  musearchOut,
  "gen/sql/queries/verb/update_chunk_text.sql",
);
const chunk = psql(`
DROP SCHEMA IF EXISTS app CASCADE;
DROP SCHEMA IF EXISTS framework CASCADE;
CREATE SCHEMA app;
CREATE SCHEMA framework;
CREATE FUNCTION framework.require_rows(bigint,text) RETURNS bigint
  LANGUAGE sql AS 'SELECT $1';
CREATE TABLE app.chunk(
  article_id uuid,
  version integer,
  seq integer,
  text text,
  PRIMARY KEY(article_id,version,seq)
);
INSERT INTO app.chunk VALUES
  ('00000000-0000-0000-0000-000000000001',7,1,'before'),
  ('00000000-0000-0000-0000-000000000001',7,2,'sibling'),
  ('00000000-0000-0000-0000-000000000001',8,1,'new-version');
PREPARE chunk_q(uuid,integer,integer,text) AS
${chunkSql}
EXECUTE chunk_q(
  '00000000-0000-0000-0000-000000000001',7,1,'after'
);
SELECT article_id::text || '|' || version || '|' || seq || '|' || text
FROM app.chunk ORDER BY version,seq;
`);
requireText(chunk, "00000000-0000-0000-0000-000000000001|7|1|after", "P0-1 target");
requireText(chunk, "00000000-0000-0000-0000-000000000001|7|2|sibling", "P0-1 sibling");
requireText(chunk, "00000000-0000-0000-0000-000000000001|8|1|new-version", "P0-1 version");
console.log("P0-1 chunk composite version key: PASS");

const createChunkSql = readSql(
  flagOut,
  "gen/sql/queries/verb/create_chunk.sql",
);
const createArticleSql = readSql(
  articleOut,
  "gen/sql/queries/verb/create_article.sql",
);
const draftClient = gateDb();
await draftClient.connect();
try {
  await dropSchema(draftClient, "gate2_r7_draft");
  await draftClient.query("CREATE SCHEMA gate2_r7_draft");
  await draftClient.query(`
    CREATE TABLE gate2_r7_draft.chunk(a integer,b integer,c integer,text text,
      PRIMARY KEY(a,b,c));
    CREATE TABLE gate2_r7_draft.article(
      slug text PRIMARY KEY,title text,body text,version integer,
      "order" integer,category_id text);
  `);
  await draftClient.query(scopedSql(createChunkSql, "gate2_r7_draft"), [
    11,
    7,
    1,
    "typed-composite-key",
  ]);
  await draftClient.query(scopedSql(createArticleSql, "gate2_r7_draft"), [
    "typed-slug",
    "title",
    "body",
    1,
    0,
    "cat",
  ]);
  const chunkRow = (
    await draftClient.query(
      'SELECT a,b,c,text FROM gate2_r7_draft.chunk',
    )
  ).rows[0];
  const articleRow = (
    await draftClient.query(
      "SELECT slug,title,body FROM gate2_r7_draft.article",
    )
  ).rows[0];
  if (
    !chunkRow ||
    chunkRow.a !== 11 ||
    chunkRow.b !== 7 ||
    chunkRow.c !== 1 ||
    chunkRow.text !== "typed-composite-key" ||
    !articleRow ||
    articleRow.slug !== "typed-slug"
  ) {
    throw new Error(
      `P0-7 create key values were not persisted: ${JSON.stringify({ chunkRow, articleRow })}`,
    );
  }
  console.log("P0-7 typed composite/natural keys reach create SQL: PASS");
} finally {
  await dropSchema(draftClient, "gate2_r7_draft");
  await draftClient.end();
}

const putSql = readSql(
  articleOut,
  "gen/sql/queries/verb/put_article.sql",
);
const updateSql = readSql(
  articleOut,
  "gen/sql/queries/verb/update_article_body.sql",
);
const putClient = gateDb();
await putClient.connect();
try {
  await dropSchema(putClient, "gate2_r7_put");
  await putClient.query("CREATE SCHEMA gate2_r7_put");
  await putClient.query(`
    CREATE FUNCTION gate2_r7_put.require_rows(affected bigint, code text)
      RETURNS bigint LANGUAGE plpgsql AS $$
      BEGIN
        IF affected=0 THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE=code;
        END IF;
        RETURN affected;
      END $$;
    CREATE TABLE gate2_r7_put.article(
      slug text PRIMARY KEY,title text,body text,version integer,
      "order" integer,category_id text,phase text,
      UNIQUE(category_id,"order"));
    INSERT INTO gate2_r7_put.article
      VALUES ('original','before','old-body',7,0,'cat','published');
  `);
  const put = scopedSql(putSql, "gate2_r7_put");
  const update = scopedSql(updateSql, "gate2_r7_put");
  let staleConflict = false;
  try {
    await transaction(putClient, () =>
      putClient.query(put, ["cat", 0, "original", "forbidden", "stale", 0]),
    );
  } catch (error) {
    staleConflict = error.code === "P0001" && error.message === "conflict";
  }
  if (!staleConflict) {
    throw new Error("P0-2 stale put was accepted");
  }
  let row = (
    await putClient.query(
      "SELECT slug,title,body,version,\"order\",category_id,phase FROM gate2_r7_put.article",
    )
  ).rows[0];
  if (row.body !== "old-body" || row.version !== 7) {
    throw new Error(`P0-2 stale put changed data: ${JSON.stringify(row)}`);
  }
  await transaction(putClient, () =>
    putClient.query(put, ["cat", 0, "original", "forbidden", "new-body", 7]),
  );
  row = (
    await putClient.query(
      "SELECT slug,title,body,version,\"order\",category_id,phase FROM gate2_r7_put.article",
    )
  ).rows[0];
  if (
    row.slug !== "original" ||
    row.title !== "before" ||
    row.body !== "new-body" ||
    row.version !== 8 ||
    row.order !== 0 ||
    row.category_id !== "cat" ||
    row.phase !== "published"
  ) {
    throw new Error(`P0-2 put result is wrong: ${JSON.stringify(row)}`);
  }
  let oldReaderConflict = false;
  try {
    await transaction(putClient, () =>
      putClient.query(update, ["original", 7, "lost-old-reader-write"]),
    );
  } catch (error) {
    oldReaderConflict = error.code === "P0001" && error.message === "conflict";
  }
  if (!oldReaderConflict) {
    throw new Error("P0-2 old-version update was accepted after put");
  }
  row = (
    await putClient.query(
      "SELECT body,version FROM gate2_r7_put.article",
    )
  ).rows[0];
  if (row.body !== "new-body" || row.version !== 8) {
    throw new Error(`P0-2 old update changed put: ${JSON.stringify(row)}`);
  }
  console.log("P0-2 put version conflict/advance and protected columns: PASS");
} finally {
  await dropSchema(putClient, "gate2_r7_put");
  await putClient.end();
}

const reorderStageSql = readSql(
  articleOut,
  "gen/sql/queries/verb/reorder_articles_stage.sql",
);
const reorderSql = readSql(
  articleOut,
  "gen/sql/queries/verb/reorder_articles.sql",
);
const reorderClient = gateDb();
await reorderClient.connect();
try {
  await dropSchema(reorderClient, "gate2_r7_reorder");
  await reorderClient.query("CREATE SCHEMA gate2_r7_reorder");
  await reorderClient.query(`
    CREATE FUNCTION gate2_r7_reorder.require_rows(affected bigint, code text)
      RETURNS bigint LANGUAGE plpgsql AS $$
      BEGIN
        IF affected=0 THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE=code;
        END IF;
        RETURN affected;
      END $$;
    CREATE TABLE gate2_r7_reorder.article(
      slug text PRIMARY KEY,"order" integer,category_id text,
      UNIQUE(category_id,"order"));
  `);
  const stage = scopedSql(reorderStageSql, "gate2_r7_reorder");
  const apply = scopedSql(reorderSql, "gate2_r7_reorder");
  const reorder = async (ids, scope = "cat") =>
    transaction(reorderClient, async () => {
      await reorderClient.query(stage, [scope, JSON.stringify(ids)]);
      return reorderClient.query(apply, [scope, JSON.stringify(ids)]);
    });
  await reorderClient.query(
    "INSERT INTO gate2_r7_reorder.article VALUES ('a',0,'cat'),('b',1,'cat')",
  );
  await reorder(["b", "a"]);
  let rows = (
    await reorderClient.query(
      'SELECT slug,"order" FROM gate2_r7_reorder.article ORDER BY "order"',
    )
  ).rows;
  if (rows.map((row) => `${row.slug}|${row.order}`).join(",") !== "b|0,a|1") {
    throw new Error(`P0-3 swap did not settle exact values: ${JSON.stringify(rows)}`);
  }
  await reorderClient.query("TRUNCATE gate2_r7_reorder.article");
  await reorderClient.query(
    "INSERT INTO gate2_r7_reorder.article VALUES ('a',0,'cat'),('b',2147483647,'cat')",
  );
  await reorder(["b", "a"]);
  rows = (
    await reorderClient.query(
      'SELECT slug,"order" FROM gate2_r7_reorder.article ORDER BY "order"',
    )
  ).rows;
  if (rows.map((row) => `${row.slug}|${row.order}`).join(",") !== "b|0,a|1") {
    throw new Error(`P0-3 Int boundary did not settle: ${JSON.stringify(rows)}`);
  }
  await reorderClient.query("TRUNCATE gate2_r7_reorder.article");
  await reorderClient.query(
    "INSERT INTO gate2_r7_reorder.article VALUES ('a',0,'cat'),('b',1,'cat'),('c',2,'cat')",
  );
  let conflict = false;
  try {
    await reorder(["b"]);
  } catch (error) {
    conflict = error.code === "23505";
  }
  if (!conflict) {
    throw new Error("P0-3 same-scope order conflict was accepted");
  }
  rows = (
    await reorderClient.query(
      'SELECT slug,"order" FROM gate2_r7_reorder.article ORDER BY slug',
    )
  ).rows;
  if (rows.map((row) => `${row.slug}|${row.order}`).join(",") !== "a|0,b|1,c|2") {
    throw new Error(`P0-3 failed reorder was not atomic: ${JSON.stringify(rows)}`);
  }
  console.log("P0-3 reorder exact values, Int max, conflict rollback: PASS");
} finally {
  await dropSchema(reorderClient, "gate2_r7_reorder");
  await reorderClient.end();
}

const rootDecoded = { id: "category-1", name: "decoded" };
const rootRelation = { resolve: async () => rootDecoded };
const rootContext = makeContext({
  record: { name: "root_arrow_probe" },
  db: {},
  root: { article: { category: rootRelation } },
  at: "2026-09-20T00:00:00.000Z",
  seed: "root-arrow-probe",
});
const rootResult = await rootArrow(
  rootContext,
  "article_read",
  "ArticleToCategory",
  rootContext.root,
);
if (rootResult !== rootDecoded || typeof rootContext.rootArrow !== "function") {
  throw new Error("P0-5 makeContext root arrow did not resolve the relation");
}
console.log("P0-5 real makeContext rootArrow relation decode: PASS");

const pageSql = readSql(flagOut, "gen/sql/queries/widget_page/paged.sql");
const page = psql(`
DROP SCHEMA IF EXISTS app CASCADE;
CREATE SCHEMA app;
CREATE TABLE app.widget(
  id uuid PRIMARY KEY,
  name text,
  place integer CHECK(place BETWEEN 1 AND 2147483647)
);
INSERT INTO app.widget VALUES
  ('00000000-0000-0000-0000-000000000001','same',2147483647),
  ('00000000-0000-0000-0000-000000000002','same',NULL),
  ('00000000-0000-0000-0000-000000000003','other',NULL);
PREPARE page_q(integer,boolean,integer,text,uuid) AS
${pageSql}
EXECUTE page_q(1,false,NULL,NULL,NULL);
EXECUTE page_q(
  1,true,2147483647,'same',
  '00000000-0000-0000-0000-000000000001'
);
EXECUTE page_q(
  1,true,NULL,'same',
  '00000000-0000-0000-0000-000000000002'
);
`);
requireText(
  page,
  "00000000-0000-0000-0000-000000000003",
  "P0-4 NULL boundary continuation",
);
console.log("P0-4 mixed keyset NULL boundary: PASS");
