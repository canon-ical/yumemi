// yumemi-0121 ── 断り(refused に載る符号)は `refused-<code>` だけ、それ以外の失敗は `failed`(`when(Failed)`)。
// 要件の符号(`consent_missing`・`declaration_missing`)も表の refused に載れば断り。偽の DOM と fetch で回す。
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
  querySelectorAll() { return []; }
};
globalThis.HTMLSelectElement = class {};
globalThis.HTMLButtonElement = class {};
globalThis.HTMLButtonElement.prototype.commandForElement = null;
globalThis.document = { activeElement: null, addEventListener() {} };

const { start } = await import("../src/yumemi/front/interactive.mjs");
const stay = { then: "stay" };
start({
  components: {
    "reply-form": { reloads: null, services: { reply_post: { method: "POST", path: "/api/replies", read: false, upload: false, accepted: false, entry: false, args: [{ name: "body", wire: "text", blob: false }], refused: ["screen_unavailable", "consent_missing", "declaration_missing"], slots: {}, ok: stay, error: stay } } },
  },
});

const states = async (status, body) => {
  reply = { ok: status < 400, body };
  const Component = defined["reply-form"];
  const element = new Component();
  element.attrs["data-yumemi-args"] = JSON.stringify({ reply_post: { body: "" } });
  const button = { name: "", type: "submit", getAttribute: (name) => (name === "data-yumemi-send" ? "reply_post" : null) };
  const form = { elements: [{ name: "reply_post.body", type: "text", value: "hi", disabled: false, checkValidity: () => true }, button], querySelector: () => null, contains: () => false };
  await element.yumemiSubmit({ submitter: button }, form, Component.yumemiSpec);
  return (element.getAttribute("data-yumemi-state") ?? "").split(" ").sort().join(" ");
};

check("service refusal is refused only", (await states(503, { code: "screen_unavailable" })) === "error refused-screen-unavailable sent-reply_post");
check("consent_missing is a refusal", (await states(403, { code: "consent_missing", consent: "use" })) === "error refused-consent-missing sent-reply_post");
check("declaration_missing is a refusal", (await states(403, { code: "declaration_missing", declaration: "adult" })) === "error refused-declaration-missing sent-reply_post");
check("a code outside refused is failed", (await states(403, { code: "forbidden" })) === "error failed sent-reply_post");
check("an unreadable body is failed", (await states(500, null)) === "error failed sent-reply_post");
check("success sets no failed", (await states(200, {})) === "ok sent-reply_post");

console.log(out.join("\n"));
