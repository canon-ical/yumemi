// 0.12 段 C(Y3、柏木 ゲート 2)── interactive.mjs の送りの file の上げ方を、偽の DOM と fetch で回す。
// `yumemi_012_y3_test_ffi.mjs` が子の node で走らせ(globals を汚さない)、1 行 1 件の ok / NG を出す。
const out = [];
const check = (name, ok) => out.push((ok ? "ok " : "NG ") + name);
const sent = [];
globalThis.window = globalThis;
globalThis.fetch = async (url, init) => {
  sent.push({ url, method: init?.method, body: init?.body });
  return { ok: true, json: async () => ({ key: `k${sent.length}`, saved: true }) };
};
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
    "article-blob-copy": { reloads: null, services: { blob_copy: { method: "POST", path: "/api/blobs", read: false, upload: true, accepted: false, entry: true, args: [{ name: "file", wire: "text", blob: true }, { name: "from", wire: "text", blob: false }], refused: [], slots: { key: "key" }, ok: stay, error: stay } } },
    "blob-save": { reloads: null, services: { article_blob_save: { method: "POST", path: "/api/articles/:slug/blob_save", read: false, upload: false, accepted: false, entry: false, args: [{ name: "slug", wire: "text", blob: false }, { name: "blob", wire: "text", blob: true }], refused: [], slots: { saved: "saved" }, ok: stay, error: stay } } },
  },
});

const submit = async (tag, service, initial, controls) => {
  const Component = defined[tag];
  const element = new Component();
  element.attrs["data-yumemi-args"] = JSON.stringify({ [service]: initial });
  const button = { name: "", type: "submit", getAttribute: (name) => (name === "data-yumemi-send" ? service : null) };
  const form = { elements: [...controls, button], querySelector: () => null, contains: () => false };
  await element.yumemiSubmit({ submitter: button }, form, Component.yumemiSpec);
};
const control = (name, type, value) => ({ name, type, value, files: type === "file" ? value : undefined, disabled: false, checkValidity: () => true });
const file = new File(["abc"], "a.png", { type: "image/png" });

// 上げ口:file は送りの本文で 1 回だけ上がる(先に /api/blobs へ上げない)
await submit("article-blob-copy", "blob_copy", { file: "", from: "" }, [control("blob_copy.file", "file", [file]), control("blob_copy.from", "text", "")]);
check("upload entry posts the file once", sent.length === 1 && sent[0].url === "/api/blobs" && sent[0].body === file);

// 上げ口:file が無ければ {from} を JSON で 1 回
sent.length = 0;
await submit("article-blob-copy", "blob_copy", { file: "", from: "" }, [control("blob_copy.file", "file", []), control("blob_copy.from", "text", "https://a.example/x.png")]);
check("upload entry copies from without a file", sent.length === 1 && sent[0].body === JSON.stringify({ from: "https://a.example/x.png" }));

// Service の Blob の欄:file を /api/blobs へ上げ、戻りの key を Args に入れて Service を 1 回
sent.length = 0;
await submit("blob-save", "article_blob_save", { slug: "s", blob: "old" }, [control("article_blob_save.blob", "file", [file])]);
check("service blob field uploads then sends the key", sent.length === 2 && sent[0].url === "/api/blobs" && sent[1].url === "/api/articles/s/blob_save" && JSON.parse(sent[1].body).blob === "k1");

// Service の Blob の欄:file を選ばなければ初期値の key のまま
sent.length = 0;
await submit("blob-save", "article_blob_save", { slug: "s", blob: "old" }, [control("article_blob_save.blob", "file", [])]);
check("service blob field keeps the initial key", sent.length === 1 && JSON.parse(sent[0].body).blob === "old");

console.log(out.join("\n"));
