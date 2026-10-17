// 0.14.7 ── 実ブラウザで「redirect を返す GET が server に何回届くか」を数える台本。`gleam test` には繋がない
// (Chromium が無い台で落とさないため)。偽の fetch は `mode` / `redirect` の挙動を持たないので、これで代えない。
//
//   node test/yumemi_0147_redirect_browser.mjs [navigate.mjs の path] [playwright-core の path] [chromium の path]
//
// 既定は src/yumemi/front/navigate.mjs、root の node_modules の playwright-core、~/.cache/ms-playwright の Chromium。
// 直す前との比較は `git show <base>:src/yumemi/front/navigate.mjs > /tmp/old.mjs` を第 1 引数に渡す。
// node の小さな server(`/` は 200 の頁、`/go` は 302 で `/`、`/out` は別の origin へ 302)を 2 つ起こし、
// `navigate.mjs` を載せた頁で link を click して、`/go` と `/` と別の origin の受信数を出す。
import http from "node:http";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createRequire } from "node:module";

const navigatePath = path.resolve(process.argv[2] ?? new URL("../src/yumemi/front/navigate.mjs", import.meta.url).pathname);
const require = createRequire(import.meta.url);
const playwrightPath = process.argv[3] ?? path.join(os.homedir(), "yumemism_repo/yumemi/node_modules/playwright-core");
const { chromium } = require(playwrightPath);
const cacheDir = path.join(os.homedir(), ".cache/ms-playwright");
const chromiumPath = process.argv[4] ?? path.join(cacheDir, fs.readdirSync(cacheDir).filter((d) => /^chromium-\d+$/.test(d)).sort().pop(), "chrome-linux64/chrome");

const counts = {};
const hit = (key) => { counts[key] = (counts[key] ?? 0) + 1; };
const page = (links) => `<!doctype html><html><head><meta charset="utf-8"><title>t</title></head><body>${links}
<script type="module">import { start } from "/nav.mjs"; start({ routes: ["/", "/go", "/out"] });</script></body></html>`;
const links = '<a id="go" href="/go">go</a> <a id="out" href="/out">out</a>';

const other = http.createServer((req, res) => {
  hit(`other ${req.url}`);
  res.writeHead(200, { "content-type": "text/html" }).end(page(links));
});
await new Promise((resolve) => other.listen(0, "127.0.0.1", resolve));
const otherOrigin = `http://127.0.0.1:${other.address().port}`;
const main = http.createServer((req, res) => {
  const url = new URL(req.url, "http://x");
  if (url.pathname === "/nav.mjs") return res.writeHead(200, { "content-type": "text/javascript" }).end(fs.readFileSync(navigatePath));
  if (url.pathname === "/favicon.ico") return res.writeHead(404).end();
  hit(`main ${url.pathname}${req.headers["x-yumemi-navigate"] ? " (fetch)" : ""}`);
  if (url.pathname === "/go") return res.writeHead(302, { location: "/" }).end();
  if (url.pathname === "/out") return res.writeHead(302, { location: otherOrigin + "/" }).end();
  res.writeHead(200, { "content-type": "text/html" }).end(page(links));
});
await new Promise((resolve) => main.listen(0, "127.0.0.1", resolve));
const origin = `http://127.0.0.1:${main.address().port}`;

const browser = await chromium.launch({ executablePath: chromiumPath, args: ["--no-sandbox"] });
const run = async (name, selector, expectUrl) => {
  for (const key of Object.keys(counts)) delete counts[key];
  const tab = await browser.newPage();
  await tab.goto(origin + "/");
  await tab.waitForFunction(() => globalThis.navigation !== undefined);
  for (const key of Object.keys(counts)) delete counts[key];
  await tab.click(selector);
  await tab.waitForURL((u) => u.href.startsWith(expectUrl), { timeout: 5000 });
  await tab.waitForLoadState("load");
  await new Promise((resolve) => setTimeout(resolve, 300));
  console.log(`${name}: final=${tab.url()} requests=${JSON.stringify(counts)}`);
  await tab.close();
};
console.log(`navigate.mjs: ${navigatePath}`);
await run("same-origin 302 (/go -> /)", "#go", origin + "/");
await run("cross-origin 302 (/out -> other)", "#out", otherOrigin + "/");
await browser.close();
main.close();
other.close();
