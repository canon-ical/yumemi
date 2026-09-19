#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { rootArrow } from "../../src/framework/io_ffi.mjs";
import { makeContext } from "/home/yumemism/yumemism_repo/musearch/app/build/dev/javascript/musearch_app/gen/runtime.mjs";

const [, , out] = process.argv;
if (!out) {
  console.error("usage: verify-root-ffi.mjs <generated-out>");
  process.exit(2);
}

if (typeof rootArrow !== "function") {
  throw new Error("framework/io_ffi.mjs does not export rootArrow");
}

const readsDir = path.join(out, "src/gen/reads");
const reads = fs
  .readdirSync(readsDir)
  .filter((name) => name.endsWith(".gleam"))
  .map((name) => path.join(readsDir, name));
const rootReads = reads.filter((file) =>
  fs.readFileSync(file, "utf8").includes("io.root_arrow("),
);
if (rootReads.length === 0) {
  throw new Error("generated reads contain no root arrow");
}
for (const file of rootReads) {
  const text = fs.readFileSync(file, "utf8");
  if (text.includes('operations_ffi.mjs", "rootArrow"')) {
    throw new Error(`app-owned rootArrow FFI remains: ${file}`);
  }
}

const decoded = { id: "category-1", name: "decoded" };
const relation = { resolve: async () => decoded };
const context = makeContext({
  record: { name: "root_arrow_probe" },
  db: {},
  root: { article: { category: relation } },
  at: "2026-09-20T00:00:00.000Z",
  seed: "root-arrow-probe",
});
const result = await rootArrow(
  context,
  "article_read",
  "ArticleToCategory",
  context.root,
);
if (result !== decoded || typeof context.rootArrow !== "function") {
  throw new Error("makeContext root arrow did not resolve and decode the relation");
}
console.log(
  `rootArrow runtime PASS; generated root reads=${rootReads.length}; decoded=${result.name}`,
);
