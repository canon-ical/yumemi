// yumemi yumemi/front ── interactive Component の runtime(0.12 段 C、51 v6「interactive Component の runtime」)。
// 生成の `priv/static/_yumemi/client.mjs` が `start({components, escapes, go, reload})` を呼ぶ。持つのは form と
// 状態と値の結合だけで、計算はしない。lustre は入らない。
//
// - Component は名前の付いた autonomous custom element(共通の class を継ぐ空の subclass をタグごとに define)。
//   中身は SSR で light DOM に描いてあり、ここは接続のたびに自分の属性(`data-yumemi-args`)を読む ── client の
//   遷移で body を替えても、来た要素が接続時に起きる(`boot()` は無い)
// - submit:submitter の `data-yumemi-send` で Service を決め、その Service の control(name が `<service>.`)だけに
//   制約検証を掛け、Args を組み(初期値に control の値を重ねる、0.11.2 の送り方)、route を 1 回叩く。送りの間は
//   `waiting` と `sent-<service>` を立て、fieldset を止め、`aria-busy`
// - Done:`ok` か `error`(と `refused-<code>`、断りの枝の無い失敗は `failed`)を立て、`data-yumemi-out` に Out の欄を textContent で入れ、After に従う
// - `reloads`:単一の値は読みを叩いて out に入れる(前の読みは中断)、一覧は query を替えた URL へ履歴を積まずに移る
// - 状態は `ElementInternals.states`(`:state()`)に立て、無ければ `data-yumemi-state` に同じ名を書く
// - 逃げ道:`<yumemi-escape name>` の接続で `mount(element, yumemi)` を呼び、外れたら戻りの関数を呼ぶ(`yumemi` は
//   `{ block }`。`Live` のある面は `live_block.mjs` の、0.14.1 から `Live` の無い面も `block.mjs` の `block`)
// - dialog:invoker commands(`command` / `commandfor`)の無い browser では click で `showModal()` / `close()` を代わる
// - notice:After の文言を sessionStorage の 1 つの鍵に置き、移った先(読み直した先)の `[data-yumemi-notice]` に 1 回出す
// - 冪等キー(0.13):書きの送り(GET でも読みでも上げ口でもない)は、送る Args にキー(UUID)を 1 つ作って
//   `Idempotency-Key` に載せる。結果の分からない失敗(5xx・網の失敗)はキーと入力を保ち、失敗の After に移らない
//   ── 同じ Args の再送は同じキーで、server は 1 本目の応答を返す。答えが出たら(2xx・4xx)キーを捨て、Args が
//   変われば新しいキー。file の欄の上げは File ごとに上げた key を同じ間だけ保ち、再送では上げ直さない(key が
//   変わると Args が変わり、キーも変わる)

const noticeKey = "yumemi:notice";
const stateNames = ["waiting", "ok", "error"];

function setStates(element, names) {
  const internals = element.yumemiInternals;
  const states = internals?.states;
  if (states && typeof states.add === "function") {
    try {
      for (const name of [...states]) states.delete(name);
      for (const name of names) states.add(name);
      return;
    } catch (_error) {
      // 古い browser の `--` 前置きの形などは属性へ落ちる
    }
  }
  if (names.length === 0) element.removeAttribute("data-yumemi-state");
  else element.setAttribute("data-yumemi-state", names.join(" "));
}

function currentStates(element) {
  const states = element.yumemiInternals?.states;
  if (states && typeof states.has === "function" && element.getAttribute("data-yumemi-state") === null) return [...states];
  return (element.getAttribute("data-yumemi-state") ?? "").split(" ").filter(Boolean);
}

function kebab(code) {
  return String(code).replaceAll("_", "-").toLowerCase();
}

/// 断り `code` の枝が、同じ Service の Failed の枝の外に 1 つでもあるか
function refusalShown(element, service, code) {
  const branches = element.querySelectorAll?.(`[data-yumemi-when~="${service}.refused-${kebab(code)}"]`) ?? [];
  return [...branches].some((branch) => !branch.parentElement?.closest(`[data-yumemi-when~="${service}.failed"]`));
}

/// 0.11.2 の送り方:欄の文字列を Args の型の JSON に。読めない綴りは文字列のまま(back が invalid_argument で返す)。
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
        try { const parsed = JSON.parse(value); return Array.isArray(parsed) ? parsed : [value]; } catch (_error) { return [value]; }
      })();
      return items.map((item) => scalar(wire.list, String(item)));
    }
  }
  if (wire === "json") {
    if (typeof value !== "string") return value;
    try { return JSON.parse(value); } catch (_error) { return value; }
  }
  return scalar(wire, Array.isArray(value) ? value[0] ?? "" : value ?? "");
}

function fillPath(path, values) {
  return path.replace(/:([A-Za-z0-9_]+)/g, (_match, name) => encodeURIComponent(String(values?.[name] ?? "")));
}

function readPath(value, path) {
  let current = value;
  for (const part of path.split(".")) {
    if (current === null || typeof current !== "object") return undefined;
    current = current[part];
  }
  return current;
}

function textOf(value) {
  if (value === undefined || value === null) return "";
  if (typeof value === "object") {
    // Option の写し(`{value: ..}`)や Blob の写しは中の値を出す
    if ("value" in value && Object.keys(value).length === 1) return textOf(value.value);
    return "";
  }
  return String(value);
}

function putNotice(text) {
  if (typeof text !== "string" || text === "") return;
  try { globalThis.sessionStorage?.setItem(noticeKey, text); } catch (_error) { /* 出せないだけ */ }
}

/// 読み直した先・移った先の `el.notice` に文言を 1 回出す(出したら鍵を消す)。
export function showNotice(root = globalThis.document) {
  let text = null;
  try { text = globalThis.sessionStorage?.getItem(noticeKey) ?? null; } catch (_error) { return; }
  if (text === null) return;
  const place = root?.querySelector?.("[data-yumemi-notice]");
  if (!place) return;
  try { globalThis.sessionStorage.removeItem(noticeKey); } catch (_error) { /* 消せなくても出す */ }
  place.textContent = text;
  place.hidden = false;
}

async function upload(file) {
  const response = await fetch("/api/blobs", {
    method: "POST",
    headers: { "content-type": file.type || "application/octet-stream" },
    body: file,
  });
  if (!response.ok) throw new Error("blob upload failed");
  const result = await response.json();
  if (typeof result?.key !== "string" || result.key === "") throw new Error("blob response has no key");
  return result.key;
}

function controlsOf(form, service) {
  return [...form.elements].filter((control) => typeof control.name === "string" && control.name.startsWith(`${service}.`));
}

/// control の値を欄ごとに集める(同じ name が並べば List の欄)。checkbox は checked、radio は選ばれた 1 つ、
/// select の multiple は選ばれた全部、file は File(上げる前)。
function collect(controls, service) {
  const values = new Map();
  const push = (name, value) => {
    const field = name.slice(service.length + 1);
    if (!values.has(field)) values.set(field, []);
    if (value !== undefined) values.get(field).push(value);
  };
  for (const control of controls) {
    if (control.disabled) continue;
    const type = (control.type ?? "").toLowerCase();
    if (type === "checkbox") {
      const group = controls.filter((other) => other.name === control.name);
      if (group.length > 1) push(control.name, control.checked ? control.value : undefined);
      else push(control.name, control.checked ? "true" : "false");
    } else if (type === "radio") push(control.name, control.checked ? control.value : undefined);
    else if (type === "file") push(control.name, control.files?.[0] ?? undefined);
    else if (control instanceof HTMLSelectElement && control.multiple) {
      for (const option of control.selectedOptions) push(control.name, option.value);
      if (control.selectedOptions.length === 0) push(control.name, undefined);
    } else if (type === "submit" || type === "button" || type === "reset") continue;
    else push(control.name, control.value);
  }
  return values;
}

/// file の欄の上げ。上げた File の key を `uploaded`(File -> key)に保ち、同じ File の再送では上げ直さない
/// ── 上げ口が上げるたびに新しい key を返すと、Args が変わって冪等キーも変わり、再送が別の書きになる
async function uploadOnce(file, uploaded) {
  const kept = uploaded?.get(file);
  if (kept !== undefined) return kept;
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
      // 上げ口(`spec.upload`)は送りそのものが file を本文で上げるので、ここで先に上げない(2 回上がる)
      if (files.length > 0) { if (!spec.upload) raw = await uploadOnce(files[0], uploaded); }
      else if (isList) raw = items;
      else if (items.length > 0) raw = items[items.length - 1];
      else if (!arg.blob) raw = "";
    }
    args[arg.name] = wireValue(arg.wire, raw);
  }
  return args;
}

/// 書きの送りか(キーを載せる送り)。読みの Service・GET・上げ口は載せない
function keyed(spec) {
  return !spec.read && !spec.upload && spec.method !== "GET";
}

/// 送りの結果が分からない(server が書いたかどうか分からない)失敗か。キーと入力を保つ
function unsettled(outcome) {
  return outcome.network === true || outcome.status >= 500;
}

function newKey() {
  if (typeof globalThis.crypto?.randomUUID === "function") return globalThis.crypto.randomUUID();
  const bytes = globalThis.crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

/// 送りのキー。保っているキーの Args と同じならそのキー、違えば(入力が変わった)新しいキー
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
    // 上げ口:file があれば本文に file、無ければ `from` の URL を写す(`{from}` を JSON で)
    if (uploadFile) {
      return fetch(spec.path, {
        method: spec.method,
        headers: { "content-type": uploadFile.type || "application/octet-stream" },
        body: uploadFile,
        signal,
      });
    }
    if (typeof args.from !== "string" || args.from === "") throw Object.assign(new Error("no file"), { code: "invalid_argument" });
    return fetch(spec.path, {
      method: spec.method,
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ from: args.from }),
      signal,
    });
  }
  let path = fillPath(spec.path, args);
  if (spec.method === "GET") {
    const holes = new Set([...spec.path.matchAll(/:([A-Za-z0-9_]+)/g)].map((match) => match[1]));
    const query = new URLSearchParams();
    for (const arg of spec.args) {
      if (holes.has(arg.name)) continue;
      const value = args[arg.name];
      if (value === null || value === undefined) continue;
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
    body: spec.method === "GET" ? undefined : spec.entry && spec.args.length === 0 ? "null" : JSON.stringify(args),
    signal,
  });
}

let hooks = { go: null, reload: null };

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

// node(test)で読んでも落ちない(定義は browser でだけ使う)
const ElementBase = globalThis.HTMLElement ?? class {};

class YumemiInteractive extends ElementBase {
  static yumemiSpec = null;

  constructor() {
    super();
    try { this.yumemiInternals = this.attachInternals(); } catch (_error) { this.yumemiInternals = null; }
    this.yumemiReading = null;
    this.yumemiSending = false;
    this.yumemiCleanup = null;
    // 書きの送りの保っているキー(Service の名 -> {body, key})。答えの出ない失敗の間だけ持つ
    this.yumemiKeys = new Map();
    // 書きの送りの file の欄の上げた key(Service の名 -> WeakMap(File -> key))。キーと同じ間だけ持つ
    this.yumemiUploads = new Map();
  }

  get yumemiInitial() {
    try { return JSON.parse(this.getAttribute("data-yumemi-args") ?? "{}"); } catch (_error) { return {}; }
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
    // 暗黙の送信(text の control で Enter):submitter は form の最初の送りのボタン。focus のある control の
    // Service と違えば捨てる(送りが 2 つの Component で、別の送りが Enter で走らない)
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
    const withKey = keyed(serviceSpec);
    let outcome;
    try {
      const fileControl = serviceSpec.upload ? controls.find((control) => control.type === "file") : null;
      let uploaded = null;
      if (withKey) {
        uploaded = this.yumemiUploads.get(service) ?? new WeakMap();
        this.yumemiUploads.set(service, uploaded);
      }
      const args = await buildArgs(serviceSpec, initial, controls, service, uploaded);
      const key = withKey ? keyFor(this.yumemiKeys, service, args) : null;
      setStates(this, ["waiting", `sent-${service}`]);
      this.yumemiBusy(form, true);
      outcome = await this.yumemiCall(serviceSpec, args, null, fileControl?.files?.[0], key);
    } catch (error) {
      // fetch が投げた(網の失敗)。code の付いた失敗(上げ口の `no file`)は送っていないので答えの出た失敗。
      // file の欄の先の上げ(`upload`)の失敗は code が無く、網の失敗と同じに入力を保つ(キーはまだ作っていない)
      outcome = { ok: false, network: error?.code === undefined, value: { code: error?.code ?? "network_error" } };
    } finally {
      this.yumemiSending = false;
      this.yumemiBusy(form, false);
    }
    // 答えが出たらキーを捨てる。結果の分からない失敗はキーと入力を保ち、失敗の After(読み直し・移動)に移らない
    const kept = withKey && !outcome.ok && unsettled(outcome);
    if (withKey && !kept) {
      this.yumemiKeys.delete(service);
      this.yumemiUploads.delete(service);
    }
    this.yumemiDone(service, serviceSpec, outcome);
    // 失敗の本文は Out でないので、error 側の穴は埋めない(生成器の第 15 条が穴のある route を止める)
    if (!serviceSpec.read && !kept) follow(outcome.ok ? serviceSpec.ok : serviceSpec.error, outcome.ok ? outcome.value : null);
  }

  async yumemiCall(serviceSpec, args, signal, file, key = null) {
    const response = await call(serviceSpec, args, signal, file, key);
    let value = null;
    try { value = await response.json(); } catch (_error) { value = response.ok ? null : { code: "request_failed" }; }
    return { ok: response.ok, status: response.status, value };
  }

  yumemiDone(service, serviceSpec, outcome) {
    if (outcome.ok) {
      setStates(this, ["ok", `sent-${service}`]);
      for (const place of this.querySelectorAll(`[data-yumemi-out^="${service}."]`)) {
        // 送りの control の中身は値になる(option の字が select の値、textarea の字)。読みの戻りを書きの
        // Args に流さないよう、そこには入れない(第 21 条の生成器の検査の書き方に依らない柵)
        if (place.closest("option, select, textarea, datalist")) continue;
        const slot = place.getAttribute("data-yumemi-out").slice(service.length + 1);
        const path = serviceSpec.slots?.[slot] ?? slot;
        place.textContent = textOf(readPath(outcome.value, path));
      }
    } else {
      // 断り(Service の `Error` の符号 `refused` と要件の符号 `requires`)は `refused-<code>`。`failed`
      // (`when(Failed)`)は、その断りの枝(`when(Refused(..))`)が Component に無い失敗にだけ立てる ── 断りの
      // 枝が出るときに汎用の失敗の枝を並べず、枝の無い断りは今までどおり Failed で出す(0.12.1)。`error` は常に。
      // 同じ Service の Failed の枝の中にある断りの枝は数えない ── Failed の枝が隠れると一緒に隠れるので、
      // 入れ子の形は 0.12.0 のとおり両方の字を出す
      const code = outcome.value?.code;
      const names = ["error", `sent-${service}`];
      const refused = typeof code === "string" && [...(serviceSpec.refused ?? []), ...(serviceSpec.requires ?? [])].includes(code);
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
      // 一覧:今の URL の query `<field>` を替えた URL へ、履歴を積まずに移る(頁の loader が読む)
      const url = new URL(globalThis.location.href);
      for (const field of reloads.on) {
        const control = form.elements.namedItem(`${prefix}${field}`);
        const value = control && "value" in control ? control.value : "";
        if (value === "") url.searchParams.delete(field);
        else url.searchParams.set(field, value);
      }
      const keep = { tag: this.localName, name: target.name };
      // 欄の変更による取り直しで利用者の遷移でないので、送り手は数えない(`count: false`)
      if (hooks.go) hooks.go(url.href, { replace: true, keep, count: false });
      else {
        try { sessionStorage.setItem("yumemi:uncounted", JSON.stringify({ href: url.href, at: Date.now() })); } catch (_error) {}
        globalThis.location.replace(url.href);
      }
      return;
    }
    // 単一の値:前の読みを中断して今の Args で 1 回叩き、out に入れる。fieldset は止めない
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
}

class YumemiEscape extends ElementBase {
  static yumemiMounts = {};
  /// 逃げ道の `mount` の 2 つ目の引数(`{ block }`、0.14 は `Live` のある面、0.14.1 から逃げ道のある面すべて)
  static yumemiApi = {};

  connectedCallback() {
    if (this.yumemiUnmount !== undefined) return;
    const mount = YumemiEscape.yumemiMounts[this.getAttribute("name") ?? ""];
    if (typeof mount !== "function") return;
    try {
      const unmount = mount(this, YumemiEscape.yumemiApi);
      this.yumemiUnmount = typeof unmount === "function" ? unmount : null;
    } catch (_error) {
      this.yumemiUnmount = null;
    }
  }

  disconnectedCallback() {
    const unmount = this.yumemiUnmount;
    this.yumemiUnmount = undefined;
    if (typeof unmount === "function") {
      try { unmount(); } catch (_error) { /* 外しの失敗は頁を壊さない */ }
    }
  }
}

/// invoker commands の無い browser の代わり(`el.dialog_opener` / `el.dialog_closer` の `show-modal` / `close`)。
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

/// `components` はタグ → `{services, reloads}`、`escapes` は名 → `mount`、`yumemi` は `mount` の 2 つ目の引数。
export function start({ components = {}, escapes = {}, go = null, reload = null, yumemi = {} } = {}) {
  if (typeof window === "undefined" || !globalThis.customElements) return;
  hooks = { go, reload };
  for (const [tag, spec] of Object.entries(components)) {
    if (globalThis.customElements.get(tag)) continue;
    // 同じ constructor を 2 つ目の名前で define できないので、タグごとに空の subclass
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

export const internals = { setStates, currentStates, wireValue, fillPath, stateNames, keyed, unsettled, keyFor, call, uploadOnce };
