// yumemi framework/front ── Page 間の client 遷移(0.11.4、H9)。生成の `priv/static/_yumemi/client.mjs` が
// `start({routes, boot})` を呼ぶ。`routes` は同じ面の Page の route のうち、client で差し替えてよいもの
// (門の frame-src の CSP を持つ Page と pageview を数える Page は生成器が外す ── どちらも頁の読み込みの応答に付く)。
//
// 同じ origin で、今の頁と行き先の両方が `routes` に当たる a の click だけを取る。次の頁は server に 1 回の
// request で取りに行く(門・成人の申告・session の判定は server の今までの道を通る)。200 の HTML で、同じ面の
// client を持ち、差し替えられる形なら head と body を差し替え、島を起こし直し(`boot`)、history を積む。
// 戻る / 進むも同じ道で取り直す。取れない(redirect・200 でない・CSP の header・script を持つ・given の島が
// 既に登録済み)ときと、route 表に無い・修飾キー付き・target 付き・download の click は、頁の読み込みに落とす。

const clientSrc = "/_yumemi/client.mjs";

/// route の綴り(`/muse/:handle/reserve`)に pathname が当たるか。門(`gen/gate.mjs` の matchRoute)と同じ規則:
/// 節の数が同じ、`:` の節は空でない値、字の節は同じか `_` を `-` に替えたもの。
export function matches(route, pathname) {
  const expected = route.split("/");
  const actual = pathname.split("/");
  if (expected.length !== actual.length) return false;
  return expected.every((segment, index) =>
    segment.startsWith(":")
      ? actual[index] !== ""
      : segment === actual[index] || segment.replaceAll("_", "-") === actual[index]);
}

export function routed(routes, pathname) {
  return routes.some((route) => matches(route, pathname));
}

/// click を client 遷移で取るか。取るなら行き先の URL、取らないなら null。
export function intercept(event, routes, location) {
  if (event.defaultPrevented || event.button !== 0) return null;
  if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return null;
  const path = typeof event.composedPath === "function" ? event.composedPath() : [event.target];
  const anchor = path.find((node) => node?.tagName === "A" && typeof node.getAttribute === "function" && node.hasAttribute("href"));
  if (!anchor) return null;
  const target = anchor.getAttribute("target");
  if ((target !== null && target !== "" && target !== "_self") || anchor.hasAttribute("download")) return null;
  let url;
  try { url = new URL(anchor.getAttribute("href"), location.href); } catch (_error) { return null; }
  if (url.origin !== location.origin) return null;
  // 同じ頁の中の # は browser に任せる
  if (url.pathname === location.pathname && url.search === location.search && url.hash !== "") return null;
  if (!routed(routes, location.pathname) || !routed(routes, url.pathname)) return null;
  return url;
}

/// 取った頁の文書を差し替えてよいか(同じ面の client を持ち、head の他の script も body の script も持たず、
/// 既に登録した given の島を持たない)。
export function swappable(doc, defined) {
  const scripts = [...doc.querySelectorAll("script")];
  const client = scripts.filter((script) => script.getAttribute("src") === clientSrc && script.getAttribute("type") === "module");
  if (client.length !== 1 || scripts.length !== 1 || client[0].parentElement !== doc.head) return false;
  if (!doc.body) return false;
  return ![...doc.body.querySelectorAll("[data-yumemi-given]")].some((element) => defined(element.localName));
}

export function start({ routes, boot }) {
  if (typeof window === "undefined" || typeof history?.pushState !== "function") return;
  let pending = null;
  // 今出している文書の pathname + search(# だけの移動は文書を変えない)
  const page = (location) => location.pathname + location.search;
  let shown = page(globalThis.location);
  const load = (url, replace) => {
    if (replace) globalThis.location.replace(url.href);
    else globalThis.location.assign(url.href);
  };
  const swap = (doc) => {
    const keep = (node) => node.nodeName === "SCRIPT" && node.getAttribute("src") === clientSrc;
    const incoming = [...doc.head.childNodes].filter((node) => !keep(node)).map((node) => document.adoptNode(node));
    const outgoing = [...document.head.childNodes].filter((node) => !keep(node));
    // 新しい stylesheet を先に入れてから古いのを外す(差し替えの間に素の頁を見せない)
    for (const node of incoming) document.head.appendChild(node);
    for (const node of outgoing) node.remove();
    const lang = doc.documentElement.getAttribute("lang");
    if (lang !== null) document.documentElement.setAttribute("lang", lang);
    document.body.replaceWith(document.adoptNode(doc.body));
  };
  const go = async (url, push) => {
    pending?.abort();
    const controller = new AbortController();
    pending = controller;
    let response;
    try {
      response = await fetch(url.href, {
        credentials: "same-origin",
        redirect: "manual",
        headers: { accept: "text/html" },
        signal: controller.signal,
      });
    } catch (error) {
      if (controller.signal.aborted) return;
      return load(url, !push);
    }
    const type = response.headers.get("content-type") ?? "";
    if (response.type === "opaqueredirect" || response.status !== 200 || !type.startsWith("text/html") || response.headers.has("content-security-policy")) {
      return load(url, !push);
    }
    let html;
    try { html = await response.text(); } catch (_error) { if (controller.signal.aborted) return; return load(url, !push); }
    if (controller.signal.aborted) return;
    const doc = new DOMParser().parseFromString(html, "text/html");
    if (!swappable(doc, (tag) => globalThis.customElements.get(tag) !== undefined)) return load(url, !push);
    pending = null;
    swap(doc);
    if (push) history.pushState({ yumemi: "navigate" }, "", url.href);
    shown = page(url);
    const anchor = url.hash ? document.getElementById(decodeURIComponent(url.hash.slice(1))) : null;
    if (anchor) anchor.scrollIntoView();
    else if (push) window.scrollTo(0, 0);
    boot();
    document.dispatchEvent(new CustomEvent("yumemi-navigated", { detail: { url: url.href } }));
  };
  // 最初の頁の history にも印を付ける(戻るで最初の頁へ戻った時も同じ道で取る)
  if (history.state === null) history.replaceState({ yumemi: "navigate" }, "", globalThis.location.href);
  document.addEventListener("click", (event) => {
    const url = intercept(event, routes, globalThis.location);
    if (url === null) return;
    event.preventDefault();
    void go(url, true);
  });
  window.addEventListener("popstate", (event) => {
    const url = new URL(globalThis.location.href);
    if (page(url) === shown) return;
    if (event.state?.yumemi !== "navigate" || !routed(routes, url.pathname)) return load(url, true);
    void go(url, false);
  });
}
