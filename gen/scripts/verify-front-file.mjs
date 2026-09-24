#!/usr/bin/env node

import { chromium } from "/home/yumemism/yumemi-front-poc/node_modules/playwright/index.mjs";
import { prepareFrontScratch, startFrontWorker } from "./front-harness.mjs";

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const work = prepareFrontScratch("front-file");
let worker;
let browser;
try {
  worker = await startFrontWorker(work, 8795);
  browser = await chromium.launch();
  const page = await browser.newPage();
  const requests = [];
  page.on("request", (request) => {
    const url = new URL(request.url());
    if (url.pathname === "/api/blobs") {
      requests.push({
        method: request.method(),
        path: url.pathname,
        contentType: request.headers()["content-type"] ?? null,
      });
      return;
    }
    if (url.pathname === "/api/articles/article/blob_save") {
      requests.push({
        method: request.method(),
        path: url.pathname,
        body: JSON.parse(request.postData() ?? "{}"),
      });
    }
  });

  await page.goto(`${worker.baseUrl}/article/42`);
  await page.waitForFunction(
    () =>
      customElements.get("blob-save") !== undefined &&
      customElements.get("article-blob-copy") !== undefined,
    { timeout: 5000 },
  );

  const existingRequest = page.waitForResponse(
    (response) =>
      response.request().method() === "POST" &&
      new URL(response.url()).pathname === "/api/articles/article/blob_save",
    { timeout: 5000 },
  );
  await page.locator("blob-save button").click();
  assert((await existingRequest).ok(), "existing-key Service request failed");
  assert(requests.length === 1, `existing key caused extra requests: ${JSON.stringify(requests)}`);
  assert(requests[0].path === "/api/articles/article/blob_save", "existing key did not go directly to Service");
  assert(requests[0].body.blob === "stored-image-key", "existing Blob key changed");
  assert(requests[0].body.existing === "stored-optional-key", "existing Option(Blob) key changed");

  await page.locator("blob-save input").setInputFiles({
    name: "selected.png",
    mimeType: "image/png",
    buffer: Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
  });
  const selectedService = page.waitForResponse(
    (response) =>
      response.request().method() === "POST" &&
      new URL(response.url()).pathname === "/api/articles/article/blob_save",
    { timeout: 5000 },
  );
  await page.locator("blob-save button").click();
  assert((await selectedService).ok(), "selected-file Service request failed");
  await page.waitForFunction(
    () => document.querySelector("blob-save")?.shadowRoot?.textContent?.includes("saved"),
    { timeout: 5000 },
  );

  assert(requests.length === 3, `selected-file request count/order: ${JSON.stringify(requests)}`);
  assert(requests[1].path === "/api/blobs", "file upload did not precede the Service request");
  assert(requests[2].path === "/api/articles/article/blob_save", "Service request did not follow the upload");
  assert(requests[1].contentType === "image/png", `blob content type: ${requests[1].contentType}`);
  assert(requests[2].body.blob === "uploaded-image-key", "Service body did not contain the blob_copy key");
  assert(requests[2].body.existing === "stored-optional-key", "existing Option(Blob) key changed after upload");

  await page.locator("blob-save input").setInputFiles({
    name: "rejected.png",
    mimeType: "image/fail",
    buffer: Buffer.from([0]),
  });
  const failedUpload = page.waitForResponse(
    (response) =>
      response.request().method() === "POST" &&
      new URL(response.url()).pathname === "/api/blobs" &&
      response.status() === 503,
    { timeout: 5000 },
  );
  await page.locator("blob-save button").click();
  assert(!(await failedUpload).ok(), "failure route unexpectedly succeeded");
  await page.waitForFunction(
    () => document.querySelector("blob-save")?.shadowRoot?.textContent?.includes("failed"),
    { timeout: 5000 },
  );
  assert(requests.length === 4, `failed upload reached Service: ${JSON.stringify(requests)}`);
  assert(requests[3].path === "/api/blobs", "failed file did not stop at blob_copy");

  await page.locator("article-blob-copy input").setInputFiles({
    name: "article.png",
    mimeType: "image/png",
    buffer: Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
  });
  const entryUpload = page.waitForResponse(
    (response) =>
      response.request().method() === "POST" &&
      new URL(response.url()).pathname === "/api/blobs",
    { timeout: 5000 },
  );
  await page.locator("article-blob-copy button").click();
  assert((await entryUpload).ok(), "Target.Entry blob_copy request failed");
  await page.waitForFunction(
    () =>
      document
        .querySelector("article-blob-copy")
        ?.shadowRoot?.querySelector('[data-blob-key]')
        ?.textContent === "uploaded-image-key",
    { timeout: 5000 },
  );

  assert(requests.length === 5, `Entry should add one request: ${JSON.stringify(requests)}`);
  assert(requests[4].path === "/api/blobs", "Entry target did not use the attached blob_copy route");
  console.log(`FILE REQUESTS: ${JSON.stringify(requests)}`);
  console.log("FILE INPUT SERVICE: PASS (existing key skipped upload; selected file uploaded before Service)");
  console.log("FILE INPUT FAILURE: PASS (upload failure ended before Service)");
  console.log("FILE INPUT ENTRY: PASS (one blob_copy request; returned key displayed)");
  console.log("ALL PASS");
} finally {
  if (browser) await browser.close();
  if (worker) await worker.stop();
}
