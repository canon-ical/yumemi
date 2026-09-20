#!/usr/bin/env node

//// 手書き verb SQL と生成 verb SQL の名前・本文を突き合わせる。
////
////   node gen/scripts/verify-verb-sql.mjs <app dir> <out dir>
////
//// 段 1 は空白だけを正規化し、段 2 はそれに PostgreSQL の型 cast の除去を
//// 加える。段 1 を合格線として残し、段 2 は cast の差を切り分ける参考値にする。

import fs from "node:fs";
import path from "node:path";

const [, , appDir, outDir] = process.argv;

if (!appDir || !outDir) {
  console.error("usage: verify-verb-sql.mjs <app dir> <out dir>");
  process.exit(2);
}

const sqlExtension = ".sql";
const handwrittenDir = path.join(appDir, "gen/sql/queries/verb");
const generatedDir = path.join(outDir, "db/queries/verb");

// PostgreSQL の通常の型名、schema-qualified 型名、型修飾子、配列型を含む。
// `timestamp with time zone` などの空白を含む組み込み型もここで落とす。
const castPattern =
  /::\s*(?:"[^"]+"|[A-Za-z_][A-Za-z0-9_$]*)(?:\s*\.\s*(?:"[^"]+"|[A-Za-z_][A-Za-z0-9_$]*))*(?:\s*\([^)]*\))?(?:\s+(?:with|without)\s+time\s+zone|\s+(?:varying|precision))?(?:\s*\[\])*/gi;

function sqlFiles(directory) {
  return fs
    .readdirSync(directory, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith(sqlExtension))
    .map((entry) => entry.name.slice(0, -sqlExtension.length))
    .sort();
}

function removeGeneratedHeaders(sql) {
  return sql
    .split(/\r\n?|\n/)
    .filter((line) => {
      const trimmed = line.replace(/^\uFEFF/, "").trim();
      return !(
        /^--\s*GENERATED\b/i.test(trimmed) ||
        /^--\s*sha256:/i.test(trimmed) ||
        /^sha256:/i.test(trimmed)
      );
    })
    .join("\n");
}

function normalizedSql(sql, ignoreCasts, generated) {
  let body = generated ? removeGeneratedHeaders(sql) : sql;
  if (ignoreCasts) body = body.replace(castPattern, "");
  return body.replace(/\s+/g, " ").trim();
}

function readSqlMap(directory, names) {
  return new Map(
    names.map((name) => [
      name,
      fs.readFileSync(path.join(directory, `${name}${sqlExtension}`), "utf8"),
    ]),
  );
}

function listText(names) {
  return names.length === 0 ? "(none)" : names.join(", ");
}

function report(label, names) {
  console.log(`${label}: ${names.length} (${listText(names)})`);
}

function compare() {
  const handwrittenNames = sqlFiles(handwrittenDir);
  const generatedNames = sqlFiles(generatedDir);
  const handwritten = readSqlMap(handwrittenDir, handwrittenNames);
  const generated = readSqlMap(generatedDir, generatedNames);

  const handwrittenSet = new Set(handwrittenNames);
  const generatedSet = new Set(generatedNames);
  const both = handwrittenNames.filter((name) => generatedSet.has(name));
  const generatedOnly = generatedNames.filter((name) => !handwrittenSet.has(name));
  const handwrittenOnly = handwrittenNames.filter((name) => !generatedSet.has(name));

  const stage1 = new Map(
    both.map((name) => [
      name,
      normalizedSql(generated.get(name), false, true) ===
        normalizedSql(handwritten.get(name), false, false),
    ]),
  );
  const stage2 = new Map(
    both.map((name) => [
      name,
      normalizedSql(generated.get(name), true, true) ===
        normalizedSql(handwritten.get(name), true, false),
    ]),
  );

  const stage1Matches = both.filter((name) => stage1.get(name));
  const stage2Matches = both.filter((name) => stage2.get(name));
  const castOnly = both.filter((name) => stage2.get(name) && !stage1.get(name));
  const mismatches = both.filter((name) => !stage2.get(name));

  console.log(`generated verb SQL: ${generatedNames.length}`);
  console.log(`handwritten verb SQL: ${handwrittenNames.length}`);
  report("both", both);
  report("generated only", generatedOnly);
  report("handwritten only", handwrittenOnly);
  report("stage 1 match (whitespace only)", stage1Matches);
  report("stage 2 match (whitespace + casts)", stage2Matches);
  report("mismatch (stage 2)", mismatches);
  report("stage 1 -> stage 2 difference (cast-only)", castOnly);

  console.log(
    `verify-verb-sql: generated=${generatedNames.length} handwritten=${handwrittenNames.length} ` +
      `both=${both.length} generated-only=${generatedOnly.length} ` +
      `handwritten-only=${handwrittenOnly.length} stage1=${stage1Matches.length} ` +
      `stage2=${stage2Matches.length} mismatch=${mismatches.length} cast-only=${castOnly.length}`,
  );
}

try {
  compare();
} catch (error) {
  const message = String(error instanceof Error ? error.message : error).replace(/\s+/g, " ");
  console.error(`verify-verb-sql: FAIL (${message})`);
  process.exit(1);
}
