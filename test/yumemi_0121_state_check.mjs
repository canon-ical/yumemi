// yumemi-0121 ── 断り(表の `refused` と `requires` の符号)は `refused-<code>`。`failed`(`when(Failed)`)は、その
// 断りの枝が Component に無い失敗にだけ立つ ── 枝のある断りで汎用の失敗の枝を並べず、枝の無い断りは Failed で出す。
// 同じ Service の Failed の枝の中にある断りの枝は数えない(入れ子の形は両方の字を出す)。偽の DOM と fetch で回す。
const out = [];
const check = (name, ok) => out.push((ok ? "ok " : "NG ") + name);
let reply = { ok: true, body: {} };
globalThis.window = globalThis;
globalThis.fetch = async () => ({ ok: reply.ok, json: async () => reply.body });
const defined = {};
globalThis.customElements = { get: (tag) => defined[tag], define: (tag, constructor) => { defined[tag] = constructor; } };
globalThis.HTMLElement = class {
  constructor() { this.attrs = {}; }
  getAttribute(name) { return this.attrs[name] ?? null; }
  setAttribute(name, value) { this.attrs[name] = value; }
  removeAttribute(name) { delete this.attrs[name]; }
  attachInternals() { return null; }
  // Component の中の `when` の枝(`data-yumemi-when~="<service>.<state>"`)。`inside` は枝を囲む枝の state
  querySelectorAll(selector) {
    const found = /^\[data-yumemi-when~="([^"]+)"\]$/.exec(selector);
    if (!found) return [];
    return branches.filter((branch) => branch.when === found[1]).map((branch) => ({
      parentElement: { closest: (outer) => (branch.inside && outer === `[data-yumemi-when~="${branch.inside}"]` ? {} : null) },
    }));
  }
};
const sibling = [
  { when: "reply_post.refused-screen-unavailable" },
  { when: "reply_post.refused-consent-missing" },
  { when: "reply_post.failed" },
];
let branches = sibling;
globalThis.HTMLSelectElement = class {};
globalThis.HTMLButtonElement = class {};
globalThis.HTMLButtonElement.prototype.commandForElement = null;
globalThis.document = { activeElement: null, addEventListener() {} };

const { start } = await import("../src/yumemi/front/interactive.mjs");
const stay = { then: "stay" };
start({
  components: {
    "reply-form": { reloads: null, services: { reply_post: { method: "POST", path: "/api/replies", read: false, upload: false, accepted: false, entry: false, args: [{ name: "body", wire: "text", blob: false }], refused: ["screen_unavailable", "blob_not_found"], requires: ["consent_missing", "declaration_missing"], slots: {}, ok: stay, error: stay } } },
  },
});

const states = async (status, body, layout = sibling) => {
  reply = { ok: status < 400, body };
  branches = layout;
  const Component = defined["reply-form"];
  const element = new Component();
  element.attrs["data-yumemi-args"] = JSON.stringify({ reply_post: { body: "" } });
  const button = { name: "", type: "submit", getAttribute: (name) => (name === "data-yumemi-send" ? "reply_post" : null) };
  const form = { elements: [{ name: "reply_post.body", type: "text", value: "hi", disabled: false, checkValidity: () => true }, button], querySelector: () => null, contains: () => false };
  await element.yumemiSubmit({ submitter: button }, form, Component.yumemiSpec);
  return (element.getAttribute("data-yumemi-state") ?? "").split(" ").sort().join(" ");
};

check("a refusal with its branch is refused only", (await states(503, { code: "screen_unavailable" })) === "error refused-screen-unavailable sent-reply_post");
check("a refusal without a branch also shows Failed", (await states(404, { code: "blob_not_found" })) === "error failed refused-blob-not-found sent-reply_post");
check("consent_missing (requires) with its branch is refused only", (await states(403, { code: "consent_missing", consent: "use" })) === "error refused-consent-missing sent-reply_post");
check("declaration_missing (requires) without a branch also shows Failed", (await states(403, { code: "declaration_missing", declaration: "adult" })) === "error failed refused-declaration-missing sent-reply_post");
check("a code outside refused and requires is failed", (await states(403, { code: "forbidden" })) === "error failed sent-reply_post");
check("an unreadable body is failed", (await states(500, null)) === "error failed sent-reply_post");
// `when(Failed, [p("…", when(Refused(ScreenUnavailable), ..), "…")])`:Failed の枝が隠れると中の断りの枝も隠れる
const nested = [{ when: "reply_post.failed" }, { when: "reply_post.refused-screen-unavailable", inside: "reply_post.failed" }];
check("a refusal branch nested in Failed also shows Failed", (await states(503, { code: "screen_unavailable" }, nested)) === "error failed refused-screen-unavailable sent-reply_post");
check("a nested refusal branch and a sibling one: refused only", (await states(503, { code: "screen_unavailable" }, [...nested, { when: "reply_post.refused-screen-unavailable" }])) === "error refused-screen-unavailable sent-reply_post");
check("success sets no failed", (await states(200, {})) === "ok sent-reply_post");

console.log(out.join("\n"));
