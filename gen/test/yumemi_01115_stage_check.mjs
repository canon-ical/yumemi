// 0.11.15 ── navigate.mjs の `stage`(head の差分の足し引きと、stylesheet を読み終えてから body を替える)を、
// 小さな偽の DOM で確かめる。`yumemi_01115_test_ffi.mjs` が子の node で走らせ、1 行 1 件の ok / NG を出す。
import { stage } from "../../src/framework/front/navigate.mjs";

const out = [];
const check = (name, ok) => out.push((ok ? "ok " : "NG ") + name);
const voids = new Set(["link", "meta"]);

class Node {
  constructor(owner, type, name, attrs = {}, value = null) {
    this.owner = owner;
    this.nodeType = type;
    this.localName = name;
    this.nodeName = type === 1 ? name.toUpperCase() : "#text";
    this.nodeValue = value;
    this.attrs = new Map(Object.entries(attrs));
    this.childNodes = [];
    this.parentNode = null;
    this.listeners = {};
  }
  getAttribute(name) { return this.attrs.has(name) ? this.attrs.get(name) : null; }
  setAttribute(name, value) { this.attrs.set(name, String(value)); }
  removeAttribute(name) { this.attrs.delete(name); }
  hasAttribute(name) { return this.attrs.has(name); }
  getAttributeNames() { return [...this.attrs.keys()]; }
  get outerHTML() {
    const attrs = [...this.attrs].map(([key, value]) => ` ${key}="${value}"`).join("");
    const inner = this.childNodes.map((node) => (node.nodeType === 1 ? node.outerHTML : node.nodeValue)).join("");
    return voids.has(this.localName) ? `<${this.localName}${attrs}>` : `<${this.localName}${attrs}>${inner}</${this.localName}>`;
  }
  insertBefore(node, ref) {
    node.remove();
    const index = ref === null ? this.childNodes.length : this.childNodes.indexOf(ref);
    if (index < 0) throw new Error("ref is not a child");
    this.childNodes.splice(index, 0, node);
    node.parentNode = this;
    this.owner.inserted(node);
    return node;
  }
  appendChild(node) { return this.insertBefore(node, null); }
  remove() {
    if (this.parentNode === null) return;
    this.parentNode.childNodes.splice(this.parentNode.childNodes.indexOf(this), 1);
    this.parentNode = null;
  }
  replaceWith(node) {
    const parent = this.parentNode;
    parent.insertBefore(node, this);
    this.remove();
  }
  addEventListener(type, listener) { (this.listeners[type] ??= []).push(listener); }
  removeEventListener(type, listener) { this.listeners[type] = (this.listeners[type] ?? []).filter((item) => item !== listener); }
  fire(type) { for (const listener of [...(this.listeners[type] ?? [])]) listener(); }
}

// 文書。`requests` は live の文書に挿された stylesheet の link(作り直すと読み直しの往復が出る)
function makeDoc(live, head, body, lang = "ja") {
  const doc = { requests: [], live };
  doc.inserted = (node) => {
    if (!doc.live || !connected(doc, node)) return;
    const walk = (item) => {
      if (item.nodeType === 1 && item.localName === "link" && item.getAttribute("rel") === "stylesheet") doc.requests.push(item);
      for (const child of item.childNodes) walk(child);
    };
    walk(node);
  };
  doc.documentElement = new Node(doc, 1, "html", { lang });
  doc.head = new Node(doc, 1, "head");
  doc.body = new Node(doc, 1, "body");
  doc.documentElement.childNodes.push(doc.head, doc.body);
  doc.head.parentNode = doc.documentElement;
  doc.body.parentNode = doc.documentElement;
  for (const spec of head) doc.head.appendChild(build(doc, spec));
  for (const spec of body) doc.body.appendChild(build(doc, spec));
  Object.defineProperty(doc, "body", { get() { return doc.documentElement.childNodes.find((node) => node.localName === "body"); } });
  doc.createElement = (name) => new Node(doc, 1, name);
  doc.adoptNode = (node) => { node.remove(); const move = (item) => { item.owner = doc; item.childNodes.forEach(move); }; move(node); return node; };
  doc.requests = [];
  return doc;
}
function connected(doc, node) {
  let item = node;
  while (item.parentNode) item = item.parentNode;
  return item === doc.documentElement;
}
function build(doc, spec) {
  if (typeof spec === "string") return new Node(doc, 3, "#text", {}, spec);
  const [name, attrs = {}, children = []] = spec;
  const node = new Node(doc, 1, name, attrs);
  for (const child of children) node.appendChild(build(doc, child));
  return node;
}
const css = (href, extra = {}) => ["link", { rel: "stylesheet", href, ...extra }];
const client = ["script", { type: "module", src: "/_yumemi/client.mjs" }];
const keep = (node) => node.nodeName === "SCRIPT" && node.getAttribute("src") === "/_yumemi/client.mjs";
const keys = (head) => head.childNodes.filter((node) => !keep(node)).map((node) => node.outerHTML);
const tick = () => new Promise((resolve) => setTimeout(resolve, 5));
const state = (promise) => {
  let value = "pending";
  promise.then(() => { value = "done"; });
  return () => value;
};

// 1. head の同じ要素は残し(作り直さない)、順を保って差分だけ足し引きする。新しい stylesheet は読み終えてから
{
  const target = makeDoc(true, [["meta", { charset: "utf-8" }], ["title", {}, ["A"]], css("/tokens.css"), css("/www.css"), client], [["p", {}, ["old"]]]);
  const tokens = target.head.childNodes[2];
  const www = target.head.childNodes[3];
  target.requests = [];
  const incoming = makeDoc(false, [["meta", { charset: "utf-8" }], ["title", {}, ["B"]], css("/tokens.css"), css("/www.css"), css("/extra.css"), ["meta", { name: "yumemi-pageview" }], client], [["p", {}, ["new"]]], "en");
  const want = keys(incoming.head);
  const staged = stage(target, incoming, keep, 1000);
  const ready = state(staged.ready);
  await tick();
  const extra = target.head.childNodes.find((node) => node.getAttribute?.("href") === "/extra.css");
  check("head new stylesheet staged quiet", extra?.getAttribute("media") === "not all" && ready() === "pending");
  check("head title not swapped before ready", target.head.childNodes.some((node) => node.outerHTML === "<title>A</title>") && !target.head.childNodes.some((node) => node.outerHTML === "<title>B</title>"));
  check("body not swapped before ready", target.body.outerHTML === "<body><p>old</p></body>");
  extra.fire("load");
  await tick();
  check("ready after load", ready() === "done");
  await staged.commit();
  check("head order follows incoming", JSON.stringify(keys(target.head)) === JSON.stringify(want));
  check("same stylesheets kept as is", target.head.childNodes[2] === tokens && target.head.childNodes[3] === www);
  check("only the new stylesheet requested", target.requests.length === 1 && target.requests[0] === extra);
  check("media restored", !extra.hasAttribute("media"));
  check("client script kept once", target.head.childNodes.filter(keep).length === 1);
  check("body swapped", target.body.outerHTML === "<body><p>new</p></body>");
  check("lang", target.documentElement.getAttribute("lang") === "en");
}

// 2. 外す要素の間に足す要素は来た順の位置へ。残す要素は動かない
{
  const target = makeDoc(true, [["meta", { name: "a" }], ["meta", { name: "x" }], ["meta", { name: "b" }], client], []);
  const [a, , b] = target.head.childNodes;
  const incoming = makeDoc(false, [["meta", { name: "a" }], ["meta", { name: "n" }], ["meta", { name: "b" }], ["meta", { name: "m" }], client], []);
  const staged = stage(target, incoming, keep, 1000);
  await staged.ready;
  await staged.commit();
  const names = target.head.childNodes.filter((node) => !keep(node)).map((node) => node.getAttribute("name"));
  check("diff order", JSON.stringify(names) === JSON.stringify(["a", "n", "b", "m"]));
  check("diff kept identity", target.head.childNodes[0] === a && target.head.childNodes.includes(b));
}

// 3. 来た頁の body にだけある stylesheet は、head に写しを置いて読み終えてから body を替え、body の側が読み終えたら写しを外す
{
  const target = makeDoc(true, [css("/www.css"), client], [["p", {}, ["old"]]]);
  target.requests = [];
  const incoming = makeDoc(false, [css("/www.css"), client], [css("/mincho.css", { media: "screen" }), ["p", {}, ["new"]], css("/www.css")]);
  const staged = stage(target, incoming, keep, 1000);
  const ready = state(staged.ready);
  await tick();
  const holds = target.head.childNodes.filter((node) => node.hasAttribute?.("data-yumemi-hold"));
  check("body stylesheet held in head", holds.length === 1 && holds[0].getAttribute("href") === "/mincho.css" && holds[0].getAttribute("media") === "not all");
  check("body stylesheet in incoming head not held", !holds.some((node) => node.getAttribute("href") === "/www.css"));
  check("body waits for held stylesheet", ready() === "pending" && target.body.outerHTML === "<body><p>old</p></body>");
  holds[0].fire("load");
  await tick();
  check("ready after held load", ready() === "done");
  const finished = state(staged.commit());
  check("held media restored", holds[0].getAttribute("media") === "screen" && holds[0].parentNode === target.head);
  check("body swapped after hold", target.body.childNodes[1]?.outerHTML === "<p>new</p>");
  await tick();
  check("hold stays until body link loads", finished() === "pending" && holds[0].parentNode === target.head);
  target.body.childNodes[0].fire("load");
  target.body.childNodes[2].fire("load");
  await tick();
  check("hold removed after body link loads", finished() === "done" && holds[0].parentNode === null);
  // 写しは次の差分に数えない
  const again = makeDoc(true, [css("/www.css"), client, ["link", { rel: "stylesheet", href: "/x.css", "data-yumemi-hold": "" }]], []);
  const kept = again.head.childNodes[0];
  const next = stage(again, makeDoc(false, [css("/www.css"), client], []), keep, 1000);
  await next.ready;
  await next.commit();
  check("hold not diffed", again.head.childNodes[0] === kept && again.head.childNodes.some((node) => node.hasAttribute?.("data-yumemi-hold")));
}

// 4. 取り消し(次の click で abort)は先に挿したものを外す
{
  const target = makeDoc(true, [css("/www.css"), client], [["p", {}, ["old"]]]);
  const before = keys(target.head);
  const incoming = makeDoc(false, [css("/www.css"), css("/extra.css"), client], [css("/mincho.css"), ["p", {}, ["new"]]]);
  const staged = stage(target, incoming, keep, 1000);
  staged.cancel();
  check("cancel restores head", JSON.stringify(keys(target.head)) === JSON.stringify(before) && target.body.outerHTML === "<body><p>old</p></body>");
}

// 5. 読めない stylesheet は上限で進む
{
  const target = makeDoc(true, [client], []);
  const staged = stage(target, makeDoc(false, [css("/never.css"), client], []), keep, 20);
  const ready = state(staged.ready);
  await tick();
  check("limit pending", ready() === "pending");
  await new Promise((resolve) => setTimeout(resolve, 40));
  check("limit passes", ready() === "done");
}

console.log(out.join("\n"));
