#!/usr/bin/env node

import { chromium } from "/home/yumemism/yumemi-front-poc/node_modules/playwright/index.mjs";
import fs from "node:fs";
import path from "node:path";
import {
  prepareFrontScratch,
  startFrontWorker,
} from "./front-harness.mjs";

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const work = prepareFrontScratch("front-overlay");
const workerEntryPath = path.join(work, "worker-entry.mjs");
const workerEntry = fs.readFileSync(workerEntryPath, "utf8");
const singleRow = "return json(back.widget_list());";
const twoRows = "return json(back.widget_list_with_summary());";
assert(workerEntry.includes(singleRow), "Worker fixture row response has changed");
fs.writeFileSync(workerEntryPath, workerEntry.replace(singleRow, twoRows));
let worker;
let browser;
try {
  worker = await startFrontWorker(work, 8795);
  const response = await fetch(`${worker.baseUrl}/article/42`);
  const ssrHtml = await response.text();
  assert(response.status === 200, `SSR status: ${response.status}`);
  assert(/\spopover(?:="")?/.test(ssrHtml), "SSR is missing popover");
  assert(
    ssrHtml.includes('popovertarget="yumemi-overlay-article-dialog"'),
    "SSR is missing the Overlay popovertarget",
  );
  assert(
    ssrHtml.includes("data-yumemi-each-modal-opener"),
    "SSR is missing each_modal openers",
  );
  const overlayHtml = ssrHtml.match(
    /<div\b[^>]*id="yumemi-overlay-article-dialog"[^>]*>/,
  )?.[0];
  assert(overlayHtml?.includes("popover") === true, "Overlay HTML tag is missing popover");
  console.log(`OVERLAY HTML: ${overlayHtml}`);
  console.log("SSR HTML: PASS (popover and popovertarget present)");

  browser = await chromium.launch();
  const context = await browser.newContext({ javaScriptEnabled: false });
  const page = await context.newPage();
  await page.goto(`${worker.baseUrl}/article/42`);

  const overlay = page.locator("#yumemi-overlay-article-dialog");
  assert((await overlay.count()) === 1, "Overlay area is missing or duplicated");
  const openButton = page.locator(
    '[data-yumemi-overlay-opener][popovertarget="yumemi-overlay-article-dialog"]',
  );
  await openButton.click();
  const overlayOpened = await overlay.evaluate((element) =>
    element.matches(":popover-open"),
  );
  assert(overlayOpened, "Overlay did not open with JavaScript disabled");
  await overlay.locator("[data-yumemi-overlay-closer]").click();
  const overlayClosed = await overlay.evaluate((element) =>
    !element.matches(":popover-open"),
  );
  assert(overlayClosed, "Overlay did not close with JavaScript disabled");
  console.log("NO-JS AREA: PASS (opener opened; closer closed)");

  const rowPopovers = page.locator("[data-yumemi-each-modal]");
  const rowIds = await rowPopovers.evaluateAll((elements) =>
    elements.map((element) => element.id),
  );
  assert(rowIds.length === 2, `Expected 2 row modal ids, got ${rowIds.length}`);
  assert(new Set(rowIds).size === rowIds.length, `Duplicate row modal ids: ${JSON.stringify(rowIds)}`);
  console.log(`ROW MODAL IDS: ${JSON.stringify(rowIds)}`);

  await page.locator("[data-yumemi-each-modal-opener]").first().click();
  const rowStates = await rowPopovers.evaluateAll((elements) =>
    elements.map((element) => element.matches(":popover-open")),
  );
  assert(
    rowStates[0] === true && rowStates[1] === false,
    `Opening one row affected other popovers: ${JSON.stringify(rowStates)}`,
  );
  console.log("NO-JS ROW: PASS (only its row popover opened)");

  const gridValues = await page.locator("[data-yumemi-grid]").evaluateAll((elements) =>
    elements.map((element) => ({
      name: element.getAttribute("data-yumemi-grid"),
      areas: getComputedStyle(element).gridTemplateAreas,
    })),
  );
  const pageGrid = gridValues.find((grid) => grid.name?.startsWith("page:"));
  assert(pageGrid, `Page grid is missing: ${JSON.stringify(gridValues)}`);
  assert(
    gridValues.every((grid) => !grid.areas.includes("article-dialog")),
    `Overlay area leaked into grid-template-areas: ${JSON.stringify(gridValues)}`,
  );
  console.log(`GRID TEMPLATE: PASS (${JSON.stringify(gridValues)})`);

  const badges = await page.locator("[data-yumemi-badge]").evaluateAll((elements) =>
    elements.map((element) => ({
      count: element.getAttribute("data-count"),
      display: getComputedStyle(element).display,
      position: getComputedStyle(element).position,
    })),
  );
  const none = badges.find((badge) => badge.count === "");
  const zero = badges.find((badge) => badge.count === "0");
  const three = badges.find((badge) => badge.count === "3");
  assert(none && zero && three, `Badge values are missing: ${JSON.stringify(badges)}`);
  assert(none.display === "none", `None badge display: ${none.display}`);
  assert(zero.display === "none", `Some(0) badge display: ${zero.display}`);
  assert(three.display !== "none", `Some(3) badge display: ${three.display}`);
  assert(three.position === "absolute", `Badge position: ${three.position}`);
  console.log("BADGE: PASS (None and Some(0) hidden; Some(3) visible and positioned)");

  await browser.close();
  browser = undefined;
  console.log("ALL PASS");
} finally {
  if (browser) await browser.close();
  if (worker) await worker.stop();
}
