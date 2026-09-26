// yumemi framework/front ── Page 間の client 遷移(0.11.4、H9)。生成の `priv/static/_yumemi/client.mjs` が
// `start({routes, boot, pageview})` を呼ぶ。`routes` は同じ面の Page の route のうち、client で差し替えてよいもの
// (門の frame-src の CSP を持つ Page は生成器が外す ── CSP の header は頁の読み込みの応答にしか効かない)。
//
// 同じ origin で、今の頁と行き先の両方が `routes` に当たる a の click だけを取る。次の頁は server に 1 回の
// request で取りに行く(門・成人の申告・session の判定は server の今までの道を通る)。200 の HTML で、同じ面の
// client を持ち、差し替えられる形なら head と body を差し替え、島を起こし直し(`boot`)、history を積む。
// 戻る / 進むも同じ道で取り直す。取れない(redirect・200 でない・CSP の header・script を持つ・given の島が
// 既に登録済み)ときと、route 表に無い・修飾キー付き・target 付き・download の click は、頁の読み込みに落とす。
//
// pageview(r2):fetch は印の header `x-yumemi-navigate: 1` を付ける。門は pageview の Page を adult の session に
// 200 の HTML で返す時、script の代わりに `<meta name="yumemi-pageview">` を head に差す。client は差し替えた後に
// だけ、その印を見て 1 回送る(kind は遷移が `spa`、書いた後の取り直しが `reload`)。頁の読み込みに落ちた時は
// 送らない ── 読み込みの応答には門が今までどおり script を差し、それが 1 回数える。
//
// 書いた後の取り直し(r2):`reload()` は今の頁が route 表に当たれば今の URL を同じ道で取り直す(history を積まず、
// scroll を保つ)。当たらない・`start` が走っていない時は頁の読み込み。

const clientSrc = "/_yumemi/client.mjs";
/// 門に「client 遷移の fetch」と知らせる header。門はこれを見て pageview の script の代わりに印を差す。
export const navigateHeader = "x-yumemi-navigate";
const pageviewMark = 'meta[name="yumemi-pageview"]';

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

/// # の行き先の要素。壊れた百分率の #(`#%E0%A4%A`)は null(投げると島の登録と yumemi-navigated が飛ぶ)。
export function hashTarget(url, byId) {
  if (!url.hash) return null;
  try { return byId(decodeURIComponent(url.hash.slice(1))); } catch (_error) { return null; }
}

/// 取った文書に門の数える印があるか(門が数えたはずの応答:adult の session・200 の HTML・pageview の Page)。
export function counted(doc) {
  return doc.head?.querySelector(pageviewMark) != null;
}

/// client 遷移の pageview の本文。門の script(頁の読み込み)と同じ欄で、kind は `spa` か `reload`。
/// 前の event(同じ tab の sessionStorage)が無い時だけ、遷移の元の path を referrer_path に置く。
export function pageviewPayload({ url, kind, from, previous, sourceParam, id, at }) {
  const payload = { id, client_at: at, kind, path: url.pathname };
  if (previous) payload.prev = previous;
  else if (from) payload.referrer_path = from;
  const sourceKey = sourceParam ? url.searchParams.get(sourceParam) : null;
  if (sourceKey && /^[a-z0-9_]{1,16}$/.test(sourceKey)) payload.source_key = sourceKey;
  return payload;
}

function sendPageview(config, url, kind, from) {
  let previous = null;
  try {
    const value = sessionStorage.getItem(config.key);
    previous = value && /^[0-9a-f-]{36}$/.test(value) ? value : null;
  } catch (_) {}
  const id = crypto.randomUUID();
  const body = JSON.stringify(pageviewPayload({ url, kind, from, previous, sourceParam: config.source, id, at: new Date().toISOString() }));
  try { sessionStorage.setItem(config.key, id); } catch (_) {}
  const post = () => fetch(config.endpoint, { method: "POST", headers: { "content-type": "application/json" }, body, keepalive: true });
  const send = () => void post().catch(() => post().catch(() => {}));
  if ("requestIdleCallback" in window) window.requestIdleCallback(send, { timeout: 1000 });
  else requestAnimationFrame(send);
}

// `start` が走った面の取り直し(書いた後の読み直し)。走っていなければ null
let refresh = null;

/// 島の Done の後の読み直し。今の頁が route 表に当たれば client 遷移で取り直し、当たらなければ頁の読み込み。
export function reload() {
  if (refresh !== null) return refresh();
  globalThis.location.assign(globalThis.location.href);
}

export function start({ routes, boot, pageview = null }) {
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
  // mode は "push"(click)・"pop"(戻る / 進む)・"refresh"(書いた後の取り直し)
  const go = async (url, mode) => {
    const push = mode === "push";
    pending?.abort();
    const controller = new AbortController();
    pending = controller;
    let response;
    try {
      response = await fetch(url.href, {
        credentials: "same-origin",
        redirect: "manual",
        cache: "no-store",
        headers: { accept: "text/html", [navigateHeader]: "1" },
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
    const from = globalThis.location.pathname;
    const scroll = [window.scrollX, window.scrollY];
    // 印は差し替えの前に読む(swap が head の子を今の文書へ移す)
    const count = pageview !== null && counted(doc);
    swap(doc);
    if (push) history.pushState({ yumemi: "navigate" }, "", url.href);
    shown = page(url);
    if (mode !== "refresh") {
      const anchor = hashTarget(url, (id) => document.getElementById(id));
      if (anchor) anchor.scrollIntoView();
      else if (push) window.scrollTo(0, 0);
    }
    boot();
    if (mode === "refresh") {
      // 取り直しは scroll を保つ。島が描き終わって高さが戻った後にも当て直す
      const keep = () => window.scrollTo(scroll[0], scroll[1]);
      keep();
      requestAnimationFrame(() => { keep(); requestAnimationFrame(keep); });
    }
    if (count) sendPageview(pageview, url, mode === "refresh" ? "reload" : "spa", from);
    document.dispatchEvent(new CustomEvent("yumemi-navigated", { detail: { url: url.href, mode } }));
  };
  refresh = () => {
    const url = new URL(globalThis.location.href);
    if (!routed(routes, url.pathname)) return globalThis.location.assign(url.href);
    void go(url, "refresh");
  };
  // 最初の頁の history にも印を付ける(戻るで最初の頁へ戻った時も同じ道で取る)
  if (history.state === null) history.replaceState({ yumemi: "navigate" }, "", globalThis.location.href);
  document.addEventListener("click", (event) => {
    const url = intercept(event, routes, globalThis.location);
    if (url === null) return;
    event.preventDefault();
    void go(url, "push");
  });
  window.addEventListener("popstate", (event) => {
    const url = new URL(globalThis.location.href);
    if (page(url) === shown) return;
    if (event.state?.yumemi !== "navigate" || !routed(routes, url.pathname)) return load(url, true);
    void go(url, "pop");
  });
}
