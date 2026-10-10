// yumemi framework/front ── Page 間の client 遷移(0.11.4、H9)。生成の `priv/static/_yumemi/client.mjs` が
// `start({routes, csp, boot, pageview})` を呼ぶ。`routes` は同じ面の Page の route の綴り、`csp` は門の frame-src の
// CSP を持つ Page の route からその値(0.11.15。0.11.14 までは生成器が CSP を持つ Page を表から外していた。`csp` を
// 知らない 0.11.14 の client は、CSP の header で頁の読み込みに落ちる)。
//
// 同じ origin で、今の頁と行き先の両方が `routes` に当たり、行き先の CSP が「今の document を読み込んだ Page の CSP」
// と同じ a の click だけを取る(CSP の header は頁の読み込みの応答にしか効かないので、違う CSP の頁へは読み込みで
// 移る)。次の頁は server に 1 回の request で取りに行く(門・成人の申告・session の判定は server の今までの道を通る)。
// 200 の HTML で、応答の CSP の header が表と同じ値で、同じ面の client を持ち、差し替えられる形なら head と body を
// 差し替え、島を起こし直し(`boot`)、history を積む。戻る / 進むも同じ道で取り直す。取れない(redirect・200 で
// ない・CSP の header が表と違う・script を持つ・given の島が既に登録済み)ときと、route 表に無い・CSP が違う・
// 修飾キー付き・target 付き・download の click は、頁の読み込みに落とす。
//
// head の差し替え(0.11.15):今の head と来た head で同じ要素(outerHTML が同じ)は残し、順を保って差分だけ
// 足し引きする(同じ stylesheet の `<link>` を作り直さない ── 作り直すと確かめ直しの往復の間に素の頁が出る)。
// 新しく足す stylesheet と、来た頁の body にだけある stylesheet は、当たらない media で先に読み終えてから body を
// 替える(body の側は、自分が読み終えるまで head の写しを残す)。
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

/// route の表の 1 行を `{route, csp}` に揃える(綴りだけの行は CSP の無い Page)。
function row(entry) {
  return typeof entry === "string" ? { route: entry, csp: null } : { route: entry.route, csp: entry.csp ?? null };
}

/// pathname の Page の CSP(無ければ null)。表に当たらない時と、当たる行の CSP が食い違う時は undefined。
export function policy(routes, pathname) {
  let found;
  for (const entry of routes) {
    const { route, csp } = row(entry);
    if (!matches(route, pathname)) continue;
    if (found !== undefined && found !== csp) return undefined;
    found = csp;
  }
  return found;
}

export function routed(routes, pathname) {
  return policy(routes, pathname) !== undefined;
}

/// 応答の CSP の header が行き先の Page の CSP(表の値)と同じか。どちらも無いのも同じ。
export function samePolicy(headers, csp) {
  return (headers.get("content-security-policy") ?? null) === csp;
}

/// click を client 遷移で取るか。取るなら行き先の URL、取らないなら null。`loaded` は今の document を読み込んだ
/// Page の CSP(既定は今の頁の表の値)で、行き先の CSP がこれと違えば取らない。
export function intercept(event, routes, location, loaded = policy(routes, location.pathname)) {
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
  const here = policy(routes, location.pathname);
  const there = policy(routes, url.pathname);
  if (here === undefined || there === undefined || here !== loaded || there !== loaded) return null;
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

/// 今の head の並びと来た head の並び(要素の鍵)の最長の共通部分。来た側の各位置に、残す今の位置か -1 を返す。
/// 残す要素は動かさない(動かすと stylesheet を読み直す)ので、順を保ったまま当たる組を最も多く取る。
export function common(current, incoming) {
  const rows = current.length;
  const columns = incoming.length;
  const table = Array.from({ length: rows + 1 }, () => new Array(columns + 1).fill(0));
  for (let i = rows - 1; i >= 0; i -= 1) {
    for (let j = columns - 1; j >= 0; j -= 1) {
      table[i][j] = current[i] === incoming[j] ? table[i + 1][j + 1] + 1 : Math.max(table[i + 1][j], table[i][j + 1]);
    }
  }
  const match = new Array(columns).fill(-1);
  let i = 0;
  let j = 0;
  while (i < rows && j < columns) {
    if (current[i] === incoming[j]) {
      match[j] = i;
      i += 1;
      j += 1;
    } else if (table[i + 1][j] >= table[i][j + 1]) i += 1;
    else j += 1;
  }
  return match;
}

// 来た頁の body の stylesheet を読み終えるまで head に置く写しの印
const holdMark = "data-yumemi-hold";
// 読み終えるのを待つ上限(読めない stylesheet で遷移を止めない)
const holdLimit = 3000;
// 読み終えるまで当てない media
const quietMedia = "not all";

function nodeKey(node) {
  return node.nodeType === 1 ? node.outerHTML : `#${node.nodeType}:${node.nodeValue}`;
}

function isStylesheet(node) {
  return node.nodeType === 1 && node.localName === "link" && /(^|\s)stylesheet(\s|$)/i.test(node.getAttribute("rel") ?? "");
}

function stylesheets(root) {
  const found = [];
  const walk = (node) => {
    for (const child of node.childNodes) {
      if (isStylesheet(child)) found.push(child);
      else if (child.nodeType === 1) walk(child);
    }
  };
  walk(root);
  return found;
}

/// link を読み終える(load か error か上限)まで待つ。挿す前に呼ぶ(挿した後の load を取りこぼさない)。
function settled(link, limit) {
  return new Promise((resolve) => {
    const done = () => {
      clearTimeout(timer);
      link.removeEventListener("load", done);
      link.removeEventListener("error", done);
      resolve();
    };
    const timer = setTimeout(done, limit);
    link.addEventListener("load", done);
    link.addEventListener("error", done);
  });
}

function setMedia(node, media) {
  if (media === null) node.removeAttribute("media");
  else node.setAttribute("media", media);
}

/// 取った文書 `doc` を今の文書 `target` へ差し替える段取り。`keep` は差し替えない head の子(client の script)。
/// 返す `ready` は、新しく足す head の stylesheet と来た body の stylesheet(head の写し)を、当たらない media で
/// 読み終えた時に解ける。`commit()` が head の差分を足し引きして body を替え、`cancel()` は先に挿したものを外す。
export function stage(target, doc, keep, limit = holdLimit) {
  const head = target.head;
  const current = [...head.childNodes].filter((node) => !keep(node) && !(node.nodeType === 1 && node.hasAttribute(holdMark)));
  const incoming = [...doc.head.childNodes].filter((node) => !keep(node));
  const match = common(current.map(nodeKey), incoming.map(nodeKey));
  const kept = new Set(match.filter((index) => index >= 0).map((index) => current[index]));
  const outgoing = current.filter((node) => !kept.has(node));
  const final = incoming.map((node, index) => (match[index] >= 0 ? current[match[index]] : target.adoptNode(node)));
  const placed = new Set(kept);
  const waits = [];
  const quiet = [];
  // 来た順の位置へ、後ろから「次に置いてある要素」の前に挿す(残す要素は動かさない)
  const place = (only) => {
    let next = null;
    for (let index = final.length - 1; index >= 0; index -= 1) {
      const node = final[index];
      if (!placed.has(node) && only(node)) {
        if (isStylesheet(node)) {
          quiet.push([node, node.getAttribute("media")]);
          waits.push(settled(node, limit));
          node.setAttribute("media", quietMedia);
        }
        head.insertBefore(node, next);
        placed.add(node);
      }
      if (placed.has(node)) next = node;
    }
  };
  place(isStylesheet);
  // 来た頁の body にだけある stylesheet は head に写しを置いて先に読む(来た head にも在る href は要らない)
  const headHrefs = new Set(final.filter(isStylesheet).map((node) => node.getAttribute("href")));
  const bodyLinks = doc.body ? stylesheets(doc.body).filter((link) => !headHrefs.has(link.getAttribute("href"))) : [];
  const holds = bodyLinks.map((link) => {
    const copy = target.createElement("link");
    for (const name of link.getAttributeNames()) copy.setAttribute(name, link.getAttribute(name));
    copy.setAttribute(holdMark, "");
    quiet.push([copy, link.getAttribute("media")]);
    waits.push(settled(copy, limit));
    copy.setAttribute("media", quietMedia);
    head.appendChild(copy);
    return copy;
  });
  const ready = Promise.all(waits).then(() => undefined);
  const commit = () => {
    place(() => true);
    for (const [node, media] of quiet) setMedia(node, media);
    for (const node of outgoing) node.remove();
    const lang = doc.documentElement?.getAttribute("lang") ?? null;
    if (lang !== null) target.documentElement.setAttribute("lang", lang);
    const body = target.adoptNode(doc.body);
    const done = bodyLinks.map((link) => settled(link, limit));
    target.body.replaceWith(body);
    // body の側が読み終えたら写しを外す
    return Promise.all(done).then(() => { for (const copy of holds) copy.remove(); });
  };
  const cancel = () => {
    for (const [node] of quiet) node.remove();
  };
  return { ready, commit, cancel };
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

/// 生成の `routes` と `csp` を、Page ごとの CSP を持つ route の表(`{route, csp}` の並び)にする。
export function table(routes, csp = {}) {
  return routes.map((route) => ({ route, csp: Object.hasOwn(csp, route) ? csp[route] : null }));
}

export function start({ routes: paths, csp = {}, boot, pageview = null }) {
  if (typeof window === "undefined" || typeof history?.pushState !== "function") return;
  const routes = table(paths, csp);
  let pending = null;
  // 今出している文書の pathname + search(# だけの移動は文書を変えない)
  const page = (location) => location.pathname + location.search;
  let shown = page(globalThis.location);
  const load = (url, replace) => {
    if (replace) globalThis.location.replace(url.href);
    else globalThis.location.assign(url.href);
  };
  const keep = (node) => node.nodeName === "SCRIPT" && node.getAttribute("src") === clientSrc;
  // 今の document を読み込んだ Page の CSP(client 遷移は同じ CSP の頁の間だけなので、遷移の後も変わらない)
  const loaded = policy(routes, globalThis.location.pathname);
  // mode は "push"(click)・"pop"(戻る / 進む)・"refresh"(書いた後の取り直し)
  const go = async (url, mode) => {
    const push = mode === "push";
    pending?.abort();
    const controller = new AbortController();
    pending = controller;
    const csp = policy(routes, url.pathname);
    if (csp === undefined || csp !== loaded) return load(url, !push);
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
    if (response.type === "opaqueredirect" || response.status !== 200 || !type.startsWith("text/html") || !samePolicy(response.headers, csp)) {
      return load(url, !push);
    }
    let html;
    try { html = await response.text(); } catch (_error) { if (controller.signal.aborted) return; return load(url, !push); }
    if (controller.signal.aborted) return;
    const doc = new DOMParser().parseFromString(html, "text/html");
    if (!swappable(doc, (tag) => globalThis.customElements.get(tag) !== undefined)) return load(url, !push);
    // 印は差し替えの前に読む(差し替えが head の子を今の文書へ移す)
    const count = pageview !== null && counted(doc);
    const staged = stage(document, doc, keep);
    await staged.ready;
    if (controller.signal.aborted) return staged.cancel();
    pending = null;
    const from = globalThis.location.pathname;
    const scroll = [window.scrollX, window.scrollY];
    void staged.commit();
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
      const stay = () => window.scrollTo(scroll[0], scroll[1]);
      stay();
      requestAnimationFrame(() => { stay(); requestAnimationFrame(stay); });
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
    const url = intercept(event, routes, globalThis.location, loaded);
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
