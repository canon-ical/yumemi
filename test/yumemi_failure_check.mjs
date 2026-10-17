// failure-page(0.14.3)── 面の失敗の頁。article の fixture の写しの public 面に、門(全頁 sign-in・`/article` は
// member だけ・全頁に CSP)と失敗の頁(`src/failure.gleam` + Block `failure_note`)を足して生成器を走らせ(compile
// 済みの `build/dev/javascript/yumemi/yumemi/gen.mjs`)、面を `gleam build` し、生成の `shell.mjs` を偽の APP で叩く。
// 後半は同じ shell を node の HTTP で立て、束ねた client.mjs(navigate)を Chromium で回す(client 遷移の差し替え)。
// 1 行 1 件の ok / NG。写しは `build/failure-fx`(git の外)。
import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { createRequire } from "node:module";
import { spawnSync } from "node:child_process";
import { pathToFileURL } from "node:url";

const require = createRequire(import.meta.url);
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const work = path.join(root, "build", "failure-fx");
const out = [];
const check = (name, ok, detail = "") => out.push(`${ok ? "ok" : "NG"} ${name}${ok || detail === "" ? "" : ` ── ${detail}`}`);
function run(command, args, cwd, log) {
  const result = spawnSync(command, args, { cwd, encoding: "utf8", timeout: 300000 });
  fs.writeFileSync(path.join(work, log), `${result.stdout ?? ""}${result.stderr ?? ""}`);
  return result.status;
}

// ── 写しと生成 ─────────────────────────────────────────────────────────────────
fs.rmSync(work, { recursive: true, force: true });
fs.mkdirSync(work, { recursive: true });
const app = path.join(work, "article");
fs.cpSync(path.join(root, "gen/fixtures/article"), app, { recursive: true });
fs.rmSync(path.join(app, "public/build"), { recursive: true, force: true });
const face = path.join(app, "public/src");
fs.writeFileSync(path.join(face, "gate.gleam"), `import yumemi/gate.{
  Csp, Deny, Every, Exact, Gate, ImgSrc, NoPageview, Prefix, Rule, SignIn, SignedIn, SubjectKind, ToSignIn,
}

pub const gate: gate.Gate = Gate(
  sign_in: SignIn(path: "/auth/sign-in", fallback_origin: "https://auth.example"),
  rules: [
    Rule(pages: [Every], except: [Exact("/status")], checks: [
      SignedIn(fail: ToSignIn(status: 302, back: True)),
    ]),
    Rule(pages: [Prefix("/article")], except: [], checks: [
      SubjectKind(kinds: ["member"], fail: Deny(status: 403, body: "members only")),
    ]),
  ],
  redirects: [],
  csp: [Csp(pages: [Every], directives: [ImgSrc(hosts: ["img.example"])])],
  pageview: NoPageview,
)
`);
fs.writeFileSync(path.join(face, "failure.gleam"), `import yumemi/front.{type Page, Area, CurrentRoute, Failure, Fixed, Flow, Frame, Page, Var}
import yumemi/front/css
import gen/blocks
import gen/service
import gleam/option.{None}
import layout
import style

pub const page: Page(service.Service, blocks.Block) = Page(
  of: None,
  layout: layout.public,
  theme: None,
  vars: [Var("failure", Failure), Var("route", CurrentRoute)],
  sp: Frame(
    areas: [
      Area(name: "page", flow: css.Stack(gap: style.s2), pin: css.NoPin, style: style.page),
    ],
    placements: [Fixed(area: "page", block: blocks.FailureNote, cell: Flow)],
    cols: [],
    rows: [],
    template: [],
  ),
  pc: None,
  tablet: None,
)
`);
fs.writeFileSync(path.join(face, "blocks/failure_note.gleam"), `//// FailureNote Block ── 失敗の頁の中身。Failure の値で文言を分ける。

import yumemi/front/attr
import yumemi/front/css
import yumemi/front/el
import yumemi/front/html

pub type In =
  Nil

pub type Arg {
  Arg(failure: String, route: String, www_origin: String)
}

pub fn view(_it: In, arg: Arg) -> el.Element {
  let heading = case arg.failure {
    "forbidden" -> "このページは表示できません"
    "unavailable" -> "ただいま表示できません"
    _ -> "ページが見つかりません"
  }
  html.section(
    css.class([]),
    [
      attr.data("failure", arg.failure),
      attr.data("route", arg.route),
      attr.data("origin", arg.www_origin),
    ],
    [
      html.h1(css.class([]), [], [el.text(heading)]),
      html.a(css.class([]), [attr.href("/status"), attr.id("top")], [
        el.text("トップへ戻る"),
      ]),
    ],
  )
}
`);
for (const name of ["public", "admin"]) {
  fs.mkdirSync(path.join(app, name, "node_modules/.bin"), { recursive: true });
  fs.symlinkSync(path.join(root, "node_modules/.bin/esbuild"), path.join(app, name, "node_modules/.bin/esbuild"));
  fs.symlinkSync(path.join(root, "node_modules/esbuild"), path.join(app, name, "node_modules/esbuild"));
  const toml = path.join(app, name, "gleam.toml");
  fs.writeFileSync(toml, fs.readFileSync(toml, "utf8").replace('path = "../../../.."', `path = ${JSON.stringify(root)}`));
}
const runner = path.join(work, "gen-run.mjs");
fs.writeFileSync(runner, `import { main } from ${JSON.stringify(pathToFileURL(path.join(root, "build/dev/javascript/yumemi/yumemi/gen.mjs")).href)};\nmain();\n`);
const genStatus = run(process.execPath, [runner, app, app], root, "gen.txt");
const genLog = fs.readFileSync(path.join(work, "gen.txt"), "utf8");
check("generator: the face with a failure page generates with stop code 0", genStatus === 0 && genLog.includes("停止コード: 0"), genLog.slice(-600));
const buildStatus = run("gleam", ["build", "--target", "javascript"], path.join(app, "public"), "build.txt");
check("face: the generated Gleam (gen/load/failure.gleam) compiles", buildStatus === 0, fs.readFileSync(path.join(work, "build.txt"), "utf8").slice(-800));
if (buildStatus !== 0) {
  console.log(out.join("\n"));
  process.exit(0);
}

const built = path.join(app, "public/build/dev/javascript/public");
const gateFile = path.join(built, "gen/gate.mjs");
const gateText = fs.readFileSync(gateFile, "utf8");
check("gate: serve takes the failure page, exports plain / isPlain / wantsPage", gateText.includes("export function serve(dispatch, failure = null)") && gateText.includes("export {text as plain};") && gateText.includes("export function isPlain(response)") && gateText.includes("export function wantsPage(request)"));
// 数える頁の印:門は pageview を宣言しないので、build の写しの表に入れて見る(失敗の頁には差さない)
fs.writeFileSync(gateFile, gateText.replace("const pageviewRoutes = [];", 'const pageviewRoutes = ["/article/:slug", "/status"];'));
const shellFile = path.join(built, "gen/shell.mjs");
const shellText = fs.readFileSync(shellFile, "utf8");
check("shell: the failure spec reads only the Layout's Widget, Vars are Failure / CurrentRoute(\"\") / Layout's Origin", shellText.includes("const failureSpec = {") && shellText.includes('{ name: "failure", optional: false, from: { type: "failure" } }') && shellText.includes('{ name: "route", optional: false, from: { type: "route", value: "" } }') && /sources: \[\n    \{ service: service\.Service\$WidgetList\$const, [^\n]*optional: true, root: false \},\n  \]/.test(shellText), shellText.slice(shellText.indexOf("const failureSpec"), shellText.indexOf("const failureSpec") + 700));
// 描画の例外を起こす写し(失敗の頁が描けない ── 平文に落ちて回らない)
fs.writeFileSync(path.join(built, "gen/shell_broken.mjs"), shellText.replace("  loader: failureLoader,\n", "  loader: {load() { return null; }, render() { failureRenders += 1; throw new Error(\"broken failure page\"); }},\n").replace("// 0.14.3:失敗の頁(", "let failureRenders = 0;\nexport function renders() { return failureRenders; }\n// 0.14.3:失敗の頁("));

const shellModule = await import(pathToFileURL(shellFile).href);
const shell = shellModule.default;
const broken = await import(pathToFileURL(path.join(built, "gen/shell_broken.mjs")).href);

// ── 偽の APP ──────────────────────────────────────────────────────────────────
const article = {
  article: { slug: "42", title: "本日の記事", body: "本文", version: 1, order: 0, category: "news", tags: { keys: ["fixture"] } },
  category: { name: "news" },
  tags: [{ name: "fixture" }],
  theme: null,
};
let mode;
const reset = () => { mode = { read: 200, widget: 200, session: 200, signedIn: true, kind: "member" }; };
reset();
let requests = [];
const APP = {
  async fetch(request) {
    const url = new URL(request.url);
    requests.push(url.pathname);
    if (url.pathname === "/api/session" || url.pathname === "/fixture/session") {
      if (mode.session !== 200) return new Response("down", { status: mode.session });
      return Response.json(mode.signedIn ? { anonymous: false, subject: { id: "u1", handle: "hana", kind: mode.kind } } : { anonymous: true });
    }
    if (url.pathname.startsWith("/api/articles/")) {
      if (mode.read === "throw") throw new Error("APP binding failed");
      if (mode.read === "bad") return Response.json({ nothing: true });
      if (mode.read !== 200 || url.pathname !== "/api/articles/42") return new Response("{}", { status: mode.read === 200 ? 404 : mode.read });
      return Response.json(article);
    }
    if (url.pathname === "/api/widgets") {
      if (mode.widget === "throw") throw new Error("widget binding failed");
      if (mode.widget === "bad") return Response.json({ rows: "not rows" });
      if (mode.widget !== 200) return new Response("{}", { status: mode.widget });
      return Response.json({ rows: [] });
    }
    return new Response("{}", { status: 404 });
  },
};
const env = { APP, PUBLIC_PUBLIC_ORIGIN: "https://www.example", PUBLIC_IDP_ORIGIN: "https://id.example" };
const pageHeaders = { accept: "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8", "sec-fetch-dest": "document" };
const apiHeaders = { accept: "*/*" };
async function get(target, pathname, headers = pageHeaders, init = {}) {
  requests = [];
  const response = await target.fetch(new Request("https://www.example" + pathname, { headers, ...init }), env, { waitUntil() {} });
  return { status: response.status, headers: response.headers, text: await response.text(), requests: [...requests] };
}
const isFailurePage = (item, status, kind) =>
  item.status === status
  && (item.headers.get("content-type") ?? "").startsWith("text/html")
  && item.headers.get("x-yumemi-failure") === String(status)
  && item.text.includes(`data-failure="${kind}"`)
  && item.text.includes('data-yumemi-area="header"')
  && item.text.includes('<script type="module" src="/_yumemi/client.mjs"></script>')
  && !item.text.includes("yumemi-pageview");
const isPlain = (item, status, body) => item.status === status && (item.headers.get("content-type") ?? "").startsWith("text/plain") && item.text === body && !item.headers.has("x-yumemi-failure");
const summary = (item) => `${item.status} ${item.headers.get("content-type")} ${item.headers.get("x-yumemi-failure")} ${JSON.stringify(item.requests)} ${item.text.slice(0, 160)}`;
const CSP = "img-src 'self' https://img.example";

// ── 頁(200)は今のまま ───────────────────────────────────────────────────────────
const ok = await get(shell, "/article/42");
check("page 200: no failure mark, the counting mark is on the page", ok.status === 200 && !ok.headers.has("x-yumemi-failure") && ok.text.includes('<meta name="yumemi-pageview">'), summary(ok));

// ── 状態の写し(shell の失敗):頁を求める要求は失敗の頁、求めない要求は今の平文 ─────────────
const table = [
  ["root read 404", { read: 404 }, 404, "not_found", "not found"],
  ["root read 403", { read: 403 }, 403, "forbidden", "forbidden"],
  ["root read 400 (another 4xx keeps the API status)", { read: 400 }, 400, "not_found", "root read failed"],
  ["root read 500", { read: 500 }, 503, "unavailable", "unavailable"],
  ["root read throws", { read: "throw" }, 503, "unavailable", "unavailable"],
  ["decode throws (render exception)", { read: "bad" }, 500, "unavailable", "unavailable"],
];
for (const [name, set, status, kind, body] of table) {
  reset();
  Object.assign(mode, set);
  const page = await get(shell, "/article/42");
  check(`${name}: a page request gets the failure page (${status}, ${kind}) with the Layout and the route's CSP`, isFailurePage(page, status, kind) && page.headers.get("content-security-policy") === CSP && /<section[^>]* data-route[ >]/.test(page.text) && !page.text.includes("data-route="), summary(page));
  const api = await get(shell, "/article/42", apiHeaders);
  check(`${name}: a request that does not want a page keeps the plain text`, isPlain(api, status, body), summary(api));
}
reset();
const reads41 = await get(shell, "/article/41");
check("the failure page reads the Layout's Widget once more (and nothing else) after the page's reads", JSON.stringify(reads41.requests) === '["/fixture/session","/api/widgets","/api/articles/41","/api/widgets"]', summary(reads41));

// ── 頁を求める要求の判定 ─────────────────────────────────────────────────────────
reset();
mode.read = 404;
const byAccept = await get(shell, "/article/42", { accept: "text/html" });
const byDest = await get(shell, "/article/42", { "sec-fetch-dest": "document" });
const byNavigate = await get(shell, "/article/42", { accept: "*/*", "x-yumemi-navigate": "1" });
check("page request: accept text/html, sec-fetch-dest document, x-yumemi-navigate alone each get the page", isFailurePage(byAccept, 404, "not_found") && isFailurePage(byDest, 404, "not_found") && isFailurePage(byNavigate, 404, "not_found"), [byAccept, byDest, byNavigate].map(summary).join(" | "));
const head = await get(shell, "/article/42", pageHeaders, { method: "HEAD" });
check("page request: HEAD gets the failure page's status and mark", head.status === 404 && head.headers.get("x-yumemi-failure") === "404", summary(head));
const post = await get(shell, "/article/42", pageHeaders, { method: "POST", body: "x=1" });
check("not a page request: POST keeps the plain text", post.status !== 200 && !post.headers.has("x-yumemi-failure") && (post.headers.get("content-type") ?? "").startsWith("text/plain"), summary(post));
const image = await get(shell, "/article/42", { accept: "image/avif,image/webp,*/*", "sec-fetch-dest": "image" });
check("not a page request: an image request keeps the plain text", isPlain(image, 404, "not found"), summary(image));
const fragment = await get(shell, "/article/42", { ...pageHeaders, "x-yumemi-block": "summary" });
check("fragment door: x-yumemi-block keeps the plain 404 even with accept text/html", isPlain(fragment, 404, "not found"), summary(fragment));
mode.read = 403;
const fragment403 = await get(shell, "/article/42", { ...pageHeaders, "x-yumemi-block": "summary" });
check("fragment door: the root 403 stays plain 403", isPlain(fragment403, 403, "forbidden"), summary(fragment403));
mode.read = "bad";
const fragment500 = await get(shell, "/article/42", { ...pageHeaders, "x-yumemi-block": "summary" });
check("fragment door: a render exception is a plain 500 unavailable (not the Worker's exception)", isPlain(fragment500, 500, "unavailable"), summary(fragment500));

// ── Layout の Widget の読みの失敗:その Widget だけ欠けて頁は出る ───────────────────────
// 頁の読みを持たない route に当たらない path の失敗の頁で見る(頁の読みの中の Widget の失敗は、今までどおり頁の失敗)
reset();
const withFeed = await get(shell, "/nowhere");
check("Layout Widget read 200: the failure page draws the Layout's Widget", isFailurePage(withFeed, 404, "not_found") && withFeed.text.includes("記事の件数: 0"), summary(withFeed));
for (const widget of [403, 500, "throw", "bad"]) {
  reset();
  mode.widget = widget;
  const page = await get(shell, "/nowhere");
  check(`Layout Widget read ${widget}: the failure page is still 404 with the header and the content, without the Widget`, isFailurePage(page, 404, "not_found") && !page.text.includes("記事の件数") && page.text.includes("トップへ戻る"), summary(page));
}

// ── 描けないときは平文へ(失敗の頁から失敗の頁へ回さない)──────────────────────────────
reset();
mode.read = 404;
const brokenPage = await get(broken.default, "/article/42");
check("failure page render throws: the plain 404 comes back, rendered once (no loop)", isPlain(brokenPage, 404, "not found") && broken.renders() === 1, `${summary(brokenPage)} renders=${broken.renders()}`);
const noOrigin = { ...env };
delete noOrigin.PUBLIC_IDP_ORIGIN;
requests = [];
const noOriginResponse = await shell.fetch(new Request("https://www.example/article/42", { headers: pageHeaders }), noOrigin, { waitUntil() {} });
const noOriginText = await noOriginResponse.text();
check("Origin env missing: the plain 500 (the env name stays out of HTML)", noOriginResponse.status === 500 && (noOriginResponse.headers.get("content-type") ?? "").startsWith("text/plain") && !noOriginText.includes("<html"), `${noOriginResponse.status} ${noOriginText}`);

// ── route に当たらない path ─────────────────────────────────────────────────────
reset();
const lost = await get(shell, "/nowhere/at/all");
check("unmatched path, signed-in: the failure page 404 with the Layout (no route CSP)", isFailurePage(lost, 404, "not_found") && !lost.headers.has("content-security-policy"), summary(lost));
const lostApi = await get(shell, "/nowhere/at/all", apiHeaders);
check("unmatched path, not a page request: plain 404 without reading the session", isPlain(lostApi, 404, "not found") && lostApi.requests.length === 0, summary(lostApi));
mode.signedIn = false;
const lostAnon = await get(shell, "/nowhere/at/all");
check("unmatched path, anonymous page request: the gate's Every rule sends to sign-in (no frame)", lostAnon.status === 302 && (lostAnon.headers.get("location") ?? "").startsWith("https://id.example/auth/sign-in") && !lostAnon.text.includes("data-yumemi-area"), summary(lostAnon));
const status = await get(shell, "/status");
check("an excepted page (/status) still opens for anonymous", status.status === 200, summary(status));
const lostExcept = await get(shell, "/status/nothing");
check("unmatched path under an excepted page: Every still applies (except is for routes)", lostExcept.status === 302, summary(lostExcept));

// ── 門の失敗 ──────────────────────────────────────────────────────────────────
reset();
mode.kind = "visitor";
const deny = await get(shell, "/article/42");
check("gate Deny: a page request gets the failure page 403 with the route's CSP", isFailurePage(deny, 403, "forbidden") && deny.headers.get("content-security-policy") === CSP, summary(deny));
const denyApi = await get(shell, "/article/42", apiHeaders);
check("gate Deny: a request that does not want a page keeps the Deny body", isPlain(denyApi, 403, "members only"), summary(denyApi));
reset();
mode.session = 500;
const gateDown = await get(shell, "/article/42");
check("gate session read 5xx: the failure page 503 (unavailable)", isFailurePage(gateDown, 503, "unavailable"), summary(gateDown));
reset();
mode.session = 404;
const gateGone = await get(shell, "/article/42");
check("gate session read 404: the failure page 404", isFailurePage(gateGone, 404, "not_found"), summary(gateGone));

// ── 入口のための口 ────────────────────────────────────────────────────────────────
reset();
const entryPage = await shellModule.failure(new Request("https://www.example/me/sign-out", { headers: pageHeaders }), env, 503);
const entryPageText = await entryPage.text();
const entryApi = await shellModule.failure(new Request("https://www.example/me/sign-out", { headers: apiHeaders }), env, 503);
check("export failure(request, env, status): the page for a page request, plain for the rest", entryPage.status === 503 && entryPage.headers.get("x-yumemi-failure") === "503" && entryPageText.includes('data-failure="unavailable"') && entryApi.status === 503 && (await entryApi.text()) === "unavailable", entryPageText.slice(0, 120));

// ── Chromium:client 遷移の差し替え ──────────────────────────────────────────────────
const client = fs.readFileSync(path.join(app, "public/priv/static/_yumemi/client.mjs"), "utf8");
const state = { documents: [], fetches: [] };
const server = http.createServer(async (incoming, response) => {
  const url = new URL(incoming.url, "http://localhost");
  if (url.pathname === "/_yumemi/client.mjs") {
    response.writeHead(200, { "content-type": "text/javascript" });
    return response.end(client);
  }
  if (url.pathname.startsWith("/_yumemi/") || url.pathname.endsWith(".css")) {
    response.writeHead(200, { "content-type": url.pathname.endsWith(".css") ? "text/css" : "text/javascript" });
    return response.end("");
  }
  const headers = new Headers();
  for (const [name, value] of Object.entries(incoming.headers)) headers.set(name, Array.isArray(value) ? value.join(", ") : value);
  if (headers.has("x-yumemi-navigate")) state.fetches.push(url.pathname);
  else if (headers.get("sec-fetch-dest") === "document") state.documents.push(url.pathname);
  const answer = await shell.fetch(new Request("https://www.example" + url.pathname + url.search, { method: incoming.method, headers }), env, { waitUntil() {} });
  const out = {};
  answer.headers.forEach((value, name) => { out[name] = value; });
  response.writeHead(answer.status, out);
  response.end(Buffer.from(await answer.arrayBuffer()));
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const base = `http://127.0.0.1:${server.address().port}`;
const { chromium } = require("playwright-core");
const chrome = await chromium.launch();
const link = (page, href) => page.evaluate((href) => {
  const a = document.createElement("a");
  a.href = href;
  a.id = "go";
  a.textContent = "go";
  document.body.prepend(a);
}, href).then(() => page.click("#go"));
try {
  reset();
  const context = await chrome.newContext({ viewport: { width: 390, height: 700 } });
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (error) => errors.push(String(error)));
  await page.goto(base + "/status");
  await page.waitForFunction(() => document.querySelector('[data-yumemi-area="header"]') !== null);
  state.documents = [];
  state.fetches = [];
  mode.read = 404;
  await link(page, "/article/41");
  await page.waitForFunction(() => document.querySelector("[data-failure]") !== null, null, { timeout: 5000 }).catch(() => {});
  const shown = await page.evaluate(() => ({ failure: document.querySelector("[data-failure]")?.getAttribute("data-failure") ?? null, header: document.querySelector('[data-yumemi-area="header"]') !== null, path: location.pathname }));
  check("SPA: a link from a 200 page to a 404 swaps in the failure page without a page load", shown.failure === "not_found" && shown.header && shown.path === "/article/41" && state.documents.length === 0 && JSON.stringify(state.fetches) === '["/article/41"]', JSON.stringify({ shown, documents: state.documents, fetches: state.fetches }));
  await page.goBack();
  await page.waitForFunction(() => document.querySelector("[data-failure]") === null, null, { timeout: 5000 }).catch(() => {});
  const back = await page.evaluate(() => ({ failure: document.querySelector("[data-failure]") !== null, path: location.pathname }));
  check("SPA: back returns to the previous page by the client transition", !back.failure && back.path === "/status" && state.documents.length === 0, JSON.stringify({ back, documents: state.documents, fetches: state.fetches }));
  mode.kind = "visitor";
  mode.read = 200;
  await link(page, "/article/42");
  await page.waitForFunction(() => document.querySelector("[data-failure]") !== null, null, { timeout: 5000 }).catch(() => {});
  const denied = await page.evaluate(() => document.querySelector("[data-failure]")?.getAttribute("data-failure") ?? null);
  check("SPA: the gate's Deny swaps in the 403 failure page (same CSP) without a page load", denied === "forbidden" && state.documents.length === 0, JSON.stringify({ denied, documents: state.documents, fetches: state.fetches }));
  mode.kind = "member";
  await page.click("#top");
  await page.waitForFunction(() => document.querySelector("[data-failure]") === null && location.pathname === "/status", null, { timeout: 5000 }).catch(() => {});
  check("SPA: the failure page's link back to the top moves by the client transition", (await page.evaluate(() => location.pathname)) === "/status" && state.documents.length === 0, JSON.stringify({ documents: state.documents, fetches: state.fetches }));
  // 頁の読み込みの失敗の頁(直に開く)は失敗の頁の HTML で、client が起き、そこから 200 の頁へ client 遷移できる
  mode.read = 404;
  const direct = await page.goto(base + "/article/40");
  const directShown = await page.evaluate(() => document.querySelector("[data-failure]")?.getAttribute("data-failure") ?? null);
  check("page load: a 404 opens the failure page with the original status", direct.status() === 404 && directShown === "not_found", String(direct.status()));
  check("SPA: no page errors", errors.length === 0, errors.join(" | "));
  await context.close();
} finally {
  await chrome.close();
  server.close();
}

console.log(out.join("\n"));
process.exit(0);
