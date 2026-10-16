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

// 断片の取り・CSS・当て方・逃げ道の口 `block` は `block.mjs`(`Live` でない Block と共に使う、0.14.1)
import { fetchBlock, internals as blockInternals, morph, remember, start as startBlock } from "./block.mjs";

export { adopt, block, fetchBlock, morph, remember } from "./block.mjs";

const minDelay = 1000;
const maxDelay = 30000;
const jitterMs = 500;
const renewBeforeMs = 60000;
const stableMs = 30000;
const atEdgePx = 8;

let options = { socket: "/_yumemi/live", reload: null, jitter: jitterMs };

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
// 逃げ道の口 `block` は `block.mjs` のもの(`<yumemi-live>` の振る舞いは 0.14.0 と同じ)を上で出している。

export function start({ socket = "/_yumemi/live", reload = null, jitter = jitterMs } = {}) {
  if (typeof window === "undefined" || !globalThis.customElements) return;
  options = { socket, reload, jitter };
  startBlock();
  if (!globalThis.customElements.get("yumemi-live")) globalThis.customElements.define("yumemi-live", YumemiLive);
}

export const internals = { ...blockInternals, expiry };
