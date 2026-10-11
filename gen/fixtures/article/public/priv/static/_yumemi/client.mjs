// GENERATED from public/src/components/*.gleam, src/escapes/*.mjs and src/entry.gleam [sha256:a59c8fadc3ee] — 手で編集しない
// public/build/dev/javascript/yumemi/yumemi/front/interactive.mjs
var noticeKey = "yumemi:notice";
function setStates(element, names) {
  const internals = element.yumemiInternals;
  const states = internals?.states;
  if (states && typeof states.add === "function") {
    try {
      for (const name of [...states]) states.delete(name);
      for (const name of names) states.add(name);
      return;
    } catch (_error) {
    }
  }
  if (names.length === 0) element.removeAttribute("data-yumemi-state");
  else element.setAttribute("data-yumemi-state", names.join(" "));
}
function kebab(code) {
  return String(code).replaceAll("_", "-").toLowerCase();
}
function scalar(kind, value) {
  switch (kind) {
    case "bool":
      if (value === "true" || value === "True" || value === "on") return true;
      if (value === "false" || value === "False" || value === "") return false;
      return value;
    case "int": {
      const number = Number(value);
      return value !== "" && Number.isInteger(number) ? number : value;
    }
    case "float": {
      const number = Number(value);
      return value !== "" && Number.isFinite(number) ? number : value;
    }
    default:
      return value;
  }
}
function wireValue(wire, value) {
  if (typeof wire === "object" && wire !== null) {
    if ("option" in wire) return value === "" || value === null ? null : wireValue(wire.option, value);
    if ("list" in wire) {
      const items = Array.isArray(value) ? value : (() => {
        if (value === "" || value == null) return [];
        try {
          const parsed = JSON.parse(value);
          return Array.isArray(parsed) ? parsed : [value];
        } catch (_error) {
          return [value];
        }
      })();
      return items.map((item) => scalar(wire.list, String(item)));
    }
  }
  if (wire === "json") {
    if (typeof value !== "string") return value;
    try {
      return JSON.parse(value);
    } catch (_error) {
      return value;
    }
  }
  return scalar(wire, Array.isArray(value) ? value[0] ?? "" : value ?? "");
}
function fillPath(path, values) {
  return path.replace(/:([A-Za-z0-9_]+)/g, (_match, name) => encodeURIComponent(String(values?.[name] ?? "")));
}
function readPath(value, path) {
  let current = value;
  for (const part of path.split(".")) {
    if (current === null || typeof current !== "object") return void 0;
    current = current[part];
  }
  return current;
}
function textOf(value) {
  if (value === void 0 || value === null) return "";
  if (typeof value === "object") {
    if ("value" in value && Object.keys(value).length === 1) return textOf(value.value);
    return "";
  }
  return String(value);
}
function putNotice(text) {
  if (typeof text !== "string" || text === "") return;
  try {
    globalThis.sessionStorage?.setItem(noticeKey, text);
  } catch (_error) {
  }
}
function showNotice(root = globalThis.document) {
  let text = null;
  try {
    text = globalThis.sessionStorage?.getItem(noticeKey) ?? null;
  } catch (_error) {
    return;
  }
  if (text === null) return;
  const place = root?.querySelector?.("[data-yumemi-notice]");
  if (!place) return;
  try {
    globalThis.sessionStorage.removeItem(noticeKey);
  } catch (_error) {
  }
  place.textContent = text;
  place.hidden = false;
}
async function upload(file) {
  const response = await fetch("/api/blobs", {
    method: "POST",
    headers: { "content-type": file.type || "application/octet-stream" },
    body: file
  });
  if (!response.ok) throw new Error("blob upload failed");
  const result = await response.json();
  if (typeof result?.key !== "string" || result.key === "") throw new Error("blob response has no key");
  return result.key;
}
function controlsOf(form, service) {
  return [...form.elements].filter((control) => typeof control.name === "string" && control.name.startsWith(`${service}.`));
}
function collect(controls, service) {
  const values = /* @__PURE__ */ new Map();
  const push = (name, value) => {
    const field = name.slice(service.length + 1);
    if (!values.has(field)) values.set(field, []);
    if (value !== void 0) values.get(field).push(value);
  };
  for (const control of controls) {
    if (control.disabled) continue;
    const type = (control.type ?? "").toLowerCase();
    if (type === "checkbox") {
      const group = controls.filter((other) => other.name === control.name);
      if (group.length > 1) push(control.name, control.checked ? control.value : void 0);
      else push(control.name, control.checked ? "true" : "false");
    } else if (type === "radio") push(control.name, control.checked ? control.value : void 0);
    else if (type === "file") push(control.name, control.files?.[0] ?? void 0);
    else if (control instanceof HTMLSelectElement && control.multiple) {
      for (const option of control.selectedOptions) push(control.name, option.value);
      if (control.selectedOptions.length === 0) push(control.name, void 0);
    } else if (type === "submit" || type === "button" || type === "reset") continue;
    else push(control.name, control.value);
  }
  return values;
}
async function buildArgs(spec, initial, controls, serviceName) {
  const collected = collect(controls, serviceName);
  const args = {};
  for (const arg of spec.args) {
    const isList = typeof arg.wire === "object" && arg.wire !== null && "list" in arg.wire;
    let raw = initial?.[arg.name] ?? "";
    if (collected.has(arg.name)) {
      const items = collected.get(arg.name);
      const files = items.filter((item) => typeof File !== "undefined" && item instanceof File);
      if (files.length > 0) raw = await upload(files[0]);
      else if (isList) raw = items;
      else if (items.length > 0) raw = items[items.length - 1];
      else if (!arg.blob) raw = "";
    }
    args[arg.name] = wireValue(arg.wire, raw);
  }
  return args;
}
async function call(spec, args, signal, uploadFile) {
  if (spec.upload) {
    if (uploadFile) {
      return fetch(spec.path, {
        method: spec.method,
        headers: { "content-type": uploadFile.type || "application/octet-stream" },
        body: uploadFile,
        signal
      });
    }
    if (typeof args.from !== "string" || args.from === "") throw Object.assign(new Error("no file"), { code: "invalid_argument" });
    return fetch(spec.path, {
      method: spec.method,
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ from: args.from }),
      signal
    });
  }
  let path = fillPath(spec.path, args);
  if (spec.method === "GET") {
    const holes = new Set([...spec.path.matchAll(/:([A-Za-z0-9_]+)/g)].map((match) => match[1]));
    const query = new URLSearchParams();
    for (const arg of spec.args) {
      if (holes.has(arg.name)) continue;
      const value = args[arg.name];
      if (value === null || value === void 0) continue;
      if (Array.isArray(value)) for (const item of value) query.append(arg.name, String(item));
      else query.append(arg.name, String(value));
    }
    const text = query.toString();
    if (text !== "") path = `${path}?${text}`;
  }
  return fetch(path, {
    method: spec.method,
    credentials: "same-origin",
    headers: { "content-type": "application/json", accept: "application/json" },
    // attached の口で本文の欄が無いものは 0.11 と同じく null を送る
    body: spec.method === "GET" ? void 0 : spec.entry && spec.args.length === 0 ? "null" : JSON.stringify(args),
    signal
  });
}
var hooks = { go: null, reload: null };
function follow(then, out) {
  if (!then || then.then === "stay") return;
  putNotice(then.notice);
  if (then.then === "reload") {
    if (hooks.reload) hooks.reload();
    else globalThis.location.assign(globalThis.location.href);
    return;
  }
  if (then.then === "goto") {
    const href = fillPath(then.path, out);
    if (hooks.go) hooks.go(href, {});
    else globalThis.location.assign(href);
  }
}
var ElementBase = globalThis.HTMLElement ?? class {
};
var YumemiInteractive = class extends ElementBase {
  static yumemiSpec = null;
  constructor() {
    super();
    try {
      this.yumemiInternals = this.attachInternals();
    } catch (_error) {
      this.yumemiInternals = null;
    }
    this.yumemiReading = null;
    this.yumemiSending = false;
    this.yumemiCleanup = null;
  }
  get yumemiInitial() {
    try {
      return JSON.parse(this.getAttribute("data-yumemi-args") ?? "{}");
    } catch (_error) {
      return {};
    }
  }
  connectedCallback() {
    const spec = this.constructor.yumemiSpec;
    const form = this.querySelector(":scope > form");
    if (!spec || !form || this.yumemiCleanup) return;
    const onSubmit = (event) => {
      event.preventDefault();
      void this.yumemiSubmit(event, form, spec);
    };
    const onChange = (event) => this.yumemiChange(event, form, spec);
    form.addEventListener("submit", onSubmit);
    form.addEventListener("change", onChange);
    this.yumemiCleanup = () => {
      form.removeEventListener("submit", onSubmit);
      form.removeEventListener("change", onChange);
      this.yumemiReading?.abort();
      this.yumemiReading = null;
    };
  }
  disconnectedCallback() {
    this.yumemiCleanup?.();
    this.yumemiCleanup = null;
  }
  yumemiBusy(form, busy) {
    const fieldset = form.querySelector(":scope > fieldset");
    if (fieldset) fieldset.disabled = busy;
    if (busy) this.setAttribute("aria-busy", "true");
    else this.removeAttribute("aria-busy");
  }
  async yumemiSubmit(event, form, spec) {
    const submitter = event.submitter;
    const service = submitter?.getAttribute?.("data-yumemi-send");
    if (!service || !Object.hasOwn(spec.services, service) || this.yumemiSending) return;
    const active = globalThis.document.activeElement;
    if (active && active !== submitter && form.contains(active) && typeof active.name === "string" && active.name.includes(".")) {
      const focused = active.name.slice(0, active.name.indexOf("."));
      if (focused !== service) return;
    }
    const serviceSpec = spec.services[service];
    const controls = controlsOf(form, service);
    for (const control of controls) {
      if (typeof control.checkValidity === "function" && !control.checkValidity()) {
        control.reportValidity?.();
        return;
      }
    }
    this.yumemiReading?.abort();
    this.yumemiReading = null;
    this.yumemiSending = true;
    const initial = this.yumemiInitial[service] ?? {};
    let outcome;
    try {
      const fileControl = serviceSpec.upload ? controls.find((control) => control.type === "file") : null;
      const args = await buildArgs(serviceSpec, initial, controls, service);
      setStates(this, ["waiting", `sent-${service}`]);
      this.yumemiBusy(form, true);
      outcome = await this.yumemiCall(serviceSpec, args, null, fileControl?.files?.[0]);
    } catch (error) {
      outcome = { ok: false, value: { code: error?.code ?? "network_error" } };
    } finally {
      this.yumemiSending = false;
      this.yumemiBusy(form, false);
    }
    this.yumemiDone(service, serviceSpec, outcome);
    if (!serviceSpec.read) follow(outcome.ok ? serviceSpec.ok : serviceSpec.error, outcome.value);
  }
  async yumemiCall(serviceSpec, args, signal, file) {
    const response = await call(serviceSpec, args, signal, file);
    let value = null;
    try {
      value = await response.json();
    } catch (_error) {
      value = response.ok ? null : { code: "request_failed" };
    }
    return { ok: response.ok, value };
  }
  yumemiDone(service, serviceSpec, outcome) {
    if (outcome.ok) {
      setStates(this, ["ok", `sent-${service}`]);
      for (const place of this.querySelectorAll(`[data-yumemi-out^="${service}."]`)) {
        const slot = place.getAttribute("data-yumemi-out").slice(service.length + 1);
        const path = serviceSpec.slots?.[slot] ?? slot;
        place.textContent = textOf(readPath(outcome.value, path));
      }
    } else {
      const code = outcome.value?.code;
      const names = ["error", `sent-${service}`];
      if (typeof code === "string" && (serviceSpec.refused ?? []).includes(code)) names.push(`refused-${kebab(code)}`);
      setStates(this, names);
    }
  }
  yumemiChange(event, form, spec) {
    const reloads = spec.reloads;
    const target = event.target;
    if (!reloads || typeof target?.name !== "string") return;
    const prefix = `${reloads.read}.`;
    if (!target.name.startsWith(prefix) || !reloads.on.includes(target.name.slice(prefix.length))) return;
    const serviceSpec = spec.services[reloads.read];
    if (reloads.list) {
      const url = new URL(globalThis.location.href);
      for (const field of reloads.on) {
        const control = form.elements.namedItem(`${prefix}${field}`);
        const value = control && "value" in control ? control.value : "";
        if (value === "") url.searchParams.delete(field);
        else url.searchParams.set(field, value);
      }
      const keep = { tag: this.localName, name: target.name };
      if (hooks.go) hooks.go(url.href, { replace: true, keep });
      else globalThis.location.replace(url.href);
      return;
    }
    this.yumemiReading?.abort();
    const controller = new AbortController();
    this.yumemiReading = controller;
    const controls = controlsOf(form, reloads.read);
    const initial = this.yumemiInitial[reloads.read] ?? {};
    setStates(this, ["waiting", `sent-${reloads.read}`]);
    void (async () => {
      let outcome;
      try {
        const args = await buildArgs(serviceSpec, initial, controls, reloads.read);
        outcome = await this.yumemiCall(serviceSpec, args, controller.signal, null);
      } catch (error) {
        if (controller.signal.aborted) return;
        outcome = { ok: false, value: { code: error?.code ?? "network_error" } };
      }
      if (controller.signal.aborted) return;
      this.yumemiReading = null;
      this.yumemiDone(reloads.read, serviceSpec, outcome);
    })();
  }
};
var YumemiEscape = class _YumemiEscape extends ElementBase {
  static yumemiMounts = {};
  connectedCallback() {
    if (this.yumemiUnmount !== void 0) return;
    const mount2 = _YumemiEscape.yumemiMounts[this.getAttribute("name") ?? ""];
    if (typeof mount2 !== "function") return;
    try {
      const unmount = mount2(this);
      this.yumemiUnmount = typeof unmount === "function" ? unmount : null;
    } catch (_error) {
      this.yumemiUnmount = null;
    }
  }
  disconnectedCallback() {
    const unmount = this.yumemiUnmount;
    this.yumemiUnmount = void 0;
    if (typeof unmount === "function") {
      try {
        unmount();
      } catch (_error) {
      }
    }
  }
};
function dialogFallback() {
  const prototype = globalThis.HTMLButtonElement?.prototype;
  if (!prototype || "commandForElement" in prototype) return;
  globalThis.document.addEventListener("click", (event) => {
    const button = event.target?.closest?.("button[command][commandfor]");
    if (!button) return;
    const dialog = globalThis.document.getElementById(button.getAttribute("commandfor"));
    if (!(dialog instanceof HTMLDialogElement)) return;
    const command = button.getAttribute("command");
    if (command === "show-modal" && !dialog.open) dialog.showModal();
    else if (command === "close" && dialog.open) dialog.close();
  });
}
function start({ components = {}, escapes = {}, go: go2 = null, reload: reload2 = null } = {}) {
  if (typeof window === "undefined" || !globalThis.customElements) return;
  hooks = { go: go2, reload: reload2 };
  for (const [tag, spec] of Object.entries(components)) {
    if (globalThis.customElements.get(tag)) continue;
    globalThis.customElements.define(tag, class extends YumemiInteractive {
      static yumemiSpec = spec;
    });
  }
  YumemiEscape.yumemiMounts = { ...YumemiEscape.yumemiMounts, ...escapes };
  if (!globalThis.customElements.get("yumemi-escape")) globalThis.customElements.define("yumemi-escape", YumemiEscape);
  dialogFallback();
  showNotice();
  globalThis.navigation?.addEventListener?.("navigatesuccess", () => showNotice());
}

// public/build/dev/javascript/yumemi/yumemi/front/navigate.mjs
var clientSrc = "/_yumemi/client.mjs";
var navigateHeader = "x-yumemi-navigate";
var pageviewName = "yumemi-pageview";
function matches(route, pathname) {
  const expected = route.split("/");
  const actual = pathname.split("/");
  if (expected.length !== actual.length) return false;
  return expected.every((segment, index) => segment.startsWith(":") ? actual[index] !== "" : segment === actual[index] || segment.replaceAll("_", "-") === actual[index]);
}
function row(entry) {
  return typeof entry === "string" ? { route: entry, csp: null } : { route: entry.route, csp: entry.csp ?? null };
}
function policy(routes, pathname) {
  let found;
  for (const entry of routes) {
    const { route, csp } = row(entry);
    if (!matches(route, pathname)) continue;
    if (found !== void 0 && found !== csp) return void 0;
    found = csp;
  }
  return found;
}
function routed(routes, pathname) {
  return policy(routes, pathname) !== void 0;
}
function samePolicy(headers, csp) {
  return (headers.get("content-security-policy") ?? null) === csp;
}
var refreshInfo = { yumemi: "reload" };
var goInfo = "go";
function accept(event, routes, location, loaded = policy(routes, location.pathname)) {
  if (!event.canIntercept || event.defaultPrevented || event.hashChange) return null;
  if (event.downloadRequest != null || event.formData != null) return null;
  const type = event.navigationType;
  if (type === "reload" ? event.info?.yumemi !== refreshInfo.yumemi : type !== "traverse" && !event.userInitiated && event.info?.yumemi !== goInfo) return null;
  let url;
  try {
    url = new URL(event.destination.url);
  } catch (_error) {
    return null;
  }
  if (url.origin !== location.origin) return null;
  const here = policy(routes, location.pathname);
  const there = policy(routes, url.pathname);
  if (here === void 0 || there === void 0 || here !== loaded || there !== loaded) return null;
  return url;
}
function stale(event) {
  return event.canIntercept && event.navigationType === "traverse" && event.destination?.sameDocument === true && !event.hashChange;
}
function swappable(doc) {
  const scripts = [...doc.querySelectorAll("script")];
  const client = scripts.filter((script) => script.getAttribute("src") === clientSrc && script.getAttribute("type") === "module");
  if (client.length !== 1 || scripts.length !== 1 || client[0].parentElement !== doc.head) return false;
  return Boolean(doc.body);
}
function common(current, incoming) {
  const rows = current.length;
  const columns = incoming.length;
  const table2 = Array.from({ length: rows + 1 }, () => new Array(columns + 1).fill(0));
  for (let i2 = rows - 1; i2 >= 0; i2 -= 1) {
    for (let j2 = columns - 1; j2 >= 0; j2 -= 1) {
      table2[i2][j2] = current[i2] === incoming[j2] ? table2[i2 + 1][j2 + 1] + 1 : Math.max(table2[i2 + 1][j2], table2[i2][j2 + 1]);
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
    } else if (table2[i + 1][j] >= table2[i][j + 1]) i += 1;
    else j += 1;
  }
  return match;
}
var holdMark = "data-yumemi-hold";
var holdLimit = 3e3;
var quietMedia = "not all";
var marks = 0;
function nodeKey(node) {
  if (node.nodeType === 1 && node.localName === "meta" && node.getAttribute("name") === pageviewName) return `#mark:${marks += 1}`;
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
function stage(target, doc, keep, limit = holdLimit) {
  const head = target.head;
  const current = [...head.childNodes].filter((node) => !keep(node) && !(node.nodeType === 1 && node.hasAttribute(holdMark)));
  const incoming = [...doc.head.childNodes].filter((node) => !keep(node));
  const match = common(current.map(nodeKey), incoming.map(nodeKey));
  const kept = new Set(match.filter((index) => index >= 0).map((index) => current[index]));
  const outgoing = current.filter((node) => !kept.has(node));
  const final = incoming.map((node, index) => match[index] >= 0 ? current[match[index]] : target.adoptNode(node));
  const placed = new Set(kept);
  const waits = [];
  const quiet = [];
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
  const ready = Promise.all(waits).then(() => void 0);
  const commit = () => {
    place(() => true);
    for (const [node, media] of quiet) setMedia(node, media);
    for (const node of outgoing) node.remove();
    const lang = doc.documentElement?.getAttribute("lang") ?? null;
    if (lang !== null) target.documentElement.setAttribute("lang", lang);
    const body = target.adoptNode(doc.body);
    const done = bodyLinks.map((link) => settled(link, limit));
    target.body.replaceWith(body);
    return Promise.all(done).then(() => {
      for (const copy of holds) copy.remove();
    });
  };
  const cancel = () => {
    for (const [node] of quiet) node.remove();
  };
  return { ready, commit, cancel };
}
var refresh = null;
function go(href, { replace = false, keep = null } = {}) {
  if (going !== null) return going(href, replace, keep);
  if (replace) globalThis.location.replace(href);
  else globalThis.location.assign(href);
}
var going = null;
function reload() {
  if (refresh !== null) return refresh();
  globalThis.location.assign(globalThis.location.href);
}
function table(routes, csp = {}) {
  return routes.map((route) => ({ route, csp: Object.hasOwn(csp, route) ? csp[route] : null }));
}
function supported(scope = globalThis) {
  return typeof scope.navigation?.addEventListener === "function" && typeof scope.NavigateEvent?.prototype?.intercept === "function";
}
function start2({ routes: paths, csp = {} }) {
  if (typeof window === "undefined" || !supported()) return;
  const navigation = globalThis.navigation;
  const routes = table(paths, csp);
  const keep = (node) => node.nodeName === "SCRIPT" && node.getAttribute("src") === clientSrc;
  const loaded = policy(routes, globalThis.location.pathname);
  const load = (url) => globalThis.location.replace(url.href);
  let latest = 0;
  let shown = 0;
  let shownSeq = 0;
  const contents = /* @__PURE__ */ new Map();
  if (navigation.currentEntry) contents.set(navigation.currentEntry.key, shown);
  const stopped = (id) => {
    setTimeout(() => {
      if (latest === id) globalThis.location.reload();
    }, 0);
  };
  const swap = async (url, signal, id, focus) => {
    const csp2 = policy(routes, url.pathname);
    let response;
    try {
      response = await fetch(url.href, {
        credentials: "same-origin",
        redirect: "manual",
        cache: "no-store",
        headers: { accept: "text/html", [navigateHeader]: "1" },
        signal
      });
    } catch (_error) {
      if (signal.aborted) return stopped(id);
      return load(url);
    }
    const type = response.headers.get("content-type") ?? "";
    if (response.type === "opaqueredirect" || response.status !== 200 || !type.startsWith("text/html") || !samePolicy(response.headers, csp2)) {
      return load(url);
    }
    let html;
    try {
      html = await response.text();
    } catch (_error) {
      if (signal.aborted) return stopped(id);
      return load(url);
    }
    if (signal.aborted) return stopped(id);
    const doc = new DOMParser().parseFromString(html, "text/html");
    if (!swappable(doc)) return load(url);
    const staged = stage(document, doc, keep);
    await staged.ready;
    if (signal.aborted) {
      staged.cancel();
      return stopped(id);
    }
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
  going = (href, replace, keepFocus) => {
    const url = new URL(href, globalThis.location.href);
    if (!routed(routes, url.pathname)) return replace ? globalThis.location.replace(url.href) : globalThis.location.assign(url.href);
    navigation.navigate(url.href, { history: replace ? "replace" : "push", info: { yumemi: goInfo, keep: keepFocus } });
  };
  navigation.addEventListener("navigatesuccess", () => {
    if (navigation.currentEntry) contents.set(navigation.currentEntry.key, shown);
  });
  navigation.addEventListener("navigate", (event) => {
    if (event.navigationType === "traverse" && event.destination?.sameDocument && contents.get(event.destination.key) === shown) return;
    const url = accept(event, routes, globalThis.location, loaded);
    if (url !== null) {
      const id = ++latest;
      const keepFocus = event.info?.yumemi === goInfo ? event.info.keep ?? null : null;
      const manual = event.navigationType === "reload" || keepFocus !== null;
      event.intercept({
        handler: () => swap(url, event.signal, id, keepFocus),
        scroll: manual ? "manual" : "after-transition",
        ...keepFocus !== null ? { focusReset: "manual" } : {}
      });
    } else if (stale(event)) {
      latest += 1;
      event.intercept({ handler: () => load(new URL(event.destination.url)) });
    } else if (!event.destination?.sameDocument) {
      latest += 1;
    }
  });
}

// public/build/dev/javascript/public/escapes/clock.mjs
function mount(element) {
  element.textContent = "mounted";
  element.dataset.mounted = String(Number(globalThis.__yumemiClockMounts ?? 0) + 1);
  globalThis.__yumemiClockMounts = Number(globalThis.__yumemiClockMounts ?? 0) + 1;
  return () => {
    globalThis.__yumemiClockUnmounts = Number(globalThis.__yumemiClockUnmounts ?? 0) + 1;
  };
}

// client-entry.mjs
start({
  components: {
    "article-blob-copy": {
      "services": {
        "blob_copy": { "method": "POST", "path": "/api/blobs", "read": false, "upload": true, "accepted": false, "entry": true, "args": [{ "name": "file", "wire": "text", "blob": true }, { "name": "from", "wire": "text", "blob": false }], "refused": [], "slots": { "key": "key" }, "ok": { "then": "stay" }, "error": { "then": "stay" } }
      },
      "reloads": null
    },
    "article-manage": {
      "services": {
        "article_publish": { "method": "POST", "path": "/api/articles/:slug/publish", "read": false, "upload": false, "accepted": false, "entry": false, "args": [{ "name": "slug", "wire": "text", "blob": false }], "refused": ["already_published", "already_retracted"], "slots": { "slug": "slug", "title": "title", "body": "body", "version": "version", "order": "order", "category": "category", "tags": "tags" }, "ok": { "then": "goto", "path": "/article/:slug", "notice": "\u516C\u958B\u3057\u307E\u3057\u305F" }, "error": { "then": "stay" } },
        "article_create": { "method": "POST", "path": "/api/articles", "read": false, "upload": false, "accepted": false, "entry": false, "args": [{ "name": "slug", "wire": "text", "blob": false }, { "name": "title", "wire": "text", "blob": false }, { "name": "body", "wire": "text", "blob": false }, { "name": "category", "wire": "text", "blob": false }, { "name": "tags", "wire": { "list": "text" }, "blob": false }], "refused": [], "slots": { "slug": "slug", "phase": "phase" }, "ok": { "then": "reload" }, "error": { "then": "stay" } }
      },
      "reloads": null
    },
    "blob-save": {
      "services": {
        "article_blob_save": { "method": "POST", "path": "/api/articles/:slug/blob_save", "read": false, "upload": false, "accepted": false, "entry": false, "args": [{ "name": "slug", "wire": "text", "blob": false }, { "name": "blob", "wire": "text", "blob": true }, { "name": "existing", "wire": { "option": "text" }, "blob": true }], "refused": [], "slots": { "saved": "saved" }, "ok": { "then": "stay" }, "error": { "then": "stay" } }
      },
      "reloads": null
    },
    "like-button": {
      "services": {
        "article_publish": { "method": "POST", "path": "/api/articles/:slug/publish", "read": false, "upload": false, "accepted": false, "entry": false, "args": [{ "name": "slug", "wire": "text", "blob": false }], "refused": ["already_published", "already_retracted"], "slots": { "slug": "slug", "title": "title", "body": "body", "version": "version", "order": "order", "category": "category", "tags": "tags" }, "ok": { "then": "stay" }, "error": { "then": "stay" } }
      },
      "reloads": null
    },
    "pick-tag": {
      "services": {
        "article_create": { "method": "POST", "path": "/api/articles", "read": false, "upload": false, "accepted": false, "entry": false, "args": [{ "name": "slug", "wire": "text", "blob": false }, { "name": "title", "wire": "text", "blob": false }, { "name": "body", "wire": "text", "blob": false }, { "name": "category", "wire": "text", "blob": false }, { "name": "tags", "wire": { "list": "text" }, "blob": false }], "refused": [], "slots": { "slug": "slug", "phase": "phase" }, "ok": { "then": "reload", "notice": "\u30BF\u30B0\u3092\u4FDD\u5B58\u3057\u307E\u3057\u305F" }, "error": { "then": "stay" } }
      },
      "reloads": null
    },
    "tag-filter": {
      "services": {
        "widget_list": { "method": "GET", "path": "/api/widgets", "read": true, "upload": false, "accepted": false, "entry": false, "args": [{ "name": "widget", "wire": { "option": "text" }, "blob": false }, { "name": "slug", "wire": { "option": "text" }, "blob": false }], "refused": [], "slots": {}, "ok": { "then": "stay" }, "error": { "then": "stay" } }
      },
      "reloads": { "read": "widget_list", "on": ["widget"], "list": true }
    },
    "title-lookup": {
      "services": {
        "article_title": { "method": "GET", "path": "/api/articles/:slug/title", "read": true, "upload": false, "accepted": false, "entry": false, "args": [{ "name": "slug", "wire": "text", "blob": false }], "refused": [], "slots": { "title": "title", "version": "version" }, "ok": { "then": "stay" }, "error": { "then": "stay" } }
      },
      "reloads": { "read": "article_title", "on": ["slug"], "list": false }
    }
  },
  escapes: { clock: mount },
  go,
  reload
});
start2({ routes: ["/article/:slug", "/status"] });
