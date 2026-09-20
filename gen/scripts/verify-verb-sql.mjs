#!/usr/bin/env node

//// 手書き verb SQL と生成 verb SQL の名前・本文を突き合わせる。
////
////   node gen/scripts/verify-verb-sql.mjs <app dir> <out dir>
////
//// 段 1 は引用リテラルの内側を保ったまま空白と記号まわりを正規化し、段 2 は
//// それに PostgreSQL の型 cast の除去を加える。段 1 を合格線として残し、段 2 は
//// cast の差を切り分ける参考値にする。

import fs from "node:fs";
import path from "node:path";

const [, , firstArg, secondArg, thirdArg] = process.argv;
const selfTestMode = firstArg === "--self-test";
const appDir = selfTestMode ? secondArg : firstArg;
const outDir = selfTestMode ? thirdArg : secondArg;

if (!appDir || !outDir) {
  console.error(
    selfTestMode
      ? "usage: verify-verb-sql.mjs --self-test <app dir> <out dir>"
      : "usage: verify-verb-sql.mjs <app dir> <out dir>",
  );
  process.exit(2);
}

const sqlExtension = ".sql";
const handwrittenDir = path.join(appDir, "gen/sql/queries/verb");
const generatedDir = path.join(outDir, "db/queries/verb");

// PostgreSQL の通常の型名、schema-qualified 型名、型修飾子、配列型を含む。
// `timestamp with time zone` などの空白を含む組み込み型もここで落とす。
const castPattern =
  /::\s*(?:"[^"]+"|[A-Za-z_][A-Za-z0-9_$]*)(?:\s*\.\s*(?:"[^"]+"|[A-Za-z_][A-Za-z0-9_$]*))*(?:\s*\([^)]*\))?(?:\s+(?:with|without)\s+time\s+zone|\s+(?:varying|precision))?(?:\s*\[\])*/i;
const punctuation = new Set(["(", ")", ",", ";", "="]);

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
  if (ignoreCasts) body = removeCastsOutsideQuotes(body);
  return normalizeOutsideQuotes(body);
}

function dollarTagAt(sql, index) {
  if (sql.startsWith("$$", index)) return "$$";
  const match = sql.slice(index).match(/^\$[A-Za-z_][A-Za-z0-9_]*\$/);
  return match ? match[0] : null;
}

function quotedTokenAt(sql, index) {
  const quote = sql[index];
  if (quote === "'" || quote === '"') {
    let cursor = index + 1;
    while (cursor < sql.length) {
      if (sql[cursor] === quote) {
        if (sql[cursor + 1] === quote) {
          cursor += 2;
          continue;
        }
        cursor += 1;
        break;
      }
      if (sql[cursor] === "\\" && cursor + 1 < sql.length) {
        cursor += 2;
      } else {
        cursor += 1;
      }
    }
    return { text: sql.slice(index, cursor), next: cursor };
  }
  const tag = dollarTagAt(sql, index);
  if (tag) {
    const end = sql.indexOf(tag, index + tag.length);
    const next = end === -1 ? sql.length : end + tag.length;
    return { text: sql.slice(index, next), next };
  }
  return null;
}

function lastChar(text) {
  return text.length === 0 ? "" : text[text.length - 1];
}

function normalizeOutsideQuotes(sql) {
  let output = "";
  let pendingSpace = false;
  let cursor = 0;
  while (cursor < sql.length) {
    const current = sql[cursor];
    if (/\s/.test(current)) {
      pendingSpace = true;
      cursor += 1;
      continue;
    }
    const token = quotedTokenAt(sql, cursor);
    if (token) {
      if (pendingSpace && output.length > 0 && !punctuation.has(lastChar(output))) {
        output += " ";
      }
      output += token.text;
      pendingSpace = false;
      cursor = token.next;
      continue;
    }
    if (punctuation.has(current)) {
      output += current;
      pendingSpace = false;
      cursor += 1;
      continue;
    }
    if (pendingSpace && output.length > 0 && !punctuation.has(lastChar(output))) {
      output += " ";
    }
    output += current;
    pendingSpace = false;
    cursor += 1;
  }
  return output.trim();
}

function removeCastsOutsideQuotes(sql) {
  let output = "";
  let cursor = 0;
  while (cursor < sql.length) {
    const token = quotedTokenAt(sql, cursor);
    if (token) {
      output += token.text;
      cursor = token.next;
      continue;
    }
    const match = sql.slice(cursor).match(castPattern);
    if (match && match.index === 0) {
      cursor += match[0].length;
      continue;
    }
    output += sql[cursor];
    cursor += 1;
  }
  return output;
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

function selfTest(appDir, outDir) {
  const left = normalizedSql("SELECT 'a = b';", false, false);
  const right = normalizedSql("SELECT 'a=b';", false, false);
  if (left === right) {
    throw new Error("quoted literal contents were normalized");
  }
  console.log("self-test quoted literal inequality: PASS");

  const handwrittenPath = path.join(
    appDir,
    "gen/sql/queries/verb/update_free_space_title.sql",
  );
  const generatedPath = path.join(
    outDir,
    "db/queries/verb/update_free_space_title.sql",
  );
  const handwritten = fs.readFileSync(handwrittenPath, "utf8");
  const generated = fs.readFileSync(generatedPath, "utf8");
  if (
    normalizedSql(generated, false, true) !==
    normalizedSql(handwritten, false, false)
  ) {
    throw new Error("update_free_space_title is not a stage 1 match");
  }
  console.log("self-test update_free_space_title stage 1 match: PASS");
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

if (selfTestMode) {
  try {
    selfTest(appDir, outDir);
  } catch (error) {
    const message = String(error instanceof Error ? error.message : error).replace(/\s+/g, " ");
    console.error(`verify-verb-sql self-test: FAIL (${message})`);
    process.exit(1);
  }
} else {
  try {
    compare();
  } catch (error) {
    const message = String(error instanceof Error ? error.message : error).replace(/\s+/g, " ");
    console.error(`verify-verb-sql: FAIL (${message})`);
    process.exit(1);
  }
}
