import path from "node:path";
import { spawnSync } from "node:child_process";
// 0.11.15 ── navigate.mjs の CSP の判定(route 表の Page ごとの CSP、今の document の CSP、応答の header)
import { common, intercept, policy, routed, samePolicy, table } from "../yumemi/framework/front/navigate.mjs";

function anchor(href) {
  return { tagName: "A", getAttribute: (name) => (name === "href" ? href : null), hasAttribute: (name) => name === "href" };
}
function click(node) {
  return { defaultPrevented: false, button: 0, metaKey: false, ctrlKey: false, shiftKey: false, altKey: false, composedPath: () => [node] };
}
const headers = (csp) => new Headers(csp === null ? { "content-type": "text/html" } : { "content-type": "text/html", "content-security-policy": csp });

export function navigation_csp() {
  const out = [];
  const check = (name, ok) => out.push((ok ? "ok " : "NG ") + name);
  const frame = "frame-src https://blogparts.cityheaven.net https://challenges.cloudflare.com";
  const mixed = ["/search", { route: "/", csp: frame }, { route: "/muse/:handle", csp: frame }, "/muse/:handle/article"];
  // 生成の `routes` と `csp` から表を組む(`csp` に無い route は CSP 無し)
  const built = table(["/search", "/", "/muse/:handle"], { "/": frame, "/muse/:handle": frame });
  check("table", JSON.stringify(built) === JSON.stringify([{ route: "/search", csp: null }, { route: "/", csp: frame }, { route: "/muse/:handle", csp: frame }]) && table(["/a"])[0].csp === null);
  check("policy plain", policy(mixed, "/search") === null);
  check("policy csp", policy(mixed, "/muse/aoi") === frame);
  check("policy miss", policy(mixed, "/nowhere") === undefined && !routed(mixed, "/nowhere"));
  check("policy disagree", policy(["/muse/:handle", { route: "/muse/:handle", csp: frame }], "/muse/aoi") === undefined);
  const top = new URL("https://www.example/");
  const search = new URL("https://www.example/search");
  // 一致:CSP を持つ頁の間は取る。不一致:CSP の在る無しをまたぐ click は読み込み
  check("same csp taken", intercept(click(anchor("/muse/aoi")), mixed, top)?.pathname === "/muse/aoi");
  check("csp to plain falls back", intercept(click(anchor("/muse/aoi/article")), mixed, top) === null);
  check("plain to csp falls back", intercept(click(anchor("/")), mixed, search) === null);
  check("plain to plain taken", intercept(click(anchor("/muse/aoi/article")), mixed, search)?.pathname === "/muse/aoi/article");
  // 今の document を読み込んだ Page の CSP が表の今の頁と違えば取らない
  check("loaded differs falls back", intercept(click(anchor("/muse/aoi")), mixed, top, null) === null);
  const other = "frame-src https://other.example";
  check("different csp falls back", intercept(click(anchor("/b")), [{ route: "/a", csp: frame }, { route: "/b", csp: other }], new URL("https://www.example/a")) === null);
  // 応答の header:表と同じ値だけ。食い違い・在るはずが無い・無いはずが在るは読み込み
  check("header same", samePolicy(headers(frame), frame));
  check("header none both", samePolicy(headers(null), null));
  check("header differs", !samePolicy(headers(other), frame));
  check("header missing", !samePolicy(headers(null), frame));
  check("header unexpected", !samePolicy(headers(frame), null));
  // head の差分:残す組は順を保って最も多く
  check("common", JSON.stringify(common(["a", "x", "b"], ["a", "n", "b", "m"])) === JSON.stringify([0, -1, 2, -1]));
  check("common reorder", JSON.stringify(common(["a", "b"], ["b", "a"])).split("-1").length === 2);
  return out.join("\n");
}

/// head の差分の足し引きと body の側の stylesheet の待ち(非同期なので子の node で走らせる)。
export function navigation_stage() {
  const result = spawnSync(process.execPath, [path.resolve("test/yumemi_01115_stage_check.mjs")], { encoding: "utf8", timeout: 60000 });
  return `${result.stdout}${result.stderr ? `\nSTDERR ${result.stderr}` : ""}`.trim();
}
