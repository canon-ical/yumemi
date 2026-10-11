// yumemi-012-y6 ── 門の読みの失敗(fixture cms の生成 `gate.mjs`)と数える口の受け口(`yumemi/server/http.mjs`)を node で起こす。
// console.error は捕まえて数える(STDERR に出さない)。
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

function node(code) {
  const result = spawnSync(process.execPath, ["--input-type=module", "-e", code], {
    cwd: process.cwd(),
    encoding: "utf8",
    timeout: 60000,
  });
  return `${result.stdout}${result.stderr ? `\nSTDERR ${result.stderr}` : ""}`.trim();
}

const built = (file) => JSON.stringify(path.resolve("build/dev/javascript/yumemi/yumemi", file));

const capture = `
const logged = [];
console.error = (...args) => logged.push(args.map((a) => a instanceof Error ? "Error: " + a.message : String(a)).join(" "));
const check = (name, ok, detail) => console.log((ok ? "ok " : "NG ") + name + (ok ? "" : " " + JSON.stringify(detail)));
`;

// 読みの 404 は not found、権限の拒否は 403 forbidden、読みの 5xx・APP binding の例外・session の path が無いときは
// 503 unavailable と console.error(元の status と原因)。CSP の各指令に 'self' が 1 つ
export function gate_checks() {
  const dir = fs.mkdtempSync(path.join(process.env.TMPDIR ?? "/tmp", "yumemi-y6-gate-"));
  const source = fs.readFileSync("gen/fixtures/cms/public/src/gen/gate.mjs", "utf8");
  fs.writeFileSync(path.join(dir, "gate.mjs"), source);
  fs.writeFileSync(path.join(dir, "pathless.mjs"), source.replace(/const sessionPath = "[^"]*";/, "const sessionPath = null;"));
  fs.writeFileSync(path.join(dir, "route.mjs"), 'export const routes = [{path: "/article/:slug"}, {path: "/status"}];\n');
  const out = node(`
import { serve } from ${JSON.stringify(path.join(dir, "gate.mjs"))};
import { serve as servePathless } from ${JSON.stringify(path.join(dir, "pathless.mjs"))};
${capture}
const html = "<!doctype html><html><head><title>t</title></head><body>x</body></html>";
const dispatch = async () => new Response(html, { status: 200, headers: { "content-type": "text/html; charset=utf-8" } });
const app = serve(dispatch), pathless = servePathless(dispatch);
const env = (fetch) => ({ APP: { fetch } });
const reply = (session, status = 200) => async () => new Response(JSON.stringify(session), { status });
const get = async (p, fetch, worker = app) => {
  const before = logged.length;
  const r = await worker.fetch(new Request("https://www.example" + p), env(fetch));
  return { status: r.status, body: await r.text(), csp: r.headers.get("content-security-policy"), logged: logged.slice(before) };
};
let r = await get("/status", reply(null, 404));
check("read 404 is not found", r.status === 404 && r.body === "not found" && r.logged.length === 0, r);
r = await get("/status", reply(null, 401));
check("read 401 on a declared rule is forbidden", r.status === 403 && r.body === "forbidden" && r.logged.length === 0, r);
r = await get("/status", reply({ error: "boom" }, 500));
check("read 500 is unavailable with the status logged", r.status === 503 && r.body === "unavailable"
  && r.logged.length === 1 && r.logged[0].includes("session read error 500") && r.logged[0].includes("session read returned 500"), r);
r = await get("/article/a", reply(null, 502));
check("read 502 is unavailable", r.status === 503 && r.body === "unavailable" && r.logged.length === 1 && r.logged[0].includes(" 502 "), r);
r = await get("/status", async () => { throw new Error("binding exploded"); });
check("APP binding exception is unavailable with the cause", r.status === 503 && r.body === "unavailable"
  && r.logged.length === 1 && r.logged[0].includes(" 502 ") && r.logged[0].includes("binding exploded"), r);
r = await get("/status", reply({ anonymous: true, declared: {} }), pathless);
check("missing session path is unavailable", r.status === 503 && r.body === "unavailable"
  && r.logged.length === 1 && r.logged[0].includes("session path is missing"), r);
r = await get("/article/a", reply({ anonymous: false, consents: { use: true }, declared: { adult: true } }));
check("article csp has 'self' on each directive", r.status === 200
  && r.csp === "frame-src 'self' https://frames.example https://*.video.example; img-src 'self' https://img.example", r);
r = await get("/status", reply({ anonymous: true, declared: { adult: true } }));
check("status csp has 'self' on each directive", r.status === 200
  && r.csp === "connect-src 'self' https://api.example; media-src 'self' https://media.example", r);
`);
  fs.rmSync(dir, { recursive: true, force: true });
  return out;
}

// 受け口:ToService は Service の requires を評価し、印の cookie は Carried の browser を持つ Service に届く event だけ。
// 想定外の失敗(SQL・Service の例外)は 202 と console.error、bot・先読み・形の外れは黙って 202。Args の Color
export function receiver_checks() {
  return node(`
import { http } from ${built("server/http.mjs")};
import { Consented, Declared } from ${built("require.mjs")};
import { Ok as GleamOk } from ${built("../gleam.mjs")};
${capture}
const snake = (name) => name.replace(/([a-z0-9])([A-Z])/g, "$1_$2").toLowerCase();
const tag = (v) => v?.__tag ?? snake(v.constructor.name);
const t = (name) => ({ __tag: name });
class Ok { constructor(v) { this[0] = v; } }
class Err { constructor(v) { this[0] = v; } }
class Fail {}
class Accepted {}
const anyone = [{ who: t("anyone"), at: t("any_phase"), owner: t("no_owner") }];
const partyOnly = [{ who: t("party"), at: t("any_phase"), owner: t("no_owner") }];
const service = (name, { method = "POST", allow = anyone, requires = [], effect = "write" } = {}) => ({
  name, method, path: "/api/" + name,
  module: { effect: t(effect), service: { allow }, requires, Args: class { constructor(...v) { this.values = v; } } },
});
const registry = [
  service("pv_consent", { requires: [new Consented("analytics")] }),
  service("pv_declared", { requires: [new Declared("adult")] }),
  service("pv_plain"),
  service("pv_carry"),
  service("pv_party", { allow: partyOnly }),
  service("pv_throw"),
  service("paint", { method: "GET", effect: "read" }),
];
const invoked = [];
let storeFails = false;
const pvArgs = [["id", ["text"]], ["kind", ["text"]], ["path", ["text"]]];
const h = http({
  Ok, Error: Err, registry, attached: [],
  c: { tag, encode: (x) => x, toList: (x) => x, text: (x) => String(x), scalar: {}, parse: (_k, v) => v,
    checked: (result, field = "value") => { if (!(result instanceof GleamOk)) throw Object.assign(new Error("invalid_argument"), { status: 400, field }); return result[0]; },
    None: class { constructor() { this.none = true; } }, Some: class { constructor(v) { this[0] = v; } } },
  runtime: {
    resolveSession: async (_db, cookie) => cookie === "party" ? { party: "p1", subject_kind: null, subjects: [], suspended: false, consents: [{ kind: "analytics" }] }
      : cookie === "bare" ? { party: "p2", subject_kind: null, subjects: [], suspended: false, consents: [] } : null,
    invoke: async (s) => {
      if (s.record.name === "pv_throw") throw new Error("service exploded");
      invoked.push({ name: s.record.name, args: s.args, browser: s.browser?.id ?? null });
      return [{ ok: true }];
    },
    run: async () => { if (storeFails) throw Object.assign(new Error("relation does not exist"), { code: "42P01" }); return []; },
    step: { Fail, Accepted },
  },
  entryCredential: () => t("session"),
  hosts: { a: "A_HOST", b: "B_HOST", c: "C_HOST", d: "D_HOST", e: "E_HOST", f: "F_HOST", g: "G_HOST" },
  args: { pv_consent: pvArgs, pv_declared: pvArgs, pv_plain: pvArgs, pv_carry: pvArgs, pv_party: pvArgs, pv_throw: pvArgs, paint: [["accent", ["color"]]] },
  modules: {}, phaseGates: {}, accepted: {}, ports: {}, hooks: {}, subjects: [], roles: {},
  browserCookie: { cookie: "_fx", binding: "KEY", maxAgeDays: 400, declarations: [{ kind: "adult", claim: "adult_declared_at", maxAgeDays: 395 }] },
  pageviews: Object.fromEntries([
    ["a", { type: "service", service: "pv_consent", browser: true }],
    ["b", { type: "service", service: "pv_plain", browser: false }],
    ["c", { type: "service", service: "pv_carry", browser: true }],
    ["d", { type: "service", service: "pv_party", browser: true }],
    ["e", { type: "store", resolve: null, rollupBy: [], excludeWhen: [] }],
    ["f", { type: "service", service: "pv_throw", browser: false }],
    ["g", { type: "service", service: "pv_declared", browser: true }],
  ].map(([name, sink]) => [name, { only: [], fields: [{ type: "kind" }, { type: "path" }], sink }])),
  subjectFree: [], apiKeyPattern: "[0-9a-f]{64}",
});
const entries = ["a", "b", "c", "d", "e", "f", "g"].map((name) =>
  ({ name, hosts: [t(name)], prefix: "/api", admit: t("anonymous"), subject: t("any_subject"), services: t("all") }));
const env = { COOKIE_DOMAIN: "example", KEY: { get: async () => "secret" },
  ...Object.fromEntries(["a", "b", "c", "d", "e", "f", "g"].map((n) => [n.toUpperCase() + "_HOST", n + ".example"])) };
async function call(method, host, p, { cookie, body, headers = {} } = {}) {
  const request = new Request("https://" + host + ".example" + p, { method, body,
    headers: { origin: "https://" + host + ".example", ...(cookie ? { cookie } : {}), ...(body ? { "content-type": "application/json" } : {}), ...headers } });
  let r = await h.host({ request, env, db: {} }, entries);
  for (const stage of [h.route, h.origin, h.browser, h.admit, h.resolve, h.subject, h.decode, h.judge]) {
    if (!(r instanceof Ok)) break;
    r = await stage(r[0]);
  }
  const before = logged.length;
  const response = r instanceof Ok ? await h.execute(r[0]) : r[0];
  const text = await response.text();
  let json = null;
  try { json = JSON.parse(text); } catch {}
  return { status: response.status, json, cookies: response.headers.getSetCookie(), logged: logged.slice(before) };
}
const event = (extra = {}) => JSON.stringify({ id: crypto.randomUUID(), kind: "initial", path: "/article/a", ...extra });
const fx = (cookies) => cookies.some((c) => c.startsWith("_fx="));
const pv = (host, opts = {}) => call("POST", host, "/api/_yumemi/pageviews", { body: event(opts.extra), ...opts });

let n = invoked.length;
let r = await pv("a", { cookie: "session=bare" });
check("requires unmet: not delivered, no mark", r.status === 202 && invoked.length === n && !fx(r.cookies) && r.logged.length === 0, r);
r = await pv("a");
check("requires unmet anonymously: not delivered, no mark", r.status === 202 && invoked.length === n && !fx(r.cookies), r);
r = await pv("a", { cookie: "session=party" });
check("requires met: delivered with a mark", r.status === 202 && invoked.length === n + 1 && invoked.at(-1).name === "pv_consent"
  && fx(r.cookies) && /^[0-9a-f]{32}$/.test(invoked.at(-1).browser), r);
n = invoked.length;
r = await pv("g");
check("declared requirement unmet: not delivered, no mark", r.status === 202 && invoked.length === n && !fx(r.cookies), r);
r = await pv("b");
check("service without the browser carried: delivered, no mark", r.status === 202 && invoked.length === n + 1
  && invoked.at(-1).name === "pv_plain" && !fx(r.cookies) && invoked.at(-1).browser === null, r);
n = invoked.length;
r = await pv("c");
check("service carrying the browser: delivered with a mark", r.status === 202 && invoked.length === n + 1
  && fx(r.cookies) && /^[0-9a-f]{32}$/.test(invoked.at(-1).browser), r);
n = invoked.length;
r = await pv("d");
check("outside the allow clauses: not delivered, no mark", r.status === 202 && invoked.length === n && !fx(r.cookies), r);
storeFails = true;
r = await pv("e");
check("store SQL failure: 202 and logged", r.status === 202 && r.logged.length === 1 && r.logged[0].includes("relation does not exist"), r);
r = await pv("e", { headers: { "user-agent": "Googlebot/2.1" } });
const bot = r;
r = await pv("e", { headers: { "sec-purpose": "prefetch;prerender" } });
const pre = r;
r = await pv("e", { extra: { kind: "bogus" } });
check("bot, prefetch and malformed are silent", bot.status === 202 && pre.status === 202 && r.status === 202
  && bot.logged.length + pre.logged.length + r.logged.length === 0, { bot, pre, r });
storeFails = false;
r = await pv("f");
check("service exception: 202 and logged", r.status === 202 && r.logged.length === 1 && r.logged[0].includes("service exploded"), r);
r = await pv("a", { cookie: "session=party", extra: { kind: 1 } });
check("event outside the shape is silent", r.status === 202 && r.logged.length === 0, r);
r = await call("GET", "b", "/api/paint?accent=%23AABBCC");
check("Args Color decodes", r.status === 200 && invoked.at(-1).name === "paint" && invoked.at(-1).args.values[0].value === "#aabbcc", { r, got: invoked.at(-1) });
n = invoked.length;
r = await call("GET", "b", "/api/paint?accent=red");
check("broken Color is invalid_argument", r.status === 400 && r.json?.code === "invalid_argument" && r.json?.field === "accent" && invoked.length === n, r);
`);
}
