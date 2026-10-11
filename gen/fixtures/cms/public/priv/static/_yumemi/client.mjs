// GENERATED from public/src/{shell,gate}.gleam [sha256:c798b715f0e0] — 手で編集しない
// public/build/dev/javascript/yumemi/yumemi/front/pageview.mjs
var mark = 'meta[name="yumemi-pageview"]';
var uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
function marked(doc = globalThis.document) {
  return doc?.head?.querySelector(mark) != null || doc?.querySelector?.(mark) != null;
}
function pageviewPayload({ fields, id, at, kind, url, previous, from, origin }) {
  const payload = { id };
  for (const field of fields) {
    switch (field.type) {
      case "kind":
        payload.kind = kind;
        break;
      case "client_at":
        payload.client_at = at;
        break;
      case "path":
        payload.path = url.pathname;
        break;
      case "previous":
        if (previous) payload.prev = previous;
        break;
      case "referrer": {
        if (previous || !from) break;
        try {
          const referrer = new URL(from);
          if (referrer.origin === origin) payload.referrer_path = referrer.pathname;
          else payload.referrer_host = referrer.host;
        } catch (_) {
        }
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
  if ("requestIdleCallback" in globalThis) globalThis.requestIdleCallback(run, { timeout: 1e3 });
  else globalThis.requestAnimationFrame?.(run) ?? setTimeout(run, 0);
}
function start({ endpoint, key, fields }) {
  if (typeof window === "undefined" || typeof document === "undefined") return;
  const send = (kind, url, from) => {
    const previous = readPrevious(key);
    const id = crypto.randomUUID();
    const body = JSON.stringify(pageviewPayload({
      fields,
      id,
      at: (/* @__PURE__ */ new Date()).toISOString(),
      kind,
      url,
      previous,
      from,
      origin: location.origin
    }));
    try {
      sessionStorage.setItem(key, id);
    } catch (_) {
    }
    const post = () => fetch(endpoint, { method: "POST", headers: { "content-type": "application/json" }, body, keepalive: true });
    void post().catch(() => post().catch(() => {
    }));
  };
  const shown = new URL(location.href);
  const entry = performance.getEntriesByType?.("navigation")?.[0];
  try {
    if (window.opener && entry?.type === "navigate") sessionStorage.removeItem(key);
  } catch (_) {
  }
  if (marked()) {
    const initial = () => idle(() => send(entry?.type === "reload" ? "reload" : "initial", shown, document.referrer || null));
    const afterLoad = () => {
      if (document.readyState === "complete") initial();
      else window.addEventListener("load", initial, { once: true });
    };
    if (document.prerendering) document.addEventListener("prerenderingchange", afterLoad, { once: true });
    else afterLoad();
  }
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
    if (navigated === null || navigation.transition == null || !marked()) return;
    const url = new URL(location.href);
    idle(() => send(navigated.type === "reload" ? "reload" : "spa", url, navigated.from));
  });
}

// client-entry.mjs
start({ endpoint: "/api/_yumemi/pageviews", key: "yumemi:pageview:public", fields: [{ type: "kind" }, { type: "client_at" }, { type: "path" }, { type: "previous" }, { type: "referrer" }, { type: "query", name: "source_key", param: "r", max: 16 }] });
