// yumemi yumemi/front ── Page 間の client 遷移(0.11.4、H9 → 0.12 で Navigation API に寄せた)。生成の
// `priv/static/_yumemi/client.mjs` が `start({routes, csp})` を呼ぶ。`routes` は同じ面の Page の route の綴り、
// `csp` は門の CSP を持つ Page の route からその値(0.11.15)。
//
// click の横取り・履歴・戻る / 進む・scroll・focus・中断・# はブラウザの Navigation API に任せる。`navigation` の
// navigate イベントのうち、利用者が起こした push / replace(link の click、GET の form)と、同じ document の中の
// 戻る / 進む(traverse)と、`reload()` が起こした reload だけを `intercept()` で取る。取るのは、今の頁と行き先の両方が
// `routes` に当たり、行き先の CSP が「今の document を読み込んだ Page の CSP」と同じときだけ(CSP の header は頁の
// 読み込みの応答にしか効かない)。scroll と focus は `intercept()` の既定(`after-transition`)のまま ── push は # の
// 先か頁の頭へ、戻る / 進むは離れた時の位置へ戻し、focus は `autofocus` の要素か body へ移る(reload だけ scroll を
// 触らせない。下の「書いた後の取り直し」)。同じ頁の中の #・
// 修飾キー・target・download・別 origin・POST の form は、ブラウザがそのまま扱う。Navigation API の無い browser では
// 何も取らない(頁の読み込み)。
//
// framework に残すのは 7 つ ── 取得・差し替えの判定・head の差分・stylesheet の待ち・body の差し替え・interactive
// Component の再起動・pageview の印。再起動は呼び出しでなく、来た body の custom element が define 済みの class で
// 接続時に起きること(0.12 段 C、`boot()` の呼び直しは無くなった)。次の頁は server に 1 回の request で取りに行き(門・成人の申告・session の判定は server の
// 今までの道を通る)、200 の HTML で、応答の CSP の header が表と同じ値で、同じ面の client を持ち、差し替えられる形
// なら head と body を差し替える。取れない(200 でない・HTML でない・CSP の header が表と違う・
// script を持つ)ときは、行き先を頁の読み込みで開き直す(URL は取った時点で行き先に
// 替わっているので、履歴は積まない `location.replace`)。redirect(0.14.7)は `follow` で辿り、差し替えずに最終の URL を
// 頁の読み込みで開く ── entry の URL は元の(副作用のある)URL のままなので、最終の頁を差し替えに使うと再読み込みで
// 元の GET がもう一度届く。`mode: "same-origin"` は別の origin への redirect を、要求を送る前に失敗させる(元の URL を開き直す)。
//
// head の差し替え(0.11.15):今の head と来た head で同じ要素(outerHTML が同じ)は残し、順を保って差分だけ
// 足し引きする(同じ stylesheet の `<link>` を作り直さない ── 作り直すと確かめ直しの往復の間に素の頁が出る)。
// 新しく足す stylesheet と、来た頁の body にだけある stylesheet は、当たらない media で先に読み終えてから body を
// 替える(body の側は、自分が読み終えるまで head の写しを残す)。
//
// 失敗の頁(0.14.3):面が失敗の頁を宣言していれば、shell は頁を求める要求の失敗(403・404・5xx)を失敗の頁の HTML
// で、元の状態コードのまま、印の header `x-yumemi-failure: <status>` を付けて返す。印のある HTML は 200 と同じく
// 差し替える(CSP の照合と `swappable` は同じ)── 頁の読み込みをもう 1 回しない。数える印は 200 にだけ差さる。
//
// pageview(0.12):fetch は印の header `x-yumemi-navigate: 1` を付け、門は数える Page の応答の head に
// `<meta name="yumemi-pageview">` を差す。ここは送らない。差し替えでは印を毎回来た頁のものに替え(前の頁の印を
// 残さない)、`navigatesuccess` の時点で今の document にあるのは来た頁の印だけ。送るのは client 側の送り手で、
// 遷移の種類は `navigation.transition.navigationType`(click は push、戻る / 進むは traverse、書いた後の取り直しは
// reload)で見る。
//
// 書いた後の取り直し:`reload()` は今の頁が route 表に当たれば `navigation.reload()` を起こし、それを取って今の URL
// を同じ道で取り直す(履歴を積まず、scroll は `manual` で今の位置のまま)。当たらない・`start` が走っていない時は
// 頁の読み込み。
//
// 取得の最中の競合(0.12 段 C、Y4 柏木 P1):取っている最中に同じ document の中の移動(# の click・
// `history.pushState` / `replaceState`)が起きると、取りは signal で止まり URL だけが替わる。止まった後に新しく
// 取った遷移も document を離れる遷移も無ければ、今の URL を頁の読み込みで開き直して URL と中身を揃える。
//
// 同じ document の中で積まれた履歴(0.12 段 C):逃げ道の JS が `pushState` した entry へ戻る / 進むのは、中身が
// 今の document のままなので取らない(取り直すと interactive Component の状態が消え、送り手が spa を数える)。
// どの entry がどの差し替えの中身かを entry の key で覚え、行き先が今の中身と同じなら browser に任せる。
// interactive Component の runtime は pushState を使わない(`reloads` の一覧は `go` の replace で移る)。

const clientSrc = "/_yumemi/client.mjs";
/// 門に「client 遷移の fetch」と知らせる header。門はこれを見て pageview の script の代わりに印を差す。
export const navigateHeader = "x-yumemi-navigate";
const pageviewName = "yumemi-pageview";
/// shell が失敗の頁の応答に付ける印(値は元の状態コード)。
export const failureHeader = "x-yumemi-failure";

/// 取った応答を差し替えてよい状態か:200 か、印のある失敗の頁。
export function swappableStatus(response) {
  return response.status === 200 || (response.status >= 400 && response.headers.has(failureHeader));
}

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

/// `reload()` が起こす reload の印(`navigation.reload` の info)。印の無い reload(`location.reload()`)は取らない。
const refreshInfo = { yumemi: "reload" };
/// runtime の移動(After の GoTo・`reloads` の一覧)の印。利用者の起こした移動と同じく取る。
const goInfo = "go";

/// navigate イベントを client 遷移で取るか。取るなら行き先の URL、取らないなら null。取るのは利用者が起こした
/// push / replace、traverse、印の付いた reload で、ブラウザが取れると言い(`canIntercept`)、同じ頁の中の # でも
/// download でも POST でもないものだけ。`loaded` は今の document を読み込んだ Page の CSP(既定は今の頁の表の値)で、
/// 行き先の CSP がこれと違えば取らない。
export function accept(event, routes, location, loaded = policy(routes, location.pathname)) {
  if (!event.canIntercept || event.defaultPrevented || event.hashChange) return null;
  if (event.downloadRequest != null || event.formData != null) return null;
  const type = event.navigationType;
  if (type === "reload" ? event.info?.yumemi !== refreshInfo.yumemi : type !== "traverse" && !event.userInitiated && event.info?.yumemi !== goInfo) return null;
  let url;
  try { url = new URL(event.destination.url); } catch (_error) { return null; }
  if (url.origin !== location.origin) return null;
  const here = policy(routes, location.pathname);
  const there = policy(routes, url.pathname);
  if (here === undefined || there === undefined || here !== loaded || there !== loaded) return null;
  return url;
}

/// 取らない navigate のうち、同じ document の中の戻る / 進む(# だけの移動でないもの)。ブラウザに任せると URL だけが
/// 替わって中身が前の頁のまま残るので、取って頁の読み込みで開き直す。
export function stale(event) {
  return event.canIntercept && event.navigationType === "traverse" && event.destination?.sameDocument === true && !event.hashChange;
}

/// 取った頁の文書を差し替えてよいか(同じ面の client を持ち、head の他の script も body の script も持たない)。
export function swappable(doc) {
  const scripts = [...doc.querySelectorAll("script")];
  const client = scripts.filter((script) => script.getAttribute("src") === clientSrc && script.getAttribute("type") === "module");
  if (client.length !== 1 || scripts.length !== 1 || client[0].parentElement !== doc.head) return false;
  return Boolean(doc.body);
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

// 門の数える印(`<meta name="yumemi-pageview">`)。字が同じでも残さず、毎回来た頁のものに替える
let marks = 0;

function nodeKey(node) {
  if (node.nodeType === 1 && node.localName === "meta" && node.getAttribute("name") === pageviewName) return `#mark:${(marks += 1)}`;
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

// `start` が走った面の取り直し(書いた後の読み直し)。走っていなければ null
let refresh = null;

/// runtime の移動(After の GoTo・`reloads` の一覧)。route 表に当たれば client の遷移で、当たらなければ頁の読み込み。
/// `replace` は履歴を積まない、`keep` は scroll を保ち focus を同じタグの同じ name の control へ戻す(`{tag, name}`)。
export function go(href, { replace = false, keep = null, count = true } = {}) {
  // 数えない移動(`reloads` の一覧の取り直し):頁の読み込みに落ちても、来た頁の送り手が印を見て 1 回だけ外す
  if (!count) markUncounted(href);
  if (going !== null) return going(href, replace, keep, count);
  if (replace) globalThis.location.replace(href);
  else globalThis.location.assign(href);
}

let going = null;

/// 送り手(pageview.mjs)が数えない頁の印。`{href, at}` を sessionStorage の 1 鍵に置き、10 秒の内だけ効く。
export const uncountedKey = "yumemi:uncounted";

function markUncounted(href) {
  try {
    sessionStorage.setItem(uncountedKey, JSON.stringify({ href: new URL(href, globalThis.location.href).href, at: Date.now() }));
  } catch (_error) {}
}

/// 書いた後の読み直し。今の頁が route 表に当たれば client 遷移で取り直し、当たらなければ頁の読み込み。
export function reload() {
  if (refresh !== null) return refresh();
  globalThis.location.assign(globalThis.location.href);
}

/// 生成の `routes` と `csp` を、Page ごとの CSP を持つ route の表(`{route, csp}` の並び)にする。
export function table(routes, csp = {}) {
  return routes.map((route) => ({ route, csp: Object.hasOwn(csp, route) ? csp[route] : null }));
}

/// この browser に Navigation API の navigate イベントと `intercept()` があるか。
export function supported(scope = globalThis) {
  return typeof scope.navigation?.addEventListener === "function" && typeof scope.NavigateEvent?.prototype?.intercept === "function";
}

export function start({ routes: paths, csp = {} }) {
  if (typeof window === "undefined" || !supported()) return;
  const navigation = globalThis.navigation;
  const routes = table(paths, csp);
  const keep = (node) => node.nodeName === "SCRIPT" && node.getAttribute("src") === clientSrc;
  // 今の document を読み込んだ Page の CSP(client 遷移は同じ CSP の頁の間だけなので、遷移の後も変わらない)
  const loaded = policy(routes, globalThis.location.pathname);
  // 取れない時は行き先を頁の読み込みで開き直す(URL は既に行き先。利用者の起こした遷移でないので取られない)
  const load = (url) => globalThis.location.replace(url.href);
  // 取った遷移と document を離れる遷移の番号。止まった取りは、自分の後に番号が進んでいなければ開き直す
  let latest = 0;
  // entry の key → その entry の中身(差し替えの番号)。0 は読み込んだ document
  let shown = 0;
  let shownSeq = 0;
  const contents = new Map();
  if (navigation.currentEntry) contents.set(navigation.currentEntry.key, shown);
  // 開き直しは `location.reload()`(今の URL が # を持つと、同じ URL への replace は # の移動になり読み込まない)
  const stopped = (id) => {
    setTimeout(() => {
      if (latest === id) globalThis.location.reload();
    }, 0);
  };
  // redirect した応答の最終の URL(同じ origin だけ。元の `#` は行き先に無ければ引き継ぐ ── ブラウザの redirect と同じ)
  const landing = (url, response) => {
    try {
      const to = new URL(response.url);
      if (to.origin !== url.origin) return url;
      if (to.hash === "" && url.hash !== "") to.hash = url.hash;
      return to;
    } catch (_error) {
      return url;
    }
  };
  const swap = async (url, signal, id, focus) => {
    const csp = policy(routes, url.pathname);
    let response;
    try {
      response = await fetch(url.href, {
        credentials: "same-origin",
        redirect: "follow",
        mode: "same-origin",
        cache: "no-store",
        headers: { accept: "text/html", [navigateHeader]: "1" },
        signal,
      });
    } catch (_error) {
      if (signal.aborted) return stopped(id);
      return load(url);
    }
    if (response.redirected) return load(landing(url, response));
    const type = response.headers.get("content-type") ?? "";
    if (response.type === "opaqueredirect" || !swappableStatus(response) || !type.startsWith("text/html") || !samePolicy(response.headers, csp)) {
      return load(url);
    }
    let html;
    try { html = await response.text(); } catch (_error) { if (signal.aborted) return stopped(id); return load(url); }
    if (signal.aborted) return stopped(id);
    const doc = new DOMParser().parseFromString(html, "text/html");
    if (!swappable(doc)) return load(url);
    const staged = stage(document, doc, keep);
    await staged.ready;
    if (signal.aborted) { staged.cancel(); return stopped(id); }
    void staged.commit();
    shown = ++shownSeq;
    if (focus !== null) {
      const control = document.querySelector(`${focus.tag} [name="${CSS.escape(focus.name)}"]`);
      control?.focus({ preventScroll: true });
    }
  };
  refresh = () => {
    if (!routed(routes, globalThis.location.pathname)) return globalThis.location.assign(globalThis.location.href);
    navigation.reload({ info: refreshInfo });
  };
  going = (href, replace, keepFocus, count) => {
    const url = new URL(href, globalThis.location.href);
    if (!routed(routes, url.pathname)) return replace ? globalThis.location.replace(url.href) : globalThis.location.assign(url.href);
    const info = count ? { yumemi: goInfo, keep: keepFocus } : { yumemi: goInfo, keep: keepFocus, count: false };
    navigation.navigate(url.href, { history: replace ? "replace" : "push", info });
  };
  navigation.addEventListener("navigatesuccess", () => {
    if (navigation.currentEntry) contents.set(navigation.currentEntry.key, shown);
  });
  navigation.addEventListener("navigate", (event) => {
    // 同じ document の中で積まれた entry(中身が今の document のまま)へ戻る / 進むのは browser に任せる
    if (event.navigationType === "traverse" && event.destination?.sameDocument && contents.get(event.destination.key) === shown) return;
    const url = accept(event, routes, globalThis.location, loaded);
    // reload の既定の scroll は、離れる時にしか取らない位置(取り直しでは頁の頭)へ戻すので、reload だけ触らせない
    // (差し替えの前後で同じ位置のまま)。push と traverse は既定(# の先か頭へ、戻る / 進むは離れた時の位置へ)
    if (url !== null) {
      const id = ++latest;
      const keepFocus = event.info?.yumemi === goInfo ? event.info.keep ?? null : null;
      const manual = event.navigationType === "reload" || keepFocus !== null;
      event.intercept({
        handler: () => swap(url, event.signal, id, keepFocus),
        scroll: manual ? "manual" : "after-transition",
        ...(keepFocus !== null ? { focusReset: "manual" } : {}),
      });
    } else if (stale(event)) {
      latest += 1;
      event.intercept({ handler: () => load(new URL(event.destination.url)) });
    } else if (!event.destination?.sameDocument) {
      // document を離れる遷移(取らないもの)。止まった取りを開き直さない
      latest += 1;
    }
  });
}
