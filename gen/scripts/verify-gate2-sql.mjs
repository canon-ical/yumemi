#!/usr/bin/env node

//// 生成 SQL を実 PG に流す検算(柏木ゲート 2 の P0-1 / 2 / 3 / 4 / 5 / 7)。
////
////   PGHOST=127.0.0.1 PGPORT=55432 PGUSER=yumemism PGDATABASE=postgres \
////   node gen/scripts/verify-gate2-sql.mjs <musearch-out> <article-out> <flag-out> <relation-out> [negative-out]
////
//// gen-3b:P0-3 は負値・両端値(int4 の上限 / 下限)・実 CHECK / UNIQUE・同一 scope の同時実行・失敗時 rollback、
//// それに `Range(min: 1, max: 10)` の順序列(fixtures/relation)を足した。P0-5 はここでは矢印の生成 SQL
//// (`db/queries/<service>/to_<prop>.sql`)を PG で流す ── Context 契約を通した復号は verify-root-ffi.mjs。

import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import pg from "/home/yumemism/yumemism_repo/musearch/app/node_modules/pg/lib/index.js";

const [, , musearchOut, articleOut, flagOut, relationOut] = process.argv;

if (!musearchOut || !articleOut || !flagOut || !relationOut) {
  console.error(
    "usage: verify-gate2-sql.mjs <musearch-out> <article-out> <flag-out> <relation-out> [negative-out]",
  );
  process.exit(2);
}

const negativeOut =
  process.argv[6] ||
  `${path.dirname(relationOut)}/fx-ordered_create_negative`;

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
  "db/queries/verb/update_chunk_text.sql",
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
  "db/queries/verb/create_chunk.sql",
);
const createArticleSql = readSql(
  articleOut,
  "db/queries/verb/create_article.sql",
);
const createArticlesSql = readSql(
  articleOut,
  "db/queries/verb/create_articles.sql",
);
const draftClient = gateDb();
await draftClient.connect();
try {
  await dropSchema(draftClient, "gate2_r7_draft");
  await draftClient.query("CREATE SCHEMA gate2_r7_draft");
  await draftClient.query(`
    CREATE FUNCTION gate2_r7_draft.require_rows(affected bigint, code text)
      RETURNS bigint LANGUAGE plpgsql AS $$
      BEGIN
        IF affected=0 THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE=code;
        END IF;
        RETURN affected;
      END $$;
    CREATE TABLE gate2_r7_draft.chunk(a integer,b integer,c integer,text text,
      PRIMARY KEY(a,b,c));
    CREATE TABLE gate2_r7_draft.category(name text PRIMARY KEY);
    INSERT INTO gate2_r7_draft.category(name) VALUES ('cat');
    CREATE TABLE gate2_r7_draft.article(
      slug text PRIMARY KEY,title text,body text,version integer,
      "order" integer,category_id text,phase text,entered_draft timestamptz);
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
    "cat",
    "2026-01-01T00:00:00Z",
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

function requireCreateManyRows(rows, expected, label) {
  const actual = rows
    .map((row) => `${row.slug}:${row.category_id}:${row.order}`)
    .join(",");
  if (actual !== expected) {
    throw new Error(`${label}: expected ${expected}, got ${actual}`);
  }
}

const createManyClient = gateDb();
await createManyClient.connect();
try {
  await dropSchema(createManyClient, "gate2_a5_create_many");
  await createManyClient.query("CREATE SCHEMA gate2_a5_create_many");
  await createManyClient.query(`
    CREATE FUNCTION gate2_a5_create_many.require_rows(affected bigint, code text)
      RETURNS bigint LANGUAGE plpgsql AS $$
      BEGIN
        IF affected=0 THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE=code;
        END IF;
        RETURN affected;
      END $$;
    CREATE TABLE gate2_a5_create_many.category(name text PRIMARY KEY);
    INSERT INTO gate2_a5_create_many.category(name) VALUES ('a'),('b'),('c');
    CREATE TABLE gate2_a5_create_many.article(
      slug text PRIMARY KEY,title text NOT NULL,body text NOT NULL,
      version integer NOT NULL,"order" integer NOT NULL,
      category_id text NOT NULL REFERENCES gate2_a5_create_many.category(name),
      phase text NOT NULL,entered_draft timestamptz NOT NULL,
      UNIQUE(category_id,"order"));
  `);
  const createMany = scopedSql(
    createArticlesSql,
    "gate2_a5_create_many",
  );
  const at = "2026-09-21T00:00:00Z";
  await createManyClient.query(createMany, [
    JSON.stringify([
      { slug: "a-0", title: "A0", body: "body", version: 1, category: "a" },
      { slug: "a-1", title: "A1", body: "body", version: 1, category: "a" },
      { slug: "a-2", title: "A2", body: "body", version: 1, category: "a" },
    ]),
    at,
  ]);
  const sameScope = (
    await createManyClient.query(`
      SELECT slug,category_id,"order",phase,entered_draft=$1::timestamptz AS entered
      FROM gate2_a5_create_many.article WHERE category_id='a'
      ORDER BY "order"`, [at])
  ).rows;
  requireCreateManyRows(sameScope, "a-0:a:0,a-1:a:1,a-2:a:2", "P0-7 same scope");
  if (sameScope.some((row) => row.phase !== "draft" || row.entered !== true)) {
    throw new Error(`P0-7 initial phase values: ${JSON.stringify(sameScope)}`);
  }
  console.log("P0-7 CreateMany same-scope ordinality and initial phase: PASS");

  await createManyClient.query(createMany, [
    JSON.stringify([
      { slug: "b-0", title: "B0", body: "body", version: 1, category: "b" },
      { slug: "c-0", title: "C0", body: "body", version: 1, category: "c" },
      { slug: "b-1", title: "B1", body: "body", version: 1, category: "b" },
      { slug: "c-1", title: "C1", body: "body", version: 1, category: "c" },
    ]),
    at,
  ]);
  const mixedScopes = (
    await createManyClient.query(`
      SELECT slug,category_id,"order" FROM gate2_a5_create_many.article
      WHERE category_id IN ('b','c') ORDER BY category_id,"order"`)
  ).rows;
  requireCreateManyRows(
    mixedScopes,
    "b-0:b:0,b-1:b:1,c-0:c:0,c-1:c:1",
    "P0-7 mixed scopes",
  );
  console.log("P0-7 CreateMany mixed scopes restart at zero: PASS");

  await createManyClient.query(createMany, [
    JSON.stringify([
      { slug: "a-3", title: "A3", body: "body", version: 1, category: "a" },
      { slug: "a-4", title: "A4", body: "body", version: 1, category: "a" },
    ]),
    at,
  ]);
  const continued = (
    await createManyClient.query(`
      SELECT slug,category_id,"order" FROM gate2_a5_create_many.article
      WHERE slug IN ('a-3','a-4') ORDER BY "order"`)
  ).rows;
  requireCreateManyRows(continued, "a-3:a:3,a-4:a:4", "P0-7 existing scope");
  console.log("P0-7 CreateMany existing scope continues: PASS");
} finally {
  await dropSchema(createManyClient, "gate2_a5_create_many");
  await createManyClient.end();
}

const putSql = readSql(
  articleOut,
  "db/queries/verb/put_article.sql",
);
const updateSql = readSql(
  articleOut,
  "db/queries/verb/update_article_body.sql",
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
  "db/queries/verb/reorder_articles_stage.sql",
);
const reorderSql = readSql(
  articleOut,
  "db/queries/verb/reorder_articles.sql",
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
  const rowsOf = async (scope = "cat") =>
    (
      await reorderClient.query(
        'SELECT slug,"order" FROM gate2_r7_reorder.article WHERE category_id=$1 ORDER BY "order",slug',
        [scope],
      )
    ).rows
      .map((row) => `${row.slug}|${row.order}`)
      .join(",");
  const reset = async (values) => {
    await reorderClient.query("TRUNCATE gate2_r7_reorder.article");
    for (const [slug, order, scope] of values) {
      await reorderClient.query(
        "INSERT INTO gate2_r7_reorder.article VALUES ($1,$2,$3)",
        [slug, order, scope ?? "cat"],
      );
    }
  };
  const expectRows = async (expected, label, scope = "cat") => {
    const found = await rowsOf(scope);
    if (found !== expected) {
      throw new Error(`${label}: expected ${expected}, got ${found}`);
    }
  };
  const expectCode = async (action, code, label) => {
    try {
      await action();
    } catch (error) {
      if (error.code === code) return error;
      throw new Error(`${label}: expected ${code}, got ${error.code} ${error.message}`);
    }
    throw new Error(`${label}: expected ${code}, but it succeeded`);
  };

  // 交換の確定値(従来)
  await reset([["a", 0], ["b", 1]]);
  await reorder(["b", "a"]);
  await expectRows("b|0,a|1", "P0-3 swap");
  // int4 の上限を含む(従来)
  await reset([["a", 0], ["b", 2147483647]]);
  await reorder(["b", "a"]);
  await expectRows("b|0,a|1", "P0-3 Int max");
  // 負の実値(柏木 3 回目の再現 ── 以前は退避が 23505)
  await reset([["a", -1], ["b", -2]]);
  await reorder(["b", "a"]);
  await expectRows("b|0,a|1", "P0-3 negative values");
  // 両端値(int4 の下限と上限が同じ scope に在る)
  await reset([["a", -2147483648], ["b", 2147483647], ["c", 0]]);
  await reorder(["c", "b", "a"]);
  await expectRows("c|0,b|1,a|2", "P0-3 Int min and max together");
  // 上端に詰まった scope(2147483647 と 2147483646 が使われている)── 一時値はそれを避けて選ばれる
  await reset([["a", 2147483647], ["b", 2147483646], ["c", 2147483645]]);
  await reorder(["a", "b", "c"]);
  await expectRows("a|0,b|1,c|2", "P0-3 scope packed at the top");
  // 別 scope は触らない
  await reset([["a", 0], ["b", 1], ["x", 0, "dog"], ["y", 1, "dog"]]);
  await reorder(["b", "a"]);
  await expectRows("b|0,a|1", "P0-3 own scope");
  await expectRows("x|0,y|1", "P0-3 other scope untouched", "dog");
  // 要求の id が scope に無い → 'conflict'(P0001)、rollback
  await reset([["a", 0], ["b", 1]]);
  await expectCode(() => reorder(["b", "zzz"]), "P0001", "P0-3 unknown id");
  await expectRows("a|0,b|1", "P0-3 unknown id rollback");
  // 部分の並べ替えが実 UNIQUE に当たる → 23505、rollback(従来)
  await reset([["a", 0], ["b", 1], ["c", 2]]);
  await expectCode(() => reorder(["c"]), "23505", "P0-3 partial reorder unique conflict");
  await expectRows("a|0,b|1,c|2", "P0-3 failed reorder atomic");
  // 実 CHECK(非負)── 柏木 3 回目の補助検証(以前は退避が 23514)
  await reorderClient.query('ALTER TABLE gate2_r7_reorder.article ADD CONSTRAINT nonneg CHECK ("order">=0)');
  await reset([["a", 0], ["b", 1]]);
  await reorder(["b", "a"]);
  await expectRows("b|0,a|1", "P0-3 nonnegative CHECK");
  await reset([["a", 0], ["b", 2147483647]]);
  await reorder(["b", "a"]);
  await expectRows("b|0,a|1", "P0-3 nonnegative CHECK with Int max");
  await reorderClient.query("ALTER TABLE gate2_r7_reorder.article DROP CONSTRAINT nonneg");
  // 同一 scope の同時実行:2 本目は FOR UPDATE で待ち、1 本目の確定後に走る。最終値は 2 本目の要求
  await reset([["a", 0], ["b", 1]]);
  const second = gateDb();
  const monitor = gateDb();
  await second.connect();
  await monitor.connect();
  try {
    await reorderClient.query("BEGIN");
    await second.query("BEGIN");
    await reorderClient.query(stage, ["cat", JSON.stringify(["b", "a"])]);
    const pending = second.query(stage, ["cat", JSON.stringify(["a", "b"])]);
    let locked = false;
    for (let i = 0; i < 200 && !locked; i++) {
      const state = await monitor.query(
        "SELECT wait_event_type FROM pg_stat_activity WHERE pid=$1",
        [second.processID],
      );
      locked = state.rows[0]?.wait_event_type === "Lock";
      if (!locked) await new Promise((resolve) => setTimeout(resolve, 10));
    }
    if (!locked) throw new Error("P0-3 concurrent: second transaction did not wait on Lock");
    await reorderClient.query(apply, ["cat", JSON.stringify(["b", "a"])]);
    await reorderClient.query("COMMIT");
    await pending;
    await second.query(apply, ["cat", JSON.stringify(["a", "b"])]);
    await second.query("COMMIT");
    await expectRows("a|0,b|1", "P0-3 concurrent final values");
  } finally {
    await second.end();
    await monitor.end();
  }
  console.log(
    "P0-3 reorder exact values, Int max/min, negative values, real CHECK/UNIQUE, same-scope concurrency, rollback: PASS",
  );
} finally {
  await dropSchema(reorderClient, "gate2_r7_reorder");
  await reorderClient.end();
}

// 値域つき順序列(`Range(min: 1, max: 10)`)── 確定値は 1 から、一時値は 10 から下へ。
// 値域が狭くて一時値が足りないときは退避せず確定へ進む:UNIQUE が無ければ通り、あれば 23505 で rollback。
const photoStageSql = readSql(relationOut, "db/queries/verb/reorder_photos_stage.sql");
const photoSql = readSql(relationOut, "db/queries/verb/reorder_photos.sql");
const photoClient = gateDb();
await photoClient.connect();
try {
  await dropSchema(photoClient, "gate3b_range");
  await photoClient.query("CREATE SCHEMA gate3b_range");
  await photoClient.query(`
    CREATE FUNCTION gate3b_range.require_rows(affected bigint, code text)
      RETURNS bigint LANGUAGE plpgsql AS $$
      BEGIN
        IF affected=0 THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE=code;
        END IF;
        RETURN affected;
      END $$;
    CREATE TABLE gate3b_range.photo(
      id uuid PRIMARY KEY,album_id uuid NOT NULL,"order" integer NOT NULL CHECK ("order" BETWEEN 1 AND 10),
      CONSTRAINT photo_unique_order UNIQUE(album_id,"order"));
  `);
  const stage = scopedSql(photoStageSql, "gate3b_range");
  const apply = scopedSql(photoSql, "gate3b_range");
  const album = "00000000-0000-0000-0000-000000000001";
  const id = (n) => `00000000-0000-0000-0000-0000000000${String(n).padStart(2, "0")}`;
  const reset = async (orders) => {
    await photoClient.query("TRUNCATE gate3b_range.photo");
    for (const [n, order] of orders) {
      await photoClient.query("INSERT INTO gate3b_range.photo VALUES ($1,$2,$3)", [id(n), album, order]);
    }
  };
  const reorder = (ns) =>
    transaction(photoClient, async () => {
      await photoClient.query(stage, [album, JSON.stringify(ns.map(id))]);
      return photoClient.query(apply, [album, JSON.stringify(ns.map(id))]);
    });
  const rows = async () =>
    (await photoClient.query('SELECT id,"order" FROM gate3b_range.photo ORDER BY "order"')).rows
      .map((row) => `${Number(row.id.slice(-2))}|${row.order}`)
      .join(",");
  const expectRows = async (expected, label) => {
    const found = await rows();
    if (found !== expected) throw new Error(`${label}: expected ${expected}, got ${found}`);
  };
  // 3 行 {1,2,3} を逆順に:一時値は 10,9,8(範囲に無く、確定の帯 [1,3] を避ける)、確定は 1..3
  await reset([[1, 1], [2, 2], [3, 3]]);
  await reorder([3, 2, 1]);
  await expectRows("3|1,2|2,1|3", "Range reorder inside CHECK 1..10 and UNIQUE");
  // 上端に詰まった行 {8,9,10} でも、範囲に無い値(7,6,5)が選ばれる
  await reset([[1, 8], [2, 9], [3, 10]]);
  await reorder([2, 3, 1]);
  await expectRows("2|1,3|2,1|3", "Range reorder with rows at the top of the range");
  // 5 行で値域 10:held 5 + 2*5 = 15 > 10 なので窓は 10..1、空きは {6..10} の 5 個 → 退避できる
  await reset([[1, 1], [2, 2], [3, 3], [4, 4], [5, 5]]);
  await reorder([5, 4, 3, 2, 1]);
  await expectRows("5|1,4|2,3|3,2|4,1|5", "Range reorder with 5 of 10 slots used");
  // 6 行で値域 10:空きは {7..10} の 4 個 < 6 → 退避せず確定へ → UNIQUE に当たり 23505、rollback
  await reset([[1, 1], [2, 2], [3, 3], [4, 4], [5, 5], [6, 6]]);
  let code;
  try {
    await reorder([6, 5, 4, 3, 2, 1]);
  } catch (error) {
    code = error.code;
  }
  if (code !== "23505") throw new Error(`Range saturated: expected 23505, got ${code}`);
  await expectRows("1|1,2|2,3|3,4|4,5|5,6|6", "Range saturated rollback");
  // 同じ状態で UNIQUE が無ければ、退避せずの確定が通る
  await photoClient.query("ALTER TABLE gate3b_range.photo DROP CONSTRAINT photo_unique_order");
  await reorder([6, 5, 4, 3, 2, 1]);
  await expectRows("6|1,5|2,4|3,3|4,2|5,1|6", "Range saturated without UNIQUE");
  console.log("P0-3 Range(1,10) order column: bounds, top-packed rows, saturation with/without UNIQUE: PASS");
} finally {
  await dropSchema(photoClient, "gate3b_range");
  await photoClient.end();
}

// P0-5 ── 矢印の生成 SQL(鍵の列 → 関係先の行、鍵の順)。Context 契約を通した復号は verify-root-ffi.mjs。
const arrowSql = readSql(musearchOut, "db/queries/article_read/to_muse.sql");
const spaceSql = readSql(musearchOut, "db/queries/widget_edit/to_space.sql");
const tagsSql = readSql(articleOut, "db/queries/article_read/to_tags.sql");
const arrowClient = gateDb();
await arrowClient.connect();
try {
  await dropSchema(arrowClient, "gate3b_arrow");
  await arrowClient.query("CREATE SCHEMA gate3b_arrow");
  await arrowClient.query(`
    CREATE TABLE gate3b_arrow.muse(id uuid PRIMARY KEY,handle text NOT NULL);
    CREATE TABLE gate3b_arrow.free_space(id uuid PRIMARY KEY,title text NOT NULL);
    CREATE TABLE gate3b_arrow.tag(name text PRIMARY KEY);
    INSERT INTO gate3b_arrow.muse VALUES('00000000-0000-0000-0000-000000000002','hana');
    INSERT INTO gate3b_arrow.free_space VALUES('00000000-0000-0000-0000-000000000003','space');
    INSERT INTO gate3b_arrow.tag VALUES('t1'),('t2'),('t3');
  `);
  const one = (await arrowClient.query(scopedSql(arrowSql, "gate3b_arrow"), [
    JSON.stringify(["00000000-0000-0000-0000-000000000002"]),
  ])).rows;
  if (one.length !== 1 || one[0].handle !== "hana") {
    throw new Error(`P0-5 to_muse SQL: ${JSON.stringify(one)}`);
  }
  const none = (await arrowClient.query(scopedSql(arrowSql, "gate3b_arrow"), [
    JSON.stringify(["00000000-0000-0000-0000-000000000009"]),
  ])).rows;
  if (none.length !== 0) throw new Error(`P0-5 to_muse SQL missing key: ${JSON.stringify(none)}`);
  const space = (await arrowClient.query(scopedSql(spaceSql, "gate3b_arrow"), [
    JSON.stringify(["00000000-0000-0000-0000-000000000003"]),
  ])).rows;
  if (space.length !== 1 || space[0].title !== "space") {
    throw new Error(`P0-5 to_space SQL: ${JSON.stringify(space)}`);
  }
  const tags = (await arrowClient.query(scopedSql(tagsSql, "gate3b_arrow"), [
    JSON.stringify(["t3", "t1"]),
  ])).rows.map((row) => row.name);
  if (tags.join(",") !== "t3,t1") throw new Error(`P0-5 to_tags SQL order: ${tags}`);
  console.log("P0-5 generated arrow SQL (uuid / text keys, key order, missing key): PASS");
} finally {
  await dropSchema(arrowClient, "gate3b_arrow");
  await arrowClient.end();
}

const pageSql = readSql(flagOut, "db/queries/widget_page/paged.sql");
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

// B1 ── ordered create の親版ロック、値域の起点、親欠落を実 PG で検算する。
const orderedArticleSql = readSql(
  articleOut,
  "db/queries/verb/create_article.sql",
);
const orderedArticlesSql = readSql(
  articleOut,
  "db/queries/verb/create_articles.sql",
);
const orderedArticleLockSql = readSql(
  articleOut,
  "db/queries/verb/create_article_lock.sql",
);
const orderedArticlesLockSql = readSql(
  articleOut,
  "db/queries/verb/create_articles_lock.sql",
);
const rangePhotoSql = readSql(
  relationOut,
  "db/queries/verb/create_photo.sql",
);
const rangePhotoLockSql = readSql(
  relationOut,
  "db/queries/verb/create_photo_lock.sql",
);
const negativeChildSql = readSql(
  negativeOut,
  "db/queries/verb/create_child.sql",
);
const negativeChildLockSql = readSql(
  negativeOut,
  "db/queries/verb/create_child_lock.sql",
);

const orderedAt = "2026-09-21T00:00:00Z";

async function createArticleHarness(client, schema, { unique = true, parents = [] } = {}) {
  await dropSchema(client, schema);
  await client.query(`CREATE SCHEMA ${schema}`);
  await client.query(`
    CREATE FUNCTION ${schema}.require_rows(affected bigint, code text)
      RETURNS bigint LANGUAGE plpgsql AS $$
      BEGIN
        IF affected=0 THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE=code;
        END IF;
        RETURN affected;
      END $$;
    CREATE TABLE ${schema}.category(name text PRIMARY KEY);
    CREATE TABLE ${schema}.article(
      slug text PRIMARY KEY,
      title text NOT NULL,
      body text NOT NULL,
      version integer NOT NULL,
      "order" integer NOT NULL,
      category_id text NOT NULL,
      phase text NOT NULL,
      entered_draft timestamptz NOT NULL
      ${unique ? ', UNIQUE(category_id,"order")' : ''}
    );
  `);
  for (const parent of parents) {
    await client.query(`INSERT INTO ${schema}.category(name) VALUES ($1)`, [parent]);
  }
}

async function createRangeHarness(client, schema) {
  await dropSchema(client, schema);
  await client.query(`CREATE SCHEMA ${schema}`);
  await client.query(`
    CREATE FUNCTION ${schema}.require_rows(affected bigint, code text)
      RETURNS bigint LANGUAGE plpgsql AS $$
      BEGIN
        IF affected=0 THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE=code;
        END IF;
        RETURN affected;
      END $$;
    CREATE TABLE ${schema}.album(id uuid PRIMARY KEY);
    CREATE TABLE ${schema}.photo(
      id uuid PRIMARY KEY,
      album_id uuid NOT NULL,
      shelf_id uuid,
      caption text,
      "order" integer NOT NULL CHECK ("order" BETWEEN 1 AND 10)
    );
  `);
  await client.query(
    `INSERT INTO ${schema}.album(id) VALUES ('00000000-0000-0000-0000-000000000001')`,
  );
}

async function createChildHarness(client, schema) {
  await dropSchema(client, schema);
  await client.query(`CREATE SCHEMA ${schema}`);
  await client.query(`
    CREATE FUNCTION ${schema}.require_rows(affected bigint, code text)
      RETURNS bigint LANGUAGE plpgsql AS $$
      BEGIN
        IF affected=0 THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE=code;
        END IF;
        RETURN affected;
      END $$;
    CREATE TABLE ${schema}.parent(id uuid PRIMARY KEY);
    CREATE TABLE ${schema}.child(
      id uuid PRIMARY KEY,
      parent_id uuid NOT NULL,
      name text NOT NULL,
      "order" integer NOT NULL
    );
  `);
}

function articleDraft(slug, scope) {
  return [slug, slug, "body", 1, scope, orderedAt];
}

function articlesDraft(slug, scope) {
  return [
    JSON.stringify([
      { slug, title: slug, body: "body", version: 1, category: scope },
    ]),
    orderedAt,
  ];
}

function sideSql(kind) {
  return kind === "single"
    ? {
        create: orderedArticleSql,
        lock: orderedArticleLockSql,
        lockParams: (scope) => [scope],
        createParams: (slug, scope) => articleDraft(slug, scope),
      }
    : {
        create: orderedArticlesSql,
        lock: orderedArticlesLockSql,
        lockParams: (scope, slug) => [JSON.stringify([
          { slug, title: slug, body: "body", version: 1, category: scope },
        ])],
        createParams: (slug, scope) => articlesDraft(slug, scope),
      };
}

async function waitForLock(monitor, pid) {
  for (let attempt = 0; attempt < 250; attempt += 1) {
    const state = await monitor.query(
      "SELECT wait_event_type FROM pg_stat_activity WHERE pid=$1",
      [pid],
    );
    if (state.rows[0]?.wait_event_type === "Lock") return true;
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  return false;
}

async function rollbackQuietly(client) {
  if (!client) return;
  try {
    await client.query("ROLLBACK");
  } catch (_) {
    // The transaction may already have been rolled back by PostgreSQL.
  }
}

async function runOrderedRace({
  schema,
  pair,
  isolation,
  useLock,
  unique,
  rollbackA = false,
}) {
  const setup = gateDb();
  const first = gateDb();
  const second = gateDb();
  const monitor = gateDb();
  await setup.connect();
  await first.connect();
  await second.connect();
  await monitor.connect();
  let secondFirstPromise;
  let secondFirstError;
  let secondCreateError;
  let secondCreateSucceeded = false;
  let waited = true;
  const firstKind = pair.split("/")[0];
  const secondKind = pair.split("/")[1];
  const firstSide = sideSql(firstKind);
  const secondSide = sideSql(secondKind);
  const firstSlug = `a-${schema}`;
  const secondSlug = `b-${schema}`;
  try {
    await createArticleHarness(setup, schema, { unique, parents: ["scope"] });
    await first.query(`BEGIN ISOLATION LEVEL ${isolation}`);
    await second.query(`BEGIN ISOLATION LEVEL ${isolation}`);
    if (useLock) {
      await first.query(
        scopedSql(firstSide.lock, schema),
        firstSide.lockParams("scope", firstSlug),
      );
      secondFirstPromise = second
        .query(
          scopedSql(secondSide.lock, schema),
          secondSide.lockParams("scope", secondSlug),
        )
        .catch((error) => {
          secondFirstError = error;
          return null;
        });
      waited = await waitForLock(monitor, second.processID);
    }

    await first.query(
      scopedSql(firstSide.create, schema),
      firstSide.createParams(firstSlug, "scope"),
    );
    if (useLock) {
      if (rollbackA) {
        await first.query("ROLLBACK");
      } else {
        await first.query("COMMIT");
      }
      if (secondFirstPromise) await secondFirstPromise;
    } else {
      try {
        await second.query(
          scopedSql(secondSide.create, schema),
          secondSide.createParams(secondSlug, "scope"),
        );
      } catch (error) {
        secondCreateError = error;
      }
      await first.query("COMMIT");
    }
    if (useLock && !secondFirstError) {
      try {
        await second.query(
          scopedSql(secondSide.create, schema),
          secondSide.createParams(secondSlug, "scope"),
        );
        secondCreateSucceeded = true;
      } catch (error) {
        secondCreateError = error;
      }
    }
    if (secondCreateSucceeded) {
      await second.query("COMMIT");
    } else {
      await rollbackQuietly(second);
    }
  } catch (error) {
    await rollbackQuietly(first);
    await rollbackQuietly(second);
    throw error;
  } finally {
    await monitor.end();
    await second.end();
    await first.end();
  }

  const rows = (
    await setup.query(
      `SELECT slug,"order" FROM ${schema}.article ORDER BY "order",slug`,
    )
  ).rows;
  const duplicateRows = (
    await setup.query(`
      SELECT category_id,"order",count(*)::integer AS count
      FROM ${schema}.article
      GROUP BY category_id,"order"
      HAVING count(*) > 1
    `)
  ).rows;
  if (duplicateRows.length !== 0) {
    throw new Error(`${schema}: duplicate ordered rows ${JSON.stringify(duplicateRows)}`);
  }

  const secondCode = secondFirstError?.code || secondCreateError?.code || "ok";
  if (!waited) {
    throw new Error(`${schema}: B ① did not wait on the parent row`);
  }
  if (rollbackA) {
    if (secondCode !== "ok" || rows.length !== 1 || rows[0].order !== 0) {
      throw new Error(`${schema}: rollback result ${JSON.stringify({ secondCode, rows })}`);
    }
  } else if (useLock && isolation === "READ COMMITTED") {
    if (secondCode !== "ok" || rows.length !== 2 || rows[0].order !== 0 || rows[1].order !== 1) {
      throw new Error(`${schema}: READ COMMITTED result ${JSON.stringify({ secondCode, rows })}`);
    }
  } else if (useLock) {
    if (secondCode !== "40001" || rows.length !== 1 || rows[0].order !== 0) {
      throw new Error(`${schema}: ${isolation} result ${JSON.stringify({ secondCode, rows })}`);
    }
  } else {
    if (secondCode !== "55P03" || rows.length !== 1 || rows[0].order !== 0) {
      throw new Error(`${schema}: no-lock result ${JSON.stringify({ secondCode, rows })}`);
    }
  }
  await dropSchema(setup, schema);
  await setup.end();
  return {
    pair,
    isolation,
    lock: useLock ? "①あり" : "①無し",
    unique: unique ? "UNIQUEあり" : "UNIQUE無し",
    outcome: `${secondCode}:${rows.map((row) => row.order).join(",")}`,
  };
}

const t1Rows = [];
const racePairs = ["single/single", "many/many", "single/many"];
const raceIsolations = ["READ COMMITTED", "REPEATABLE READ", "SERIALIZABLE"];
let raceNumber = 0;
for (const useLock of [true, false]) {
  for (const pair of racePairs) {
    for (const isolation of raceIsolations) {
      for (const unique of [true, false]) {
        raceNumber += 1;
        t1Rows.push(
          await runOrderedRace({
            schema: `gate2_t1_${String(raceNumber).padStart(2, "0")}`,
            pair,
            isolation,
            useLock,
            unique,
          }),
        );
      }
    }
  }
}
const rollbackRow = await runOrderedRace({
  schema: "gate2_t1_rollback",
  pair: "single/single",
  isolation: "READ COMMITTED",
  useLock: true,
  unique: true,
  rollbackA: true,
});
t1Rows.push({ ...rollbackRow, outcome: `rollback:${rollbackRow.outcome}` });
console.log("T1 ordered-create matrix: PASS (37 rows; no duplicate scope/order)");
console.log("pair\tlock\tisolation\tunique\tresult");
for (const row of t1Rows) {
  console.log(
    `${row.pair}\t${row.lock}\t${row.isolation}\t${row.unique}\t${row.outcome}`,
  );
}

async function applyInTransaction(client, schema, lockSql, lockParams, createSql, createParams) {
  await client.query("BEGIN");
  try {
    await client.query(scopedSql(lockSql, schema), lockParams);
    const result = await client.query(scopedSql(createSql, schema), createParams);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  }
}

async function expectP0001(action, label) {
  try {
    await action();
  } catch (error) {
    if (error.code === "P0001" && error.message === "conflict") return;
    throw new Error(`${label}: expected P0001 conflict, got ${error.code} ${error.message}`);
  }
  throw new Error(`${label}: expected P0001 conflict, but it succeeded`);
}

const t2Client = gateDb();
await t2Client.connect();
try {
  await createRangeHarness(t2Client, "gate2_t2_range");
  const rangeRow = await applyInTransaction(
    t2Client,
    "gate2_t2_range",
    rangePhotoLockSql,
    ["00000000-0000-0000-0000-000000000001"],
    rangePhotoSql,
    [
      "00000000-0000-0000-0000-000000000011",
      "00000000-0000-0000-0000-000000000001",
      "00000000-0000-0000-0000-000000000021",
      "caption",
    ],
  );
  if (rangeRow.rows.length !== 1 || rangeRow.rows[0].order !== 1) {
    throw new Error(`T2 Range(1,10) expected order 1: ${JSON.stringify(rangeRow.rows)}`);
  }
  console.log("T2 Range(1,10) single starts at 1 and satisfies CHECK: PASS");

  await createArticleHarness(t2Client, "gate2_t2_article_single", { parents: ["scope"] });
  const articleSingle = await applyInTransaction(
    t2Client,
    "gate2_t2_article_single",
    orderedArticleLockSql,
    ["scope"],
    orderedArticleSql,
    articleDraft("single", "scope"),
  );
  if (articleSingle.rows.length !== 1 || articleSingle.rows[0].order !== 0) {
    throw new Error(`T2 declaration-free single expected order 0: ${JSON.stringify(articleSingle.rows)}`);
  }
  console.log("T2 declaration-free single starts at 0: PASS");

  await createArticleHarness(t2Client, "gate2_t2_article_many", { parents: ["scope"] });
  const articleMany = await applyInTransaction(
    t2Client,
    "gate2_t2_article_many",
    orderedArticlesLockSql,
    [JSON.stringify([
      { slug: "many-0", title: "many-0", body: "body", version: 1, category: "scope" },
      { slug: "many-1", title: "many-1", body: "body", version: 1, category: "scope" },
      { slug: "many-2", title: "many-2", body: "body", version: 1, category: "scope" },
    ])],
    orderedArticlesSql,
    [JSON.stringify([
      { slug: "many-0", title: "many-0", body: "body", version: 1, category: "scope" },
      { slug: "many-1", title: "many-1", body: "body", version: 1, category: "scope" },
      { slug: "many-2", title: "many-2", body: "body", version: 1, category: "scope" },
    ]), orderedAt],
  );
  if (articleMany.rows.map((row) => row.order).join(",") !== "0,1,2") {
    throw new Error(`T2 declaration-free many expected 0,1,2: ${JSON.stringify(articleMany.rows)}`);
  }
  console.log("T2 declaration-free CreateMany starts at 0,1,2: PASS");

  await createChildHarness(t2Client, "gate2_t2_negative");
  await t2Client.query(
    `INSERT INTO gate2_t2_negative.parent(id) VALUES ('00000000-0000-0000-0000-000000000031')`,
  );
  const negativeRow = await applyInTransaction(
    t2Client,
    "gate2_t2_negative",
    negativeChildLockSql,
    ["00000000-0000-0000-0000-000000000031"],
    negativeChildSql,
    [
      "00000000-0000-0000-0000-000000000041",
      "00000000-0000-0000-0000-000000000031",
      "negative",
    ],
  );
  if (negativeRow.rows.length !== 1 || negativeRow.rows[0].order !== 0) {
    throw new Error(`T2 negative Range expected order 0: ${JSON.stringify(negativeRow.rows)}`);
  }
  console.log("T2 negative lower bound starts at 0: PASS");
} finally {
  await dropSchema(t2Client, "gate2_t2_range");
  await dropSchema(t2Client, "gate2_t2_article_single");
  await dropSchema(t2Client, "gate2_t2_article_many");
  await dropSchema(t2Client, "gate2_t2_negative");
  await t2Client.end();
}

const t3Client = gateDb();
await t3Client.connect();
try {
  await createArticleHarness(t3Client, "gate2_t3_valid", {
    unique: false,
    parents: ["a", "b"],
  });
  const validRows = await applyInTransaction(
    t3Client,
    "gate2_t3_valid",
    orderedArticlesLockSql,
    [JSON.stringify([
      { slug: "valid-a", title: "valid-a", body: "body", version: 1, category: "a" },
      { slug: "valid-b", title: "valid-b", body: "body", version: 1, category: "b" },
    ])],
    orderedArticlesSql,
    [JSON.stringify([
      { slug: "valid-a", title: "valid-a", body: "body", version: 1, category: "a" },
      { slug: "valid-b", title: "valid-b", body: "body", version: 1, category: "b" },
    ]), orderedAt],
  );
  if (validRows.rows.length !== 2) {
    throw new Error(`T3 valid parents did not pass: ${JSON.stringify(validRows.rows)}`);
  }
  console.log("T3 all parents present passes without FK: PASS");

  await createArticleHarness(t3Client, "gate2_t3_mixed", {
    unique: false,
    parents: ["a"],
  });
  await expectP0001(
    () => applyInTransaction(
      t3Client,
      "gate2_t3_mixed",
      orderedArticlesLockSql,
      [JSON.stringify([
        { slug: "mixed-a", title: "mixed-a", body: "body", version: 1, category: "a" },
        { slug: "mixed-b", title: "mixed-b", body: "body", version: 1, category: "missing" },
      ])],
      orderedArticlesSql,
      [JSON.stringify([
        { slug: "mixed-a", title: "mixed-a", body: "body", version: 1, category: "a" },
        { slug: "mixed-b", title: "mixed-b", body: "body", version: 1, category: "missing" },
      ]), orderedAt],
    ),
    "T3 mixed parent",
  );
  const mixedCount = (
    await t3Client.query("SELECT count(*)::integer AS count FROM gate2_t3_mixed.article")
  ).rows[0].count;
  if (mixedCount !== 0) throw new Error(`T3 mixed parent left ${mixedCount} rows`);
  console.log("T3 mixed valid/missing parents returns P0001 and 0 rows: PASS");

  await createArticleHarness(t3Client, "gate2_t3_all_missing", {
    unique: false,
    parents: [],
  });
  await expectP0001(
    () => applyInTransaction(
      t3Client,
      "gate2_t3_all_missing",
      orderedArticlesLockSql,
      [JSON.stringify([
        { slug: "none-a", title: "none-a", body: "body", version: 1, category: "a" },
        { slug: "none-b", title: "none-b", body: "body", version: 1, category: "b" },
      ])],
      orderedArticlesSql,
      [JSON.stringify([
        { slug: "none-a", title: "none-a", body: "body", version: 1, category: "a" },
        { slug: "none-b", title: "none-b", body: "body", version: 1, category: "b" },
      ]), orderedAt],
    ),
    "T3 all missing parents",
  );
  const allMissingCount = (
    await t3Client.query("SELECT count(*)::integer AS count FROM gate2_t3_all_missing.article")
  ).rows[0].count;
  if (allMissingCount !== 0) throw new Error(`T3 all-missing parent left ${allMissingCount} rows`);
  console.log("T3 all parents missing returns P0001 and 0 rows: PASS");

  await createArticleHarness(t3Client, "gate2_t3_single_missing", {
    unique: false,
    parents: [],
  });
  await expectP0001(
    () => applyInTransaction(
      t3Client,
      "gate2_t3_single_missing",
      orderedArticleLockSql,
      ["missing"],
      orderedArticleSql,
      articleDraft("single-missing", "missing"),
    ),
    "T3 single missing parent",
  );
  const singleMissingCount = (
    await t3Client.query("SELECT count(*)::integer AS count FROM gate2_t3_single_missing.article")
  ).rows[0].count;
  if (singleMissingCount !== 0) throw new Error(`T3 single-missing parent left ${singleMissingCount} rows`);
  console.log("T3 single missing parent returns P0001 and 0 rows: PASS");
} finally {
  await dropSchema(t3Client, "gate2_t3_valid");
  await dropSchema(t3Client, "gate2_t3_mixed");
  await dropSchema(t3Client, "gate2_t3_all_missing");
  await dropSchema(t3Client, "gate2_t3_single_missing");
  await t3Client.end();
}
