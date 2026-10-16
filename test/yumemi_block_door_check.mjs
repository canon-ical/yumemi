// block-door(0.14.1)── `Live` の無い面の逃げ道の口 `yumemi.block` を Playwright で回す。
// 試験の server(この process の node の HTTP)は、shell の形の頁(`Live` の無い頁、Block は包まない)と、断片の口
// (`x-yumemi-block` に `<style>` と `<yumemi-block name>` を返す)を持つ。socket の口は無く、upgrade が来たら数える。
// 頁の client は src の `interactive.mjs` と `block.mjs` をそのまま読む(`?live=1` の頁だけ `live_block.mjs` を読む)。
// 1 行 1 件の ok / NG を出す。生成した shell の断片の口は `yumemi_block_door_shell_check.mjs` が見る。
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright-core");
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");

const out = [];
const check = (name, ok, detail = "") => {
  out.push(`${ok ? "ok" : "NG"} ${name}${ok || detail === "" ? "" : ` ── ${detail}`}`);
};
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// ── 試験の server ──────────────────────────────────────────────────────────────

const state = { days: {}, gate: "pass", pageLoads: 0, fragments: [], upgrades: 0 };
function reset() {
  state.days = { 1: ["朝番 佐藤"], 2: ["朝番 鈴木", "夜番 田中"], 3: ["休み"] };
  state.gate = "pass";
  state.pageLoads = 0;
  state.fragments = [];
  state.upgrades = 0;
}
const escapeHtml = (text) => String(text).replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;");

/// 日の板の Block の中身(頁と断片で同じ字。頁は包まない)。行は鍵つき、メモの欄は利用者の持ち物。
function dayHtml(day) {
  return `<section class="c-day c-day${day}" data-day="${day}"><h2>${day} 日</h2>`
    + state.days[day].map((row, index) => `<p class="c-row" data-yumemi-key="${day}-${index}">${escapeHtml(row)}</p>`).join("")
    + `<input name="memo" value=""></section>`;
}
// 頁の `<style>`(頁を描いた間に使った class だけ)。`.c-day2`・`.c-day3` の規則は別の日の断片にしか無い
const pageCss = ".c-day{display:block;margin:0}.c-day1{color:rgb(0, 0, 255)}";
const fragmentCss = (day) => `.c-day{display:block;margin:0}.c-day${day}{color:rgb(${day === "2" ? "255, 0, 0" : "0, 128, 0"})}`;

function pageHtml(day, live) {
  return `<!doctype html><html lang="ja"><head><meta charset="utf-8"><title>day</title><script type="module" src="/_yumemi/client${live ? "-live" : ""}.mjs"></script></head>`
    + `<body><style id="page-style">${pageCss}</style><main id="board">${dayHtml(day)}</main><yumemi-escape name="probe"></yumemi-escape></body></html>`;
}

// `Live` の無い面の client.mjs(生成器の形:interactive と block.mjs だけ、`startBlock()`)
const clientMjs = `import { start as startInteractive } from "/src/interactive.mjs";
import { block as yumemiBlock, start as startBlock } from "/src/block.mjs";
startInteractive({
  components: {},
  escapes: { probe: (element, yumemi) => { globalThis.__yumemi = yumemi; element.dataset.mounted = "1"; } },
  yumemi: { block: yumemiBlock },
  go: null, reload: null,
});
startBlock();
`;
// `Live` のある面の client.mjs(0.14.0 の形)
const clientLiveMjs = `import { start as startInteractive } from "/src/interactive.mjs";
import { block as liveBlock, start as startLive } from "/src/live_block.mjs";
startInteractive({
  components: {},
  escapes: { probe: (element, yumemi) => { globalThis.__yumemi = yumemi; element.dataset.mounted = "1"; } },
  yumemi: { block: liveBlock },
  go: null, reload: null,
});
startLive({ socket: "/api/_yumemi/live", reload: null });
`;

const server = http.createServer(async (request, response) => {
  const url = new URL(request.url, "http://localhost");
  if (url.pathname === "/_yumemi/client.mjs" || url.pathname === "/_yumemi/client-live.mjs") {
    response.writeHead(200, { "content-type": "text/javascript" });
    return response.end(url.pathname.endsWith("-live.mjs") ? clientLiveMjs : clientMjs);
  }
  if (url.pathname.startsWith("/src/")) {
    response.writeHead(200, { "content-type": "text/javascript" });
    return response.end(fs.readFileSync(path.join(root, "src/yumemi/front", path.basename(url.pathname))));
  }
  const match = url.pathname.match(/^\/day\/(\d+)$/);
  if (match && request.method === "GET") {
    const day = match[1];
    const block = request.headers["x-yumemi-block"];
    if (block === undefined) {
      state.pageLoads += 1;
      response.writeHead(200, { "content-type": "text/html; charset=utf-8" });
      return response.end(pageHtml(day, url.searchParams.get("live") === "1"));
    }
    state.fragments.push(url.pathname + url.search);
    if (state.gate === "redirect") {
      response.writeHead(302, { location: "/login" });
      return response.end();
    }
    if (state.gate === "unavailable") {
      response.writeHead(503, { "content-type": "text/plain" });
      return response.end("unavailable");
    }
    if (block !== "day" || !state.days[day]) {
      response.writeHead(404, { "content-type": "text/plain" });
      return response.end("not found");
    }
    response.writeHead(200, { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" });
    return response.end(`<style>${fragmentCss(day)}</style><yumemi-block name="day">${dayHtml(day)}</yumemi-block>`);
  }
  if (url.pathname === "/login") {
    response.writeHead(200, { "content-type": "text/html" });
    return response.end("<!doctype html><p>login</p>");
  }
  response.writeHead(404);
  response.end();
});
server.on("upgrade", (_request, socket) => {
  state.upgrades += 1;
  socket.end("HTTP/1.1 403 Forbidden\r\ncontent-length: 0\r\n\r\n");
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const base = `http://127.0.0.1:${server.address().port}`;

async function open(browser, pathname = "/day/1") {
  const context = await browser.newContext({ viewport: { width: 420, height: 520 } });
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (error) => errors.push(String(error)));
  const scripts = [];
  page.on("request", (request) => { if (request.resourceType() === "script") scripts.push(new URL(request.url()).pathname); });
  await page.goto(base + pathname);
  await page.waitForFunction(() => globalThis.__yumemi !== undefined, null, { timeout: 5000 });
  return { context, page, errors, scripts };
}

/// 逃げ道が別の日の Block を取って板と差し替える(day_swipe の形)。
const swipe = (page, href) => page.evaluate(async (href) => {
  const element = await globalThis.__yumemi.block("day", { href });
  if (element === null) return null;
  const board = document.querySelector("#board");
  board.firstElementChild.replaceWith(element);
  return { tag: element.localName, href: element.getAttribute("href"), connected: element.isConnected };
}, href);

const boardState = (page) => page.evaluate(() => {
  const section = document.querySelector("#board section");
  const holder = document.querySelector("#board").firstElementChild;
  return {
    holder: holder.localName,
    display: getComputedStyle(holder).display,
    day: section?.dataset.day ?? null,
    rows: [...document.querySelectorAll("#board .c-row")].map((row) => row.textContent),
    color: section ? getComputedStyle(section).color : null,
    styleInBlock: document.querySelectorAll("#board style").length,
  };
});

const chrome = await chromium.launch();
try {
  // 1. `Live` の無い面:逃げ道は yumemi.block を受け、札・socket の runtime は読まない
  reset();
  {
    const a = await open(chrome);
    const api = await a.page.evaluate(() => ({ keys: Object.keys(globalThis.__yumemi), block: typeof globalThis.__yumemi.block, live: globalThis.customElements.get("yumemi-live") === undefined, defined: globalThis.customElements.get("yumemi-block") !== undefined }));
    check("no Live: the escape's mount gets yumemi.block", api.block === "function" && api.keys.join() === "block", JSON.stringify(api));
    check("no Live: yumemi-block is defined, yumemi-live is not, live_block.mjs is not loaded", api.defined && api.live && !a.scripts.some((p) => p.endsWith("live_block.mjs")) && a.scripts.some((p) => p.endsWith("block.mjs")), JSON.stringify(a.scripts));

    // 2. 別の URL の Block を取って replaceWith:HTML と CSS が当たる
    const placed = await swipe(a.page, "/day/2");
    const two = await boardState(a.page);
    check("yumemi.block: another URL returns a detached <yumemi-block> with its href", placed?.tag === "yumemi-block" && placed.href === `${base}/day/2` && placed.connected === true, JSON.stringify(placed));
    check("yumemi.block: the placed Block shows the other day's HTML (display: contents, no <style> left)", two.holder === "yumemi-block" && two.display === "contents" && two.day === "2" && two.rows.join("|") === "朝番 鈴木|夜番 田中" && two.styleInBlock === 0, JSON.stringify(two));
    check("css: the fragment's rule that the page lacks is added and takes effect", two.color === "rgb(255, 0, 0)", JSON.stringify(two));
    const rules = await a.page.evaluate(() => document.adoptedStyleSheets.flatMap((sheet) => [...sheet.cssRules]).map((rule) => rule.cssText));
    check("css: only the missing rule is added (the page's .c-day rule is not duplicated)", rules.filter((text) => text.includes(".c-day2")).length === 1 && rules.filter((text) => text.startsWith(".c-day {")).length === 0, JSON.stringify(rules));

    // 3. 合図が無いので自分では読み直さない:server が変わっても、visibilitychange でも取らない
    const before = state.fragments.length;
    state.days[2] = ["朝番 鈴木", "夜番 田中", "深夜 高橋"];
    await a.page.evaluate(() => document.dispatchEvent(new Event("visibilitychange")));
    await sleep(1200);
    const idle = await boardState(a.page);
    check("no signal: the placed Block does not refresh by itself (no fetch, no socket)", state.fragments.length === before && idle.rows.length === 2 && state.upgrades === 0, JSON.stringify({ fragments: state.fragments.length - before, rows: idle.rows, upgrades: state.upgrades }));

    // 4. 同じ URL で呼べば、置いた要素を取り直して当てる(書きかけと focus は残る)
    await a.page.click("#board input[name=memo]");
    await a.page.keyboard.type("メモ");
    const again = await a.page.evaluate(async () => {
      const placed = document.querySelector("#board yumemi-block");
      const element = await globalThis.__yumemi.block("day", { href: "/day/2" });
      return { same: element === placed, connected: element?.isConnected ?? false };
    });
    const refreshed = await boardState(a.page);
    const memo = await a.page.evaluate(() => ({ value: document.querySelector("#board input[name=memo]").value, focused: document.activeElement?.name ?? null }));
    check("yumemi.block: the same URL refreshes the placed Block in place and returns it", again.same && again.connected && refreshed.rows.join("|") === "朝番 鈴木|夜番 田中|深夜 高橋", JSON.stringify({ again, rows: refreshed.rows }));
    check("morph: the half-typed memo and its focus survive the refresh", memo.value === "メモ" && memo.focused === "memo", JSON.stringify(memo));

    // 5. また別の URL:新しい要素を返し、置き換えると規則が足される
    const three = await swipe(a.page, "/day/3");
    const third = await boardState(a.page);
    check("yumemi.block: a third URL returns a new element and its rule takes effect", three?.href === `${base}/day/3` && third.day === "3" && third.color === "rgb(0, 128, 0)", JSON.stringify({ three, third }));

    // 6. 頁を移った後:頁の `<style>` が外れても(client 遷移で頁の head が替わった形)、取り直すと規則を足し直す
    await a.page.evaluate(() => {
      document.querySelector("#page-style").remove();
      for (const sheet of document.adoptedStyleSheets) {
        for (let index = sheet.cssRules.length - 1; index >= 0; index -= 1) if (sheet.cssRules[index].cssText.startsWith(".c-day")) sheet.deleteRule(index);
      }
    });
    await a.page.evaluate(() => globalThis.__yumemi.block("day", { href: "/day/3" }));
    const after = await a.page.evaluate(() => {
      const section = document.querySelector("#board section");
      return { color: getComputedStyle(section).color, display: getComputedStyle(section).display, margin: getComputedStyle(section).marginTop };
    });
    check("after moving pages: the rules the document lost are added again from the fragment", after.color === "rgb(0, 128, 0)" && after.display === "block", JSON.stringify(after));

    // 7. 断片が来ない:404・門の 302・5xx は null、頁は読み直さない
    const loads = state.pageLoads;
    const missing = await a.page.evaluate(async () => (await globalThis.__yumemi.block("day", { href: "/day/9" })) === null);
    const unknown = await a.page.evaluate(async () => (await globalThis.__yumemi.block("nothing", { href: "/day/2" })) === null);
    state.gate = "redirect";
    const redirected = await a.page.evaluate(async () => (await globalThis.__yumemi.block("day", { href: "/day/2" })) === null);
    const placedRedirect = await a.page.evaluate(async () => (await globalThis.__yumemi.block("day", { href: "/day/3" })) === null);
    state.gate = "unavailable";
    const unavailable = await a.page.evaluate(async () => (await globalThis.__yumemi.block("day", { href: "/day/2" })) === null);
    state.gate = "pass";
    await sleep(300);
    const kept = await boardState(a.page);
    check("no fragment: 404 (no data, unknown name), the gate's 302 and 503 give null", missing && unknown && redirected && unavailable && placedRedirect, JSON.stringify({ missing, unknown, redirected, unavailable, placedRedirect }));
    check("no fragment: the page is not reloaded and the placed Block stays", state.pageLoads === loads && kept.day === "3", JSON.stringify({ loads: state.pageLoads - loads, kept }));

    // 8. 今の URL の `Fixed` の Block も `<yumemi-block>` で返り、取った URL を `href` に持つ(client 遷移で URL が
    //    替わっても、置いた要素は取った URL で探せて取り直せる)
    const here = await a.page.evaluate(async () => {
      const element = await globalThis.__yumemi.block("day");
      document.querySelector("#board").firstElementChild.replaceWith(element);
      history.pushState(null, "", "/day/7");
      const again = await globalThis.__yumemi.block("day", { href: "/day/1" });
      return { href: element.getAttribute("href"), same: again === element };
    });
    check("yumemi.block: the current URL's Fixed Block keeps its href and is found by it after the URL changes", here.href === `${base}/day/1` && here.same, JSON.stringify(here));
    check("no page errors", a.errors.length === 0, a.errors.join(" | "));
    await a.context.close();
  }

  // 9. `Live` のある面でも、`Fixed` の Block は `<yumemi-block>` で返り、同じ URL で取り直せる
  reset();
  {
    const b = await open(chrome, "/day/1?live=1");
    const placed = await swipe(b.page, "/day/2");
    state.days[2] = ["朝番 鈴木"];
    const again = await b.page.evaluate(async () => {
      const placed = document.querySelector("#board yumemi-block");
      const element = await globalThis.__yumemi.block("day", { href: "/day/2" });
      return { same: element === placed, live: globalThis.customElements.get("yumemi-live") !== undefined };
    });
    const rows = (await boardState(b.page)).rows;
    check("Live face: yumemi.block returns <yumemi-block> for a Fixed Block and refreshes it on the same URL", placed?.tag === "yumemi-block" && again.same && again.live && rows.join("|") === "朝番 鈴木" && state.upgrades === 0, JSON.stringify({ placed, again, rows, upgrades: state.upgrades }));
    check("Live face: no page errors", b.errors.length === 0, b.errors.join(" | "));
    await b.context.close();
  }
} finally {
  await chrome.close();
}

server.close();
console.log(out.join("\n"));
process.exit(0);
