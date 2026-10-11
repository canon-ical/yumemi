// 0.12(Y4)── navigate.mjs の `start` と `reload` を、偽の Navigation API(`navigation`・`NavigateEvent`)と偽の
// location・fetch で回す。`yumemi_012_y4_test_ffi.mjs` が子の node で走らせ(globals を汚さない)、1 行 1 件の ok / NG を出す。
import { reload, start, supported } from "../src/yumemi/front/navigate.mjs";

const out = [];
const check = (name, ok) => out.push((ok ? "ok " : "NG ") + name);
const tick = () => new Promise((resolve) => setTimeout(resolve, 5));
const loads = [];
const at = (href) => {
  const url = new URL(href, "https://www.example/");
  globalThis.location = {
    href: url.href, pathname: url.pathname, origin: url.origin,
    assign: (to) => loads.push(["assign", to]),
    replace: (to) => loads.push(["replace", to]),
    reload: () => loads.push(["reload", url.href]),
  };
};
at("/a");
globalThis.window = globalThis;

// Navigation API の無い browser:何も取らず、取り直しは頁の読み込み
check("unsupported", !supported());
start({ routes: ["/a", "/b"] });
reload();
check("unsupported reload loads page", loads.length === 1 && loads[0][0] === "assign" && loads[0][1] === "https://www.example/a");
loads.length = 0;

// 偽の Navigation API
const listeners = [];
const reloads = [];
globalThis.NavigateEvent = class { intercept() {} };
globalThis.navigation = {
  addEventListener: (type, listener) => { if (type === "navigate") listeners.push(listener); },
  currentEntry: { key: "k0" },
  reload: (options) => reloads.push(options),
};
check("supported", supported());
start({ routes: ["/a", "/b"] });
check("listens navigate", listeners.length === 1);
const fire = (href, extra = {}) => {
  const controller = new AbortController();
  const event = {
    canIntercept: true, defaultPrevented: false, hashChange: false, downloadRequest: null, formData: null,
    navigationType: "push", userInitiated: true, info: undefined, signal: controller.signal,
    destination: { url: new URL(href, "https://www.example/").href, sameDocument: false }, handlers: [], ...extra,
  };
  event.intercept = (options) => { event.handlers.push(options.handler); event.options = options; };
  event.abort = () => controller.abort();
  listeners[0](event);
  return event;
};

check("user push taken", fire("/b").handlers.length === 1);
check("script push left to browser", fire("/b", { userInitiated: false }).handlers.length === 0);
check("unrouted push left to browser", fire("/c").handlers.length === 0);
check("plain reload left to browser", fire("/a", { navigationType: "reload", userInitiated: false }).handlers.length === 0);
// 書いた後の取り直し:navigation.reload に印を付け、その reload を取る
reload();
check("reload goes through navigation", reloads.length === 1 && reloads[0].info?.yumemi === "reload" && loads.length === 0);
const marked = fire("/a", { navigationType: "reload", userInitiated: false, info: reloads[0].info });
check("marked reload taken", marked.handlers.length === 1);
// 取り直しは scroll を触らせない(reload の既定は頁の頭へ戻す)。push は既定のまま
check("reload keeps scroll", marked.options?.scroll === "manual" && fire("/b").options?.scroll === "after-transition");
// 同じ document の戻る / 進むで表に当たらない行き先は、取って頁の読み込みで開き直す
const stale = fire("/c", { navigationType: "traverse", userInitiated: false, destination: { url: "https://www.example/c", sameDocument: true } });
stale.handlers[0]?.();
check("stale traverse reloads", loads.length === 1 && loads[0][0] === "replace" && loads[0][1] === "https://www.example/c");
loads.length = 0;
check("cross document traverse left to browser", fire("/c", { navigationType: "traverse", userInitiated: false, destination: { url: "https://www.example/c", sameDocument: false } }).handlers.length === 0);

// 取れない応答は行き先を頁の読み込みで開き直す(履歴を積まない replace)。中断された取得は何もしない
const fetched = [];
const respond = (response) => { globalThis.fetch = async (href, init) => { fetched.push([href, init]); return response; }; };
respond({ type: "opaqueredirect", status: 0, headers: new Headers() });
const redirected = fire("/b");
await redirected.handlers[0]();
check("fetch marks navigate header", fetched[0]?.[1]?.headers?.["x-yumemi-navigate"] === "1" && fetched[0][1].signal === redirected.signal);
check("redirect falls back to load", loads.length === 1 && loads[0][0] === "replace" && loads[0][1] === "https://www.example/b");
loads.length = 0;
globalThis.fetch = async () => { throw new Error("offline"); };
await fire("/b").handlers[0]();
check("network error falls back to load", loads.length === 1 && loads[0][0] === "replace");
loads.length = 0;
const aborted = fire("/b");
globalThis.fetch = async () => { aborted.abort(); throw new DOMException("aborted", "AbortError"); };
await aborted.handlers[0]();
await tick();
// 0.12 段 C(Y4 柏木 P1):止まった後に新しく取った遷移が無ければ、URL と中身を揃えるため今の URL を読み込み直す
check("aborted without a newer navigation reloads", loads.length === 1 && loads[0][0] === "reload");
loads.length = 0;
const first = fire("/b");
globalThis.fetch = async () => { first.abort(); fire("/a"); throw new DOMException("aborted", "AbortError"); };
await first.handlers[0]();
await tick();
check("aborted by a newer taken navigation does nothing", loads.length === 0);
// 表に当たらない頁での取り直しは頁の読み込み
at("/c");
reload();
check("unrouted reload loads page", reloads.length === 1 && loads.length === 1 && loads[0][0] === "assign");

await tick();
console.log(out.join("\n"));
