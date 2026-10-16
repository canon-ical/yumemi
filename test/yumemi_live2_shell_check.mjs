// yumemi-live-2(0.14)── 生成した面の shell の断片の口を node で叩く。article の fixture の写しの頁の
// `Fixed(.., blocks.Article, ..)` を `Live(.., cell: Span(..), edge: Bottom)` に替え、生成器を走らせ(compile 済みの
// `build/dev/javascript/yumemi/yumemi/gen.mjs`)、面を `gleam build` し、生成の `shell.mjs` を偽の APP で叩く。
// 1 行 1 件の ok / NG。写しは `build/live2-fx`(git の外)。
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { pathToFileURL } from "node:url";

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const work = path.join(root, "build", "live2-fx");
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
const pageFile = path.join(app, "public/src/pages/article/arg_slug/page.gleam");
const pageText = fs.readFileSync(pageFile, "utf8");
fs.writeFileSync(pageFile, pageText
  .replace('Fixed(area: "page", block: blocks.Article, cell: Flow)', 'Live(area: "page", block: blocks.Article, cell: Span(cols: 2, rows: 1), edge: Bottom)')
  .replace("SubjectHandle, Var, Widget,", "SubjectHandle, Var, Widget, Live, Bottom, Span,"));
for (const face of ["public", "admin"]) {
  fs.mkdirSync(path.join(app, face, "node_modules/.bin"), { recursive: true });
  fs.symlinkSync(path.join(root, "node_modules/.bin/esbuild"), path.join(app, face, "node_modules/.bin/esbuild"));
  fs.symlinkSync(path.join(root, "node_modules/esbuild"), path.join(app, face, "node_modules/esbuild"));
}
// 面の gleam.toml の yumemi の path(`../../../..`)を作業木の root に
for (const face of ["public", "admin"]) {
  const toml = path.join(app, face, "gleam.toml");
  fs.writeFileSync(toml, fs.readFileSync(toml, "utf8").replace('path = "../../../.."', `path = ${JSON.stringify(root)}`));
}
const runner = path.join(work, "gen-run.mjs");
fs.writeFileSync(runner, `import { main } from ${JSON.stringify(pathToFileURL(path.join(root, "build/dev/javascript/yumemi/yumemi/gen.mjs")).href)};\nmain();\n`);
const genStatus = run(process.execPath, [runner, app, app], root, "gen.txt");
const genLog = fs.readFileSync(path.join(work, "gen.txt"), "utf8");
check("generator: the Live page generates with stop code 0", genStatus === 0 && genLog.includes("停止コード: 0"), genLog.slice(-400));
check("generator: the warning names the missing el.fresh", genLog.includes("Live(block: Article) は edge: Bottom で、Block に el.fresh が無い"));
const buildStatus = run("gleam", ["build", "--target", "javascript"], path.join(app, "public"), "build.txt");
check("face: the generated Gleam (loader with live_article) compiles", buildStatus === 0, fs.readFileSync(path.join(work, "build.txt"), "utf8").slice(-600));
if (buildStatus !== 0) {
  console.log(out.join("\n"));
  process.exit(0);
}

// 数える頁の印:fixture の門は pageview を宣言しないので、build の写しの表に `/article/:slug` を入れて見る
const built = path.join(app, "public/build/dev/javascript/public");
const gateFile = path.join(built, "gen/gate.mjs");
const gateText = fs.readFileSync(gateFile, "utf8");
check("gate: the face with Live skips the counting mark for x-yumemi-block", gateText.includes("if (request.headers.has(blockHeader) || !tracksPageview(context)"));
fs.writeFileSync(gateFile, gateText.replace("const pageviewRoutes = [];", 'const pageviewRoutes = ["/article/:slug"];'));

const shell = (await import(pathToFileURL(path.join(built, "gen/shell.mjs")).href)).default;

// ── 偽の APP ──────────────────────────────────────────────────────────────────
const article = {
  article: { slug: "42", title: "本日の記事", body: "本文", version: 1, order: 0, category: "news", tags: { keys: ["fixture"] } },
  category: { name: "news" },
  tags: [{ name: "fixture" }],
  theme: null,
};
let mode = { read: 200, token: "tok.en1" };
let requests = [];
const APP = {
  async fetch(request) {
    const url = new URL(request.url);
    requests.push(url.pathname);
    if (url.pathname === "/api/session") return Response.json({ anonymous: true });
    if (url.pathname.startsWith("/api/articles/")) {
      if (mode.read !== 200) return new Response("{}", { status: mode.read });
      const headers = { "content-type": "application/json" };
      if (mode.token) headers["x-yumemi-live"] = mode.token;
      return new Response(JSON.stringify(article), { headers });
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

const page = await get("/article/42?widget=summary");
check("page: 200 with the Block wrapped in <yumemi-live name edge token>", page.status === 200 && page.text.includes('<yumemi-live token="tok.en1" edge="bottom" name="article">'), page.text.slice(0, 300));
check("page: display: contents for yumemi-live and the hidden el.fresh rule", page.text.includes("yumemi-live { display: contents; }") && page.text.includes("[data-yumemi-fresh][hidden] { display: none !important; }"));
check("page: the counting mark is on the page", page.text.includes('<meta name="yumemi-pageview">'));
check("page: the page reads the Layout's widget and the root", page.requests.some((p) => p.startsWith("/api/widgets")) && page.requests.some((p) => p.startsWith("/api/articles/")), JSON.stringify(page.requests));

const frag = await get("/article/42?widget=summary", { "x-yumemi-block": "article" });
check("fragment: 200, only <style> and <yumemi-live> (no html, head, Layout)", frag.status === 200 && frag.text.startsWith("<style>") && frag.text.includes('<yumemi-live token="tok.en1" edge="bottom" name="article">') && !frag.text.includes("<html") && !frag.text.includes("<head") && !frag.text.includes('data-yumemi-area="header"') && frag.text.trimEnd().endsWith("</yumemi-live>"), frag.text.slice(0, 200));
check("fragment: the <style> carries the Block's class rules", /<style>[^<]*\.[a-z0-9_-]+\s*\{/i.test(frag.text));
check("fragment: reads the session (the Vars) and the Block's Service only (no Layout widget)", JSON.stringify(frag.requests) === '["/api/session","/api/articles/42"]', JSON.stringify(frag.requests));
check("fragment: no-store, vary x-yumemi-block, no counting mark", frag.headers.get("cache-control") === "no-store" && frag.headers.get("vary") === "x-yumemi-block" && !frag.text.includes("yumemi-pageview"));
const inner = (text) => text.slice(text.indexOf("<yumemi-live"), text.lastIndexOf("</yumemi-live>"));
check("fragment: the Block's HTML is the same as in the page", inner(page.text).length > 0 && inner(page.text) === inner(frag.text), `${inner(page.text).length} / ${inner(frag.text).length}`);
// r2(柏木 P2-1):`Span` の cell の包みが頁と断片の両方にある
const cellWrap = '<div style="grid-column: span 2; grid-row: span 1;">';
check("fragment: the Span cell's wrapper is in both the page and the fragment", inner(page.text).includes(cellWrap) && inner(frag.text).includes(cellWrap), inner(frag.text).slice(0, 200));

const unknown = await get("/article/42", { "x-yumemi-block": "summary" });
check("fragment: a Block that is not Live on the page is 404", unknown.status === 404, String(unknown.status));
mode = { read: 404, token: "tok.en1" };
const gone = await get("/article/42", { "x-yumemi-block": "article" });
check("fragment: the root read 404 gives 404 (the client reloads the page)", gone.status === 404, String(gone.status));
mode = { read: 403, token: "tok.en1" };
const denied = await get("/article/42", { "x-yumemi-block": "article" });
check("fragment: the root read 403 gives 403", denied.status === 403, String(denied.status));
mode = { read: 200, token: null };
const bare = await get("/article/42", { "x-yumemi-block": "article" });
const barePage = await get("/article/42");
check("no token: without x-yumemi-live the Block has no token (the client opens no socket)", bare.status === 200 && bare.text.includes('<yumemi-live edge="bottom" name="article">') && barePage.text.includes('<yumemi-live edge="bottom" name="article">'));
mode = { read: 200, token: 'a"b<c' };
const odd = await get("/article/42", { "x-yumemi-block": "article" });
check("token: the attribute value is escaped", odd.text.includes('token="a&quot;b&lt;c"'));

// client.mjs:Live の runtime を起こし、逃げ道に yumemi.block を渡す
const client = fs.readFileSync(path.join(app, "public/priv/static/_yumemi/client.mjs"), "utf8");
check("client.mjs (bundled): defines yumemi-live, starts it with the socket path and passes yumemi.block to escapes", client.includes('customElements.define("yumemi-live"') && /start\w*\(\{ socket: "\/api\/_yumemi\/live", reload(: \w+)? \}\)/.test(client) && client.includes("yumemi: { block"));
// admin の面(Live 無し)は今のまま
const adminShell = fs.readFileSync(path.join(app, "admin/src/gen/shell.mjs"), "utf8");
const fixtureAdmin = fs.readFileSync(path.join(root, "gen/fixtures/article/admin/src/gen/shell.mjs"), "utf8");
check("faces without Live: the admin shell is byte-identical to the committed fixture", adminShell === fixtureAdmin);
const adminGate = fs.readFileSync(path.join(app, "admin/src/gen/gate.mjs"), "utf8");
check("faces without Live: the admin gate is byte-identical to the committed fixture", adminGate === fs.readFileSync(path.join(root, "gen/fixtures/article/admin/src/gen/gate.mjs"), "utf8"));

console.log(out.join("\n"));
process.exit(0);
