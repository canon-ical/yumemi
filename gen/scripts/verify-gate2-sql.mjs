#!/usr/bin/env node

import fs from "node:fs";
import { spawnSync } from "node:child_process";

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

const putSql = readSql(
  articleOut,
  "gen/sql/queries/verb/put_article.sql",
);
const put = psql(`
DROP SCHEMA IF EXISTS app CASCADE;
CREATE SCHEMA app;
CREATE TABLE app.article(
  slug text PRIMARY KEY,
  title text,
  body text,
  version integer,
  "order" integer,
  category_id text,
  phase text,
  UNIQUE(category_id,"order")
);
INSERT INTO app.article VALUES
  ('original','before','old-body',7,0,'cat','published');
PREPARE put_q(text,integer,text,text,text,integer) AS
${putSql}
EXECUTE put_q('cat',0,'replacement','forbidden','new-body',0);
SELECT slug || '|' || title || '|' || body || '|' || version || '|' || "order"
  || '|' || category_id || '|' || phase
FROM app.article;
`);
requireText(put, "original|before|new-body|7|0|cat|published", "P0-2 protected columns");
if (put.includes("replacement|")) {
  throw new Error(`P0-2 changed key: ${put}`);
}
console.log("P0-2 put protected key/version/phase fields: PASS");

const reorderSql = readSql(
  articleOut,
  "gen/sql/queries/verb/reorder_articles.sql",
);
const reorder = psql(`
DROP SCHEMA IF EXISTS app CASCADE;
CREATE SCHEMA app;
CREATE TABLE app.article(
  slug text PRIMARY KEY,
  "order" integer,
  category_id text,
  UNIQUE(category_id,"order")
);
INSERT INTO app.article VALUES ('a',0,'cat'),('b',1,'cat');
PREPARE reorder_q(text,jsonb) AS
${reorderSql}
EXECUTE reorder_q('cat','["b","a"]');
SELECT string_agg(slug,',' ORDER BY "order") || '|' || count(*) || '|'
  || count(DISTINCT "order")
FROM app.article;
`);
requireText(reorder, "b,a|2|2", "P0-3 reorder order and uniqueness");
console.log("P0-3 reorder UNIQUE swap: PASS");

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
