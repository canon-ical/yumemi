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
import { intercept, matches, swappable } from "../yumemi/framework/front/navigate.mjs";

function anchor(href, attrs = {}) {
  return { tagName: "A", getAttribute: (name) => (name === "href" ? href : attrs[name] ?? null), hasAttribute: (name) => name === "href" || name in attrs };
}
function click(node, extra = {}) {
  return { defaultPrevented: false, button: 0, metaKey: false, ctrlKey: false, shiftKey: false, altKey: false, composedPath: () => [{ tagName: "SPAN" }, node], ...extra };
}
function fakeDoc({ scripts, head = true, given = [] }) {
  const headEl = { tag: "head" };
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
  return out.join("\n");
}
