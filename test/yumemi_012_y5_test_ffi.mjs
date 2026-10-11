// yumemi-012-y5 ── runtime(`yumemi/server/http.mjs`)と送り手(`yumemi/front/pageview.mjs`)を node で起こす。
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

// 申告(2 種)・同意(3 種)・session の読み・期間の切れた申告・要件と役の 403 の本文・数える口の受け口
export function runtime_checks() {
  return node(`
import { http } from ${built("server/http.mjs")};
import { Declared, Consented, ConsentedFor } from ${built("require.mjs")};
const snake = (name) => name.replace(/([a-z0-9])([A-Z])/g, "$1_$2").toLowerCase();
const tag = (v) => v?.__tag ?? snake(v.constructor.name);
const list = (items) => items;
const t = (name) => ({ __tag: name });
class Ok { constructor(v) { this[0] = v; } }
class Err { constructor(v) { this[0] = v; } }
class Fail {}
class Accepted {}
const runs = [];
const anyone = [{ who: t("anyone"), at: t("any_phase"), owner: t("no_owner") }];
const service = (name, requires, args = []) => ({
  name, method: "GET", path: "/api/" + name,
  module: { effect: t("read"), service: { allow: anyone }, requires: list(requires), Args: class { constructor(...v) { this.values = v; } } },
  args,
});
const invoked = [];
const registry = [
  { name: "pv_record", method: "POST", path: "/api/pv_record",
    module: { effect: t("write"), service: { allow: [{ who: t("anyone"), at: t("any_phase"), owner: t("no_owner") }] }, requires: [],
      Args: class { constructor(...v) { this.values = v; } } } },
  service("adult_only", [new Declared("adult")]),
  service("terms_only", [new Consented("terms")]),
  service("handling_only", [new Consented("handling")]),
  service("identity_x", [new ConsentedFor("identity", () => "x")]),
  service("identity_y", [new ConsentedFor("identity", () => "y")]),
];
const attached = [
  { name: "declare_adult", method: "POST", path: "/api/declare/adult", who: "anyone" },
  { name: "declare_region", method: "POST", path: "/api/declare/region", who: "anyone" },
  { name: "session", method: "GET", path: "/api/session", who: "anyone" },
  { name: "media", method: "GET", path: "/api/media/:key", who: "anyone" },
];
const sessions = {
  party: { party: "p1", subject_kind: null, subjects: [], suspended: false,
    consents: [{ kind: "use" }, { kind: "handling" }, { kind: "identity", subject: "x" }] },
};
const h = http({
  Ok, Error: Err, registry, attached,
  c: { tag, encode: (x) => x, toList: (x) => x, text: (x) => String(x), scalar: {}, parse: (_k, v) => v,
    None: class { constructor() { this.none = true; } }, Some: class { constructor(v) { this[0] = v; } } },
  runtime: {
    resolveSession: async (_db, cookie) => sessions[cookie] ?? null,
    invoke: async (s) => { invoked.push({ name: s.record.name, args: s.args, browser: s.browser?.id ?? null, clauses: s.clauses }); return [{ ok: true }]; },
    run: async (_db, key, params) => { runs.push([key, params]); return []; },
    step: { Fail, Accepted },
  },
  entryCredential: () => t("session"),
  hosts: { www: "WWW_HOST", plain: "PLAIN_HOST", svc: "SVC_HOST" },
  args: { pv_record: [["id", ["text"]], ["kind", ["text"]], ["client_at", ["text"]], ["path", ["text"]], ["prev", ["option", ["text"]]], ["source_key", ["option", ["text"]]]] },
  modules: {}, phaseGates: {}, accepted: {},
  ports: { media: async (s, { response }) => response(s, { served: true }) },
  hooks: {}, subjects: [],
  roles: { declare_adult: ["declare:adult"], declare_region: ["declare:region"], session: ["read_session"], media: ["needs_declared:adult"] },
  browserCookie: { cookie: "_fx", binding: "KEY", maxAgeDays: 400, declarations: [
    { kind: "adult", claim: "adult_declared_at", maxAgeDays: 395 },
    { kind: "region", claim: "region_declared_at", maxAgeDays: 30 },
  ] },
  pageviews: { www: { only: [{ type: "declared", kind: "adult" }],
    fields: [{ type: "kind" }, { type: "client_at" }, { type: "path" }, { type: "previous" }, { type: "referrer" }, { type: "query", name: "source_key", max: 16 }],
    sink: { type: "store", resolve: null, rollupBy: [], excludeWhen: [] } },
    svc: { only: [{ type: "declared", kind: "adult" }], fields: [{ type: "kind" }, { type: "client_at" }, { type: "path" }, { type: "previous" }, { type: "query", name: "source_key", max: 16 }],
    sink: { type: "service", service: "pv_record" } },
    plain: { only: [], fields: [{ type: "kind" }, { type: "client_at" }, { type: "path" }],
    sink: { type: "store", resolve: null, rollupBy: [], excludeWhen: [] } } },
  subjectFree: [], apiKeyPattern: "[0-9a-f]{64}",
});
const entries = [
  { name: "www", hosts: [t("www")], prefix: "/api", admit: t("anonymous"), subject: t("any_subject"), services: t("all") },
  { name: "svc", hosts: [t("svc")], prefix: "/s", admit: t("anonymous"), subject: t("any_subject"), services: t("all") },
  { name: "plain", hosts: [t("plain")], prefix: "/p", admit: t("anonymous"), subject: t("any_subject"), services: t("all") },
];
const env = { WWW_HOST: "www.example", PLAIN_HOST: "plain.example", SVC_HOST: "svc.example", COOKIE_DOMAIN: "example", KEY: { get: async () => "secret" } };
async function call(method, p, { cookie, body, headers = {}, at, host = "www.example" } = {}) {
  const request = new Request("https://" + host + p, { method, body,
    headers: { origin: "https://" + host, ...(cookie ? { cookie } : {}), ...headers } });
  let r = await h.host({ request, env, db: {}, at }, entries);
  for (const stage of [h.route, h.origin, h.browser, h.admit, h.resolve, h.subject, h.decode, h.judge]) {
    if (!(r instanceof Ok)) break;
    r = await stage(r[0]);
  }
  const response = r instanceof Ok ? await h.execute(r[0]) : r[0];
  const text = await response.text();
  let json = null;
  try { json = JSON.parse(text); } catch {}
  return { status: response.status, json, cookies: response.headers.getSetCookie() };
}
const check = (name, ok, detail) => console.log((ok ? "ok " : "NG ") + name + (ok ? "" : " " + JSON.stringify(detail)));
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const fx = (cookies) => cookies.find((c) => c.startsWith("_fx="))?.split(";")[0];

let r = await call("GET", "/api/adult_only");
check("declaration_missing", r.status === 403 && same(r.json, { code: "declaration_missing", declaration: "adult" }), r);
r = await call("GET", "/api/terms_only", { cookie: "session=party" });
check("consent_missing", r.status === 403 && same(r.json, { code: "consent_missing", consent: "terms" }), r);
r = await call("GET", "/api/handling_only", { cookie: "session=party" });
check("declared consent kind passes", r.status === 200, r);
r = await call("GET", "/api/identity_x", { cookie: "session=party" });
check("consented_for matches subject", r.status === 200, r);
r = await call("GET", "/api/identity_y", { cookie: "session=party" });
check("consented_for other subject", r.status === 403 && same(r.json, { code: "consent_missing", consent: "identity" }), r);

const declared = await call("POST", "/api/declare/adult", { body: "{}", headers: { "content-type": "application/json" } });
const adultCookie = fx(declared.cookies);
check("declare adult", declared.status === 200 && same(declared.json, { declared: { adult: true } }) && !!adultCookie
  && runs.at(-1)[0] === "framework/browser" && runs.at(-1)[1][2] === "adult", declared);
r = await call("GET", "/api/adult_only", { cookie: adultCookie });
check("declared passes requires", r.status === 200, r);
const both = await call("POST", "/api/declare/region", { cookie: adultCookie, body: "{}", headers: { "content-type": "application/json" } });
const bothCookie = fx(both.cookies);
check("declare region keeps adult and the mark", same(both.json, { declared: { adult: true, region: true } })
  && runs.at(-1)[1][0] === runs.at(-2)[1][0], both);
r = await call("GET", "/api/session", { cookie: bothCookie + "; session=party" });
check("session reads declarations and all consents", same(r.json?.declared, { adult: true, region: true })
  && same(r.json?.consents, { use: true, handling: true, identity: true }) && !("adult" in r.json), r);
r = await call("GET", "/api/session", { cookie: bothCookie });
check("anonymous session reads declarations", same(r.json, { anonymous: true, declared: { adult: true, region: true } }), r);

// 期間の切れた申告は「申告なし」(cookie と印は有効)
const old = new Date(Date.now() - 396 * 86400000).toISOString();
const stale = "_fx=" + await h.signBrowser(env, "a".repeat(32), { adult_declared_at: old, region_declared_at: new Date().toISOString() });
r = await call("GET", "/api/session", { cookie: stale });
check("expired declaration reads as none", same(r.json, { anonymous: true, declared: { region: true } }), r);
// 0.11 の形の cookie(payload {id, adult_declared_at})を種類 adult の申告として読む
const legacy = "_fx=" + await h.signBrowser(env, "b".repeat(32), { adult_declared_at: new Date().toISOString() });
r = await call("GET", "/api/media/x.webp", { cookie: legacy });
check("legacy payload reads as adult, needs_declared passes", r.status === 200 && same(r.json, { served: true }), r);
r = await call("GET", "/api/media/x.webp");
check("needs_declared without declaration", r.status === 403 && same(r.json, { code: "declaration_missing", declaration: "adult" }), r);

// 数える口の受け口:常に 202、数える条件・bot・先読みは行を作らない
const event = (extra = {}) => JSON.stringify({ id: crypto.randomUUID(), kind: "initial", client_at: new Date().toISOString(), path: "/article/a", source_key: "ig_1", unknown: "x", ...extra });
const before = runs.length;
r = await call("POST", "/api/_yumemi/pageviews", { cookie: adultCookie, body: event(), headers: { "content-type": "application/json" } });
const row = runs.at(-1);
check("pageview recorded with declared fields only", r.status === 202 && runs.length === before + 1 && row[0] === "framework/pageview_record"
  && row[1][4] === "initial" && row[1][5] === "/article/a" && row[1][11] === JSON.stringify({ source_key: "ig_1" }), { r, row });
r = await call("POST", "/api/_yumemi/pageviews", { body: event(), headers: { "content-type": "application/json" } });
check("no declaration no row no mark", r.status === 202 && runs.length === before + 1 && !fx(r.cookies), r);
for (const headers of [{ "user-agent": "Googlebot/2.1" }, { "sec-purpose": "prefetch;prerender" }]) {
  r = await call("POST", "/api/_yumemi/pageviews", { cookie: adultCookie, body: event(), headers: { "content-type": "application/json", ...headers } });
}
r = await call("POST", "/api/_yumemi/pageviews", { cookie: adultCookie, body: event({ kind: "bogus" }), headers: { "content-type": "application/json" } });
check("bot prefetch and malformed make no row", r.status === 202 && runs.length === before + 1, r);
// 数える条件の無い口:印の無い browser の最初の event で印だけの cookie を焼き、後の申告は同じ印に足される
r = await call("POST", "/p/_yumemi/pageviews", { host: "plain.example", body: event(), headers: { "content-type": "application/json" } });
const markCookie = r.cookies.find((c) => c.startsWith("_fx="));
const markId = runs.at(-1)[1][1];
check("mark-only cookie on the first counted event", r.status === 202 && (markCookie ?? "").endsWith("; Path=/; Domain=example; HttpOnly; Secure; SameSite=Lax; Max-Age=34560000")
  && /^[0-9a-f]{32}$/.test(markId) && runs.at(-1)[1][2] === "plain", { r, markCookie });
const later = await call("POST", "/api/declare/adult", { cookie: fx([markCookie]), body: "{}", headers: { "content-type": "application/json" } });
// ToService:入口の検査を通した event を app の Service に渡す。Args は欄から組み、印は s.browser で root に運ぶ
const sent = JSON.parse(event());
r = await call("POST", "/s/_yumemi/pageviews", { host: "svc.example", cookie: adultCookie, body: JSON.stringify(sent), headers: { "content-type": "application/json" } });
const got = invoked.at(-1);
check("to_service invokes the Service with Args from the fields", r.status === 202 && got?.name === "pv_record"
  && got.args.values[0] === sent.id && got.args.values[1] === "initial" && got.args.values[3] === "/article/a"
  && got.args.values[4].none === true && got.args.values[5][0] === "ig_1"
  && /^[0-9a-f]{32}$/.test(got.browser) && got.clauses.length === 1, got);
const calls = invoked.length;
r = await call("POST", "/s/_yumemi/pageviews", { host: "svc.example", body: event(), headers: { "content-type": "application/json", "user-agent": "Googlebot" } });
check("to_service skips bots and undeclared", r.status === 202 && invoked.length === calls, r);
check("declaration adds to the same mark", runs.at(-1)[1][0] === markId && same(later.json, { declared: { adult: true } }), later);
`);
}

// 送り手:偽の window で、頁の読み込みで 1 回・reload・prerender・client の遷移(navigatesuccess)・fragment
export function sender_checks() {
  return node(`
const sent = [];
const listeners = {};
let marked = true;
function setup({ type = "navigate", prerendering = false, href = "https://www.example/article/a?r=ig_1" } = {}) {
  sent.length = 0;
  const store = new Map();
  const navigation = new EventTarget();
  globalThis.window = globalThis;
  globalThis.navigation = navigation;
  globalThis.location = new URL(href);
  globalThis.sessionStorage = { getItem: (k) => store.get(k) ?? null, setItem: (k, v) => store.set(k, v), removeItem: (k) => store.delete(k) };
  globalThis.performance = { getEntriesByType: () => [{ type }] };
  globalThis.requestIdleCallback = (run) => run();
  globalThis.fetch = async (url, init) => { sent.push({ url, body: JSON.parse(init.body) }); return new Response(null, { status: 202 }); };
  const docListeners = {};
  globalThis.document = {
    readyState: "complete", referrer: "https://search.example/q", prerendering,
    head: { querySelector: (q) => (marked && q === 'meta[name="yumemi-pageview"]' ? {} : null) },
    querySelector: () => null,
    addEventListener: (name, fn) => { docListeners[name] = fn; },
  };
  return { navigation, docListeners };
}
const { start, pageviewPayload } = await import(${built("front/pageview.mjs")});
const config = { endpoint: "/api/_yumemi/pageviews", key: "yumemi:pageview:www",
  fields: [{ type: "kind" }, { type: "client_at" }, { type: "path" }, { type: "previous" }, { type: "referrer" }, { type: "query", name: "source_key", param: "r", max: 16 }] };
const check = (name, ok, detail) => console.log((ok ? "ok " : "NG ") + name + (ok ? "" : " " + JSON.stringify(detail)));
const settle = () => new Promise((resolve) => setTimeout(resolve, 0));

let { navigation, docListeners } = setup();
start(config);
await settle();
const first = sent[0]?.body;
check("initial once", sent.length === 1 && sent[0].url === config.endpoint && first.kind === "initial" && first.path === "/article/a"
  && first.source_key === "ig_1" && first.referrer_host === "search.example" && /^[0-9a-f-]{36}$/.test(first.id), sent);
check("only declared fields", Object.keys(first).sort().join() === "client_at,id,kind,path,referrer_host,source_key", first);

// client の遷移:navigate の種類を覚え、navigatesuccess で今の document の印を見て 1 回
location.href = "https://www.example/article/b";
navigation.dispatchEvent(Object.assign(new Event("navigate"), { navigationType: "push", hashChange: false, downloadRequest: null }));
globalThis.location = new URL("https://www.example/article/b");
navigation.dispatchEvent(new Event("navigatesuccess"));
await settle();
check("spa once with prev", sent.length === 2 && sent[1].body.kind === "spa" && sent[1].body.path === "/article/b"
  && sent[1].body.prev === first.id && !("referrer_path" in sent[1].body), sent);
navigation.dispatchEvent(Object.assign(new Event("navigate"), { navigationType: "push", hashChange: true, downloadRequest: null }));
navigation.dispatchEvent(new Event("navigatesuccess"));
await settle();
check("fragment not counted", sent.length === 2, sent);
navigation.dispatchEvent(Object.assign(new Event("navigate"), { navigationType: "reload", hashChange: false, downloadRequest: null }));
navigation.dispatchEvent(new Event("navigatesuccess"));
await settle();
check("navigation reload", sent.length === 3 && sent[2].body.kind === "reload", sent);
marked = false;
navigation.dispatchEvent(Object.assign(new Event("navigate"), { navigationType: "traverse", hashChange: false, downloadRequest: null }));
navigation.dispatchEvent(new Event("navigatesuccess"));
await settle();
check("no mark after navigation not counted", sent.length === 3, sent);
marked = true;

({ navigation } = setup({ type: "reload" }));
start(config);
await settle();
check("page reload", sent.length === 1 && sent[0].body.kind === "reload", sent);

({ navigation, docListeners } = setup({ prerendering: true }));
start(config);
await settle();
const waited = sent.length === 0;
docListeners.prerenderingchange?.();
await settle();
check("prerender waits for activation", waited && sent.length === 1 && sent[0].body.kind === "initial", sent);
`);
}

// framework・runtime・生成器・README に adult の綴りが残っていないか(fixture と test の app の値は除く)。
// 段 B の Y4 の持ち場(`yumemi/front/navigate.mjs` と README の「Client navigation」の節)は Y4 が書き換えるので見ない
export function adult_spellings() {
  const hits = [];
  const walk = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (/\.(gleam|mjs)$/.test(entry.name) && entry.name !== "navigate.mjs") scan(full);
    }
  };
  const scan = (file) => {
    let y4 = false;
    fs.readFileSync(file, "utf8").split("\n").forEach((line, i) => {
      if (file.endsWith(".md") && line.startsWith("## ")) y4 = line.includes("Client navigation");
      if (!y4 && /adult/i.test(line)) hits.push(`${file}:${i + 1}: ${line.trim()}`);
    });
  };
  walk("src");
  scan("README.md");
  return hits.join("\n");
}

// 門(fixture cms の生成 `gate.mjs`):宣言した任意の同意・申告・条件つきの redirect・CSP・印・失敗の文言
export function gate_checks() {
  const dir = fs.mkdtempSync(path.join(process.env.TMPDIR ?? "/tmp", "yumemi-y5-gate-"));
  fs.copyFileSync("gen/fixtures/cms/public/src/gen/gate.mjs", path.join(dir, "gate.mjs"));
  fs.writeFileSync(path.join(dir, "route.mjs"), 'export const routes = [{path: "/article/:slug"}, {path: "/status"}];\n');
  const out = node(`
import { serve } from ${JSON.stringify(path.join(dir, "gate.mjs"))};
const html = "<!doctype html><html><head><title>t</title></head><body>x</body></html>";
const app = serve(async () => new Response(html, { status: 200, headers: { "content-type": "text/html; charset=utf-8" } }));
const env = (session, status = 200) => ({ APP: { fetch: async () => new Response(JSON.stringify(session), { status }) } });
const get = async (p, session, status) => {
  const r = await app.fetch(new Request("https://www.example" + p), env(session, status));
  return { status: r.status, body: await r.text(), location: r.headers.get("location"), csp: r.headers.get("content-security-policy") };
};
const check = (name, ok, detail) => console.log((ok ? "ok " : "NG ") + name + (ok ? "" : " " + JSON.stringify(detail)));
let r = await get("/article/a", { anonymous: false, consents: { use: true }, declared: { adult: true } });
check("declared consent passes, csp, mark", r.status === 200 && r.csp === "frame-src https://frames.example https://*.video.example; img-src https://img.example"
  && r.body.includes('<meta name="yumemi-pageview"></head>') && !r.body.includes("<script"), r);
r = await get("/article/a", { anonymous: false, consents: { handling: true }, declared: {} });
check("missing consent fails", r.status === 302 && r.location.startsWith("https://auth.example/auth/sign-in?redirect_uri="), r);
r = await get("/status", { anonymous: true, declared: {} });
check("missing declaration redirects back", r.status === 302 && r.location === "/?next=%2Fstatus", r);
r = await get("/status", { anonymous: true, declared: { adult: true } });
check("declared passes, other csp, mark", r.status === 200 && r.csp === "connect-src https://api.example; media-src https://media.example"
  && r.body.includes("yumemi-pageview"), r);
r = await get("/status?returnTo=%2Farticle%2Fb", { anonymous: true, declared: { adult: true, region: true } });
check("WhenDeclared redirect", r.status === 302 && r.location === "/article/b", r);
r = await get("/status", null, 404);
check("read 404 is not found", r.status === 404 && r.body === "not found", r);
r = await get("/status", null, 500);
check("read failure is forbidden", r.status === 403 && r.body === "forbidden", r);
`);
  fs.rmSync(dir, { recursive: true, force: true });
  return out;
}
