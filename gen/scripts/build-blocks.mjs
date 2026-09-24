#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { prepareFrontScratch, startFrontWorker, repoRoot } from "./front-harness.mjs";

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const work = prepareFrontScratch("blocks-preview");
let worker;
try {
  worker = await startFrontWorker(work, 8794);
  const response = await fetch(`${worker.baseUrl}/_blocks`);
  const html = await response.text();
  assert(response.status === 200, `/_blocks returned ${response.status}`);
  assert(html.includes("blocks/article"), "article block is missing");
  assert(html.includes("blocks/feed"), "feed block is missing");
  assert(html.includes("blocks/row_article"), "row_article block is missing");
  assert(html.includes("blocks/row_summary"), "row_summary block is missing");
  assert(html.includes("blocks/site_header"), "site_header block is missing");
  assert(html.includes("blocks/summary"), "summary block is missing");
  assert(html.includes("blocks/notice"), "notice block is missing");
  assert(html.includes("<style>"), "preview style is missing");
  assert(html.includes('/_yumemi/client.mjs'), "preview client reference is missing");

  const output = path.join(
    repoRoot,
    "gen",
    "fixtures",
    "article",
    "public",
    "build",
    "blocks.html",
  );
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(output, html);
  console.log(`BLOCKS: PASS (7 blocks) -> ${output}`);
} finally {
  if (worker) await worker.stop();
}
