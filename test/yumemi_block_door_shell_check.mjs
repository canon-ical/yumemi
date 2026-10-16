// block-door(0.14.1)── `Live` の無い面の生成した shell の断片の口を node で叩く。article の fixture の写しに面の門
// (`/article` は sign-in を要る)を足して生成器を走らせ(compile 済みの `build/dev/javascript/yumemi/yumemi/gen.mjs`)、
// 面を `gleam build` し、生成の `shell.mjs` を偽の APP で叩く。頁は `Fixed` の Article・Summary(読みは ArticleRead)・
// Notice(`In = Nil`)を置き、Layout は SiteHeader(`Fixed`)と Feed(`Widget`)を置く。1 行 1 件の ok / NG。
// 写しは `build/block-door-fx`(git の外)。
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { pathToFileURL } from "node:url";

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const work = path.join(root, "build", "block-door-fx");
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
fs.writeFileSync(path.join(app, "public/src/gate.gleam"), `import yumemi/gate.{Gate, NoPageview, Prefix, Rule, SignIn, SignedIn, ToSignIn}

pub const gate: gate.Gate = Gate(
  sign_in: SignIn(path: "/auth/sign-in", fallback_origin: "https://auth.example"),
  rules: [
    Rule(pages: [Prefix("/article")], except: [], checks: [
      SignedIn(fail: ToSignIn(status: 302, back: True)),
    ]),
  ],
  redirects: [],
  csp: [],
  pageview: NoPageview,
)
`);
for (const face of ["public", "admin"]) {
  fs.mkdirSync(path.join(app, face, "node_modules/.bin"), { recursive: true });
  fs.symlinkSync(path.join(root, "node_modules/.bin/esbuild"), path.join(app, face, "node_modules/.bin/esbuild"));
  fs.symlinkSync(path.join(root, "node_modules/esbuild"), path.join(app, face, "node_modules/esbuild"));
  const toml = path.join(app, face, "gleam.toml");
  fs.writeFileSync(toml, fs.readFileSync(toml, "utf8").replace('path = "../../../.."', `path = ${JSON.stringify(root)}`));
}
const runner = path.join(work, "gen-run.mjs");
fs.writeFileSync(runner, `import { main } from ${JSON.stringify(pathToFileURL(path.join(root, "build/dev/javascript/yumemi/yumemi/gen.mjs")).href)};\nmain();\n`);
const genStatus = run(process.execPath, [runner, app, app], root, "gen.txt");
const genLog = fs.readFileSync(path.join(work, "gen.txt"), "utf8");
check("generator: the face with a gate and no Live generates with stop code 0", genStatus === 0 && genLog.includes("停止コード: 0"), genLog.slice(-400));
const buildStatus = run("gleam", ["build", "--target", "javascript"], path.join(app, "public"), "build.txt");
check("face: the generated Gleam (loader with block_<name>) compiles", buildStatus === 0, fs.readFileSync(path.join(work, "build.txt"), "utf8").slice(-600));
if (buildStatus !== 0) {
  console.log(out.join("\n"));
  process.exit(0);
}

const built = path.join(app, "public/build/dev/javascript/public");
const gateFile = path.join(built, "gen/gate.mjs");
const gateText = fs.readFileSync(gateFile, "utf8");
check("gate: the face without Live skips the counting mark for x-yumemi-block", gateText.includes("if (request.headers.has(blockHeader) || !tracksPageview(context)"));
// 数える頁の印:門は pageview を宣言しないので、build の写しの表に `/article/:slug` を入れて見る
fs.writeFileSync(gateFile, gateText.replace("const pageviewRoutes = [];", 'const pageviewRoutes = ["/article/:slug"];'));
const shellText = fs.readFileSync(path.join(built, "gen/shell.mjs"), "utf8");
check("shell: no Live machinery (no tokens, no <yumemi-live>)", !shellText.includes("withLiveToken") && !shellText.includes("x-yumemi-live") && !shellText.includes("lives:"));

const shell = (await import(pathToFileURL(path.join(built, "gen/shell.mjs")).href)).default;

// ── 偽の APP ──────────────────────────────────────────────────────────────────
const article = {
  article: { slug: "42", title: "本日の記事", body: "本文", version: 1, order: 0, category: "news", tags: { keys: ["fixture"] } },
  category: { name: "news" },
  tags: [{ name: "fixture" }],
  theme: null,
};
let mode = { read: 200, signedIn: true };
let requests = [];
const APP = {
  async fetch(request) {
    const url = new URL(request.url);
    requests.push(url.pathname);
    const session = mode.signedIn ? { anonymous: false, subject: { id: "u1", handle: "hana", kind: "member" } } : { anonymous: true };
    if (url.pathname === "/api/session" || url.pathname === "/fixture/session") return Response.json(session);
    if (url.pathname.startsWith("/api/articles/")) {
      if (mode.read !== 200) return new Response("{}", { status: mode.read });
      return new Response(JSON.stringify(article), { headers: { "content-type": "application/json", "x-yumemi-live": "tok.en1" } });
    }
    if (url.pathname === "/api/widgets") return Response.json({ rows: [] });
    return new Response("{}", { status: 404 });
  },
};
const env = { APP, PUBLIC_PUBLIC_ORIGIN: "https://www.example", PUBLIC_IDP_ORIGIN: "https://id.example" };
async function get(pathname, headers = {}) {
  requests = [];
  const response = await shell.fetch(new Request("https://www.example" + pathname, { headers }), env, { waitUntil() {} });
  return { status: response.status, headers: response.headers, text: await response.text(), requests: [...requests] };
}
const reads = (item) => item.requests.filter((p) => p.startsWith("/api/"));

const page = await get("/article/42?term=x");
check("page: 200, the Blocks are not wrapped and the counting mark is on the page", page.status === 200 && !page.text.includes("<yumemi-block") && !page.text.includes("<yumemi-live") && page.text.includes('<meta name="yumemi-pageview">'), page.text.slice(0, 200));

const summary = await get("/article/42?term=x", { "x-yumemi-block": "summary" });
check("fragment (Fixed): 200, only <style> and <yumemi-block name> (no html, head, Layout, token)", summary.status === 200 && summary.text.startsWith("<style>") && summary.text.includes('<yumemi-block name="summary">') && summary.text.trimEnd().endsWith("</yumemi-block>") && !summary.text.includes("<html") && !summary.text.includes("<head") && !summary.text.includes('data-yumemi-area="header"') && !summary.text.includes("token="), summary.text.slice(0, 300));
const inner = (text) => text.slice(text.indexOf(">", text.indexOf("<yumemi-block")) + 1, text.lastIndexOf("</yumemi-block>"));
check("fragment (Fixed): the Block's HTML is the same as in the page", inner(summary.text).length > 0 && page.text.includes(inner(summary.text)), inner(summary.text).slice(0, 200));
check("fragment (Fixed): the <style> carries the Block's class rules", /<style>[^<]*\.[a-z0-9_-]+\s*\{/i.test(summary.text));
check("fragment (Fixed): the gate's session read once, then the Block's Service only (no Layout widget)", JSON.stringify(summary.requests) === '["/fixture/session","/api/articles/42"]', JSON.stringify(summary.requests));
check("fragment (Fixed): no-store, vary x-yumemi-block, no counting mark", summary.headers.get("cache-control") === "no-store" && summary.headers.get("vary") === "x-yumemi-block" && !summary.text.includes("yumemi-pageview"));

const notice = await get("/article/42", { "x-yumemi-block": "notice" });
check("fragment (In = Nil): 200 with the Vars only, and the root is still read for the gate's meaning", notice.status === 200 && notice.text.includes('<yumemi-block name="notice">') && notice.text.includes("Current article: 42") && JSON.stringify(reads(notice)) === '["/api/articles/42"]', `${notice.status} ${JSON.stringify(notice.requests)} ${notice.text.slice(0, 200)}`);
const articleBlock = await get("/article/42", { "x-yumemi-block": "article" });
check("fragment (Fixed): the page's root Block answers too", articleBlock.status === 200 && articleBlock.text.includes('<yumemi-block name="article">'), String(articleBlock.status));

const refused = [];
for (const name of ["site_header", "feed", "row_article", "row_summary", "nothing", ""]) {
  const item = await get("/article/42", { "x-yumemi-block": name });
  refused.push({ name, status: item.status, reads: reads(item) });
}
check("fragment: Layout Blocks, Widget Blocks and names not on the page are 404 without touching a read", refused.every((item) => item.status === 404 && item.reads.length === 0), JSON.stringify(refused));

mode = { read: 200, signedIn: false };
const gated = await get("/article/42", { "x-yumemi-block": "summary" });
check("gate: an anonymous fragment request gets the gate's 302 and no read", gated.status === 302 && (gated.headers.get("location") ?? "").includes("/auth/sign-in") && reads(gated).length === 0, `${gated.status} ${gated.headers.get("location")} ${JSON.stringify(gated.requests)}`);
mode = { read: 404, signedIn: true };
const gone = await get("/article/42", { "x-yumemi-block": "notice" });
check("fragment: the root read 404 gives 404 (also for a Block that reads nothing itself)", gone.status === 404, String(gone.status));
mode = { read: 403, signedIn: true };
const denied = await get("/article/42", { "x-yumemi-block": "summary" });
check("fragment: the root read 403 gives 403", denied.status === 403, String(denied.status));
mode = { read: 200, signedIn: true };

// 別の頁(/status)は自分の Block だけに答える
const status = await get("/status", { "x-yumemi-block": "summary" });
check("fragment: another page does not answer for Blocks it does not place", status.status === 404, String(status.status));

// client.mjs:逃げ道に yumemi.block を渡し、`<yumemi-block>` を定める。札・socket の runtime は無い
const client = fs.readFileSync(path.join(app, "public/priv/static/_yumemi/client.mjs"), "utf8");
check("client.mjs (bundled): defines yumemi-block and passes yumemi.block to escapes, without the Live runtime", client.includes('customElements.define("yumemi-block"') && client.includes("yumemi: { block") && !client.includes('customElements.define("yumemi-live"') && !client.includes("WebSocket"));

console.log(out.join("\n"));
process.exit(0);
