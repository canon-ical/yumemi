// yumemi yumemi/front ── `Live` の Block の runtime(0.15、87「案 (i′)」)。生成の `priv/static/_yumemi/client.mjs`
// が `start({socket, reload})` を呼ぶ。★ は Page の placements に `Live(.., edge:)` と書くだけで、ここは目に無い。
//
// - `<yumemi-live name edge token>`(`display: contents`)は shell が `Live` の Block の外に描く。接続すると札
//   (`token`、yumemi-live-1 の `x-yumemi-live`)で `wss://<host><socket>?token=` を張る。札が無ければ張らない
// - 合図は `1` の 1 字だけ(本文も差分も載らない)。受けたら 0〜500ms の揺らぎの後、今の URL を header
//   `x-yumemi-block: <name>` で取り直し、返った断片(`<style>` と `<yumemi-live>`)を今の Block に当てる。取っている
//   最中の合図は「終わったらもう 1 回」の 1 つに畳む。client は本文を組まない ── 当てるのは server の描いた HTML
// - 断片が 200 の HTML でない(門の redirect・403・404、root の 404)なら頁ごと取り直す(navigate の `reload`、
//   無ければ頁の読み込み)
// - 断片の `<style>` の規則のうち document に無いものを、構築した 1 枚の sheet に足す(sched-css の穴)
// - 当て方の 4 規則(87):1. 一致した節は動かさない(前へ進むだけの照合。節を動かす操作が無いので、focus と変換中
//   の文字を持つ節は document から一度も外れない) 2. interactive Component は tag と `data-yumemi-args` が同じなら
//   中に触らない。違えば、接続した時の control の値の写しと今の値が同じで focus も無いときだけ差し替え、そうで
//   なければ残して `:state(stale)` 3. 利用者の持ち物の属性は古い側を残す(`details` / `dialog` の `open`、focus の
//   ある control の値、`el.fresh` の `hidden`)。逃げ道は属性が同じなら中に触らない 4. 鍵は `data-yumemi-key`、
//   無ければ Component は tag+Args(当たらなければ同じ tag の Component)、それ以外は tag
// - スクロール:`bottom` は当てる前に端にいれば当てた後も端へ追い、上を読んでいれば留まって `el.fresh` を出す。
//   `top` は頭にいれば頭のまま、読んでいれば留まって印。`anywhere` は留まる。留まるときは、見えていた先頭の節の
//   位置を当てる前と同じに戻す(browser の scroll anchoring の無いときの代わり)
// - 繋ぎ直し:切れたら 1 秒から倍々(上限 30 秒)で張り直し、張り直して繋がったら 1 回取り直す。頁が見えるように
//   なったら(`visibilitychange`)待たずに張り直して 1 回取り直す。札の期限(payload の `exp`)の 1 分前に取り直し、
//   来た札で張り直す。server が期限で閉じた(`4001`)・張れなかったときも、先に取り直して新しい札で張る

const blockHeader = "x-yumemi-block";
const minDelay = 1000;
const maxDelay = 30000;
const jitterMs = 500;
const renewBeforeMs = 60000;
const atEdgePx = 8;

let options = { socket: "/_yumemi/live", reload: null, jitter: jitterMs };

// ── 断片の取りと CSS ──────────────────────────────────────────────────────────

let adopted = null;
const knownRules = new Set();
let knownSheets = new WeakSet();

function sheetRules(sheet) {
  try { return [...sheet.cssRules]; } catch (_error) { return []; }
}

function noteDocumentRules() {
  for (const sheet of [...globalThis.document.styleSheets, ...globalThis.document.adoptedStyleSheets]) {
    if (sheet === adopted || knownSheets.has(sheet)) continue;
    knownSheets.add(sheet);
    for (const rule of sheetRules(sheet)) knownRules.add(rule.cssText);
  }
}

/// 断片の `<style>` の規則のうち document に無いものを足す。足した数を返す。
export function adopt(text) {
  const document = globalThis.document;
  if (!adopted) {
    adopted = new CSSStyleSheet();
    document.adoptedStyleSheets = [...document.adoptedStyleSheets, adopted];
  }
  noteDocumentRules();
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
/// `<yumemi-live>`、`<style>` の規則は足し済み)、門が頁を返さなければ null。
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
  if (response.type === "opaqueredirect" || response.status !== 200 || !type.startsWith("text/html")) return null;
  const template = globalThis.document.createElement("template");
  template.innerHTML = await response.text();
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

function morphNode(old, incoming, log) {
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
  morphChildren(old, incoming, log);
}

function findAhead(olds, from, key) {
  for (let index = from; index < olds.length; index += 1) if (keyOf(olds[index]) === key) return index;
  return -1;
}

function findLoose(olds, from, loose) {
  for (let index = from; index < olds.length; index += 1) if (looseKey(olds[index]) === loose) return index;
  return -1;
}

function morphChildren(oldParent, newParent, log) {
  const olds = [...oldParent.childNodes];
  let at = 0;
  for (const incoming of [...newParent.childNodes]) {
    let found = findAhead(olds, at, keyOf(incoming));
    const loose = looseKey(incoming);
    if (found < 0 && loose !== null) {
      found = findLoose(olds, at, loose);
      // 当たった古い Component が、新しい側で鍵(tag+Args)どおりに後で当たるなら、ここでは使わない
      if (found >= 0 && [...newParent.childNodes].some((other) => other !== incoming && keyOf(other) === keyOf(olds[found]))) found = -1;
    }
    if (found >= 0) {
      for (let index = at; index < found; index += 1) {
        olds[index].remove();
        log.changed += 1;
      }
      morphNode(olds[found], incoming, log);
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
  morphChildren(current, incoming, log);
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
    this.yumemiRenew = null;
    this.yumemiFetching = null;
    this.yumemiAgain = false;
    this.yumemiWaiting = null;
    this.yumemiOpened = false;
    this.yumemiReopen = false;
    this.yumemiStale = false;
    this.yumemiCleanup = null;
  }

  connectedCallback() {
    if (this.yumemiCleanup) return;
    queueMicrotask(() => remember(this));
    const onVisible = () => {
      if (globalThis.document.visibilityState !== "visible") return;
      this.yumemiDelay = minDelay;
      if (!this.yumemiSocket) {
        clearTimeout(this.yumemiRetry);
        this.yumemiRetry = null;
        this.yumemiConnect(true);
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
    this.yumemiConnect(false);
  }

  disconnectedCallback() {
    this.yumemiCleanup?.();
    this.yumemiCleanup = null;
    clearTimeout(this.yumemiRetry);
    clearTimeout(this.yumemiRenew);
    clearTimeout(this.yumemiWaiting);
    this.yumemiRetry = this.yumemiRenew = this.yumemiWaiting = null;
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

  /// 札で socket を張る。`refreshOnOpen` は繋がったら 1 回取り直す(切れていた間の合図を拾う)。
  yumemiConnect(refreshOnOpen) {
    if (!this.isConnected) return;
    this.yumemiClose();
    const token = this.getAttribute("token");
    if (!token) return;
    const exp = expiry(token);
    clearTimeout(this.yumemiRenew);
    if (exp !== null) {
      if (exp - Date.now() <= renewBeforeMs) {
        // 期限の近い・過ぎた札では張らない。取り直して来た札で張る
        void this.refresh().then(() => this.yumemiConnectAfterRefresh(token));
        return;
      }
      // 期限の 1 分前に取り直し、来た札で張り直す(server が期限で閉じる前に替える)
      this.yumemiRenew = setTimeout(() => {
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
      this.yumemiDelay = minDelay;
      this.dispatchEvent(new CustomEvent("yumemi-live-open"));
      if (refreshOnOpen) void this.refresh();
    };
    socket.onmessage = (event) => {
      if (event.data === "1") this.signal();
    };
    socket.onclose = (event) => {
      this.yumemiLastClose = event.code;
      if (this.yumemiSocket !== socket) return;
      this.yumemiSocket = null;
      // 期限(4001)・張れなかった(開く前に閉じた)は札を替えてから張る
      this.yumemiScheduleRetry(event.code === 4001 || !this.yumemiOpened);
    };
  }

  yumemiConnectAfterRefresh(previous) {
    if (!this.isConnected || this.yumemiSocket) return;
    const token = this.getAttribute("token");
    if (!token || token === previous) {
      // 札が替わらなかった(断片が来なかった・api に鍵が無い)。倍々で待って取り直しからやり直す
      this.yumemiScheduleRetry(true);
      return;
    }
    this.yumemiConnect(false);
  }

  yumemiScheduleRetry(renew) {
    if (!this.isConnected) return;
    clearTimeout(this.yumemiRetry);
    const delay = this.yumemiDelay;
    this.yumemiDelay = Math.min(delay * 2, maxDelay);
    this.yumemiRetry = setTimeout(async () => {
      this.yumemiRetry = null;
      if (renew) {
        const before = this.getAttribute("token");
        await this.refresh();
        if (!this.isConnected || this.yumemiSocket) return;
        if (this.getAttribute("token") === before) {
          this.yumemiScheduleRetry(true);
          return;
        }
        this.yumemiConnect(false);
      } else this.yumemiConnect(true);
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

  /// 今の URL の Block を取り直して当てる。取っている最中に呼ばれたら、終わった後にもう 1 回。
  refresh() {
    if (this.yumemiFetching) {
      this.yumemiAgain = true;
      return this.yumemiFetching;
    }
    const run = async () => {
      do {
        this.yumemiAgain = false;
        await this.yumemiApply(globalThis.location.href);
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
    if (result.error) return null;
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
/// 今の URL の Block で、頁にその `<yumemi-live>` があれば取り直して当て(合図と同じ当て方)、その要素を返す。
/// 別の URL なら当てずに、規則を足した `<yumemi-live>`(document の外)を返す ── 逃げ道が置く(`replaceWith` など)。
/// 門が頁を返さなければ null(今の URL なら頁ごと取り直す)。
export async function block(name, { href = globalThis.location.href } = {}) {
  const target = new URL(href, globalThis.location.href);
  const here = new URL(globalThis.location.href);
  const current = [...globalThis.document.querySelectorAll("yumemi-live")].find((item) => item.getAttribute("name") === name);
  if (current && target.pathname === here.pathname && target.search === here.search && typeof current.refresh === "function") {
    await current.refresh();
    return current.isConnected ? current : null;
  }
  const result = await fetchBlock(name, target.href);
  if (result === null || result.error) return null;
  return globalThis.document.importNode(result.element, true);
}

export function start({ socket = "/_yumemi/live", reload = null, jitter = jitterMs } = {}) {
  if (typeof window === "undefined" || !globalThis.customElements) return;
  options = { socket, reload, jitter };
  if (!globalThis.customElements.get("yumemi-live")) globalThis.customElements.define("yumemi-live", YumemiLive);
}

export const internals = { keyOf, morph, remember, expiry, adopt };
