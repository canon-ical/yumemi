// yumemi yumemi/front ── 数える口の送り手(0.12)。生成の `priv/static/_yumemi/client.mjs` が
// `start({endpoint, key, fields})` を 1 回呼ぶ。送り手はこれ 1 つで、門の inline の script も navigate.mjs も送らない。
//
// 門は数える頁(`pageview` の Page・条件 `only` を満たす要求・200 の HTML)に `<meta name="yumemi-pageview">` を差す
// だけ。送り手は次の 2 回だけ、今の document にその印があれば 1 回ずつ送る。
// - 頁の読み込み:`load` の後の `requestIdleCallback`。prerender の間は送らず activation(`prerenderingchange`)を
//   待つ。kind は navigation の種類が `reload` なら `reload`、他は `initial`。bfcache から戻った頁は数えない
// - client の遷移:Navigation API の `navigatesuccess`(遷移の側が来た頁の印を今の document に置いた後)。kind は
//   その遷移の `navigate` の種類が `reload` なら `reload`、他(`push` / `replace` / `traverse`)は `spa`。
//   数えるのは遷移の側が `intercept()` で取った移動(`navigation.transition` が null でない)だけで、fragment だけの
//   遷移と、頁の替わらない `history.pushState` / `replaceState`(transition は null)は数えない
//
// 本文の欄は門の `fields` の宣言だけ。event の id(`crypto.randomUUID()`)は常に足す。送りに失敗したら同じ本文で
// 1 回だけ送り直す(同じ id なので受け口が重ねない)。前の event の id は sessionStorage の `key` に持つ。

const mark = 'meta[name="yumemi-pageview"]';
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

/// 今の document に門の数える印があるか。
export function marked(doc = globalThis.document) {
  return doc?.head?.querySelector(mark) != null || doc?.querySelector?.(mark) != null;
}

/// 送る本文。`fields` は門の宣言(`{type}` の並び、`query` は `{name, param, max}`)、`url` は数える頁の URL、
/// `from` は前の頁の URL の文字列か null(頁の読み込みでは `document.referrer`、client 遷移では遷移の元)。
export function pageviewPayload({ fields, id, at, kind, url, previous, from, origin }) {
  const payload = { id };
  for (const field of fields) {
    switch (field.type) {
      case "kind": payload.kind = kind; break;
      case "client_at": payload.client_at = at; break;
      case "path": payload.path = url.pathname; break;
      case "previous": if (previous) payload.prev = previous; break;
      case "referrer": {
        if (previous || !from) break;
        try {
          const referrer = new URL(from);
          if (referrer.origin === origin) payload.referrer_path = referrer.pathname;
          else payload.referrer_host = referrer.host;
        } catch (_) {}
        break;
      }
      case "query": {
        const value = url.searchParams.get(field.param);
        if (value && new RegExp("^[a-z0-9_]{1," + field.max + "}$").test(value)) payload[field.name] = value;
        break;
      }
    }
  }
  return payload;
}

function readPrevious(key) {
  try {
    const value = sessionStorage.getItem(key);
    return value && uuid.test(value) ? value : null;
  } catch (_) {
    return null;
  }
}

function idle(run) {
  if ("requestIdleCallback" in globalThis) globalThis.requestIdleCallback(run, { timeout: 1000 });
  else globalThis.requestAnimationFrame?.(run) ?? setTimeout(run, 0);
}

export function start({ endpoint, key, fields }) {
  if (typeof window === "undefined" || typeof document === "undefined") return;
  const send = (kind, url, from) => {
    const previous = readPrevious(key);
    const id = crypto.randomUUID();
    const body = JSON.stringify(pageviewPayload({
      fields, id, at: new Date().toISOString(), kind, url, previous, from, origin: location.origin,
    }));
    try { sessionStorage.setItem(key, id); } catch (_) {}
    const post = () => fetch(endpoint, { method: "POST", headers: { "content-type": "application/json" }, body, keepalive: true });
    void post().catch(() => post().catch(() => {}));
  };

  // 頁の読み込み:走った時の頁を数える(送る前に client の遷移で頁が替わっても、この頁)
  const shown = new URL(location.href);
  const entry = performance.getEntriesByType?.("navigation")?.[0];
  // 新しい tab(opener のある navigate)では、元の tab の鎖を引き継がない
  try { if (window.opener && entry?.type === "navigate") sessionStorage.removeItem(key); } catch (_) {}
  if (marked()) {
    const initial = () => idle(() => send(entry?.type === "reload" ? "reload" : "initial", shown, document.referrer || null));
    const afterLoad = () => {
      if (document.readyState === "complete") initial();
      else window.addEventListener("load", initial, { once: true });
    };
    if (document.prerendering) document.addEventListener("prerenderingchange", afterLoad, { once: true });
    else afterLoad();
  }

  // client の遷移:navigate の種類を覚え、navigatesuccess で今の document の印を見る
  const navigation = globalThis.navigation;
  if (!navigation?.addEventListener) return;
  let pending = null;
  let current = location.href;
  navigation.addEventListener("navigate", (event) => {
    pending = event.hashChange || event.downloadRequest != null ? null : { type: event.navigationType, from: current };
  });
  navigation.addEventListener("navigatesuccess", () => {
    const navigated = pending;
    pending = null;
    current = location.href;
    // 島の `pushState` / `replaceState` も `navigatesuccess` を出すが、transition は null で印は今の頁のまま
    if (navigated === null || navigation.transition == null || !marked()) return;
    const url = new URL(location.href);
    idle(() => send(navigated.type === "reload" ? "reload" : "spa", url, navigated.from));
  });
}
