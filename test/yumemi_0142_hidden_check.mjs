// 0.14.2 ── 生成した共通 CSS の `[hidden]` の規則を Chromium の computed style で見る。stdin に生成の style.css の全文。
// 作者の class が display を持っていても `hidden` で隠れ、`hidden="until-found"` と `hidden` の無い要素は隠れない。
// 1 行 1 件の ok / NG を出す。
import fs from "node:fs";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright-core");

const generated = fs.readFileSync(0, "utf8");
const out = [];
const check = (name, ok, detail = "") => {
  out.push(`${ok ? "ok" : "NG"} ${name}${ok || detail === "" ? "" : ` ── ${detail}`}`);
};

// 作者の規則: class の display、層の中の display、層の中の display の !important、inline の display
const author = `
.flow { display: flex; }
.grid { display: grid; }
@layer author { .layered { display: flex; } .layered-important { display: flex !important; } }
.important { display: flex !important; }
`;
const body = `
<div id="plain" class="flow">x</div>
<div id="flow" class="flow" hidden>x</div>
<div id="grid" class="grid" hidden>x</div>
<div id="layered" class="layered" hidden>x</div>
<div id="layered-important" class="layered-important" hidden>x</div>
<div id="important" class="important" hidden>x</div>
<div id="inline" style="display:flex" hidden>x</div>
<div id="empty" class="flow" hidden="">x</div>
<div id="until" class="flow" hidden="until-found">x</div>
<div id="until-caps" class="flow" hidden="UNTIL-FOUND">x</div>
<button id="fresh" class="flow" data-yumemi-fresh hidden>x</button>
<p id="p" hidden>x</p>
`;

const chrome = await chromium.launch();
try {
  const page = await chrome.newPage();
  await page.setContent(`<!doctype html><html><head><meta charset="utf-8"><style>${generated}</style><style>${author}</style></head><body>${body}</body></html>`);
  const display = await page.evaluate(() => Object.fromEntries([...document.querySelectorAll("body > *")].map((el) => [el.id, getComputedStyle(el).display])));
  const expectNone = ["flow", "grid", "layered", "layered-important", "important", "inline", "empty", "fresh", "p"];
  for (const id of expectNone) check(`hidden hides #${id} (computed display none)`, display[id] === "none", display[id]);
  check("a flex element without hidden stays flex", display.plain === "flex", display.plain);
  check('hidden="until-found" is not display:none (find-in-page and fragments still open it)', display.until !== "none" && display["until-caps"] !== "none", JSON.stringify([display.until, display["until-caps"]]));
  const height = await page.evaluate(() => document.getElementById("flow").getBoundingClientRect().height);
  check("a hidden flex element takes no height", height === 0, String(height));
  // JS が hidden を外せば見える(Live の差し替え・el.fresh の出し入れ)
  const shown = await page.evaluate(() => {
    const el = document.getElementById("flow");
    el.hidden = false;
    return getComputedStyle(el).display;
  });
  check("removing hidden shows the element again", shown === "flex", shown);
  // 層のある規則は「層の無い browser」の代わりに両方を見る
  check("the CSS has the rule outside and inside @layer", generated.includes("[hidden]:not([hidden=until-found i]) { display: none !important; }\n@layer yumemi-hidden { [hidden]:not([hidden=until-found i]) { display: none !important; } }"));
} finally {
  await chrome.close();
}
console.log(out.join("\n"));
process.exit(0);
