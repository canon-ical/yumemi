// yumemi-live-2(0.14)── `Live` の Block の client の runtime(`src/yumemi/front/live_block.mjs`)を Playwright で回す。
// 試験の server(この process の node の HTTP)は、shell の形の頁(`<yumemi-live name edge token>` で包んだ Block)・
// 断片の口(`x-yumemi-block`)・socket の口(札・Origin を見て `1` を流す、手で書いた WebSocket)・書きの口を持つ。
// 頁の client は src の `interactive.mjs` と `live_block.mjs` をそのまま読む。1 行 1 件の ok / NG を出す。
// 生成した shell の断片の口そのものは `yumemi_live2_shell_check.mjs` が見る。
import http from "node:http";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { chromium, webkit } = require("playwright-core");
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");

const out = [];
const check = (name, ok, detail = "") => {
  out.push(`${ok ? "ok" : "NG"} ${name}${ok || detail === "" ? "" : ` ── ${detail}`}`);
};
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
async function until(fn, ms = 5000) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    if (await fn()) return true;
    await sleep(25);
  }
  return false;
}

// ── 試験の server ──────────────────────────────────────────────────────────────

const state = {
  lines: [],
  title: "最初の名前",
  gate: "pass", // pass | redirect | notfound
  ttl: 3600,
  pageLoads: 0,
  fragments: 0,
  tokens: new Set(),
  sockets: new Set(),
  opened: [],
  openedAt: [],
  fragmentLog: [],
  refusals: 0,
  closeOnOpen: null,
  banner: false,
  sibling: false,
  upgradeDelay: 0,
};
let seq = 0;
function reset(count = 5) {
  state.lines = [];
  seq = 0;
  for (let i = 0; i < count; i += 1) addLine(`発言 ${i + 1}`);
  state.title = "最初の名前";
  state.gate = "pass";
  state.ttl = 3600;
  state.pageLoads = 0;
  state.fragments = 0;
  state.refusals = 0;
  state.opened = [];
  state.openedAt = [];
  state.fragmentLog = [];
  state.closeOnOpen = null;
  state.banner = false;
  state.sibling = false;
  state.upgradeDelay = 0;
}
function addLine(body, { front = false, fresh = false } = {}) {
  seq += 1;
  const line = { id: `m${seq}`, body, fresh };
  if (front) state.lines.unshift(line);
  else state.lines.push(line);
  return line;
}

const b64 = (value) => Buffer.from(value).toString("base64url");
function issue(ttl = state.ttl) {
  const token = `${b64(JSON.stringify({ to: "chat:1", party: null, exp: Math.floor(Date.now() / 1000) + ttl }))}.${crypto.randomBytes(8).toString("base64url")}`;
  state.tokens.add(token);
  return token;
}
const escapeHtml = (value) => String(value).replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;");

function blockHtml(edge, token) {
  const order = edge === "top" ? [...state.lines].reverse() : state.lines;
  const lines = order.map((line) =>
    `<li class="c-line${line.fresh ? " c-new" : ""}" data-yumemi-key="${line.id}"><p>${escapeHtml(line.body)}</p>`
    + `<details data-r="${line.id}"><summary>通報</summary><report-file data-yumemi-island data-yumemi-args="${escapeHtml(JSON.stringify({ report_file: { message: line.id } }))}"><form method="dialog"><fieldset><textarea name="report_file.reason"></textarea></fieldset></form></report-file></details></li>`).join("");
  const nameArgs = escapeHtml(JSON.stringify({ name_edit: { name: state.title } }));
  // banner:条件で出る `<p>`(後ろにも `<p class="c-foot">` がある)。sibling:鍵の無い同じ tag の兄弟が前に入る
  return `<yumemi-live name="thread" token="${token}" edge="${edge}"><section class="c-shell"><h1 class="c-title">${escapeHtml(state.title)}</h1>`
    + (state.banner ? `<p class="c-banner">相手が退会しました</p>` : "")
    + `<name-edit data-yumemi-island data-yumemi-args="${nameArgs}"><form method="dialog"><fieldset><input id="name" name="name_edit.name" value="${escapeHtml(state.title)}"></fieldset></form></name-edit>`
    + `<ol class="c-lines">${lines}</ol>`
    + `<button type="button" class="c-fresh" data-yumemi-fresh hidden>新しい発言があります</button>`
    + `<yumemi-escape name="probe"></yumemi-escape>`
    + (state.sibling ? `<div class="c-x">X</div>` : "")
    + `<div class="c-note">送りの注意</div>`
    + `<div class="c-send"><chat-compose data-yumemi-island data-yumemi-args="${escapeHtml(JSON.stringify({ message_send: { chat: "1" } }))}"><form method="dialog"><fieldset><textarea id="compose" name="message_send.body"></textarea><button type="submit" data-yumemi-send="message_send">送る</button></fieldset></form></chat-compose></div>`
    + `<input id="memo" name="memo" value="">`
    + `<a href="/chat/1">新着を読み込む</a><p class="c-foot">foot</p></section></yumemi-live>`;
}

// 頁の `<style>`(頁を描いた間に使った class だけ)。`.c-new` の規則は新着の行がある断片にしか無い
const pageCss = ".c-line{min-height:120px;margin:0}.c-fresh{position:sticky;bottom:0}yumemi-live{display:contents}[data-yumemi-fresh][hidden]{display:none!important}";
const fragmentCss = (edge) => (state.lines.some((line) => line.fresh) ? ".c-new{color:rgb(255, 0, 0)}" : "") + ".c-line{min-height:120px;margin:0}" + (edge ? "" : "");

function pageHtml(edge) {
  return `<!doctype html><html lang="ja"><head><meta charset="utf-8"><title>chat</title><script type="module" src="/_yumemi/client.mjs"></script></head>`
    + `<body><style>${pageCss}</style>${blockHtml(edge, issue(state.pageTtl ?? state.ttl))}</body></html>`;
}

const clientMjs = `import { start as startInteractive } from "/src/interactive.mjs";
import { block as liveBlock, start as startLive } from "/src/live_block.mjs";
const send = { method: "POST", path: "/api/chats/1/messages", read: false, upload: false, accepted: false, entry: false, args: [{ name: "chat", wire: "text", blob: false }, { name: "body", wire: "text", blob: false }], refused: [], requires: [], slots: {}, ok: { then: "stay" }, error: { then: "stay" } };
startInteractive({
  components: { "chat-compose": { services: { message_send: send } }, "report-file": { services: {} }, "name-edit": { services: {} } },
  escapes: { probe: (element, yumemi) => { globalThis.__yumemi = yumemi; element.dataset.mounted = "1"; } },
  yumemi: { block: liveBlock },
  go: null, reload: null,
});
startLive({ socket: "/api/_yumemi/live", reload: null });
`;

function frame(text) {
  const payload = Buffer.from(text);
  return Buffer.concat([Buffer.from([0x81, payload.length]), payload]);
}
function closeFrame(code) {
  return Buffer.from([0x88, 2, (code >> 8) & 0xff, code & 0xff]);
}
function signal() {
  for (const socket of state.sockets) socket.write(frame("1"));
}
function closeAll(code) {
  for (const socket of [...state.sockets]) {
    socket.write(closeFrame(code));
    socket.end();
    state.sockets.delete(socket);
  }
}

const server = http.createServer(async (request, response) => {
  const url = new URL(request.url, "http://localhost");
  if (url.pathname === "/_yumemi/client.mjs") {
    response.writeHead(200, { "content-type": "text/javascript" });
    return response.end(clientMjs);
  }
  if (url.pathname.startsWith("/src/")) {
    response.writeHead(200, { "content-type": "text/javascript" });
    return response.end(fs.readFileSync(path.join(root, "src/yumemi/front", path.basename(url.pathname))));
  }
  if (url.pathname === "/chat/1" && request.method === "GET") {
    const edge = url.searchParams.get("edge") ?? "bottom";
    const block = request.headers["x-yumemi-block"];
    if (block === undefined) {
      state.pageLoads += 1;
      response.writeHead(200, { "content-type": "text/html; charset=utf-8" });
      return response.end(pageHtml(edge));
    }
    state.fragments += 1;
    state.fragmentLog.push({ t: Date.now(), search: url.search });
    if (state.gate === "unavailable") {
      response.writeHead(503, { "content-type": "text/plain" });
      return response.end("unavailable");
    }
    if (state.gate === "drop") {
      request.socket.destroy();
      return;
    }
    if (state.gate === "redirect") {
      response.writeHead(302, { location: "/login" });
      return response.end();
    }
    if (state.gate === "notfound" || block !== "thread") {
      response.writeHead(404, { "content-type": "text/plain" });
      return response.end("not found");
    }
    response.writeHead(200, { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" });
    return response.end(`<style>${fragmentCss(edge)}</style>${blockHtml(edge, issue())}`);
  }
  if (url.pathname === "/api/chats/1/messages" && request.method === "POST") {
    let body = "";
    for await (const chunk of request) body += chunk;
    addLine(JSON.parse(body).body);
    response.writeHead(200, { "content-type": "application/json" });
    response.end("{}");
    signal();
    return;
  }
  if (url.pathname === "/login") {
    response.writeHead(200, { "content-type": "text/html" });
    return response.end("<!doctype html><p>login</p>");
  }
  response.writeHead(404);
  response.end();
});
server.on("upgrade", async (request, socket) => {
  if (state.upgradeDelay > 0) await sleep(state.upgradeDelay);
  const url = new URL(request.url, "http://localhost");
  const token = url.searchParams.get("token");
  const origin = request.headers.origin;
  let exp = 0;
  try { exp = JSON.parse(Buffer.from(token.split(".")[0], "base64url")).exp; } catch (_error) {}
  if (url.pathname !== "/api/_yumemi/live" || !state.tokens.has(token) || exp * 1000 <= Date.now() || origin !== `http://127.0.0.1:${port}`) {
    state.refusals += 1;
    socket.end("HTTP/1.1 403 Forbidden\r\ncontent-length: 0\r\n\r\n");
    return;
  }
  const accept = crypto.createHash("sha1").update(request.headers["sec-websocket-key"] + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").digest("base64");
  socket.write(`HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ${accept}\r\n\r\n`);
  state.opened.push(token);
  state.openedAt.push(Date.now());
  if (state.closeOnOpen !== null) {
    socket.write(closeFrame(state.closeOnOpen));
    socket.end();
    return;
  }
  state.sockets.add(socket);
  socket.on("data", (data) => {
    if ((data[0] & 0x0f) === 0x8) {
      state.sockets.delete(socket);
      socket.end(closeFrame(1000));
    }
  });
  socket.on("close", () => state.sockets.delete(socket));
  socket.on("error", () => state.sockets.delete(socket));
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const port = server.address().port;
const base = `http://127.0.0.1:${port}`;

// ── 頁の道具 ───────────────────────────────────────────────────────────────────

/// 頁を開き、socket が開いて最初の取り直し(繋がったら毎回 1 回)が当たるまで待つ。
async function open(browser, { edge = "bottom", viewport = { width: 420, height: 520 }, js = true, init = null } = {}) {
  const context = await browser.newContext({ viewport, javaScriptEnabled: js });
  if (js) {
    await context.addInitScript(() => {
      globalThis.__appliedCount = 0;
      document.addEventListener("yumemi-live-applied", () => { globalThis.__appliedCount += 1; }, true);
    });
  }
  if (init) await context.addInitScript(init);
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (error) => errors.push(String(error)));
  const before = state.opened.length;
  await page.goto(`${base}/chat/1?edge=${edge}`);
  if (js) {
    await until(() => state.opened.length > before);
    await until(() => page.evaluate(() => globalThis.__appliedCount > 0));
  }
  return { context, page, errors };
}
/// 次の当て(`yumemi-live-applied`)を待つ約束を頁に置く
async function armApplied(page) {
  await page.evaluate(() => {
    globalThis.__applied = new Promise((resolve) => {
      document.querySelector("yumemi-live").addEventListener("yumemi-live-applied", (event) => resolve(event.detail), { once: true });
    });
  });
}
async function applied(page) {
  return page.evaluate(() => Promise.race([globalThis.__applied, new Promise((resolve) => setTimeout(() => resolve("timeout"), 5000))]));
}
const remaining = (page) => page.evaluate(() => { const s = document.scrollingElement; return s.scrollHeight - s.scrollTop - s.clientHeight; });
const scrollTop = (page) => page.evaluate(() => document.scrollingElement.scrollTop);
const freshShown = (page) => page.evaluate(() => !document.querySelector("[data-yumemi-fresh]").hidden);
async function push(page, body, options = {}) {
  await armApplied(page);
  addLine(body, options);
  signal();
  return applied(page);
}

const chrome = await chromium.launch();
try {
  // 1. 2 者:相手が送ると、変換中のまま最新が見える(CDP の IME)
  reset();
  {
    const a = await open(chrome);
    const b = await open(chrome);
    await a.page.evaluate(() => {
      globalThis.events = [];
      for (const type of ["compositionstart", "compositionupdate", "compositionend", "blur", "focusout"]) {
        document.addEventListener(type, (event) => globalThis.events.push(type + (event.data !== undefined && event.data !== null ? ":" + event.data : "")), true);
      }
    });
    await a.page.click("#compose");
    await a.page.keyboard.type("書きかけ");
    const cdp = await a.context.newCDPSession(a.page);
    await cdp.send("Input.imeSetComposition", { text: "にほんご", selectionStart: 4, selectionEnd: 4 });
    const composing = await a.page.$eval("#compose", (t) => t.value);
    await armApplied(a.page);
    await b.page.fill("#compose", "こんにちは、届きますか");
    await b.page.click("[data-yumemi-send]");
    const log = await applied(a.page);
    const mid = await a.page.evaluate(() => ({
      value: document.querySelector("#compose").value,
      active: document.activeElement?.id,
      last: [...document.querySelectorAll(".c-line p")].at(-1)?.textContent,
      events: [...globalThis.events],
    }));
    await cdp.send("Input.insertText", { text: "日本語" });
    const after = await a.page.evaluate(() => ({ value: document.querySelector("#compose").value, events: [...globalThis.events] }));
    check("ime: the other party's message arrives in the open page", log !== "timeout" && mid.last === "こんにちは、届きますか", JSON.stringify(mid.last));
    check("ime: composing text survives the morph", composing === "書きかけにほんご" && mid.value === "書きかけにほんご", JSON.stringify({ composing, mid: mid.value }));
    check("ime: focus stays in the compose box (no blur / focusout)", mid.active === "compose" && !mid.events.some((e) => e === "blur" || e === "focusout"), JSON.stringify(mid));
    check("ime: commit after the morph gives 書きかけ日本語", after.value === "書きかけ日本語", after.value);
    const comp = after.events.filter((e) => e.startsWith("composition"));
    check("ime: one composition from start to end", comp[0] === "compositionstart:" && comp.at(-1) === "compositionend:日本語" && comp.filter((e) => e.startsWith("compositionstart")).length === 1, JSON.stringify(comp));
    check("ime: the compose component was kept, not replaced", Array.isArray(log?.kept) && log.kept.includes("chat-compose") && !log.replaced.includes("chat-compose"), JSON.stringify(log));
    const bValue = await b.page.$eval("#compose", (t) => t.value);
    check("send: the sender's own page also applied the signal and kept its form (Stay)", bValue === "こんにちは、届きますか", bValue);
    check("no page errors (2 parties)", a.errors.length === 0 && b.errors.length === 0, JSON.stringify([...a.errors, ...b.errors]));
    await a.context.close();
    await b.context.close();
  }

  // 2. details の開閉と通報の書きかけ・前に行が入っても同じ発言の行
  reset();
  {
    const a = await open(chrome);
    await a.page.evaluate(() => { document.querySelector('details[data-r="m2"]').open = true; });
    await a.page.fill('details[data-r="m2"] textarea', "理由の書きかけ");
    await push(a.page, "新着 1");
    await push(a.page, "新着 2");
    const d1 = await a.page.evaluate(() => ({ open: document.querySelector('details[data-r="m2"]').open, reason: document.querySelector('details[data-r="m2"] textarea').value }));
    check("details: open and the report draft survive two refreshes", d1.open === true && d1.reason === "理由の書きかけ", JSON.stringify(d1));
    await armApplied(a.page);
    addLine("前に入った発言", { front: true });
    signal();
    await applied(a.page);
    const d2 = await a.page.evaluate(() => ({ openOn: [...document.querySelectorAll("details")].filter((x) => x.open).map((x) => x.dataset.r), reason: document.querySelector('details[data-r="m2"] textarea').value, first: document.querySelector(".c-line p").textContent }));
    check("details: a line inserted before keeps the open details on the same message (keyed)", JSON.stringify(d2.openOn) === '["m2"]' && d2.reason === "理由の書きかけ" && d2.first === "前に入った発言", JSON.stringify(d2));
    await a.page.focus('details[data-r="m2"] textarea');
    await push(a.page, "新着 3");
    const active = await a.page.evaluate(() => document.activeElement?.closest("details")?.dataset.r);
    check("focus: focus in a report draft stays through a refresh", active === "m2", String(active));
    await a.context.close();
  }

  // 3. edge: bottom ── 端にいれば追う、上なら留まって印、印を押すと端へ
  reset();
  {
    const a = await open(chrome);
    await a.page.evaluate(() => window.scrollTo(0, document.scrollingElement.scrollHeight));
    await push(a.page, "下 1");
    const r1 = await remaining(a.page);
    check("bottom: at the end it follows the new line", r1 <= 8 && !(await freshShown(a.page)), String(r1));
    await a.page.evaluate(() => window.scrollTo(0, 100));
    const log2 = await push(a.page, "下 2");
    const top = await scrollTop(a.page);
    check("bottom: reading above it stays and shows el.fresh", Math.abs(top - 100) <= 1 && (await freshShown(a.page)), JSON.stringify({ top, log2 }));
    await a.page.click("[data-yumemi-fresh]", { timeout: 2000 }).catch(() => {});
    const r2 = await remaining(a.page);
    check("bottom: pressing el.fresh goes to the end and hides it", r2 <= 8 && !(await freshShown(a.page)), String(r2));
    await a.page.evaluate(() => window.scrollTo(0, 100));
    await armApplied(a.page);
    signal();
    await applied(a.page);
    check("bottom: a refresh with no change does not show el.fresh", !(await freshShown(a.page)));
    await a.context.close();
  }

  // 4. edge: top ── 新しい行は頭に入る。読んでいれば見えている行が動かない、頭にいれば頭のまま
  reset(8);
  {
    const a = await open(chrome, { edge: "top" });
    await a.page.evaluate(() => window.scrollTo(0, 300));
    const before = await a.page.evaluate(() => { const el = document.elementFromPoint(100, 60).closest("li"); return { key: el.dataset.yumemiKey, top: el.getBoundingClientRect().top }; });
    await push(a.page, "頭 1");
    const after = await a.page.evaluate((key) => document.querySelector(`li[data-yumemi-key="${key}"]`).getBoundingClientRect().top, before.key);
    check("top: reading below the top the visible line does not move", Math.abs(after - before.top) <= 1 && (await freshShown(a.page)), JSON.stringify({ before, after }));
    await a.page.evaluate(() => window.scrollTo(0, 0));
    await push(a.page, "頭 2");
    const first = await a.page.evaluate(() => ({ top: document.scrollingElement.scrollTop, text: document.querySelector(".c-line p").textContent }));
    check("top: at the top it stays at the top with the new line first", first.top <= 1 && first.text === "頭 2", JSON.stringify(first));
    await a.context.close();
  }

  // 5. edge: anywhere ── 留まる、印は出さない
  reset(8);
  {
    const a = await open(chrome, { edge: "anywhere" });
    await a.page.evaluate(() => window.scrollTo(0, 400));
    const before = await a.page.evaluate(() => { const el = document.elementFromPoint(100, 60).closest("li"); return { key: el.dataset.yumemiKey, top: el.getBoundingClientRect().top }; });
    await armApplied(a.page);
    addLine("前 1", { front: true });
    signal();
    await applied(a.page);
    const after = await a.page.evaluate((key) => document.querySelector(`li[data-yumemi-key="${key}"]`).getBoundingClientRect().top, before.key);
    check("anywhere: a line inserted above keeps the visible line and shows no el.fresh", Math.abs(after - before.top) <= 1 && !(await freshShown(a.page)), JSON.stringify({ before, after }));
    // browser の scroll anchoring の無いとき(`overflow-anchor: none`)も、当てる前の見えていた行の位置に戻す
    await a.page.evaluate(() => { document.documentElement.style.overflowAnchor = "none"; document.body.style.overflowAnchor = "none"; window.scrollTo(0, 400); });
    const before2 = await a.page.evaluate(() => { const el = document.elementFromPoint(100, 60).closest("li"); return { key: el.dataset.yumemiKey, top: el.getBoundingClientRect().top }; });
    await armApplied(a.page);
    addLine("前 2", { front: true });
    signal();
    await applied(a.page);
    const after2 = await a.page.evaluate((key) => document.querySelector(`li[data-yumemi-key="${key}"]`).getBoundingClientRect().top, before2.key);
    check("anywhere: without browser scroll anchoring the visible line is kept by the runtime", Math.abs(after2 - before2.top) <= 1, JSON.stringify({ before2, after2 }));
    await a.context.close();
  }

  // 6. 断片の CSS:頁に無い規則を足す、2 回当てても 1 本
  reset();
  {
    const a = await open(chrome);
    const before = await a.page.evaluate(() => [...document.styleSheets].flatMap((s) => [...s.cssRules]).some((r) => r.cssText.includes("c-new")));
    await push(a.page, "色の付く新着", { fresh: true });
    await push(a.page, "もう 1 行", { fresh: true });
    const css = await a.page.evaluate(() => ({
      color: getComputedStyle([...document.querySelectorAll(".c-new")].at(0)).color,
      rules: document.adoptedStyleSheets.flatMap((s) => [...s.cssRules]).filter((r) => r.cssText.includes("c-new")).length,
      styleInBlock: document.querySelector("yumemi-live").querySelectorAll("style").length,
    }));
    check("css: the fragment's rule for a class the page never used is added and applies", !before && css.color === "rgb(255, 0, 0)", JSON.stringify(css));
    check("css: applying the same rule twice keeps one rule, no <style> inside the Block", css.rules === 1 && css.styleInBlock === 0, JSON.stringify(css));
    await a.context.close();
  }

  // 7. Args が替わる Component:素のままなら差し替え、書きかけなら残して :state(stale)
  reset();
  {
    const a = await open(chrome);
    await armApplied(a.page);
    state.title = "二つ目の名前";
    signal();
    const log1 = await applied(a.page);
    const v1 = await a.page.evaluate(() => ({ value: document.querySelector("#name").value, stale: document.querySelector("name-edit").matches(":state(stale)") }));
    check("stale: a pristine component with new Args is replaced", v1.value === "二つ目の名前" && !v1.stale && log1.replaced.includes("name-edit"), JSON.stringify({ v1, log1 }));
    await a.page.fill("#name", "打ちかけの名前");
    await a.page.click("h1");
    await armApplied(a.page);
    state.title = "三つ目の名前";
    signal();
    const log2 = await applied(a.page);
    const v2 = await a.page.evaluate(() => ({ value: document.querySelector("#name").value, stale: document.querySelector("name-edit").matches(":state(stale)"), title: document.querySelector("h1").textContent }));
    check("stale: a component with a draft is kept and gets :state(stale)", v2.value === "打ちかけの名前" && v2.stale && v2.title === "三つ目の名前" && log2.stale.includes("name-edit"), JSON.stringify({ v2, log2 }));
    await a.context.close();
  }

  // 8. 門が頁を返さない(302・404)なら頁ごと取り直す
  for (const gate of ["redirect", "notfound"]) {
    reset();
    const a = await open(chrome);
    const loads = state.pageLoads;
    state.gate = gate;
    signal();
    const reloaded = await until(() => state.pageLoads > loads, 4000);
    check(`gate ${gate === "redirect" ? "302" : "404"}: the client reloads the whole page`, reloaded, String(state.pageLoads - loads));
    state.gate = "pass";
    await a.context.close();
  }

  // 9. JS 無しは今のまま:頁は読め、el.fresh は出ず、socket は張らない
  reset();
  {
    const before = state.opened.length;
    const a = await open(chrome, { js: false });
    const lines = await a.page.locator(".c-line").count();
    const freshVisible = await a.page.locator("[data-yumemi-fresh]").isVisible();
    const link = await a.page.locator("a[href='/chat/1']").isVisible();
    await sleep(300);
    check("no js: the page renders, el.fresh stays hidden, the reload link is there, no socket", lines === 5 && !freshVisible && link && state.opened.length === before, JSON.stringify({ lines, freshVisible, link, opened: state.opened.length - before }));
    await a.context.close();
  }

  // 10. 繋ぎ直し:切れたら張り直して 1 回取り直す。期限(4001)は先に取り直して新しい札で張る
  reset();
  {
    const a = await open(chrome);
    const fragments = state.fragments;
    const opened = state.opened.length;
    closeAll(1001);
    const again = await until(() => state.opened.length > opened, 4000);
    await until(() => state.fragments > fragments, 2000);
    check("reconnect: a dropped socket is reopened and the Block is refreshed once", again && state.fragments - fragments === 1, JSON.stringify({ again, fragments: state.fragments - fragments }));
    await sleep(800);
    check("reconnect: a refresh with a new token does not reopen a live socket", state.opened.length === opened + 1, String(state.opened.length - opened));
    const lastToken = state.opened.at(-1);
    const opened2 = state.opened.length;
    const fragments2 = state.fragments;
    closeAll(4001);
    const again2 = await until(() => state.opened.length > opened2, 8000);
    const code = await a.page.evaluate(() => document.querySelector("yumemi-live").yumemiLastClose);
    check("reconnect: a 4001 close refreshes first and reopens with a new token", again2 && state.fragments > fragments2 && state.opened.at(-1) !== lastToken && code === 4001, JSON.stringify({ again2, code, fragments: state.fragments - fragments2, same: state.opened.at(-1) === lastToken }));
    // 張れない(server が札を忘れた)→ 取り直して来た札で張る(開いた後の取り直しが札を出し終えるのを待つ)
    await sleep(700);
    state.tokens.clear();
    const refusals = state.refusals;
    const opened3 = state.opened.length;
    closeAll(1001);
    const again3 = await until(() => state.opened.length > opened3, 16000);
    check("reconnect: a refused socket refreshes the Block and opens with the new token", again3 && state.refusals > refusals, JSON.stringify({ again3, refusals: state.refusals - refusals }));
    // 頁が見えるようになった
    const fragments4 = state.fragments;
    await a.page.evaluate(() => document.dispatchEvent(new Event("visibilitychange")));
    const visible = await until(() => state.fragments > fragments4, 3000);
    check("visibilitychange: becoming visible refreshes the Block", visible);
    // 畳み:合図が続けて来ても取り直しは 1〜2 本
    await sleep(700);
    const fragments5 = state.fragments;
    // 同じ時に 6 回(揺らぎの待ちの間に来る合図は 1 つに畳む)。間を空けて来る合図は、取りの最中なら
    // 「終わったらもう 1 回」、取りの後なら次の取りになる(散らばった合図の本数は揺らぎしだいなので数えない)
    for (let i = 0; i < 6; i += 1) signal();
    await sleep(1500);
    check("coalesce: six signals at once make one or two fetches", state.fragments - fragments5 >= 1 && state.fragments - fragments5 <= 2, String(state.fragments - fragments5));
    check("no page errors (reconnect)", a.errors.length === 0, JSON.stringify(a.errors));
    await a.context.close();
  }

  // 11. 札の期限の前:期限が 1 分を切った札では張らず、先に取り直して来た札で張る
  reset();
  {
    state.pageTtl = 30;
    const context = await chrome.newContext();
    const page = await context.newPage();
    const opened = state.opened.length;
    const fragments = state.fragments;
    await page.goto(`${base}/chat/1`);
    state.pageTtl = null;
    const ok = await until(() => state.opened.length > opened, 4000);
    const token = state.opened.at(-1);
    const exp = JSON.parse(Buffer.from(token.split(".")[0], "base64url")).exp;
    check("expiry: a token near its exp is renewed by a refresh before the socket opens", ok && state.fragments > fragments && exp * 1000 - Date.now() > 3000 * 1000, JSON.stringify({ ok, fragments: state.fragments - fragments }));
    await context.close();
  }

  // 12. 逃げ道の口 yumemi.block
  reset();
  {
    const a = await open(chrome);
    const fragments = state.fragments;
    addLine("逃げ道から");
    const same = await a.page.evaluate(async () => {
      const element = await globalThis.__yumemi.block("thread");
      return { connected: element?.isConnected, last: [...document.querySelectorAll(".c-line p")].at(-1).textContent };
    });
    check("yumemi.block: the current URL refreshes and applies the Block in place", same.connected === true && same.last === "逃げ道から" && state.fragments === fragments + 1, JSON.stringify(same));
    const other = await a.page.evaluate(async () => {
      const element = await globalThis.__yumemi.block("thread", { href: "/chat/1?edge=anywhere" });
      return { tag: element?.localName, edge: element?.getAttribute("edge"), connected: element?.isConnected, live: document.querySelectorAll("yumemi-live").length };
    });
    check("yumemi.block: another URL returns a detached Block for the escape to place", other.tag === "yumemi-live" && other.edge === "anywhere" && other.connected === false && other.live === 1, JSON.stringify(other));
    const missing = await a.page.evaluate(async () => (await globalThis.__yumemi.block("nothing", { href: "/chat/1?x=1" })) === null);
    check("yumemi.block: a name the page does not serve gives null", missing);
    await a.context.close();
  }

  // ── r2(柏木 ゲート 2 の P2・P1)──────────────────────────────────────────────

  // P2-2:client の時計が 2 時間進んでいても、取り直しが輪にならない(取り直して来た札は期限を見ずに張る)
  reset();
  {
    const opened = state.opened.length;
    const a = await open(chrome, { init: () => { const real = Date.now.bind(Date); Date.now = () => real() + 2 * 3600 * 1000; } });
    // 頁の札は期限を過ぎて見えるので 1 回取り直して張り、開いた後に 1 回取り直す。その後は止まる
    await sleep(1000);
    const fragments = state.fragments;
    await sleep(3000);
    check("clock ahead (P2-2): a client clock 2h ahead opens the socket and stops refreshing", state.opened.length > opened && fragments <= 3 && state.fragments - fragments === 0 && state.sockets.size >= 1, JSON.stringify({ opened: state.opened.length - opened, settled: fragments, later: state.fragments - fragments }));
    await a.context.close();
  }

  // P2-2:開いてすぐ閉じられる socket(4001)の輪も倍々で待つ
  reset();
  {
    const a = await open(chrome);
    const opened = state.opened.length;
    state.closeOnOpen = 4001;
    closeAll(4001);
    await sleep(6000);
    const attempts = state.opened.length - opened;
    state.closeOnOpen = null;
    check("backoff (P2-2): a socket closed right after opening is retried with doubling waits", attempts >= 2 && attempts <= 4, JSON.stringify({ attempts, fragments: state.fragments }));
    await a.context.close();
  }

  // P2-3:断片の 5xx と通信の失敗は頁ごとにせず、倍々の待ちで取り直す(書きかけは残る)
  for (const gate of ["unavailable", "drop"]) {
    reset();
    const a = await open(chrome);
    await a.page.click("#compose");
    await a.page.keyboard.type("書きかけ");
    const loads = state.pageLoads;
    const fragments = state.fragments;
    state.gate = gate;
    addLine("落ちている間の発言");
    signal();
    await until(() => state.fragments > fragments + 1, 4000);
    state.gate = "pass";
    const healed = await until(() => a.page.evaluate(() => [...document.querySelectorAll(".c-line p")].at(-1).textContent === "落ちている間の発言"), 8000);
    const r = await a.page.evaluate(() => ({ value: document.querySelector("#compose").value, active: document.activeElement?.id }));
    const label = gate === "unavailable" ? "503" : "a network failure";
    check(`retry (P2-3): ${label} does not reload the page and retries until the Block arrives`, state.pageLoads === loads && healed && r.value === "書きかけ" && r.active === "compose", JSON.stringify({ reloads: state.pageLoads - loads, healed, r, fragments: state.fragments - fragments }));
    await a.context.close();
  }

  // P2-4:client 遷移で頁の `<style>` が外れたら、断片の規則を足し直す(在る規則の表を頁をまたいで持たない)
  reset();
  {
    const a = await open(chrome);
    await a.page.evaluate(() => document.querySelector("body > style").remove());
    await push(a.page, "遷移の後");
    const minHeight = await a.page.evaluate(() => getComputedStyle(document.querySelector(".c-line")).minHeight);
    check("css (P2-4): a rule whose page <style> went away is added again", minHeight === "120px", minHeight);
    await a.context.close();
  }

  // P2-5:前へ探す照合が、focus と書きかけのある節を消さない
  for (const shape of ["banner", "sibling"]) {
    reset();
    const a = await open(chrome);
    await a.page.fill("#memo", "メモの書きかけ");
    await a.page.click("#compose");
    await a.page.keyboard.type("送りの書きかけ");
    const before = await a.page.evaluate(() => document.querySelector("#compose") !== null);
    await a.page.evaluate(() => { globalThis.__compose = document.querySelector("#compose"); globalThis.__memo = document.querySelector("#memo"); });
    state[shape] = true;
    await push(a.page, "前に兄弟が入った");
    const r = await a.page.evaluate((shape) => ({
      value: document.querySelector("#compose").value,
      memo: document.querySelector("#memo").value,
      active: document.activeElement?.id,
      same: document.querySelector("#compose") === globalThis.__compose && document.querySelector("#memo") === globalThis.__memo,
      inserted: Boolean(document.querySelector(shape === "banner" ? ".c-banner" : ".c-x")),
      last: [...document.querySelectorAll(".c-line p")].at(-1).textContent,
    }), shape);
    const label = shape === "banner" ? "a conditional <p> before (and a <p> after)" : "a keyless sibling <div> before";
    check(`morph (P2-5): ${label} keeps the focused draft and the plain control's draft`, before && r.value === "送りの書きかけ" && r.memo === "メモの書きかけ" && r.active === "compose" && r.same && r.inserted && r.last === "前に兄弟が入った", JSON.stringify(r));
    await a.context.close();
  }

  // P2-6:`yumemi.block` が別の URL から返した要素は、置かれた後もその URL から取り直す
  reset();
  {
    const a = await open(chrome);
    await a.page.evaluate(async () => {
      const element = await globalThis.__yumemi.block("thread", { href: "/chat/1?edge=anywhere" });
      globalThis.__placed = element;
      document.querySelector("yumemi-live").replaceWith(element);
    });
    const href = await a.page.evaluate(() => globalThis.__placed.getAttribute("href"));
    await until(() => a.page.evaluate(() => globalThis.__appliedCount > 1));
    const log = state.fragmentLog.length;
    await a.page.evaluate(() => {
      globalThis.__placedApplied = new Promise((resolve) => globalThis.__placed.addEventListener("yumemi-live-applied", () => resolve(true), { once: true }));
    });
    addLine("別の日の発言");
    signal();
    await a.page.evaluate(() => Promise.race([globalThis.__placedApplied, new Promise((resolve) => setTimeout(resolve, 3000))]));
    const viaSignal = state.fragmentLog.slice(log).map((row) => row.search);
    const log2 = state.fragmentLog.length;
    await a.page.evaluate(() => document.dispatchEvent(new Event("visibilitychange")));
    await until(() => state.fragmentLog.length > log2, 3000);
    const viaVisible = state.fragmentLog.slice(log2).map((row) => row.search);
    const again = await a.page.evaluate(async () => (await globalThis.__yumemi.block("thread", { href: "/chat/1?edge=anywhere" })) === globalThis.__placed);
    check("yumemi.block (P2-6): a Block from another URL keeps that href and refreshes from it on a signal and visibilitychange", String(href).endsWith("/chat/1?edge=anywhere") && viaSignal.length >= 1 && viaSignal.every((q) => q === "?edge=anywhere") && viaVisible.length >= 1 && viaVisible.every((q) => q === "?edge=anywhere") && again, JSON.stringify({ href, viaSignal, viaVisible, again }));
    await a.context.close();
  }

  // P1-2:頁を描いてから socket が開くまでの書きを、開いたときの取り直しで拾う(最初も、張り直しも)
  reset();
  {
    state.upgradeDelay = 400;
    const context = await chrome.newContext();
    const page = await context.newPage();
    const opened = state.opened.length;
    await page.goto(`${base}/chat/1`);
    addLine("開くまでの発言");
    await until(() => state.opened.length > opened);
    const first = await until(() => page.evaluate(() => [...document.querySelectorAll(".c-line p")].at(-1).textContent === "開くまでの発言"), 3000);
    state.upgradeDelay = 0;
    const fragments = state.fragments;
    const opened2 = state.opened.length;
    closeAll(4001);
    await until(() => state.opened.length > opened2, 8000);
    const renewed = await until(() => state.fragments >= fragments + 2, 3000);
    check("open (P1-2): every open refreshes once, the first one and the reopen after 4001", first && renewed, JSON.stringify({ first, renewed, fragments: state.fragments - fragments }));
    await context.close();
  }

  // P1-3:繋ぎ直しの待ちと開いた後の取り直しに揺らぎ(Math.random を 0 と 0.999 にした 2 枚で時が違う)
  reset();
  {
    const low = await open(chrome, { init: () => { Math.random = () => 0; } });
    const high = await open(chrome, { init: () => { Math.random = () => 0.999; } });
    const t0 = Date.now();
    const log = state.fragmentLog.length;
    const opened = state.opened.length;
    closeAll(1001);
    await until(() => state.opened.length >= opened + 2, 4000);
    await until(() => state.fragmentLog.length >= log + 2, 3000);
    const opens = state.openedAt.slice(opened).map((t) => t - t0).sort((x, y) => x - y);
    const fetches = state.fragmentLog.slice(log).map((row) => row.t - t0).sort((x, y) => x - y);
    // 待ちは 1 秒の半分(500ms)〜全部(1000ms)。開いた後の取り直しは 0〜500ms
    const spreadOpen = opens.length === 2 && opens[0] < 800 && opens[1] >= 900;
    const lagLow = fetches[0] - opens[0];
    const lagHigh = fetches[1] - opens[1];
    check("jitter (P1-3): reconnect waits and the refresh after open are spread", spreadOpen && lagLow < 250 && lagHigh >= 300, JSON.stringify({ opens, fetches }));
    await low.context.close();
    await high.context.close();
  }
} finally {
  await chrome.close();
}

// 13. WebKit:IME の CDP は無い。値・focus・選択範囲が当てをまたいで残るか
const wk = await webkit.launch();
try {
  reset();
  const a = await open(wk);
  await a.page.click("#compose");
  await a.page.keyboard.type("書きかけ");
  await a.page.evaluate(() => document.querySelector("#compose").setSelectionRange(1, 2));
  await push(a.page, "webkit の新着");
  const r = await a.page.evaluate(() => { const t = document.querySelector("#compose"); return { value: t.value, active: document.activeElement?.id, sel: [t.selectionStart, t.selectionEnd], last: [...document.querySelectorAll(".c-line p")].at(-1).textContent }; });
  check("webkit: value, focus and selection survive the morph", r.value === "書きかけ" && r.active === "compose" && r.sel[0] === 1 && r.sel[1] === 2 && r.last === "webkit の新着", JSON.stringify(r));
  await a.context.close();
} finally {
  await wk.close();
}

server.close();
for (const socket of state.sockets) socket.destroy();
console.log(out.join("\n"));
process.exit(0);
