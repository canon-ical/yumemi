// 0.12 段 C(Y3 r2、柏木 ゲート 2 の P1)── runtime(interactive.mjs)と送り手(pageview.mjs)を偽の DOM で回す。
// `yumemi_012_y3_test_ffi.mjs` が子の node で走らせ(globals を汚さない)、1 行 1 件の ok / NG を出す。
const out = [];
const check = (name, ok, detail) => out.push((ok ? "ok " : "NG ") + name + (ok ? "" : " " + JSON.stringify(detail)));
const settle = () => new Promise((resolve) => setTimeout(resolve, 0));

const store = new Map();
globalThis.window = globalThis;
globalThis.sessionStorage = { getItem: (k) => store.get(k) ?? null, setItem: (k, v) => store.set(k, v), removeItem: (k) => store.delete(k) };
globalThis.location = new URL("https://www.example/feed?widget=a");
let reply = { ok: true, value: {} };
const sent = [];
globalThis.fetch = async (url, init) => {
  sent.push({ url, method: init?.method, body: init?.body });
  return { ok: reply.ok, json: async () => reply.value };
};
const defined = {};
globalThis.customElements = { get: (tag) => defined[tag], define: (tag, constructor) => { defined[tag] = constructor; } };
globalThis.HTMLElement = class {
  constructor() { this.attrs = {}; this.places = []; }
  getAttribute(name) { return this.attrs[name] ?? null; }
  setAttribute(name, value) { this.attrs[name] = value; }
  removeAttribute(name) { delete this.attrs[name]; }
  attachInternals() { return null; }
  querySelectorAll() { return this.places; }
  get localName() { return "probe-one"; }
};
globalThis.HTMLSelectElement = class {};
globalThis.HTMLButtonElement = class {};
globalThis.HTMLButtonElement.prototype.commandForElement = null;
globalThis.document = { activeElement: null, addEventListener() {} };

const { start, internals } = await import("../src/yumemi/front/interactive.mjs");
const gone = [];
const goto = { then: "goto", path: "/article/:slug", notice: null };
const stay = { then: "stay" };
start({
  components: {
    "probe-one": {
      reloads: { read: "widget_list", on: ["widget"], list: true },
      services: {
        article_publish: { method: "POST", path: "/api/articles/:slug/publish", read: false, upload: false, accepted: false, entry: false, args: [{ name: "slug", wire: "text", blob: false }], refused: [], slots: { slug: "slug" }, ok: stay, error: goto },
        widget_list: { method: "GET", path: "/api/widgets", read: true, upload: false, accepted: false, entry: false, args: [{ name: "widget", wire: { option: "text" }, blob: false }], refused: [], slots: {}, ok: stay, error: stay },
      },
    },
  },
  go: (href, options) => gone.push({ href, options }),
  reload: () => {},
});
const Component = defined["probe-one"];

// Block が型で書いた初期値(Bool・Int・Option・List)は JSON の値のまま表の型で送る
const w = internals.wireValue;
check("typed initial values", w("bool", true) === true && w("int", 3) === 3 && w({ option: "int" }, null) === null
  && w({ option: "int" }, 7) === 7 && JSON.stringify(w({ list: "text" }, ["a", "b"])) === '["a","b"]'
  && JSON.stringify(w({ list: "int" }, [1, 2])) === "[1,2]" && w("float", 2.5) === 2.5);

// 読みの戻り(out)は option・select・textarea の中には入れない(書きの Args に流れる)
const place = (slot, inside) => ({ textContent: "", getAttribute: () => `article_publish.${slot}`, closest: (q) => (inside && q.includes(inside) ? {} : null) });
const element = new Component();
const plain = place("slug", null);
const inOption = place("slug", "option");
const inSelect = place("slug", "select");
const inTextarea = place("slug", "textarea");
element.places = [plain, inOption, inSelect, inTextarea];
element.yumemiDone("article_publish", Component.yumemiSpec.services.article_publish, { ok: true, value: { slug: "from-read" } });
check("out outside controls is filled", plain.textContent === "from-read", plain);
check("out inside option / select / textarea is not filled", inOption.textContent === "" && inSelect.textContent === "" && inTextarea.textContent === "");

// error 側の GoTo は失敗の本文で穴を埋めない
reply = { ok: false, value: { code: "conflict", slug: "leak" } };
element.attrs["data-yumemi-args"] = JSON.stringify({ article_publish: { slug: "s" } });
const button = { name: "", type: "submit", getAttribute: (name) => (name === "data-yumemi-send" ? "article_publish" : null) };
const form = { elements: [button], querySelector: () => null, contains: () => false };
await element.yumemiSubmit({ submitter: button }, form, Component.yumemiSpec);
check("error goto does not fill holes from the failure body", gone.length === 1 && !gone[0].href.includes("leak"), gone);

// 一覧の reloads は go に count: false を渡す(送り手が数えない)
gone.length = 0;
const select = { name: "widget_list.widget", value: "b" };
const listForm = { elements: { namedItem: (name) => (name === "widget_list.widget" ? select : null) } };
element.yumemiChange({ target: select }, listForm, Component.yumemiSpec);
check("list reloads go without counting", gone.length === 1 && gone[0].options.count === false && gone[0].options.replace === true
  && new URL(gone[0].href).searchParams.get("widget") === "b", gone);

// navigate.go(count: false) は頁の読み込みに落ちても印を置く
const navigate = await import("../src/yumemi/front/navigate.mjs");
let replaced = null;
globalThis.location = Object.assign(new URL("https://www.example/feed?widget=a"), { replace: (href) => { replaced = href; }, assign: () => {} });
navigate.go("https://www.example/feed?widget=c", { replace: true, count: false });
const mark = JSON.parse(store.get(navigate.uncountedKey) ?? "null");
check("go without counting marks the page", replaced === "https://www.example/feed?widget=c" && mark?.href === "https://www.example/feed?widget=c", { replaced, mark });

// 送り手:印のある頁の読み込みは数えない(印は 1 回で消える)、info の count: false の client 遷移も数えない
const beacons = [];
globalThis.fetch = async (url, init) => { beacons.push({ url, body: JSON.parse(init.body) }); return new Response(null, { status: 202 }); };
const navigation = new EventTarget();
globalThis.navigation = navigation;
globalThis.location = new URL("https://www.example/feed?widget=c");
globalThis.performance = { getEntriesByType: () => [{ type: "navigate" }] };
globalThis.requestIdleCallback = (run) => run();
globalThis.document = { readyState: "complete", referrer: "", prerendering: false, head: { querySelector: () => ({}) }, querySelector: () => null, addEventListener() {} };
const { start: startSender } = await import("../src/yumemi/front/pageview.mjs");
startSender({ endpoint: "/api/_yumemi/pageviews", key: "yumemi:pageview:www", fields: [{ type: "kind" }, { type: "path" }] });
await settle();
check("marked page load is not counted once", beacons.length === 0 && !store.has(navigate.uncountedKey), beacons);
const travel = (info, href) => {
  navigation.dispatchEvent(Object.assign(new Event("navigate"), { navigationType: "replace", hashChange: false, downloadRequest: null, info }));
  globalThis.location = new URL(href);
  navigation.transition = { navigationType: "replace" };
  navigation.dispatchEvent(new Event("navigatesuccess"));
  navigation.transition = null;
};
travel({ yumemi: "go", keep: null, count: false }, "https://www.example/feed?widget=d");
await settle();
check("list reloads are not counted as spa", beacons.length === 0, beacons);
travel({ yumemi: "go", keep: null }, "https://www.example/article/x");
await settle();
check("a user navigation is still counted as spa", beacons.length === 1 && beacons[0].body.kind === "spa", beacons);

console.log(out.join("\n"));
