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

  const fallbackResponse = await fetch(`${worker.baseUrl}/not-a-generated-route`);
  const fallbackBody = await fallbackResponse.text();
  assert(fallbackResponse.status === 200, `SVELTE fallback status: ${fallbackResponse.status}`);
  assert(
    fallbackBody.includes("SVELTE fallback: /not-a-generated-route"),
    `SVELTE fallback body: ${fallbackBody}`,
  );
  console.log("SVELTE FALLBACK: PASS");

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
  const initialPage = await browser.newPage();
  await initialPage.goto(`${worker.baseUrl}/article/42`);
  await initialPage.waitForFunction(
    () => customElements.get("pick-tag") !== undefined,
    { timeout: 5000 },
  );
  const initialPostRequest = initialPage.waitForRequest(
    (request) =>
      request.method() === "POST" &&
      request.url() === `${worker.baseUrl}/api/articles`,
    { timeout: 5000 },
  );
  await initialPage.locator("pick-tag button").click();
  const initialPostBody = JSON.parse((await initialPostRequest).postData());
  assert(
    initialPostBody.tags === "fixture",
    `initial tag POST body: ${JSON.stringify(initialPostBody)}, expected tags "fixture"`,
  );
  console.log(`SSR INITIAL: PASS (posted ${JSON.stringify(initialPostBody)})`);
  await initialPage.close();

  const page = await browser.newPage();
  const errors = [];
  const documentRequests = [];
  page.on("pageerror", (error) => errors.push(String(error)));
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(message.text());
  });
  page.on("request", (request) => {
    if (request.resourceType() === "document") documentRequests.push(request.url());
  });
  await page.goto(`${worker.baseUrl}/article/42`);
  await page.waitForFunction(
    () => customElements.get("like-button") !== undefined,
    { timeout: 5000 },
  );
  await page.waitForFunction(
    () => customElements.get("pick-tag") !== undefined,
    { timeout: 5000 },
  );
  const likeButton = page.locator("like-button").first().locator("button");
  const before = await likeButton.textContent();
  await likeButton.click();
  await page.waitForFunction(
    () => {
      const button = document
        .querySelector('[data-yumemi-area="page"] like-button')
        ?.shadowRoot?.querySelector("button");
      return button?.textContent?.includes("13") === true;
    },
    { timeout: 5000 },
  );
  const after = await likeButton.textContent();

  assert(after?.includes("13"), `island did not change after click: ${after}`);
  assert(errors.length === 0, `browser errors: ${errors.join("; ")}`);
  console.log(`SSR ISLAND: PASS (${before} -> ${after})`);

  const articleUrl = `${worker.baseUrl}/article/42`;
  const reloadRequest = page.waitForRequest(
    (request) =>
      request.resourceType() === "document" && request.url() === articleUrl,
    { timeout: 5000 },
  );
  const selectedPostRequest = page.waitForRequest(
    (request) =>
      request.method() === "POST" &&
      request.url() === `${worker.baseUrl}/api/articles`,
    { timeout: 5000 },
  );
  await page.locator("pick-tag select").selectOption("gleam");
  await page.locator("pick-tag button").click();
  const selectedPostBody = JSON.parse((await selectedPostRequest).postData());
  assert(
    selectedPostBody.tags === "gleam",
    `selected tag POST body: ${JSON.stringify(selectedPostBody)}, expected tags "gleam"`,
  );
  console.log(`SSR SELECTED: PASS (posted ${JSON.stringify(selectedPostBody)})`);
  await reloadRequest;
  await page.waitForLoadState("load");

  const articleRequests = documentRequests.filter((url) => url === articleUrl);
  assert(
    articleRequests.length === 2,
    `document request loop: ${JSON.stringify(documentRequests)}`,
  );
  console.log(`SSR RELOAD REQUESTS: ${JSON.stringify(documentRequests)}`);
  console.log("SSR RELOAD: PASS (one same-URL re-request, no loop)");
  await browser.close();
  console.log("ALL PASS");
} finally {
  if (worker) await worker.stop();
}
