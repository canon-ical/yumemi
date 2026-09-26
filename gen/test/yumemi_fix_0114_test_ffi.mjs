import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

// 子の node で ES module を走らせ、標準出力を返す(gleeunit の test は同期なので、非同期の検査は子に閉じる)
function node(code) {
  const result = spawnSync(process.execPath, ["--input-type=module", "-e", code], {
    cwd: process.cwd(),
    encoding: "utf8",
    timeout: 60000,
  });
  return `${result.stdout}${result.stderr ? `\nSTDERR ${result.stderr}` : ""}`.trim();
}

const retry = JSON.stringify(path.resolve("../src/framework/server/read_retry.mjs"));

/// H10:読みの判定と、timeout → 再試行 → 成功、2 回とも落ちた時の log、SQLSTATE の失敗はやり直さない。
export function driver_read_retry() {
  return node(`
import { readOnly, readWithRetry } from ${retry};
const out = [];
const check = (name, ok) => out.push((ok ? "ok " : "NG ") + name);
check("select", readOnly("-- GENERATED\\nSELECT id FROM app.page_view WHERE id=$1::uuid LIMIT 1;"));
check("with select", readOnly("WITH a AS (SELECT 1) SELECT * FROM a"));
check("literal update", readOnly("SELECT 'update' AS x, \\"delete\\" FROM t"));
check("updated_at", readOnly("SELECT updated_at FROM t"));
check("cte update", !readOnly("WITH x AS (UPDATE t SET a=1 RETURNING *) SELECT * FROM x"));
check("insert", !readOnly("INSERT INTO t VALUES (1)"));
check("for update", !readOnly("SELECT * FROM t FOR UPDATE"));
check("app function", !readOnly("SELECT * FROM framework.insert_links_guarded($1::jsonb);"));
check("nextval", !readOnly("SELECT nextval('s')"));
check("two statements", !readOnly("SELECT 1; SELECT 2;"));
const lines = [];
const log = line => lines.push(JSON.parse(line));
// 1 回目は止まる(signal で切られる)、2 回目は返る
let calls = 0;
const stall = signal => new Promise((resolve, reject) => { signal.addEventListener("abort", () => reject(signal.reason)); });
const rows = await readWithRetry(signal => (++calls === 1 ? stall(signal) : Promise.resolve([{ id: 1 }])), { key: "k/read", timeoutMs: 50, log });
check("timeout then retry", calls === 2 && rows[0].id === 1 && lines.length === 1 && lines[0].body === "timeout" && lines[0].attempt === 1 && lines[0].key === "k/read");
// 2 回とも落ちる:2 行の log(本文つき)、2 回目の失敗を投げる
lines.length = 0; calls = 0;
let thrown = null;
try {
  await readWithRetry(() => { calls++; const e = new Error("Server error (HTTP status 503): upstream stalled " + calls); return Promise.reject(e); }, { key: "k/read", timeoutMs: 50, log });
} catch (error) { thrown = error; }
check("both fail", calls === 2 && thrown?.message.endsWith("stalled 2") && lines.length === 2 && lines[1].attempt === 2 && lines[0].body.includes("upstream stalled 1"));
// SQLSTATE の失敗はやり直さず、log にも出さない
lines.length = 0; calls = 0; thrown = null;
try {
  await readWithRetry(() => { calls++; return Promise.reject(Object.assign(new Error("dup"), { code: "23505" })); }, { key: "k/read", timeoutMs: 50, log });
} catch (error) { thrown = error; }
check("sqlstate once", calls === 1 && thrown?.code === "23505" && lines.length === 0);
console.log(out.join("\\n"));
`);
}

// H8 ── 生成の client が島を包む `styled` を、node で島の view に当てる(ブラウザでだけ出ていた panic を node で捕まえる)
import { styled } from "../yumemi/framework/front/island_style.mjs";
import { class$, color } from "../sketch/sketch/css.mjs";
import { element as sketchElement, element_ as plainElement } from "../sketch_lustre/sketch/lustre/element.mjs";
import { node as sketchNode, render as sketchRender, setup as sketchSetup } from "../sketch_lustre/sketch/lustre.mjs";
import { text, to_string } from "../lustre/lustre/element.mjs";
import { toList } from "../prelude.mjs";

function classedView(model) {
  return sketchElement("a", class$(toList([color("red")])), toList([]), toList([text(model)]));
}
function plainView(model) {
  return plainElement("a", toList([]), toList([text(model)]));
}

/// 包まない view は panic し、包んだ view は class の CSS を `<style>` に出す。class の無い島は DOM を変えない。
export function island_stylesheet() {
  const out = [];
  const check = (name, ok) => out.push((ok ? "ok " : "NG ") + name);
  let panicked = "";
  try { classedView("x"); } catch (error) { panicked = String(error?.message ?? error); }
  check("bare view panics", panicked.includes("Stylesheet is not initialized"));
  const app = { init: () => null, update: (m) => m, view: classedView, config: {} };
  let html = "";
  try { html = to_string(styled(app).view("claim-url")); } catch (error) { html = "THROW " + String(error?.message ?? error); }
  check("styled renders", html.includes("claim-url") && !html.startsWith("THROW"));
  check("style has class css", /<style>[^<]*color:\s*red/.test(html));
  const cls = html.match(/<a class="([^"]+)"/)?.[1] ?? "";
  check("class in style", cls !== "" && html.includes("." + cls.split(" ")[0]));
  // 2 回目の描画も同じ(stylesheet は島ごとに持ち続ける)
  let again = "";
  try { again = to_string(styled(app).view("claim-url")); } catch (error) { again = "THROW"; }
  check("second island renders", again === html);
  const plain = { ...app, view: plainView };
  check("plain unchanged", to_string(styled(plain).view("p")) === to_string(plainView("p")));
  // 自分で stylesheet を持って render する島(www の島の形)は、包んでも同じ DOM(`<style>` を二重にしない)
  const own = sketchSetup()[0];
  const ownView = (model) => sketchRender(own, toList([sketchNode()]), () => classedView(model));
  const ownHtml = to_string(ownView("own"));
  check("own render unchanged", to_string(styled({ ...app, view: ownView }).view("own")) === ownHtml && (ownHtml.match(/<style>/g) ?? []).length === 1);
  // 描き終えたら current を戻す(島の外の描画に stylesheet を漏らさない)
  let after = "";
  try { classedView("y"); } catch (error) { after = String(error?.message ?? error); }
  check("current dismissed", after.includes("Stylesheet is not initialized"));
  return out.join("\n");
}

// H9 ── navigate.mjs の純な判定(click の取り方・route の当て方・差し替えてよい文書)
import { counted, hashTarget, intercept, matches, pageviewPayload, swappable } from "../yumemi/framework/front/navigate.mjs";

function anchor(href, attrs = {}) {
  return { tagName: "A", getAttribute: (name) => (name === "href" ? href : attrs[name] ?? null), hasAttribute: (name) => name === "href" || name in attrs };
}
function click(node, extra = {}) {
  return { defaultPrevented: false, button: 0, metaKey: false, ctrlKey: false, shiftKey: false, altKey: false, composedPath: () => [{ tagName: "SPAN" }, node], ...extra };
}
function fakeDoc({ scripts, head = true, given = [], mark = false }) {
  const headEl = { tag: "head", querySelector: (q) => (mark && q === 'meta[name="yumemi-pageview"]' ? {} : null) };
  const els = scripts.map((s) => ({ getAttribute: (n) => s[n] ?? null, parentElement: s.inHead === false ? {} : headEl }));
  return {
    head: headEl,
    body: { querySelectorAll: () => given.map((tag) => ({ localName: tag })) },
    querySelectorAll: () => els,
  };
}

export function navigation_rules() {
  const out = [];
  const check = (name, ok) => out.push((ok ? "ok " : "NG ") + name);
  const routes = ["/muse/:handle/reserve", "/muse/:handle/reserve/course", "/me"];
  const here = new URL("https://www.example/muse/aoi/reserve");
  check("route param", matches("/muse/:handle/reserve", "/muse/aoi/reserve"));
  check("route empty param", !matches("/muse/:handle/reserve", "/muse//reserve"));
  check("route hyphen", matches("/for_stores/api", "/for-stores/api"));
  check("routed link", intercept(click(anchor("/muse/aoi/reserve/course?slot=1")), routes, here)?.href === "https://www.example/muse/aoi/reserve/course?slot=1");
  check("unrouted link", intercept(click(anchor("/search")), routes, here) === null);
  check("modifier", intercept(click(anchor("/me"), { metaKey: true }), routes, here) === null);
  check("middle button", intercept(click(anchor("/me"), { button: 1 }), routes, here) === null);
  check("other origin", intercept(click(anchor("https://evil.example/me")), routes, here) === null);
  check("target blank", intercept(click(anchor("/me", { target: "_blank" })), routes, here) === null);
  check("prevented", intercept(click(anchor("/me"), { defaultPrevented: true }), routes, here) === null);
  check("from unrouted page", intercept(click(anchor("/me")), routes, new URL("https://www.example/search")) === null);
  const client = { src: "/_yumemi/client.mjs", type: "module" };
  check("swappable", swappable(fakeDoc({ scripts: [client] }), () => false));
  check("inline script falls back", !swappable(fakeDoc({ scripts: [client, {}] }), () => false));
  check("given island defined falls back", !swappable(fakeDoc({ scripts: [client], given: ["reserve-time"] }), (tag) => tag === "reserve-time"));
  // r2(柏木 P1-7):download 付きの a は頁の読み込み
  check("download", intercept(click(anchor("/me", { download: "" })), routes, here) === null);
  // r2(柏木 P1-4):壊れた百分率の # は投げずに null(島の登録と yumemi-navigated を飛ばさない)
  check("broken hash", hashTarget(new URL("https://www.example/me#%E0%A4%A"), () => { throw new Error("unreached"); }) === null);
  check("hash", hashTarget(new URL("https://www.example/me#a%20b"), (id) => id) === "a b");
  // r2:数える印は門が client 遷移の fetch に差す meta だけ
  check("counted mark", counted(fakeDoc({ scripts: [client], mark: true })) && !counted(fakeDoc({ scripts: [client] })));
  const spa = pageviewPayload({ url: new URL("https://www.example/muse/aoi?r=ig_1"), kind: "spa", from: "/search", previous: null, sourceParam: "r", id: "i", at: "t" });
  check("payload spa", JSON.stringify(spa) === '{"id":"i","client_at":"t","kind":"spa","path":"/muse/aoi","referrer_path":"/search","source_key":"ig_1"}');
  const chained = pageviewPayload({ url: new URL("https://www.example/muse/aoi?r=BAD!"), kind: "reload", from: "/search", previous: "p", sourceParam: "r", id: "i", at: "t" });
  check("payload reload chained", JSON.stringify(chained) === '{"id":"i","client_at":"t","kind":"reload","path":"/muse/aoi","prev":"p"}');
  return out.join("\n");
}

// H10 r2(柏木 P1-1)── 書きを読みに数える形は 0、musearch の形の読みは読みのまま
export function read_classification() {
  return node(`
import { readOnly } from ${retry};
const writes = {
  "unqualified user fn": "SELECT do_write($1)",
  "set-returning user fn in FROM": "SELECT * FROM bump_counter($1)",
  "SELECT INTO": "SELECT * INTO app.snapshot FROM app.muse",
  "literal -- hides CTE UPDATE": "WITH a AS (SELECT '--' AS x), b AS (UPDATE app.muse SET phase='x' RETURNING id) SELECT * FROM b",
  "E-string hides CTE UPDATE": "WITH a AS (SELECT E'\\\\'' AS x), b AS (UPDATE t SET y=1 RETURNING *) SELECT * FROM b",
  "comment quote hides UPDATE": "WITH a AS (SELECT 1 /* ' */), b AS (UPDATE t SET y=1 RETURNING *) SELECT * FROM b",
  "quoted schema call": 'SELECT * FROM "framework"."insert_x"($1)',
  "quoted fn": 'SELECT "do_write"($1)',
  "schema call": "SELECT * FROM framework.insert_links_guarded($1)",
  "FOR NO KEY UPDATE": "SELECT * FROM t FOR NO KEY UPDATE",
  "FOR SHARE": "SELECT * FROM t FOR SHARE",
  "advisory lock": "SELECT pg_try_advisory_lock(1)",
  "nextval": "SELECT nextval('s')",
  "two statements": "SELECT 1; DELETE FROM t",
};
const reads = {
  "plain": "SELECT id, name FROM app.muse WHERE handle = $1",
  "jsonb": "SELECT to_jsonb(m) FROM jsonb_array_elements_text($1::jsonb) WITH ORDINALITY AS keys(value,ord) JOIN app.muse m ON m.id = keys.value::uuid",
  "aggregate": "WITH x AS MATERIALIZED (SELECT count(*) FILTER (WHERE a) AS n FROM t) SELECT coalesce(max(n), 0) FROM x",
  "percentile": "SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY ms) FROM generate_series(1, 3) AS g(ms)",
  "literal words": "SELECT 'update; insert into' AS x, $$delete$$ AS y -- drop table\\n FROM t",
  "cast": "SELECT $1::numeric(10,2), CAST($2 AS varchar(20))",
  "vector": "SELECT id FROM app.article c ORDER BY c.embedding OPERATOR(public.<=>) $1::public.vector LIMIT 5",
};
for (const [name, sql] of Object.entries(writes)) console.log((readOnly(sql) ? "NG write read as read " : "ok write ") + name);
for (const [name, sql] of Object.entries(reads)) console.log((readOnly(sql) ? "ok read " : "NG read counted as write ") + name);
`);
}

// r2 ── 門の after_response:client 遷移の fetch(x-yumemi-navigate: 1)には script でなく meta を head に差す
export function gate_marks_navigation_fetch(text) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "yumemi-gate-"));
  fs.writeFileSync(path.join(dir, "gate.mjs"), text);
  fs.writeFileSync(path.join(dir, "route.mjs"), 'export const routes = [{path: "/search"}, {path: "/muse/:handle"}, {path: "/me"}];\n');
  const out = node(`
import { serve } from ${JSON.stringify(path.join(dir, "gate.mjs"))};
const html = "<!doctype html><html><head><title>t</title></head><body><main>x</main></body></html>";
const env = (adult) => ({ APP: { fetch: async () => new Response(JSON.stringify({ adult, anonymous: false, subject: null }), { status: 200 }) } });
const app = serve(async () => new Response(html, { status: 200, headers: { "content-type": "text/html; charset=utf-8" } }));
const get = async (p, adult, nav) => {
  const r = await app.fetch(new Request("https://www.example" + p, { headers: nav ? { "x-yumemi-navigate": "1" } : {} }), env(adult));
  return { body: await r.text(), vary: r.headers.get("vary") ?? "" };
};
const check = (name, ok) => console.log((ok ? "ok " : "NG ") + name);
const load = await get("/search", true, false);
check("load gets script", load.body.includes("<script>") && !load.body.includes("<meta name="));
const nav = await get("/search", true, true);
check("navigate gets mark in head", nav.body.includes('<meta name="yumemi-pageview"></head>') && !nav.body.includes("<script>"));
check("vary", nav.vary.includes("x-yumemi-navigate") && load.vary.includes("x-yumemi-navigate"));
const minor = await get("/search", false, true);
check("no adult no mark", !minor.body.includes("yumemi-pageview") && !minor.body.includes("<script>"));
const other = await get("/me", true, true);
check("not counted page no mark", !other.body.includes("yumemi-pageview"));
`);
  fs.rmSync(dir, { recursive: true, force: true });
  return out;
}
