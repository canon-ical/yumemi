// GENERATED from public/src/components/*.gleam, src/escapes/*.mjs and src/entry.gleam [sha256:a5a42f5277cb] — 手で編集しない
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
function refusalShown(element, service, code) {
  const branches = element.querySelectorAll?.(`[data-yumemi-when~="${service}.refused-${kebab(code)}"]`) ?? [];
  return [...branches].some((branch) => !branch.parentElement?.closest(`[data-yumemi-when~="${service}.failed"]`));
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
async function uploadOnce(file, uploaded) {
  const kept = uploaded?.get(file);
  if (kept !== void 0) return kept;
  const key = await upload(file);
  uploaded?.set(file, key);
  return key;
}
async function buildArgs(spec, initial, controls, serviceName, uploaded = null) {
  const collected = collect(controls, serviceName);
  const args = {};
  for (const arg of spec.args) {
    const isList = typeof arg.wire === "object" && arg.wire !== null && "list" in arg.wire;
    let raw = initial?.[arg.name] ?? "";
    if (collected.has(arg.name)) {
      const items = collected.get(arg.name);
      const files = items.filter((item) => typeof File !== "undefined" && item instanceof File);
      if (files.length > 0) {
        if (!spec.upload) raw = await uploadOnce(files[0], uploaded);
      } else if (isList) raw = items;
      else if (items.length > 0) raw = items[items.length - 1];
      else if (!arg.blob) raw = "";
    }
    args[arg.name] = wireValue(arg.wire, raw);
  }
  return args;
}
function keyed(spec) {
  return !spec.read && !spec.upload && spec.method !== "GET";
}
function unsettled(outcome) {
  return outcome.network === true || outcome.status >= 500;
}
function newKey() {
  if (typeof globalThis.crypto?.randomUUID === "function") return globalThis.crypto.randomUUID();
  const bytes = globalThis.crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = bytes[6] & 15 | 64;
  bytes[8] = bytes[8] & 63 | 128;
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}
function keyFor(pending, service, args) {
  const body = JSON.stringify(args);
  const kept = pending.get(service);
  if (kept && kept.body === body) return kept.key;
  const key = newKey();
  pending.set(service, { body, key });
  return key;
}
async function call(spec, args, signal, uploadFile, key = null) {
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
  const headers = { "content-type": "application/json", accept: "application/json" };
  if (key !== null) headers["idempotency-key"] = key;
  return fetch(path, {
    method: spec.method,
    credentials: "same-origin",
    headers,
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
    this.yumemiKeys = /* @__PURE__ */ new Map();
    this.yumemiUploads = /* @__PURE__ */ new Map();
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
      const focused2 = active.name.slice(0, active.name.indexOf("."));
      if (focused2 !== service) return;
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
    const withKey = keyed(serviceSpec);
    let outcome;
    try {
      const fileControl = serviceSpec.upload ? controls.find((control) => control.type === "file") : null;
      let uploaded = null;
      if (withKey) {
        uploaded = this.yumemiUploads.get(service) ?? /* @__PURE__ */ new WeakMap();
        this.yumemiUploads.set(service, uploaded);
      }
      const args = await buildArgs(serviceSpec, initial, controls, service, uploaded);
      const key = withKey ? keyFor(this.yumemiKeys, service, args) : null;
      setStates(this, ["waiting", `sent-${service}`]);
      this.yumemiBusy(form, true);
      outcome = await this.yumemiCall(serviceSpec, args, null, fileControl?.files?.[0], key);
    } catch (error) {
      outcome = { ok: false, network: error?.code === void 0, value: { code: error?.code ?? "network_error" } };
    } finally {
      this.yumemiSending = false;
      this.yumemiBusy(form, false);
    }
    const kept = withKey && !outcome.ok && unsettled(outcome);
    if (withKey && !kept) {
      this.yumemiKeys.delete(service);
      this.yumemiUploads.delete(service);
    }
    this.yumemiDone(service, serviceSpec, outcome);
    if (!serviceSpec.read && !kept) follow(outcome.ok ? serviceSpec.ok : serviceSpec.error, outcome.ok ? outcome.value : null);
  }
  async yumemiCall(serviceSpec, args, signal, file, key = null) {
    const response = await call(serviceSpec, args, signal, file, key);
    let value = null;
    try {
      value = await response.json();
    } catch (_error) {
      value = response.ok ? null : { code: "request_failed" };
    }
    return { ok: response.ok, status: response.status, value };
  }
  yumemiDone(service, serviceSpec, outcome) {
    if (outcome.ok) {
      setStates(this, ["ok", `sent-${service}`]);
      for (const place of this.querySelectorAll(`[data-yumemi-out^="${service}."]`)) {
        if (place.closest("option, select, textarea, datalist")) continue;
        const slot = place.getAttribute("data-yumemi-out").slice(service.length + 1);
        const path = serviceSpec.slots?.[slot] ?? slot;
        place.textContent = textOf(readPath(outcome.value, path));
      }
    } else {
      const code = outcome.value?.code;
      const names = ["error", `sent-${service}`];
      const refused = typeof code === "string" && [...serviceSpec.refused ?? [], ...serviceSpec.requires ?? []].includes(code);
      if (refused) names.push(`refused-${kebab(code)}`);
      if (!refused || !refusalShown(this, service, code)) names.push("failed");
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
      if (hooks.go) hooks.go(url.href, { replace: true, keep, count: false });
      else {
        try {
          sessionStorage.setItem("yumemi:uncounted", JSON.stringify({ href: url.href, at: Date.now() }));
        } catch (_error) {
        }
        globalThis.location.replace(url.href);
      }
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
  /// 逃げ道の `mount` の 2 つ目の引数(`{ block }`、0.14 は `Live` のある面、0.14.1 から逃げ道のある面すべて)
  static yumemiApi = {};
  connectedCallback() {
    if (this.yumemiUnmount !== void 0) return;
    const mount2 = _YumemiEscape.yumemiMounts[this.getAttribute("name") ?? ""];
    if (typeof mount2 !== "function") return;
    try {
      const unmount = mount2(this, _YumemiEscape.yumemiApi);
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
function start({ components = {}, escapes = {}, go: go2 = null, reload: reload2 = null, yumemi = {} } = {}) {
  if (typeof window === "undefined" || !globalThis.customElements) return;
  hooks = { go: go2, reload: reload2 };
  for (const [tag, spec] of Object.entries(components)) {
    if (globalThis.customElements.get(tag)) continue;
    globalThis.customElements.define(tag, class extends YumemiInteractive {
      static yumemiSpec = spec;
    });
  }
  YumemiEscape.yumemiMounts = { ...YumemiEscape.yumemiMounts, ...escapes };
  YumemiEscape.yumemiApi = { ...YumemiEscape.yumemiApi, ...yumemi };
  if (!globalThis.customElements.get("yumemi-escape")) globalThis.customElements.define("yumemi-escape", YumemiEscape);
  dialogFallback();
  showNotice();
  globalThis.navigation?.addEventListener?.("navigatesuccess", () => showNotice());
}

// public/build/dev/javascript/yumemi/yumemi/front/block.mjs
var blockHeader = "x-yumemi-block";
var adopted = null;
function sheetRules(sheet) {
  try {
    return [...sheet.cssRules];
  } catch (_error) {
    return [];
  }
}
function documentRules() {
  const rules = /* @__PURE__ */ new Set();
  for (const sheet of [...globalThis.document.styleSheets, ...globalThis.document.adoptedStyleSheets]) {
    for (const rule of sheetRules(sheet)) rules.add(rule.cssText);
  }
  return rules;
}
function adopt(text) {
  const document2 = globalThis.document;
  if (!adopted) adopted = new CSSStyleSheet();
  if (!document2.adoptedStyleSheets.includes(adopted)) document2.adoptedStyleSheets = [...document2.adoptedStyleSheets, adopted];
  const knownRules = documentRules();
  const incoming = new CSSStyleSheet();
  try {
    incoming.replaceSync(text);
  } catch (_error) {
    return 0;
  }
  let added = 0;
  for (const rule of incoming.cssRules) {
    if (knownRules.has(rule.cssText)) continue;
    try {
      adopted.insertRule(rule.cssText, adopted.cssRules.length);
      knownRules.add(rule.cssText);
      added += 1;
    } catch (_error) {
    }
  }
  return added;
}
async function fetchBlock(name, href = globalThis.location.href) {
  let response;
  try {
    response = await globalThis.fetch(href, {
      headers: { [blockHeader]: name },
      redirect: "manual",
      credentials: "same-origin",
      cache: "no-store"
    });
  } catch (error) {
    return { error };
  }
  const type = response.headers.get("content-type") ?? "";
  const status = response.status;
  if (response.type === "opaqueredirect" || status >= 300 && status < 400 || status === 403 || status === 404) return null;
  if (status !== 200) return { error: new Error(`fragment ${status}`), status };
  if (!type.startsWith("text/html")) return null;
  let text;
  try {
    text = await response.text();
  } catch (error) {
    return { error };
  }
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
var snapshots = /* @__PURE__ */ new WeakMap();
var owned = { details: ["open"], dialog: ["open"] };
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
  return [...component.querySelectorAll("input,textarea,select")].map(controlValue).join("\0");
}
function remember(root) {
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
    try {
      states.add("stale");
      return;
    } catch (_error) {
    }
  }
  const names = (component.getAttribute("data-yumemi-state") ?? "").split(" ").filter(Boolean);
  if (!names.includes("stale")) component.setAttribute("data-yumemi-state", [...names, "stale"].join(" "));
}
function keptAttributes(node) {
  const keep = [...owned[node.localName] ?? []];
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
function sameAttributes(old, incoming) {
  return [...incoming.attributes].every((attribute) => old.getAttribute(attribute.name) === attribute.value);
}
function morphComponent(old, incoming, log) {
  if (old.localName === incoming.localName && old.getAttribute("data-yumemi-args") === incoming.getAttribute("data-yumemi-args")) {
    log.kept.push(old.localName);
    return;
  }
  const before = snapshots.get(old);
  const dirty = before !== void 0 && before !== snapshot(old);
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
  if (old.localName === "textarea" && focused(old)) return;
  morphChildren(old, incoming, log, guards);
}
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
  return before !== void 0 && before !== snapshot(component);
}
function guardsOf(live) {
  const guards = [];
  const document2 = globalThis.document;
  const active = document2.activeElement;
  for (const component of live.querySelectorAll("[data-yumemi-island]")) {
    if (componentDirty(component) || focused(component)) guards.push({ node: component, selector: guardSelector(component) });
  }
  for (const control of live.querySelectorAll("input,textarea,select")) {
    if (control.closest("[data-yumemi-island]")) continue;
    if (controlDirty(control) || control === active) guards.push({ node: control, selector: guardSelector(control) });
  }
  if (active && active !== document2.body && live.contains(active) && !active.closest("[data-yumemi-island]") && !isControl(active)) {
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
function receives(old, incoming, guards) {
  if (incoming.nodeType !== 1 || keyOf(old) !== keyOf(incoming)) return false;
  return guards.every((guard) => !old.contains(guard.node) || incoming.matches(guard.selector) || incoming.querySelector(guard.selector) !== null);
}
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
      if (found >= 0 && news.some((other) => other !== incoming && keyOf(other) === keyOf(olds[found]))) found = -1;
    }
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
function morph(current, incoming) {
  const log = { changed: 0, inserted: 0, kept: [], stale: [], replaced: [] };
  morphChildren(current, incoming, log, guardsOf(current));
  return log;
}
var ElementBase2 = globalThis.HTMLElement ?? class {
};
var YumemiBlock = class extends ElementBase2 {
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
    this.yumemiFetching = run().finally(() => {
      this.yumemiFetching = null;
    });
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
};
async function block(name, { href = globalThis.location.href } = {}) {
  const here = globalThis.location.href;
  const target = new URL(href, here);
  const same = (element2) => {
    const at = new URL(element2.getAttribute("href") ?? here, here);
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
function start2() {
  if (typeof window === "undefined" || !globalThis.customElements) return;
  if (globalThis.customElements.get("yumemi-block")) return;
  globalThis.customElements.define("yumemi-block", YumemiBlock);
  try {
    const sheet = new CSSStyleSheet();
    sheet.replaceSync("yumemi-block { display: contents; }");
    globalThis.document.adoptedStyleSheets = [...globalThis.document.adoptedStyleSheets, sheet];
  } catch (_error) {
  }
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
function go(href, { replace = false, keep = null, count = true } = {}) {
  if (!count) markUncounted(href);
  if (going !== null) return going(href, replace, keep, count);
  if (replace) globalThis.location.replace(href);
  else globalThis.location.assign(href);
}
var going = null;
var uncountedKey = "yumemi:uncounted";
function markUncounted(href) {
  try {
    sessionStorage.setItem(uncountedKey, JSON.stringify({ href: new URL(href, globalThis.location.href).href, at: Date.now() }));
  } catch (_error) {
  }
}
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
function start3({ routes: paths, csp = {} }) {
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
        "blob_copy": { "method": "POST", "path": "/api/blobs", "read": false, "upload": true, "accepted": false, "entry": true, "args": [{ "name": "file", "wire": "text", "blob": true }, { "name": "from", "wire": "text", "blob": false }], "refused": [], "requires": [], "slots": { "key": "key" }, "ok": { "then": "stay" }, "error": { "then": "stay" } }
      },
      "reloads": null
    },
    "article-manage": {
      "services": {
        "article_publish": { "method": "POST", "path": "/api/articles/:slug/publish", "read": false, "upload": false, "accepted": false, "entry": false, "args": [{ "name": "slug", "wire": "text", "blob": false }], "refused": ["already_published", "already_retracted"], "requires": [], "slots": { "slug": "slug", "title": "title", "body": "body", "version": "version", "order": "order", "category": "category", "tags": "tags" }, "ok": { "then": "goto", "path": "/article/:slug", "notice": "\u516C\u958B\u3057\u307E\u3057\u305F" }, "error": { "then": "stay" } },
        "article_create": { "method": "POST", "path": "/api/articles", "read": false, "upload": false, "accepted": false, "entry": false, "args": [{ "name": "slug", "wire": "text", "blob": false }, { "name": "title", "wire": "text", "blob": false }, { "name": "body", "wire": "text", "blob": false }, { "name": "category", "wire": "text", "blob": false }, { "name": "tags", "wire": { "list": "text" }, "blob": false }], "refused": [], "requires": [], "slots": { "slug": "slug", "phase": "phase" }, "ok": { "then": "reload" }, "error": { "then": "stay" } }
      },
      "reloads": null
    },
    "blob-save": {
      "services": {
        "article_blob_save": { "method": "POST", "path": "/api/articles/:slug/blob_save", "read": false, "upload": false, "accepted": false, "entry": false, "args": [{ "name": "slug", "wire": "text", "blob": false }, { "name": "blob", "wire": "text", "blob": true }, { "name": "existing", "wire": { "option": "text" }, "blob": true }], "refused": [], "requires": [], "slots": { "saved": "saved" }, "ok": { "then": "stay" }, "error": { "then": "stay" } }
      },
      "reloads": null
    },
    "like-button": {
      "services": {
        "article_publish": { "method": "POST", "path": "/api/articles/:slug/publish", "read": false, "upload": false, "accepted": false, "entry": false, "args": [{ "name": "slug", "wire": "text", "blob": false }], "refused": ["already_published", "already_retracted"], "requires": [], "slots": { "slug": "slug", "title": "title", "body": "body", "version": "version", "order": "order", "category": "category", "tags": "tags" }, "ok": { "then": "stay" }, "error": { "then": "stay" } }
      },
      "reloads": null
    },
    "pick-tag": {
      "services": {
        "article_create": { "method": "POST", "path": "/api/articles", "read": false, "upload": false, "accepted": false, "entry": false, "args": [{ "name": "slug", "wire": "text", "blob": false }, { "name": "title", "wire": "text", "blob": false }, { "name": "body", "wire": "text", "blob": false }, { "name": "category", "wire": "text", "blob": false }, { "name": "tags", "wire": { "list": "text" }, "blob": false }], "refused": [], "requires": [], "slots": { "slug": "slug", "phase": "phase" }, "ok": { "then": "reload", "notice": "\u30BF\u30B0\u3092\u4FDD\u5B58\u3057\u307E\u3057\u305F" }, "error": { "then": "stay" } }
      },
      "reloads": null
    },
    "tag-filter": {
      "services": {
        "widget_list": { "method": "GET", "path": "/api/widgets", "read": true, "upload": false, "accepted": false, "entry": false, "args": [{ "name": "widget", "wire": { "option": "text" }, "blob": false }, { "name": "slug", "wire": { "option": "text" }, "blob": false }], "refused": [], "requires": [], "slots": {}, "ok": { "then": "stay" }, "error": { "then": "stay" } }
      },
      "reloads": { "read": "widget_list", "on": ["widget"], "list": true }
    },
    "title-lookup": {
      "services": {
        "article_title": { "method": "GET", "path": "/api/articles/:slug/title", "read": true, "upload": false, "accepted": false, "entry": false, "args": [{ "name": "slug", "wire": "text", "blob": false }], "refused": [], "requires": [], "slots": { "title": "title", "version": "version" }, "ok": { "then": "stay" }, "error": { "then": "stay" } }
      },
      "reloads": { "read": "article_title", "on": ["slug"], "list": false }
    }
  },
  escapes: { clock: mount },
  yumemi: { block },
  go,
  reload
});
start2();
start3({ routes: ["/article/:slug", "/status"] });
