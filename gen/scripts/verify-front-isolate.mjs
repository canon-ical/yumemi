#!/usr/bin/env node

import { prepareFrontScratch, startFrontWorker } from "./front-harness.mjs";

function extractStyle(html) {
  const match = html.match(/<style>([\s\S]*?)<\/style>/);
  return match?.[1] ?? null;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const work = prepareFrontScratch("front-isolate");
let worker;
try {
  worker = await startFrontWorker(work, 8793);
  const rows = [];
  for (let i = 0; i < 40; i += 1) {
    const path = i % 2 === 0 ? "/article/first" : "/article/second";
    const response = await fetch(`${worker.baseUrl}${path}`);
    const html = await response.text();
    const style = extractStyle(html);
    assert(response.status === 200, `${path} returned ${response.status}`);
    assert(style !== null, `${path} did not return a style tag`);
    rows.push({ path, style });
  }

  const first = rows.filter((row) => row.path.endsWith("first"));
  const second = rows.filter((row) => row.path.endsWith("second"));
  const firstLengths = new Set(first.map((row) => row.style.length));
  const secondLengths = new Set(second.map((row) => row.style.length));
  const firstStyles = new Set(first.map((row) => row.style));
  const secondStyles = new Set(second.map((row) => row.style));

  assert(firstLengths.size === 1, "first style length changed across requests");
  assert(secondLengths.size === 1, "second style length changed across requests");
  assert(firstStyles.size === 1, "first style content changed across requests");
  assert(secondStyles.size === 1, "second style content changed across requests");
  const firstStyle = first[0].style;
  const secondStyle = second[0].style;
  const generatedLayout =
    firstStyle === secondStyle && firstStyle.includes('[data-yumemi-grid="layout"]');
  if (generatedLayout) {
    assert(firstStyle.includes("#2b1d3a"), "generated style marker is missing");
    assert(secondStyle.includes("#123524"), "generated style marker is missing");
    assert(firstStyle === secondStyle, "generated style crossed between requests");
  } else {
    assert(firstStyle.includes("#2b1d3a"), "first style marker is missing");
    assert(secondStyle.includes("#123524"), "second style marker is missing");
    assert(!firstStyle.includes("#123524"), "second style crossed into first page");
    assert(!secondStyle.includes("#2b1d3a"), "first style crossed into second page");
  }

  console.log(
    `ISOLATE: PASS (40 requests; first length ${first[0].style.length}, second length ${second[0].style.length})`,
  );
  console.log("ALL PASS");
} finally {
  if (worker) await worker.stop();
}
