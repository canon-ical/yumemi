#!/usr/bin/env node

import { chromium } from "/home/yumemism/yumemi-front-poc/node_modules/playwright/index.mjs";
import {
  prepareFrontScratch,
  startFrontWorker,
} from "./front-harness.mjs";

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const work = prepareFrontScratch("front-ssr");
let worker;
try {
  worker = await startFrontWorker(work, 8792);

  const noJsBrowser = await chromium.launch();
  const noJsContext = await noJsBrowser.newContext({ javaScriptEnabled: false });
  const noJsPage = await noJsContext.newPage();
  await noJsPage.goto(`${worker.baseUrl}/article/42`);
  const noJsHtml = await noJsPage.content();
  const noJsBody = await noJsPage.textContent("body");
  const styleCount = (noJsHtml.match(/<style>/g) ?? []).length;
  const styleIsFirstBodyElement = await noJsPage.evaluate(
    () => document.body.firstElementChild?.tagName === "STYLE",
  );
  await noJsBrowser.close();

  assert(
    noJsBody?.includes("本日の記事"),
    "SSR body is missing the fixture article title",
  );
  assert(
    noJsBody?.includes("夜のシフトが得意な新人です"),
    "SSR body is missing the fixture article text",
  );
  assert(styleCount === 1, `SSR emitted ${styleCount} style tags, expected 1`);
  assert(styleIsFirstBodyElement, "SSR style is not the first body element");
  console.log(
    `SSR NO-JS: PASS (title/body present, style tags: ${styleCount}, body first: yes)`,
  );

  const browser = await chromium.launch();
  const page = await browser.newPage();
  const errors = [];
  page.on("pageerror", (error) => errors.push(String(error)));
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(message.text());
  });
  await page.goto(`${worker.baseUrl}/article/42`);
  await page.waitForFunction(
    () => customElements.get("like-button") !== undefined,
    { timeout: 5000 },
  );
  const before = await page.locator("like-button button").textContent();
  await page.locator("like-button button").click();
  await page.waitForFunction(
    () => {
      const button = document
        .querySelector("like-button")
        ?.shadowRoot?.querySelector("button");
      return button?.textContent?.includes("13") === true;
    },
    { timeout: 5000 },
  );
  const after = await page.locator("like-button button").textContent();
  await browser.close();

  assert(after?.includes("13"), `island did not change after click: ${after}`);
  assert(errors.length === 0, `browser errors: ${errors.join("; ")}`);
  console.log(`SSR ISLAND: PASS (${before} -> ${after})`);
  console.log("ALL PASS");
} finally {
  if (worker) await worker.stop();
}
