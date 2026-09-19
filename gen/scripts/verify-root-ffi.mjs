#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { rootArrow } from "../../src/framework/io_ffi.mjs";

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
console.log(`rootArrow export loaded; generated root reads=${rootReads.length}`);
