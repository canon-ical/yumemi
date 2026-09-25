#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const genDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const repoRoot = path.resolve(genDir, "..");
const sourcePath = process.argv[2]
  ? path.resolve(process.argv[2])
  : path.resolve(repoRoot, "../musearch-yumemi-5/api/src/gen/codec.mjs");
const copyPath = path.join(genDir, "scripts/codec-encode.mjs");
const outputPath = path.join(genDir, "build/yd1-encode-diff.txt");
const source = fs.readFileSync(sourcePath, "utf8");
const copy = fs.readFileSync(copyPath, "utf8");

function functionBody(text, name) {
  const match = text.match(new RegExp(`(?:export\\s+)?function\\s+${name}\\s*\\([^)]*\\)\\s*\\{`));
  if (!match) throw new Error(`cannot find function ${name}`);
  const start = match.index + match[0].lastIndexOf("{");
  let depth = 0;
  for (let index = start; index < text.length; index += 1) {
    if (text[index] === "{") depth += 1;
    if (text[index] === "}") depth -= 1;
    if (depth === 0) return text.slice(start + 1, index);
  }
  throw new Error(`unterminated function ${name}`);
}

function tagExpression(text, local) {
  const pattern = local
    ? /const\s+tag\s*=\s*([^;]+);/
    : /export\s+const\s+tag\s*=\s*([^;]+);/;
  const match = text.match(pattern);
  if (!match) throw new Error("cannot find tag expression");
  return match[1];
}

const compact = text => text.replace(/\s+/g, "");
const tagMatches = compact(tagExpression(source, false)) === compact(tagExpression(copy, true));
const encodeMatches = compact(functionBody(source, "encode")) === compact(functionBody(copy, "encode"));
const lines = [
  `source: ${sourcePath}`,
  `tag body whitespace-insensitive diff: ${tagMatches ? 0 : "nonzero"}`,
  `encode body whitespace-insensitive diff: ${encodeMatches ? 0 : "nonzero"}`,
  `RESULT: ${tagMatches && encodeMatches ? "MATCH" : "MISMATCH"}`,
];
fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${lines.join("\n")}\n`);
process.stdout.write(`${lines.join("\n")}\n`);
if (!tagMatches || !encodeMatches) process.exitCode = 1;
