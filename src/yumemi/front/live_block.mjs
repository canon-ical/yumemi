// yumemi yumemi/front ── `Live` の Block の runtime(0.14、87「案 (i′)」)。生成の `priv/static/_yumemi/client.mjs`
// が `start({socket, reload})` を呼ぶ。★ は Page の placements に `Live(.., edge:)` と書くだけで、ここは目に無い。
//
// - `<yumemi-live name edge token>`(`display: contents`)は shell が `Live` の Block の外に描く。接続すると札
//   (`token`、yumemi-live-1 の `x-yumemi-live`)で `wss://<host><socket>?token=` を張る。札が無ければ張らない
// - 合図は `1` の 1 字だけ(本文も差分も載らない)。受けたら 0〜500ms の揺らぎの後、今の URL を header
//   `x-yumemi-block: <name>` で取り直し、返った断片(`<style>` と `<yumemi-live>`)を今の Block に当てる。取っている
//   最中の合図は「終わったらもう 1 回」の 1 つに畳む。client は本文を組まない ── 当てるのは server の描いた HTML
// - 門の redirect・403・404(root の 404 を含む)、200 でも断片の形でないなら頁ごと取り直す(navigate の `reload`、
//   無ければ頁の読み込み)。5xx・その他の status・通信の失敗は頁に触らず、倍々の待ち(揺らぎつき)で取り直す
// - 断片の `<style>` の規則のうち document の今の sheet に無いものを、構築した 1 枚の sheet に足す(sched-css の穴)。
//   在る規則の表は取るたびに今の sheet から作り直す(client 遷移で頁の `<style>` が外れたら足し直す)
// - 当て方の 4 規則(87):1. 一致した節は動かさない(前へ進むだけの照合。節を動かす操作が無いので、focus と変換中
//   の文字を持つ節は document から一度も外れない) 2. interactive Component は tag と `data-yumemi-args` が同じなら
//   中に触らない。違えば、接続した時の control の値の写しと今の値が同じで focus も無いときだけ差し替え、そうで
//   なければ残して `:state(stale)` 3. 利用者の持ち物の属性は古い側を残す(`details` / `dialog` の `open`、focus の
//   ある control の値、`el.fresh` の `hidden`)。逃げ道は属性が同じなら中に触らない 4. 鍵は `data-yumemi-key`、
//   無ければ Component は tag+Args(当たらなければ同じ tag の Component)、それ以外は tag。前へ探す照合は、focus
//   のある節・書きかけのある Component / control を含む節を飛ばして消さない ── 後ろの新しい節がそれを受けられる
//   (同じ鍵で、中に同じ Component / control がある)なら、今の新しい節は新しく挿す
// - スクロール:`bottom` は当てる前に端にいれば当てた後も端へ追い、上を読んでいれば留まって `el.fresh` を出す。
//   `top` は頭にいれば頭のまま、読んでいれば留まって印。`anywhere` は留まる。留まるときは、見えていた先頭の節の
//   位置を当てる前と同じに戻す(browser の scroll anchoring の無いときの代わり)
// - 繋ぎ直し:切れたら 1 秒から倍々(上限 30 秒、揺らぎつき)で張り直す。繋がったら毎回(最初も)揺らぎの後に
//   1 回取り直す(描いてから開くまで・切れていた間の合図を拾う)。倍々の待ちは開いて 30 秒続いた socket で戻す
//   (開いてすぐ閉じられる輪も倍々で待つ)。頁が見えるようになったら(`visibilitychange`)待たずに張り直すか取り直す。
//   頁に描かれた札だけは期限(payload の `exp`)を見て、1 分を切っていれば先に取り直し、そうでなければ期限の 1 分前に
//   取り直して来た札で張り直す。取り直して来た札は期限を見ずに張り、期限は server の `4001` に任せる(client の時計が
//   ずれていても輪にならない)。`4001`・張れなかったときは、倍々で待ってから取り直して新しい札で張る
// - `yumemi.block` が別の URL から返した `<yumemi-live>` は取った URL を `href` に持ち、合図・`visibilitychange` の
//   取り直しはその URL から取る

const blockHeader = "x-yumemi-block";
const minDelay = 1000;
const maxDelay = 30000;
const jitterMs = 500;
const renewBeforeMs = 60000;
const stableMs = 30000;
const atEdgePx = 8;

let options = { socket: "/_yumemi/live", reload: null, jitter: jitterMs };

// ── 断片の取りと CSS ──────────────────────────────────────────────────────────

let adopted = null;

function sheetRules(sheet) {
  try { return [...sheet.cssRules]; } catch (_error) { return []; }
}

/// document の今の sheet(頁の `<style>`・`<link>`・足した sheet)の規則。取るたびに作り直す ── 頁をまたいで
/// 持ち越すと、client 遷移で外れた `<style>` の規則を「在る」と見て足さない。
function documentRules() {
  const rules = new Set();
  for (const sheet of [...globalThis.document.styleSheets, ...globalThis.document.adoptedStyleSheets]) {
    for (const rule of sheetRules(sheet)) rules.add(rule.cssText);
  }
  return rules;
}

/// 断片の `<style>` の規則のうち document の今の sheet に無いものを足す。足した数を返す。
export function adopt(text) {
  const document = globalThis.document;
  if (!adopted) adopted = new CSSStyleSheet();
  if (!document.adoptedStyleSheets.includes(adopted)) document.adoptedStyleSheets = [...document.adoptedStyleSheets, adopted];
  const knownRules = documentRules();
  const incoming = new CSSStyleSheet();
  try { incoming.replaceSync(text); } catch (_error) { return 0; }
  let added = 0;
  for (const rule of incoming.cssRules) {
    if (knownRules.has(rule.cssText)) continue;
    try {
      adopted.insertRule(rule.cssText, adopted.cssRules.length);
      knownRules.add(rule.cssText);
      added += 1;
    } catch (_error) { /* 読めない規則は捨てる(頁の規則は残る) */ }
  }
  return added;
}

/// `href` の頁の `name` の Block を取る。断片が来れば `{element, adopted}`(element は document の外の
/// `<yumemi-live>`、`<style>` の規則は足し済み)。門が頁を返さない(redirect・403・404)・200 でも断片の形でないなら
/// null(頁ごと取り直す)。5xx・その他の status・通信の失敗は `{error}`(待って取り直す)。
export async function fetchBlock(name, href = globalThis.location.href) {
  let response;
  try {
    response = await globalThis.fetch(href, {
      headers: { [blockHeader]: name },
      redirect: "manual",
      credentials: "same-origin",
      cache: "no-store",
    });
  } catch (error) {
    return { error };
  }
  const type = response.headers.get("content-type") ?? "";
  const status = response.status;
  if (response.type === "opaqueredirect" || (status >= 300 && status < 400) || status === 403 || status === 404) return null;
  if (status !== 200) return { error: new Error(`fragment ${status}`), status };
  if (!type.startsWith("text/html")) return null;
  let text;
  try { text = await response.text(); } catch (error) { return { error }; }
  const template = globalThis.document.createElement("template");
  template.innerHTML = text;
  let added = 0;
  for (const style of template.content.querySelectorAll("style")) {
    added += adopt(style.textContent ?? "");
    style.remove();
  }
  const element = [...template.content.querySelectorAll("yumemi-live")].find((item) => item.getAttribute("name") === name);
  if (!element) return null;
  return { element, adopted: added };
}

// ── 当て方 ───────────────────────────────────────────────────────────────────

const snapshots = new WeakMap();
const owned = { details: ["open"], dialog: ["open"] };

function isComponent(node) {
  return node.nodeType === 1 && node.hasAttribute("data-yumemi-island");
}

function controlValue(control) {
  if (control.type === "checkbox" || control.type === "radio") return String(control.checked);
  if (control.type === "file") return String(control.files?.length ?? 0);
  if (control.localName === "select") return [...control.options].map((option) => option.selected ? "1" : "0").join("");
  return control.value;
}

function snapshot(component) {
  return [...component.querySelectorAll("input,textarea,select")].map(controlValue).join("\u0000");
}

/// 接続した時の control の値の写し(逃げ道が hidden の control に値を書くと `defaultValue` も替わるので、写しで比べる)。
export function remember(root) {
  const components = isComponent(root) ? [root] : [...root.querySelectorAll("[data-yumemi-island]")];
  for (const component of components) if (!snapshots.has(component)) snapshots.set(component, snapshot(component));
}

function keyOf(node) {
  if (node.nodeType !== 1) return "#" + node.nodeType;
  const key = node.getAttribute("data-yumemi-key");
  if (key !== null) return node.localName + "|k:" + key;
  if (isComponent(node)) return node.localName + "|c:" + (node.getAttribute("data-yumemi-args") ?? "");
  return node.localName;
}

function looseKey(node) {
  if (node.nodeType === 1 && isComponent(node) && node.getAttribute("data-yumemi-key") === null) return node.localName + "|c";
  return null;
}

function focused(node) {
  const active = globalThis.document.activeElement;
  return Boolean(active) && (node === active || node.contains(active));
}

function setStale(component) {
  const states = component.yumemiInternals?.states;
  if (states && typeof states.add === "function") {
    try { states.add("stale"); return; } catch (_error) { /* 属性へ落ちる */ }
  }
  const names = (component.getAttribute("data-yumemi-state") ?? "").split(" ").filter(Boolean);
  if (!names.includes("stale")) component.setAttribute("data-yumemi-state", [...names, "stale"].join(" "));
}

function keptAttributes(node) {
  const keep = [...(owned[node.localName] ?? [])];
  if (node.hasAttribute("data-yumemi-fresh")) keep.push("hidden");
  if (focused(node) && /^(input|textarea|select|option)$/.test(node.localName)) keep.push("value", "checked", "selected");
  return keep;
}

function syncAttributes(from, to, log) {
  const keep = keptAttributes(from);
  for (const attribute of [...from.attributes]) {
    if (!keep.includes(attribute.name) && !to.hasAttribute(attribute.name)) {
      from.removeAttribute(attribute.name);
      log.changed += 1;
    }
  }
  for (const attribute of [...to.attributes]) {
    if (!keep.includes(attribute.name) && from.getAttribute(attribute.name) !== attribute.value) {
      from.setAttribute(attribute.name, attribute.value);
      log.changed += 1;
    }
  }
}

/// 来た側の属性が全部、今の側に同じ値である(逃げ道の JS が自分に足した属性は数えない)。
function sameAttributes(old, incoming) {
  return [...incoming.attributes].every((attribute) => old.getAttribute(attribute.name) === attribute.value);
}

function morphComponent(old, incoming, log) {
  if (old.localName === incoming.localName && old.getAttribute("data-yumemi-args") === incoming.getAttribute("data-yumemi-args")) {
    log.kept.push(old.localName);
    return;
  }
  const before = snapshots.get(old);
  const dirty = before !== undefined && before !== snapshot(old);
  if (dirty || focused(old)) {
    setStale(old);
    log.stale.push(old.localName);
    return;
  }
  old.replaceWith(incoming);
  remember(incoming);
  log.replaced.push(old.localName);
  log.changed += 1;
}

function morphNode(old, incoming, log, guards) {
  if (old.nodeType === 3 || old.nodeType === 8) {
    if (old.nodeValue !== incoming.nodeValue) {
      old.nodeValue = incoming.nodeValue;
      log.changed += 1;
    }
    return;
  }
  if (isComponent(old)) return morphComponent(old, incoming, log);
  if (old.localName === "yumemi-escape") {
    if (sameAttributes(old, incoming)) return;
    old.replaceWith(incoming);
    log.changed += 1;
    return;
  }
  syncAttributes(old, incoming, log);
  // focus のある textarea の字(子の text)は利用者の持ち物
  if (old.localName === "textarea" && focused(old)) return;
  morphChildren(old, incoming, log, guards);
}

// ── 守る節(前へ探す照合で消さない)──────────────────────────────────────────────

function isControl(node) {
  return /^(input|textarea|select)$/.test(node.localName);
}

function controlDirty(control) {
  if (control.localName === "select") return [...control.options].some((option) => option.selected !== option.defaultSelected);
  if (control.type === "checkbox" || control.type === "radio") return control.checked !== control.defaultChecked;
  if (control.type === "file") return (control.files?.length ?? 0) > 0;
  return control.value !== control.defaultValue;
}

function componentDirty(component) {
  const before = snapshots.get(component);
  return before !== undefined && before !== snapshot(component);
}

/// 今の Block の中で利用者の持ち物を持つ節:focus のある要素、書きかけのある Component、Component の外の書きかけの
/// control。それぞれ「新しい側で受けられる節」の目印(selector)を持つ。
function guardsOf(live) {
  const guards = [];
  const document = globalThis.document;
  const active = document.activeElement;
  for (const component of live.querySelectorAll("[data-yumemi-island]")) {
    if (componentDirty(component) || focused(component)) guards.push({ node: component, selector: guardSelector(component) });
  }
  for (const control of live.querySelectorAll("input,textarea,select")) {
    if (control.closest("[data-yumemi-island]")) continue;
    if (controlDirty(control) || control === active) guards.push({ node: control, selector: guardSelector(control) });
  }
  if (active && active !== document.body && live.contains(active) && !active.closest("[data-yumemi-island]") && !isControl(active)) {
    guards.push({ node: active, selector: guardSelector(active) });
  }
  return guards;
}

function guardSelector(node) {
  const escape = globalThis.CSS?.escape ?? ((value) => value.replace(/["\\]/g, "\\$&"));
  let selector = node.localName;
  const key = node.getAttribute("data-yumemi-key");
  if (key !== null) selector += `[data-yumemi-key="${escape(key)}"]`;
  if (isComponent(node)) selector += "[data-yumemi-island]";
  else if (node.hasAttribute("name")) selector += `[name="${escape(node.getAttribute("name"))}"]`;
  else if (node.id) selector += `#${escape(node.id)}`;
  return selector;
}

/// 新しい節 `incoming` が、古い節 `old` の中の守る節をみな受けられる(同じ鍵で、中に同じ目印の節がある)。
function receives(old, incoming, guards) {
  if (incoming.nodeType !== 1 || keyOf(old) !== keyOf(incoming)) return false;
  return guards.every((guard) => !old.contains(guard.node) || incoming.matches(guard.selector) || incoming.querySelector(guard.selector) !== null);
}

/// `olds[at..found]` を当てに使うと、守る節を持つ古い節が消えるか、守る節を受けられない新しい節に当たる。しかも
/// 後ろの新しい節(`later`)にその古い節を受けられるものがある。そのときは今の新しい節を新しく挿す。
function dropsGuarded(olds, at, found, incoming, later, guards) {
  if (guards.length === 0) return false;
  for (let index = at; index <= found; index += 1) {
    const old = olds[index];
    if (old.nodeType !== 1 || !guards.some((guard) => old.contains(guard.node))) continue;
    if (index === found && receives(old, incoming, guards)) continue;
    if (later.some((other) => receives(old, other, guards))) return true;
  }
  return false;
}

function findAhead(olds, from, key) {
  for (let index = from; index < olds.length; index += 1) if (keyOf(olds[index]) === key) return index;
  return -1;
}

function findLoose(olds, from, loose) {
  for (let index = from; index < olds.length; index += 1) if (looseKey(olds[index]) === loose) return index;
  return -1;
}

function morphChildren(oldParent, newParent, log, guards) {
  const olds = [...oldParent.childNodes];
  const news = [...newParent.childNodes];
  let at = 0;
  for (const [position, incoming] of news.entries()) {
    let found = findAhead(olds, at, keyOf(incoming));
    const loose = looseKey(incoming);
    if (found < 0 && loose !== null) {
      found = findLoose(olds, at, loose);
      // 当たった古い Component が、新しい側で鍵(tag+Args)どおりに後で当たるなら、ここでは使わない
      if (found >= 0 && news.some((other) => other !== incoming && keyOf(other) === keyOf(olds[found]))) found = -1;
    }
    // 守る節を飛ばして消す・受けられない新しい節に当てる当たりは使わない(後ろで受けられるとき)
    if (found >= 0 && dropsGuarded(olds, at, found, incoming, news.slice(position + 1), guards)) found = -1;
    if (found >= 0) {
      for (let index = at; index < found; index += 1) {
        olds[index].remove();
        log.changed += 1;
      }
      morphNode(olds[found], incoming, log, guards);
      at = found + 1;
    } else {
      oldParent.insertBefore(incoming, olds[at] ?? null);
      if (incoming.nodeType === 1) remember(incoming);
      log.inserted += 1;
      log.changed += 1;
    }
  }
  for (let index = at; index < olds.length; index += 1) {
    olds[index].remove();
    log.changed += 1;
  }
}

/// 来た `<yumemi-live>`(document の外)を今の `<yumemi-live>` に当てる。何を変えたかの記録を返す。
export function morph(current, incoming) {
  const log = { changed: 0, inserted: 0, kept: [], stale: [], replaced: [] };
  morphChildren(current, incoming, log, guardsOf(current));
  return log;
}

// ── スクロール ───────────────────────────────────────────────────────────────

function scroller(element) {
  const document = globalThis.document;
  for (let node = element.parentElement; node && node !== document.body && node !== document.documentElement; node = node.parentElement) {
    const overflow = globalThis.getComputedStyle(node).overflowY;
    if ((overflow === "auto" || overflow === "scroll") && node.scrollHeight > node.clientHeight) return node;
  }
  return document.scrollingElement ?? document.documentElement;
}

function viewTop(box) {
  const document = globalThis.document;
  return box === document.scrollingElement || box === document.documentElement ? 0 : box.getBoundingClientRect().top;
}

function atBottom(box) {
  return box.scrollHeight - box.scrollTop - box.clientHeight <= atEdgePx;
}

function atTop(box) {
  return box.scrollTop <= atEdgePx;
}

/// 見えている先頭の節(当てた後に位置を戻す目印)。
function anchorOf(live, box) {
  const top = viewTop(box);
  const walker = globalThis.document.createTreeWalker(live, 1);
  let best = null;
  for (let node = walker.nextNode(); node; node = walker.nextNode()) {
    const rect = node.getBoundingClientRect();
    if (rect.height === 0 && rect.width === 0) continue;
    if (rect.bottom > top) {
      best = { node, top: rect.top };
      if (node.hasAttribute("data-yumemi-key") || node.children.length === 0) break;
    }
  }
  return best;
}

function freshMarks(live) {
  return [...live.querySelectorAll("[data-yumemi-fresh]")];
}

function showFresh(live, shown) {
  for (const mark of freshMarks(live)) mark.hidden = !shown;
}

function toEdge(live, box) {
  if (live.getAttribute("edge") === "top") box.scrollTop = 0;
  else box.scrollTop = box.scrollHeight;
  showFresh(live, false);
}

// ── 要素 ─────────────────────────────────────────────────────────────────────

function expiry(token) {
  try {
    const payload = token.split(".")[0].replaceAll("-", "+").replaceAll("_", "/");
    const json = JSON.parse(globalThis.atob(payload + "=".repeat((4 - (payload.length % 4)) % 4)));
    return typeof json.exp === "number" ? json.exp * 1000 : null;
  } catch (_error) {
    return null;
  }
}

/// 倍々の待ちの揺らぎ(待ちの半分から全部の間)。deploy で全員の socket が落ちても同じ時に来ない。
function jittered(delay) {
  return delay / 2 + Math.random() * (delay / 2);
}

function reloadPage() {
  if (typeof options.reload === "function") options.reload();
  else globalThis.location.reload();
}

const ElementBase = globalThis.HTMLElement ?? class {};

class YumemiLive extends ElementBase {
  constructor() {
    super();
    this.yumemiSocket = null;
    this.yumemiDelay = minDelay;
    this.yumemiRetry = null;
    this.yumemiRetryRenew = false;
    this.yumemiRenew = null;
    this.yumemiFetching = null;
    this.yumemiFetchDelay = minDelay;
    this.yumemiRefetch = null;
    this.yumemiAgain = false;
    this.yumemiWaiting = null;
    this.yumemiOpened = false;
    this.yumemiOpenedAt = 0;
    this.yumemiCleanup = null;
  }

  connectedCallback() {
    if (this.yumemiCleanup) return;
    queueMicrotask(() => remember(this));
    const onVisible = () => {
      if (globalThis.document.visibilityState !== "visible") return;
      if (this.yumemiRetry !== null) {
        // 繋ぎ直しを待っている:待たずに今やる(倍々の待ちは戻さない)
        clearTimeout(this.yumemiRetry);
        this.yumemiRetry = null;
        void this.yumemiReconnect(this.yumemiRetryRenew);
      } else void this.refresh();
    };
    const onClick = (event) => {
      const mark = event.target?.closest?.("[data-yumemi-fresh]");
      if (!mark || !this.contains(mark)) return;
      toEdge(this, scroller(this));
    };
    const box = scroller(this);
    const target = box === globalThis.document.scrollingElement || box === globalThis.document.documentElement ? globalThis : box;
    const onScroll = () => {
      const edge = this.getAttribute("edge");
      if ((edge === "bottom" && atBottom(box)) || (edge === "top" && atTop(box))) showFresh(this, false);
    };
    globalThis.document.addEventListener("visibilitychange", onVisible);
    this.addEventListener("click", onClick);
    target.addEventListener("scroll", onScroll, { passive: true });
    this.yumemiCleanup = () => {
      globalThis.document.removeEventListener("visibilitychange", onVisible);
      this.removeEventListener("click", onClick);
      target.removeEventListener("scroll", onScroll);
    };
    this.yumemiConnect(true);
  }

  disconnectedCallback() {
    this.yumemiCleanup?.();
    this.yumemiCleanup = null;
    clearTimeout(this.yumemiRetry);
    clearTimeout(this.yumemiRenew);
    clearTimeout(this.yumemiWaiting);
    clearTimeout(this.yumemiRefetch);
    this.yumemiRetry = this.yumemiRenew = this.yumemiWaiting = this.yumemiRefetch = null;
    this.yumemiClose();
  }

  yumemiClose() {
    const socket = this.yumemiSocket;
    this.yumemiSocket = null;
    if (socket) {
      socket.onopen = socket.onmessage = socket.onclose = socket.onerror = null;
      try { socket.close(1000); } catch (_error) { /* 閉じ済み */ }
    }
  }

  /// 札で socket を張る。繋がったら毎回、揺らぎの後に 1 回取り直す(描いてから・切れていた間の合図を拾う)。
  /// `lookAhead` は頁に描かれた札のときだけ:期限が 1 分を切っていれば先に取り直し、そうでなければ期限の 1 分前に
  /// 取り直す timer を置く。取り直して来た札は期限を見ずに張る(期限は server の `4001`。時計のずれで輪にしない)。
  yumemiConnect(lookAhead) {
    if (!this.isConnected) return;
    this.yumemiClose();
    clearTimeout(this.yumemiRenew);
    this.yumemiRenew = null;
    const token = this.getAttribute("token");
    if (!token) return;
    const exp = lookAhead ? expiry(token) : null;
    if (exp !== null) {
      if (exp - Date.now() <= renewBeforeMs) {
        // 期限の近い・過ぎた札では張らない。取り直して来た札で張る(来なければ倍々で待つ)
        void this.yumemiReconnect(true);
        return;
      }
      // 期限の 1 分前に取り直し、来た札で張り直す(server が期限で閉じる前に替える)。1 回だけ
      this.yumemiRenew = setTimeout(() => {
        this.yumemiRenew = null;
        void this.refresh().then(() => {
          if (this.isConnected && this.getAttribute("token") !== token) this.yumemiConnect(false);
        });
      }, exp - Date.now() - renewBeforeMs);
    }
    const location = globalThis.location;
    const scheme = location.protocol === "https:" ? "wss:" : "ws:";
    let socket;
    try {
      socket = new WebSocket(`${scheme}//${location.host}${options.socket}?token=${encodeURIComponent(token)}`);
    } catch (_error) {
      this.yumemiScheduleRetry(true);
      return;
    }
    this.yumemiSocket = socket;
    this.yumemiOpened = false;
    socket.onopen = () => {
      this.yumemiOpened = true;
      this.yumemiOpenedAt = globalThis.performance?.now?.() ?? Date.now();
      this.dispatchEvent(new CustomEvent("yumemi-live-open"));
      this.signal();
    };
    socket.onmessage = (event) => {
      if (event.data === "1") this.signal();
    };
    socket.onclose = (event) => {
      this.yumemiLastClose = event.code;
      if (this.yumemiSocket !== socket) return;
      this.yumemiSocket = null;
      // 倍々の待ちは、開いて続いた socket が切れたときだけ戻す(開いてすぐ閉じられる輪も倍々で待つ)
      const now = globalThis.performance?.now?.() ?? Date.now();
      if (this.yumemiOpened && now - this.yumemiOpenedAt >= stableMs) this.yumemiDelay = minDelay;
      // 期限(4001)・張れなかった(開く前に閉じた)は札を替えてから張る
      this.yumemiScheduleRetry(event.code === 4001 || !this.yumemiOpened);
    };
  }

  /// 張り直す。`renew` なら先に取り直して来た札で張る(札が替わらなければ倍々で待ってやり直す)。
  async yumemiReconnect(renew) {
    if (!this.isConnected || this.yumemiSocket) return;
    if (!renew) {
      this.yumemiConnect(false);
      return;
    }
    const before = this.getAttribute("token");
    await this.refresh();
    if (!this.isConnected || this.yumemiSocket || this.yumemiRetry !== null) return;
    const token = this.getAttribute("token");
    if (!token || token === before) {
      // 札が替わらなかった(断片が来なかった・api に鍵が無い)。倍々で待って取り直しからやり直す
      this.yumemiScheduleRetry(true);
      return;
    }
    this.yumemiConnect(false);
  }

  yumemiScheduleRetry(renew) {
    if (!this.isConnected) return;
    clearTimeout(this.yumemiRetry);
    const delay = jittered(this.yumemiDelay);
    this.yumemiDelay = Math.min(this.yumemiDelay * 2, maxDelay);
    this.yumemiRetryRenew = renew;
    this.yumemiRetry = setTimeout(() => {
      this.yumemiRetry = null;
      void this.yumemiReconnect(renew);
    }, delay);
  }

  /// 合図を受けた:揺らぎの後に 1 回取り直す。揺らぎと取りの間の合図は畳む。
  signal() {
    if (this.yumemiWaiting !== null) return;
    if (this.yumemiFetching) {
      this.yumemiAgain = true;
      return;
    }
    const wait = Math.random() * (options.jitter ?? jitterMs);
    this.yumemiWaiting = setTimeout(() => {
      this.yumemiWaiting = null;
      void this.refresh();
    }, wait);
  }

  /// 取る URL:`yumemi.block` が別の URL から返した要素は取った `href`、それ以外は今の URL。
  yumemiHref() {
    return this.getAttribute("href") ?? globalThis.location.href;
  }

  /// この Block を取り直して当てる。取っている最中に呼ばれたら、終わった後にもう 1 回。
  refresh() {
    if (this.yumemiFetching) {
      this.yumemiAgain = true;
      return this.yumemiFetching;
    }
    clearTimeout(this.yumemiRefetch);
    this.yumemiRefetch = null;
    const run = async () => {
      do {
        this.yumemiAgain = false;
        await this.yumemiApply(this.yumemiHref());
      } while (this.yumemiAgain && this.isConnected);
    };
    this.yumemiFetching = run().finally(() => { this.yumemiFetching = null; });
    return this.yumemiFetching;
  }

  async yumemiApply(href) {
    const name = this.getAttribute("name") ?? "";
    const result = await fetchBlock(name, href);
    if (!this.isConnected) return null;
    if (result === null) {
      // 門が頁を返さない(redirect・403・404)・root が読めない:頁ごと取り直す
      this.yumemiClose();
      reloadPage();
      return null;
    }
    if (result.error) {
      // 5xx・その他の status・通信の失敗:頁に触らず、倍々の待ち(揺らぎつき)で取り直す
      clearTimeout(this.yumemiRefetch);
      const delay = jittered(this.yumemiFetchDelay);
      this.yumemiFetchDelay = Math.min(this.yumemiFetchDelay * 2, maxDelay);
      this.yumemiRefetch = setTimeout(() => {
        this.yumemiRefetch = null;
        void this.refresh();
      }, delay);
      this.dispatchEvent(new CustomEvent("yumemi-live-failed", { detail: { status: result.status ?? null, delay } }));
      return null;
    }
    this.yumemiFetchDelay = minDelay;
    return this.yumemiPut(result.element);
  }

  /// 来た `<yumemi-live>` を当て、端の規則でスクロールを揃える。来た札は持つだけ(次に張るときに使う)。
  yumemiPut(incoming) {
    const box = scroller(this);
    const edge = this.getAttribute("edge") ?? "bottom";
    const following = edge === "bottom" ? atBottom(box) : edge === "top" ? atTop(box) : false;
    const anchor = following ? null : anchorOf(this, box);
    const log = morph(this, incoming);
    const token = incoming.getAttribute("token");
    if (token !== null) this.setAttribute("token", token);
    if (following) {
      if (edge === "bottom") box.scrollTop = box.scrollHeight;
      else box.scrollTop = 0;
      showFresh(this, false);
    } else {
      if (anchor && anchor.node.isConnected) {
        const delta = anchor.node.getBoundingClientRect().top - anchor.top;
        if (Math.abs(delta) >= 1) box.scrollTop += delta;
      }
      if (log.changed > 0 && edge !== "anywhere") showFresh(this, true);
    }
    this.dispatchEvent(new CustomEvent("yumemi-live-applied", { detail: log }));
    // 来た札は次に張るときに使う(張った socket は札の期限まで生きる。期限の前の張り直しは renew の timer)
    return log;
  }
}

// ── 口 ───────────────────────────────────────────────────────────────────────

/// 逃げ道の口(`mount(element, yumemi)` の `yumemi.block`)。`name` の Block を `href`(既定は今の URL)から取る。
/// 頁にその URL のその `<yumemi-live>` があれば取り直して当て(合図と同じ当て方)、その要素を返す。
/// 無ければ当てずに、規則を足した `<yumemi-live>`(document の外)を返す ── 逃げ道が置く(`replaceWith` など)。
/// 別の URL から返した要素は取った URL を `href` に持ち、置かれた後の合図・`visibilitychange` もその URL から取る。
/// 門が頁を返さなければ null(頁にある要素なら頁ごと取り直す)。
export async function block(name, { href = globalThis.location.href } = {}) {
  const here = globalThis.location.href;
  const target = new URL(href, here);
  const same = (element) => {
    const at = new URL(element.getAttribute("href") ?? here, here);
    return at.pathname === target.pathname && at.search === target.search;
  };
  const current = [...globalThis.document.querySelectorAll("yumemi-live")].find((item) => item.getAttribute("name") === name && same(item));
  if (current && typeof current.refresh === "function") {
    await current.refresh();
    return current.isConnected ? current : null;
  }
  const result = await fetchBlock(name, target.href);
  if (result === null || result.error) return null;
  const element = globalThis.document.importNode(result.element, true);
  const local = new URL(here);
  if (target.pathname !== local.pathname || target.search !== local.search) element.setAttribute("href", target.href);
  return element;
}

export function start({ socket = "/_yumemi/live", reload = null, jitter = jitterMs } = {}) {
  if (typeof window === "undefined" || !globalThis.customElements) return;
  options = { socket, reload, jitter };
  if (!globalThis.customElements.get("yumemi-live")) globalThis.customElements.define("yumemi-live", YumemiLive);
}

export const internals = { keyOf, morph, remember, expiry, adopt };
