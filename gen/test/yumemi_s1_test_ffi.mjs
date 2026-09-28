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

// 0.11.5 ── 門の RedirectBack(戻り先付きで面の中へ)と FixedKeep(query を保つ)
export function gate_redirect_back(text) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "yumemi-gate-s1-"));
  fs.writeFileSync(path.join(dir, "gate.mjs"), text);
  fs.writeFileSync(path.join(dir, "route.mjs"),
    'export const routes = [{path: "/"}, {path: "/about/external"}, {path: "/me"}, {path: "/me/chats"}, {path: "/search"}, {path: "/:handle/:page"}];\n');
  const out = node(`
import { serve } from ${JSON.stringify(path.join(dir, "gate.mjs"))};
const sessions = {
  anonymous: { anonymous: true, adult: false, subject: null },
  minor: { anonymous: false, adult: false, subject: null },
  adult: { anonymous: false, adult: true, subject: null },
};
const env = (who) => ({ APP: { fetch: async () => new Response(JSON.stringify(sessions[who]), { status: 200 }) } });
const app = serve(async () => new Response("<!doctype html><html><head></head><body>x</body></html>", { status: 200, headers: { "content-type": "text/html" } }));
const get = async (url, who, nav) => {
  const r = await app.fetch(new Request(url, { headers: nav ? { "x-yumemi-navigate": "1" } : {} }), env(who));
  return { status: r.status, location: r.headers.get("location") };
};
const check = (name, ok, got) => console.log((ok ? "ok " : "NG ") + name + (ok ? "" : " " + JSON.stringify(got)));
const www = "https://www.example";

let r = await get(www + "/me/chats?tab=a b&x=1", "anonymous", false);
check("inside face with encoded path+search", r.status === 302 && r.location === "/?returnTo=" + encodeURIComponent("/me/chats?tab=a%20b&x=1"), r);
r = await get(www + "/me", "anonymous", false);
check("no query", r.status === 302 && r.location === "/?returnTo=%2Fme", r);
r = await get(www + "/me/chats?q=1", "minor", false);
check("location with query joins by &", r.status === 302 && r.location === "/about/external?kind=adult&next=%2Fme%2Fchats%3Fq%3D1", r);
r = await get(www + "/me/chats?tab=a", "anonymous", true);
check("client navigation fetch gets the same 302", r.status === 302 && r.location === "/?returnTo=%2Fme%2Fchats%3Ftab%3Da", r);
// 面の外:path が // で始まる要求(https://www.example//evil.example)は戻り先にしない(open redirect にしない)
r = await get(www + "//evil.example", "anonymous", false);
check("outside face drops param", r.status === 302 && r.location === "/", r);
r = await get(www + "/me", "adult", false);
check("passes when signed-in adult", r.status === 200, r);
r = await get(www + "/search?x=1&y=%2F#frag", "adult", false);
check("FixedKeep keeps query", r.status === 302 && r.location === "/me/chats?x=1&y=%2F", r);
r = await get(www + "/search", "adult", true);
check("FixedKeep without query", r.status === 302 && r.location === "/me/chats", r);
r = await get(www + "/about/external?x=1", "adult", false);
check("Fixed drops query (unchanged)", r.status === 302 && r.location === "/search", r);
r = await get(www + "/search?x=1", "anonymous", false);
check("FixedKeep only when signed-in", r.status === 200, r);
`);
  fs.rmSync(dir, { recursive: true, force: true });
  return out;
}

// 0.11.5 ── fixture の写し(root.sql を抜く・入口を足す)
export function copy_app(from) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "yumemi-s1-app-"));
  const skip = (source) => !/[\\/](build|node_modules)$/.test(source);
  const dir = path.join(root, path.basename(from));
  fs.cpSync(from, dir, { recursive: true, filter: skip });
  // fixture は隣の docs/(静的資料)を読む
  const docs = path.join(path.dirname(from), "docs");
  if (fs.existsSync(docs)) fs.cpSync(docs, path.join(root, "docs"), { recursive: true, filter: skip });
  return dir;
}

export function remove_app(dir) {
  fs.rmSync(path.dirname(dir), { recursive: true, force: true });
}

export function remove(dir, file) {
  fs.rmSync(path.join(dir, file));
}

export function edit(dir, file, from, to) {
  const target = path.join(dir, file);
  const text = fs.readFileSync(target, "utf8");
  if (!text.includes(from)) return false;
  fs.writeFileSync(target, text.replace(from, to));
  return true;
}

// 0.11.5 ── 検査 7 の entries(framework/server/http.mjs の subject)
export function entries_check() {
  const http = JSON.stringify(path.resolve("build/dev/javascript/yumemi/framework/server/http.mjs"));
  return node(`
import { http } from ${http};
class Ok { constructor(value) { this[0] = value; } }
class Er { constructor(value) { this[0] = value; } }
const c = { tag: (value) => value };
const h = http({ c, registry: [], attached: [], Ok, Error: Er, hosts: {}, runtime: {}, roles: {} });
const run = async (record, entry) => {
  const out = await h.subject({ trace: [], setCookies: [], env: {}, record, entry: { name: entry, subject: "any_subject" }, resolved: null });
  return out instanceof Ok ? 200 : out[0].status;
};
const check = (name, ok, got) => console.log((ok ? "ok " : "NG ") + name + (ok ? "" : " " + got));
let got = await run({ name: "course_add", module: {}, entries: ["console", "admin"] }, "www");
check("outside entries is 403", got === 403, got);
got = await run({ name: "course_add", module: {}, entries: ["console", "admin"] }, "admin");
check("inside entries passes", got === 200, got);
got = await run({ name: "course_add", module: {}, entries: ["console", "admin"] }, "console");
check("other inside entry passes", got === 200, got);
got = await run({ name: "feed", module: {} }, "www");
check("every face passes", got === 200, got);
got = await run({ name: "only", module: {}, entry: "admin" }, "www");
check("one face entry is 403 outside", got === 403, got);
got = await run({ name: "only", module: {}, entry: "admin" }, "admin");
check("one face entry passes inside", got === 200, got);
`);
}
