// yumemi yumemi/front ── 別の URL の Block を取って当てる道(0.14.1)。`Live` の runtime(`live_block.mjs`)と、
// `Live` の無い面の逃げ道の口 `yumemi.block` が共に使う。生成の `priv/static/_yumemi/client.mjs` が、逃げ道のある面で
// `start()` を呼ぶ(`Live` のある面は `live_block.mjs` の `start` が呼ぶ)。札も socket も持たない。
//
// - 断片の口:頁の URL を header `x-yumemi-block: <name>` で取ると、shell が `<style>` と、`Live` の Block なら
//   `<yumemi-live name edge token>`、`Fixed` の Block なら `<yumemi-block name>`(どちらも `display: contents`)を返す
// - 断片の `<style>` の規則のうち document の今の sheet に無いものを、構築した 1 枚の sheet に足す。在る規則の表は取る
//   たびに今の sheet から作り直す(client 遷移で頁の `<style>` が外れたら足し直す)
// - 当て方の 4 規則(87):1. 一致した節は動かさない(前へ進むだけの照合。節を動かす操作が無いので、focus と変換中
//   の文字を持つ節は document から一度も外れない) 2. interactive Component は tag と `data-yumemi-args` が同じなら
//   中に触らない。違えば、接続した時の control の値の写しと今の値が同じで focus も無いときだけ差し替え、そうで
//   なければ残して `:state(stale)` 3. 利用者の持ち物の属性は古い側を残す(`details` / `dialog` の `open`、focus の
//   ある control の値、`el.fresh` の `hidden`)。逃げ道は属性が同じなら中に触らない 4. 鍵は `data-yumemi-key`、
//   無ければ Component は tag+Args(当たらなければ同じ tag の Component)、それ以外は tag。前へ探す照合は、focus
//   のある節・書きかけのある Component / control を含む節を飛ばして消さない ── 後ろの新しい節がそれを受けられる
//   (同じ鍵で、中に同じ Component / control がある)なら、今の新しい節は新しく挿す
// - `<yumemi-block name href>` は合図を持たないので自分では読み直さない。`yumemi.block(name, { href })` を同じ URL で
//   呼ぶと、置かれた要素を取り直して当てる(当て方は `Live` と同じ)

export const blockHeader = "x-yumemi-block";

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
/// `<yumemi-live>` か `<yumemi-block>`、`<style>` の規則は足し済み)。門が頁を返さない(redirect・403・404)・200 でも断片の形でないなら
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
  const element = [...template.content.querySelectorAll("yumemi-live, yumemi-block")].find((item) => item.getAttribute("name") === name);
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

/// 来た `<yumemi-live>` / `<yumemi-block>`(document の外)を今の要素に当てる。何を変えたかの記録を返す。
export function morph(current, incoming) {
  const log = { changed: 0, inserted: 0, kept: [], stale: [], replaced: [] };
  morphChildren(current, incoming, log, guardsOf(current));
  return log;
}

// ── `<yumemi-block>`(`Live` でない Block、0.14.1)──────────────────────────────

const ElementBase = globalThis.HTMLElement ?? class {};

class YumemiBlock extends ElementBase {
  constructor() {
    super();
    this.yumemiFetching = null;
    this.yumemiAgain = false;
  }

  connectedCallback() {
    queueMicrotask(() => remember(this));
  }

  /// 取った URL(`href`)から取り直して当てる。当てたら true。取っている最中に呼ばれたら、終わった後にもう 1 回。
  /// 断片が来ない(門の redirect・403・404、断片の形でない)・5xx・通信の失敗は頁に触らず false(`yumemi-block-failed`)。
  refresh() {
    if (this.yumemiFetching) {
      this.yumemiAgain = true;
      return this.yumemiFetching;
    }
    const run = async () => {
      let applied = false;
      do {
        this.yumemiAgain = false;
        applied = await this.yumemiApply();
      } while (this.yumemiAgain && this.isConnected);
      return applied;
    };
    this.yumemiFetching = run().finally(() => { this.yumemiFetching = null; });
    return this.yumemiFetching;
  }

  async yumemiApply() {
    const name = this.getAttribute("name") ?? "";
    const result = await fetchBlock(name, this.getAttribute("href") ?? globalThis.location.href);
    if (!this.isConnected) return false;
    if (result === null || result.error) {
      this.dispatchEvent(new CustomEvent("yumemi-block-failed", { detail: { status: result?.status ?? null } }));
      return false;
    }
    const log = morph(this, result.element);
    this.dispatchEvent(new CustomEvent("yumemi-block-applied", { detail: log }));
    return true;
  }
}

// ── 口 ───────────────────────────────────────────────────────────────────────

/// 逃げ道の口(`mount(element, yumemi)` の `yumemi.block`)。`name` の Block を `href`(既定は今の URL)から取る。
/// 頁にその URL のその Block(`<yumemi-live>` か、前に置いた `<yumemi-block>`)があれば取り直して当て、その要素を返す。
/// 無ければ当てずに、規則を足した要素(document の外)を返す ── 逃げ道が置く(`replaceWith` など)。
/// `<yumemi-block>` はいつも、`<yumemi-live>` は別の URL のとき、取った URL を `href` に持つ。
/// 門が頁を返さない・その名の Block が頁に無い・取れないなら null(`Live` の Block が頁にあれば、その要素の決まりで
/// 頁ごと取り直すか待って取り直す ── 0.14.0 と同じ)。
export async function block(name, { href = globalThis.location.href } = {}) {
  const here = globalThis.location.href;
  const target = new URL(href, here);
  const same = (element) => {
    const at = new URL(element.getAttribute("href") ?? here, here);
    return at.pathname === target.pathname && at.search === target.search;
  };
  const current = [...globalThis.document.querySelectorAll("yumemi-live, yumemi-block")].find((item) => item.getAttribute("name") === name && same(item));
  if (current && typeof current.refresh === "function") {
    if (current.localName === "yumemi-live") {
      await current.refresh();
      return current.isConnected ? current : null;
    }
    const applied = await current.refresh();
    return applied && current.isConnected ? current : null;
  }
  const result = await fetchBlock(name, target.href);
  if (result === null || result.error) return null;
  const element = globalThis.document.importNode(result.element, true);
  const local = new URL(here);
  if (element.localName === "yumemi-block" || target.pathname !== local.pathname || target.search !== local.search) element.setAttribute("href", target.href);
  return element;
}

/// `<yumemi-block>` を定め、`display: contents` の規則を足す(`Live` の無い面の頁の `<style>` には無い)。
export function start() {
  if (typeof window === "undefined" || !globalThis.customElements) return;
  if (globalThis.customElements.get("yumemi-block")) return;
  globalThis.customElements.define("yumemi-block", YumemiBlock);
  try {
    const sheet = new CSSStyleSheet();
    sheet.replaceSync("yumemi-block { display: contents; }");
    globalThis.document.adoptedStyleSheets = [...globalThis.document.adoptedStyleSheets, sheet];
  } catch (_error) { /* 構築した sheet の無い browser:Block は箱のまま描かれる */ }
}

export const internals = { keyOf, morph, remember, adopt };
