// GENERATED from public/src/{gen/route.gleam,gen/load/**,pages/**,layout.gleam,shell.gleam} [sha256:42cb85aa9a59] — 手で編集しない

import * as api from "./api.mjs";
import * as blocksPreview from "./blocks_preview.mjs";
import * as frontCss from "../../yumemi/yumemi/front/css.mjs";
import * as gate from "./gate.mjs";
import * as layoutDefinition from "../layout.mjs";
import * as out_article_blob_save from "./out/article_blob_save.mjs";
import * as out_article_create from "./out/article_create.mjs";
import * as out_article_publish from "./out/article_publish.mjs";
import * as out_article_read from "./out/article_read.mjs";
import * as out_article_title from "./out/article_title.mjs";
import * as out_widget_list from "./out/widget_list.mjs";
import * as pageDefinition0 from "../pages/article/arg_slug/page.mjs";
import * as pageDefinition1 from "../pages/status/page.mjs";
import * as pageLoader0 from "./load/article/arg_slug/page.mjs";
import * as pageLoader1 from "./load/status/page.mjs";
import * as route from "./route.mjs";
import * as service from "./service.mjs";
import {Ok} from "../gleam.mjs";
import {Some, Option$None$const} from "../../gleam_stdlib/gleam/option.mjs";
import {run as decodeRun} from "../../gleam_stdlib/gleam/dynamic/decode.mjs";
import {to_document_string, to_string as to_fragment_string} from "../../yumemi/yumemi/front/el.mjs";

const pageRoutes = [...route.routes];
const pages = new Map([
  ["/article/:slug", pageDefinition0.page],
  ["/status", pageDefinition1.page],
]);
const pageSpecs = new Map([
  ["/article/:slug", {
    loader: pageLoader0,
    layout: layoutDefinition.public$,
    vars: [
      { name: "widget", optional: true, from: { type: "query", name: "widget" } },
      { name: "slug", optional: false, from: { type: "path", name: "slug" } },
      { name: "view_only", optional: false, from: { type: "path", name: "slug" } },
      { name: "term", optional: true, from: { type: "query", name: "term" } },
      { name: "subject_handle", optional: true, from: { type: "session", name: "SubjectHandle" } },
      { name: "www_origin", optional: false, from: { type: "origin", name: "public" } },
      { name: "auth_origin", optional: false, from: { type: "auth-origin" } },
    ],
    givens: [
    ],
    sources: [
      { service: service.Service$WidgetList$const, args: [["widget", "widget", true], ["slug", "slug", true]], decoder: decodeWidgetList, optional: true, root: false },
      { service: service.Service$ArticleRead$const, args: [["slug", "slug", false]], decoder: decodeArticleRead, optional: false, root: true },
      { theme: true, from: service.Service$ArticleRead$const, path: [["theme", true]] },
    ],
    blocks: {
      "article": { service: service.Service$ArticleRead$const, render: pageLoader0.block_article },
      "summary": { service: service.Service$ArticleRead$const, render: pageLoader0.block_summary },
      "notice": { service: null, render: pageLoader0.block_notice },
    },
  }],
  ["/status", {
    loader: pageLoader1,
    layout: layoutDefinition.public$,
    vars: [
      { name: "widget", optional: true, from: { type: "query", name: "widget" } },
      { name: "www_origin", optional: false, from: { type: "origin", name: "public" } },
      { name: "auth_origin", optional: false, from: { type: "auth-origin" } },
    ],
    givens: [
    ],
    sources: [
      { service: service.Service$WidgetList$const, args: [], decoder: decodeWidgetList, optional: true, root: false },
    ],
    blocks: {
      "site_header": { service: null, render: pageLoader1.block_site_header },
    },
  }],
]);

function decodeArticleBlobSave(raw) {
  const decoded = decodeRun(raw, out_article_blob_save.decoder());
  if (!(decoded instanceof Ok)) throw new Error("invalid article_blob_save response");
  return decoded[0];
}
function decodeArticleCreate(raw) {
  const decoded = decodeRun(raw, out_article_create.decoder());
  if (!(decoded instanceof Ok)) throw new Error("invalid article_create response");
  return decoded[0];
}
function decodeArticlePublish(raw) {
  const decoded = decodeRun(raw, out_article_publish.decoder());
  if (!(decoded instanceof Ok)) throw new Error("invalid article_publish response");
  return decoded[0];
}
function decodeArticleRead(raw) {
  const decoded = decodeRun(raw, out_article_read.decoder());
  if (!(decoded instanceof Ok)) throw new Error("invalid article_read response");
  return decoded[0];
}
function decodeArticleTitle(raw) {
  const decoded = decodeRun(raw, out_article_title.decoder());
  if (!(decoded instanceof Ok)) throw new Error("invalid article_title response");
  return decoded[0];
}
function decodeWidgetList(raw) {
  const decoded = decodeRun(raw, out_widget_list.decoder());
  if (!(decoded instanceof Ok)) throw new Error("invalid widget_list response");
  return decoded[0];
}

function areaNames(areas) {
  return areas.map((area) => area.name);
}

function gridTemplateAreas(areas) {
  return areas.map((area) => '"' + area.name + '"').join(" ");
}

function pcGridTemplateAreas(spAreas, pcAreas) {
  const spNames = new Set(areaNames(spAreas));
  const pcOnlyNames = new Set(pcAreas.filter((area) => !spNames.has(area.name)).map((area) => area.name));
  const columns = pcOnlyNames.size + 1;
  return spAreas.map((area) => {
    const row = [area.name];
    const pcIndex = pcAreas.findIndex((candidate) => candidate.name === area.name);
    let next = pcIndex + 1;
    while (next < pcAreas.length && pcOnlyNames.has(pcAreas[next].name)) {
      row.push(pcAreas[next].name);
      next += 1;
    }
    while (row.length < columns) row.push(area.name);
    return '"' + row.join(" ") + '"';
  }).join(" ");
}

function areaRule(area, visibility) {
  const rules = [
    '[data-yumemi-grid="layout"] > [data-yumemi-area="' + area.name + '"] {',
    '  grid-area: ' + area.name + ';',
  ];
  if (visibility === "hidden") rules.push("  display: none;");
  if (visibility === "visible") rules.push("  display: block;");
  if (frontCss.Pin$isTop(area.pin)) {
    rules.push("  position: sticky;", "  top: env(safe-area-inset-top);", "  z-index: 3;");
  }
  if (frontCss.Pin$isBottom(area.pin)) {
    rules.push("  position: sticky;", "  bottom: env(safe-area-inset-bottom);", "  z-index: 3;");
  }
  rules.push("}");
  return rules.join("\n");
}

function frameValue(value, fallback) {
  return value instanceof Some ? value[0] : fallback;
}

function mediaBlock(media, body) {
  const query = media === "tablet"
    ? "@media (min-width: 768px) and (max-width: 1023px)"
    : "@media (min-width: 1024px)";
  return query + " {\n" + body + "\n}\n";
}

function gridCssFromLayout(_layout) {
  return "\n[data-yumemi-grid=\"layout\"] {\n  display: grid;\n  grid-template-columns: minmax(0, 1fr);\n  grid-template-areas: \"header\" \"page\" \"footer\";\n  gap: 0;\n}\n[data-yumemi-grid=\"layout\"] > [data-yumemi-area=\"header\"] {\n  grid-area: header;\n  display: flex;\n  flex-direction: column;\n  align-items: stretch;\n  gap: 0.0px;\n  position: sticky;\n  top: env(safe-area-inset-top);\n  z-index: 3;\n}\n[data-yumemi-grid=\"layout\"] > [data-yumemi-area=\"page\"] {\n  grid-area: page;\n  display: flex;\n  flex-direction: column;\n  align-items: stretch;\n  gap: 16.0px;\n}\n[data-yumemi-grid=\"layout\"] > [data-yumemi-area=\"footer\"] {\n  grid-area: footer;\n  display: flex;\n  flex-direction: row;\n  flex-wrap: nowrap;\n  gap: 0.0px;\n  position: sticky;\n  bottom: env(safe-area-inset-bottom);\n  z-index: 3;\n}\n[data-yumemi-grid=\"layout\"] > [data-yumemi-area=\"aside\"] {\n  grid-area: aside;\n  display: flex;\n  flex-direction: column;\n  align-items: stretch;\n  gap: 8.0px;\n  display: none;\n}\n@media (min-width: 1024px) {\n  [data-yumemi-grid=\"layout\"] {\n    grid-template-columns: minmax(0, 1fr) minmax(12rem, 20rem);\n    grid-template-areas: \"header header\" \"page aside\" \"footer footer\";\n  }\n[data-yumemi-grid=\"layout\"] > [data-yumemi-area=\"header\"] {\n  grid-area: header;\n  display: flex;\n  flex-direction: column;\n  align-items: stretch;\n  gap: 0.0px;\n  position: sticky;\n  top: env(safe-area-inset-top);\n  z-index: 3;\n}\n[data-yumemi-grid=\"layout\"] > [data-yumemi-area=\"page\"] {\n  grid-area: page;\n  display: flex;\n  flex-direction: column;\n  align-items: stretch;\n  gap: 16.0px;\n}\n[data-yumemi-grid=\"layout\"] > [data-yumemi-area=\"aside\"] {\n  grid-area: aside;\n  display: flex;\n  flex-direction: column;\n  align-items: stretch;\n  gap: 8.0px;\n}\n[data-yumemi-grid=\"layout\"] > [data-yumemi-area=\"footer\"] {\n  grid-area: footer;\n  display: flex;\n  flex-direction: row;\n  flex-wrap: nowrap;\n  gap: 0.0px;\n  position: sticky;\n  bottom: env(safe-area-inset-bottom);\n  z-index: 3;\n}\n}\n\n[data-yumemi-grid=\"page:pages/article/arg_slug/page\"] {\n  display: grid;\n  grid-template-columns: minmax(0, 1fr);\n  grid-template-areas: \"page\" \"rail\";\n  gap: 0;\n}\n[data-yumemi-grid=\"page:pages/article/arg_slug/page\"] > [data-yumemi-area=\"page\"] {\n  grid-area: page;\n  display: flex;\n  flex-direction: column;\n  align-items: stretch;\n  gap: 16.0px;\n}\n[data-yumemi-grid=\"page:pages/article/arg_slug/page\"] > [data-yumemi-area=\"rail\"] {\n  grid-area: rail;\n  display: flex;\n  flex-direction: column;\n  align-items: stretch;\n  gap: 8.0px;\n}\n[data-yumemi-grid=\"page:pages/article/arg_slug/page\"] > [data-yumemi-area=\"aside\"] {\n  grid-area: aside;\n  display: flex;\n  flex-direction: column;\n  align-items: stretch;\n  gap: 8.0px;\n  display: none;\n}\n@media (min-width: 1024px) {\n  [data-yumemi-grid=\"page:pages/article/arg_slug/page\"] {\n    grid-template-columns: minmax(0, 1fr) minmax(12rem, 20rem);\n    grid-template-areas: \"page page\" \"rail aside\";\n  }\n[data-yumemi-grid=\"page:pages/article/arg_slug/page\"] > [data-yumemi-area=\"page\"] {\n  grid-area: page;\n  display: flex;\n  flex-direction: column;\n  align-items: stretch;\n  gap: 16.0px;\n}\n[data-yumemi-grid=\"page:pages/article/arg_slug/page\"] > [data-yumemi-area=\"rail\"] {\n  grid-area: rail;\n  display: flex;\n  flex-direction: column;\n  align-items: stretch;\n  gap: 8.0px;\n}\n[data-yumemi-grid=\"page:pages/article/arg_slug/page\"] > [data-yumemi-area=\"aside\"] {\n  grid-area: aside;\n  display: flex;\n  flex-direction: column;\n  align-items: stretch;\n  gap: 8.0px;\n}\n}\n\n[data-yumemi-grid=\"page:pages/status/page\"] {\n  display: grid;\n  grid-template-columns: minmax(0, 1fr);\n  grid-template-areas: \"page\";\n  gap: 0;\n}\n[data-yumemi-grid=\"page:pages/status/page\"] > [data-yumemi-area=\"page\"] {\n  grid-area: page;\n  display: flex;\n  flex-direction: column;\n  align-items: stretch;\n  gap: 0.0px;\n}\n[data-yumemi-badge] {\n  position: absolute;\n  inset-block-start: 0;\n  inset-inline-end: 0;\n  display: inline-flex;\n  align-items: center;\n  justify-content: center;\n  min-width: 1.25rem;\n  height: 1.25rem;\n  padding-inline: 0.25rem;\n  border-radius: 999px;\n  color: var(--yumemi-theme-bg);\n  background: var(--yumemi-theme-accent);\n  font: 600 0.75rem/1 system-ui, sans-serif;\n}\n[data-yumemi-badge][data-count=\"\"],\n[data-yumemi-badge][data-count=\"0\"] { display: none; }\ndialog:not([open]) { display: none !important; }\n@layer yumemi-closed-dialog { dialog:not([open]) { display: none !important; } }\n[hidden]:not([hidden=until-found i]) { display: none !important; }\n@layer yumemi-hidden { [hidden]:not([hidden=until-found i]) { display: none !important; } }\n[popover]::backdrop { background: rgba(0, 0, 0, 0.45); }\n[data-yumemi-island] > form > fieldset { border: 0; margin: 0; padding: 0; min-inline-size: 0; }\n[data-yumemi-when] { display: contents; }\n@supports selector(:state(x)) {\n  article-blob-copy:state(sent-blob_copy) [data-yumemi-when~=\"blob_copy.idle\"] { display: none; }\n  article-blob-copy:not(:state(waiting):state(sent-blob_copy)) [data-yumemi-when~=\"blob_copy.waiting\"] { display: none; }\n  article-blob-copy:not(:state(ok):state(sent-blob_copy)) [data-yumemi-when~=\"blob_copy.succeeded\"] { display: none; }\n  article-blob-copy:not(:state(failed):state(sent-blob_copy)) [data-yumemi-when~=\"blob_copy.failed\"] { display: none; }\n  article-manage:state(sent-article_publish) [data-yumemi-when~=\"article_publish.idle\"] { display: none; }\n  article-manage:not(:state(waiting):state(sent-article_publish)) [data-yumemi-when~=\"article_publish.waiting\"] { display: none; }\n  article-manage:not(:state(ok):state(sent-article_publish)) [data-yumemi-when~=\"article_publish.succeeded\"] { display: none; }\n  article-manage:not(:state(failed):state(sent-article_publish)) [data-yumemi-when~=\"article_publish.failed\"] { display: none; }\n  article-manage:not(:state(refused-already-published):state(sent-article_publish)) [data-yumemi-when~=\"article_publish.refused-already-published\"] { display: none; }\n  article-manage:not(:state(refused-already-retracted):state(sent-article_publish)) [data-yumemi-when~=\"article_publish.refused-already-retracted\"] { display: none; }\n  article-manage:state(sent-article_create) [data-yumemi-when~=\"article_create.idle\"] { display: none; }\n  article-manage:not(:state(waiting):state(sent-article_create)) [data-yumemi-when~=\"article_create.waiting\"] { display: none; }\n  article-manage:not(:state(ok):state(sent-article_create)) [data-yumemi-when~=\"article_create.succeeded\"] { display: none; }\n  article-manage:not(:state(failed):state(sent-article_create)) [data-yumemi-when~=\"article_create.failed\"] { display: none; }\n  blob-save:state(sent-article_blob_save) [data-yumemi-when~=\"article_blob_save.idle\"] { display: none; }\n  blob-save:not(:state(waiting):state(sent-article_blob_save)) [data-yumemi-when~=\"article_blob_save.waiting\"] { display: none; }\n  blob-save:not(:state(ok):state(sent-article_blob_save)) [data-yumemi-when~=\"article_blob_save.succeeded\"] { display: none; }\n  blob-save:not(:state(failed):state(sent-article_blob_save)) [data-yumemi-when~=\"article_blob_save.failed\"] { display: none; }\n  like-button:state(sent-article_publish) [data-yumemi-when~=\"article_publish.idle\"] { display: none; }\n  like-button:not(:state(waiting):state(sent-article_publish)) [data-yumemi-when~=\"article_publish.waiting\"] { display: none; }\n  like-button:not(:state(ok):state(sent-article_publish)) [data-yumemi-when~=\"article_publish.succeeded\"] { display: none; }\n  like-button:not(:state(failed):state(sent-article_publish)) [data-yumemi-when~=\"article_publish.failed\"] { display: none; }\n  like-button:not(:state(refused-already-published):state(sent-article_publish)) [data-yumemi-when~=\"article_publish.refused-already-published\"] { display: none; }\n  like-button:not(:state(refused-already-retracted):state(sent-article_publish)) [data-yumemi-when~=\"article_publish.refused-already-retracted\"] { display: none; }\n  pick-tag:state(sent-article_create) [data-yumemi-when~=\"article_create.idle\"] { display: none; }\n  pick-tag:not(:state(waiting):state(sent-article_create)) [data-yumemi-when~=\"article_create.waiting\"] { display: none; }\n  pick-tag:not(:state(ok):state(sent-article_create)) [data-yumemi-when~=\"article_create.succeeded\"] { display: none; }\n  pick-tag:not(:state(failed):state(sent-article_create)) [data-yumemi-when~=\"article_create.failed\"] { display: none; }\n  tag-filter:state(sent-widget_list) [data-yumemi-when~=\"widget_list.idle\"] { display: none; }\n  tag-filter:not(:state(waiting):state(sent-widget_list)) [data-yumemi-when~=\"widget_list.waiting\"] { display: none; }\n  tag-filter:not(:state(ok):state(sent-widget_list)) [data-yumemi-when~=\"widget_list.succeeded\"] { display: none; }\n  tag-filter:not(:state(failed):state(sent-widget_list)) [data-yumemi-when~=\"widget_list.failed\"] { display: none; }\n  title-lookup:state(sent-article_title) [data-yumemi-when~=\"article_title.idle\"] { display: none; }\n  title-lookup:not(:state(waiting):state(sent-article_title)) [data-yumemi-when~=\"article_title.waiting\"] { display: none; }\n  title-lookup:not(:state(ok):state(sent-article_title)) [data-yumemi-when~=\"article_title.succeeded\"] { display: none; }\n  title-lookup:not(:state(failed):state(sent-article_title)) [data-yumemi-when~=\"article_title.failed\"] { display: none; }\n}\n@supports not selector(:state(x)) {\n  article-blob-copy[data-yumemi-state~=\"sent-blob_copy\"] [data-yumemi-when~=\"blob_copy.idle\"] { display: none; }\n  article-blob-copy:not([data-yumemi-state~=\"waiting\"][data-yumemi-state~=\"sent-blob_copy\"]) [data-yumemi-when~=\"blob_copy.waiting\"] { display: none; }\n  article-blob-copy:not([data-yumemi-state~=\"ok\"][data-yumemi-state~=\"sent-blob_copy\"]) [data-yumemi-when~=\"blob_copy.succeeded\"] { display: none; }\n  article-blob-copy:not([data-yumemi-state~=\"failed\"][data-yumemi-state~=\"sent-blob_copy\"]) [data-yumemi-when~=\"blob_copy.failed\"] { display: none; }\n  article-manage[data-yumemi-state~=\"sent-article_publish\"] [data-yumemi-when~=\"article_publish.idle\"] { display: none; }\n  article-manage:not([data-yumemi-state~=\"waiting\"][data-yumemi-state~=\"sent-article_publish\"]) [data-yumemi-when~=\"article_publish.waiting\"] { display: none; }\n  article-manage:not([data-yumemi-state~=\"ok\"][data-yumemi-state~=\"sent-article_publish\"]) [data-yumemi-when~=\"article_publish.succeeded\"] { display: none; }\n  article-manage:not([data-yumemi-state~=\"failed\"][data-yumemi-state~=\"sent-article_publish\"]) [data-yumemi-when~=\"article_publish.failed\"] { display: none; }\n  article-manage:not([data-yumemi-state~=\"refused-already-published\"][data-yumemi-state~=\"sent-article_publish\"]) [data-yumemi-when~=\"article_publish.refused-already-published\"] { display: none; }\n  article-manage:not([data-yumemi-state~=\"refused-already-retracted\"][data-yumemi-state~=\"sent-article_publish\"]) [data-yumemi-when~=\"article_publish.refused-already-retracted\"] { display: none; }\n  article-manage[data-yumemi-state~=\"sent-article_create\"] [data-yumemi-when~=\"article_create.idle\"] { display: none; }\n  article-manage:not([data-yumemi-state~=\"waiting\"][data-yumemi-state~=\"sent-article_create\"]) [data-yumemi-when~=\"article_create.waiting\"] { display: none; }\n  article-manage:not([data-yumemi-state~=\"ok\"][data-yumemi-state~=\"sent-article_create\"]) [data-yumemi-when~=\"article_create.succeeded\"] { display: none; }\n  article-manage:not([data-yumemi-state~=\"failed\"][data-yumemi-state~=\"sent-article_create\"]) [data-yumemi-when~=\"article_create.failed\"] { display: none; }\n  blob-save[data-yumemi-state~=\"sent-article_blob_save\"] [data-yumemi-when~=\"article_blob_save.idle\"] { display: none; }\n  blob-save:not([data-yumemi-state~=\"waiting\"][data-yumemi-state~=\"sent-article_blob_save\"]) [data-yumemi-when~=\"article_blob_save.waiting\"] { display: none; }\n  blob-save:not([data-yumemi-state~=\"ok\"][data-yumemi-state~=\"sent-article_blob_save\"]) [data-yumemi-when~=\"article_blob_save.succeeded\"] { display: none; }\n  blob-save:not([data-yumemi-state~=\"failed\"][data-yumemi-state~=\"sent-article_blob_save\"]) [data-yumemi-when~=\"article_blob_save.failed\"] { display: none; }\n  like-button[data-yumemi-state~=\"sent-article_publish\"] [data-yumemi-when~=\"article_publish.idle\"] { display: none; }\n  like-button:not([data-yumemi-state~=\"waiting\"][data-yumemi-state~=\"sent-article_publish\"]) [data-yumemi-when~=\"article_publish.waiting\"] { display: none; }\n  like-button:not([data-yumemi-state~=\"ok\"][data-yumemi-state~=\"sent-article_publish\"]) [data-yumemi-when~=\"article_publish.succeeded\"] { display: none; }\n  like-button:not([data-yumemi-state~=\"failed\"][data-yumemi-state~=\"sent-article_publish\"]) [data-yumemi-when~=\"article_publish.failed\"] { display: none; }\n  like-button:not([data-yumemi-state~=\"refused-already-published\"][data-yumemi-state~=\"sent-article_publish\"]) [data-yumemi-when~=\"article_publish.refused-already-published\"] { display: none; }\n  like-button:not([data-yumemi-state~=\"refused-already-retracted\"][data-yumemi-state~=\"sent-article_publish\"]) [data-yumemi-when~=\"article_publish.refused-already-retracted\"] { display: none; }\n  pick-tag[data-yumemi-state~=\"sent-article_create\"] [data-yumemi-when~=\"article_create.idle\"] { display: none; }\n  pick-tag:not([data-yumemi-state~=\"waiting\"][data-yumemi-state~=\"sent-article_create\"]) [data-yumemi-when~=\"article_create.waiting\"] { display: none; }\n  pick-tag:not([data-yumemi-state~=\"ok\"][data-yumemi-state~=\"sent-article_create\"]) [data-yumemi-when~=\"article_create.succeeded\"] { display: none; }\n  pick-tag:not([data-yumemi-state~=\"failed\"][data-yumemi-state~=\"sent-article_create\"]) [data-yumemi-when~=\"article_create.failed\"] { display: none; }\n  tag-filter[data-yumemi-state~=\"sent-widget_list\"] [data-yumemi-when~=\"widget_list.idle\"] { display: none; }\n  tag-filter:not([data-yumemi-state~=\"waiting\"][data-yumemi-state~=\"sent-widget_list\"]) [data-yumemi-when~=\"widget_list.waiting\"] { display: none; }\n  tag-filter:not([data-yumemi-state~=\"ok\"][data-yumemi-state~=\"sent-widget_list\"]) [data-yumemi-when~=\"widget_list.succeeded\"] { display: none; }\n  tag-filter:not([data-yumemi-state~=\"failed\"][data-yumemi-state~=\"sent-widget_list\"]) [data-yumemi-when~=\"widget_list.failed\"] { display: none; }\n  title-lookup[data-yumemi-state~=\"sent-article_title\"] [data-yumemi-when~=\"article_title.idle\"] { display: none; }\n  title-lookup:not([data-yumemi-state~=\"waiting\"][data-yumemi-state~=\"sent-article_title\"]) [data-yumemi-when~=\"article_title.waiting\"] { display: none; }\n  title-lookup:not([data-yumemi-state~=\"ok\"][data-yumemi-state~=\"sent-article_title\"]) [data-yumemi-when~=\"article_title.succeeded\"] { display: none; }\n  title-lookup:not([data-yumemi-state~=\"failed\"][data-yumemi-state~=\"sent-article_title\"]) [data-yumemi-when~=\"article_title.failed\"] { display: none; }\n}\n";
}

function matchPage(pathname) {
  for (const pageRoute of pageRoutes) {
    const expected = pageRoute.path.split("/");
    const actual = pathname.split("/");
    if (expected.length !== actual.length) continue;
    const params = {};
    let matches = true;
    for (let index = 0; index < expected.length; index += 1) {
      const segment = expected[index];
      const value = actual[index];
      if (segment.startsWith(":")) params[segment.slice(1)] = decodeURIComponent(value);
      else if (segment !== value) matches = false;
    }
    if (matches && pages.has(pageRoute.path)) {
      return {path: pageRoute.path, definition: pages.get(pageRoute.path), spec: pageSpecs.get(pageRoute.path), params};
    }
  }
  return null;
}

function apiPathFor(serviceValue) {
  const entry = [...api.routes].find((item) => item.service === serviceValue);
  if (!entry) throw new Error("missing front API route");
  return entry.path;
}

function argsFor(vars, mapping) {
  return Object.fromEntries(mapping.map(([name, field, optional]) => {
    const value = vars[field];
    return [name, optional && typeof value === "string" ? new Some(value) : value];
  }));
}

async function readFromApp(app, request, serviceValue, args) {
  const used = new Set();
  const path = apiPathFor(serviceValue).replace(/:([A-Za-z0-9_]+)/g, (_, name) => {
    used.add(name);
    const arg = args[name];
    const value = arg instanceof Some ? arg[0] : arg;
    if (typeof value !== "string") throw new Error("missing service path arg: " + name);
    return encodeURIComponent(value);
  });
  const target = new URL(path, request.url);
  for (const [name, arg] of Object.entries(args)) {
    if (used.has(name)) continue;
    const value = arg instanceof Some ? arg[0] : arg;
    if (typeof value === "string") target.searchParams.set(name, value);
  }
  return app.fetch(new Request(target, request));
}

function pageTheme(path, value) {
  if (value === undefined || value === null) return Option$None$const;
  for (const [field, optional] of path) {
    value = value[field];
    if (value instanceof Some) value = value[0];
    else if (optional || value === undefined || value === null) return Option$None$const;
  }
  return new Some(value);
}

function failure(status, body) {
  return new Response(body, {status, headers: {"content-type": "text/plain; charset=utf-8"}});
}

async function renderPage(request, env, matched, gateSession) {
  const vars = {};
  const query = new URL(request.url).searchParams;
  let sessionLoaded = gateSession !== undefined;
  let session = gateSession ?? null;
  for (const field of matched.spec.vars) {
    const source = field.from;
    let value;
    if (source.type === "path") {
      value = matched.params[source.name];
    } else if (source.type === "query") {
      const found = query.get(source.name);
      value = found === null || found.trim() === "" ? Option$None$const : new Some(found);
    } else if (source.type === "origin") {
      const envName = "PUBLIC_" + source.name.toUpperCase() + "_ORIGIN";
      const origin = env[envName];
      if (typeof origin !== "string" || origin.length === 0) return failure(500, envName);
      value = origin;
    } else if (source.type === "auth-origin") {
      const envName = "PUBLIC_IDP_ORIGIN";
      const origin = env[envName];
      if (typeof origin !== "string" || origin.length === 0) return failure(500, envName);
      value = origin;
    } else if (source.type === "session") {
      if (!sessionLoaded) {
        sessionLoaded = true;
        // 読みの 5xx と例外は匿名に畳まず 503 の unavailable、元の status と原因は log へ(0.12)
        let response;
        try {
          const target = new URL("/api/session", request.url);
          response = await env.APP.fetch(new Request(target, request));
          if (response.ok) session = await response.json();
        } catch (error) {
          console.error("yumemi shell: session read error", 502, error);
          return failure(503, "unavailable");
        }
        if (response.status >= 500) {
          console.error("yumemi shell: session read error", response.status, await response.text().catch(() => ""));
          return failure(503, "unavailable");
        }
      }
      const subject = session?.anonymous === true ? undefined : session?.subject;
      const found = source.name === "SubjectHandle" ? subject?.handle : subject?.id;
      if (typeof found === "string") value = field.optional ? new Some(found) : found;
      else if (field.optional) value = Option$None$const;
      else return failure(401, "unauthorized");
    } else {
      return failure(500, "invalid variable source");
    }
    vars[field.name] = value;
  }
  const values = [vars];
  const read = new Map();
  for (const source of matched.spec.sources) {
    if (source.theme) {
      values.push(pageTheme(source.path ?? [], read.get(source.from)));
      continue;
    }
    let response;
    try {
      response = await readFromApp(env.APP, request, source.service, argsFor(vars, source.args));
    } catch (error) {
      console.error(source.root ? "yumemi shell: root read error" : "yumemi shell: widget read error", 502, error);
      return failure(503, "unavailable");
    }
    if (!response.ok) {
      if (response.status === 403) return failure(403, "forbidden");
      if (response.status === 404 && !source.root) { values.push(Option$None$const); continue; }
      if (response.status === 404) return failure(404, "not found");
      // 読みの 5xx は門と同じ 503 の unavailable、元の status と原因は log へ(0.12)
      if (response.status >= 500) {
        console.error(source.root ? "yumemi shell: root read error" : "yumemi shell: widget read error", response.status, await response.text().catch(() => ""));
        return failure(503, "unavailable");
      }
      return failure(response.status, source.root ? "root read failed" : "widget read failed");
    }
    const decoded = source.decoder(await response.json());
    read.set(source.service, decoded);
    values.push(source.optional ? new Some(decoded) : decoded);
  }
  const givens = [];
  for (const given of matched.spec.givens) {
    const response = await readFromApp(env.APP, request, given.service, argsFor(vars, given.args));
    if (!response.ok) continue;
    const raw = await response.json();
    given.decoder(raw);
    givens.push({tag: given.tag, raw});
  }
  const html = to_document_string(matched.spec.loader.render(matched.spec.loader.load(...values)));
  const withGivens = addGivenAttributes(html, givens);
  return new Response(htmlWithGridCss(withGivens, matched.spec.layout), {status: 200, headers: {"content-type": "text/html; charset=utf-8"}});
}

async function renderBlock(request, env, matched, gateSession, name) {
  const blocks = matched.spec.blocks ?? {};
  const live = Object.hasOwn(blocks, name) ? blocks[name] : null;
  if (live === null) return failure(404, "not found");
  const vars = {};
  const query = new URL(request.url).searchParams;
  let sessionLoaded = gateSession !== undefined;
  let session = gateSession ?? null;
  for (const field of matched.spec.vars) {
    const source = field.from;
    let value;
    if (source.type === "path") {
      value = matched.params[source.name];
    } else if (source.type === "query") {
      const found = query.get(source.name);
      value = found === null || found.trim() === "" ? Option$None$const : new Some(found);
    } else if (source.type === "origin") {
      const envName = "PUBLIC_" + source.name.toUpperCase() + "_ORIGIN";
      const origin = env[envName];
      if (typeof origin !== "string" || origin.length === 0) return failure(500, envName);
      value = origin;
    } else if (source.type === "auth-origin") {
      const envName = "PUBLIC_IDP_ORIGIN";
      const origin = env[envName];
      if (typeof origin !== "string" || origin.length === 0) return failure(500, envName);
      value = origin;
    } else if (source.type === "session") {
      if (!sessionLoaded) {
        sessionLoaded = true;
        // 読みの 5xx と例外は匿名に畳まず 503 の unavailable、元の status と原因は log へ(0.12)
        let response;
        try {
          const target = new URL("/api/session", request.url);
          response = await env.APP.fetch(new Request(target, request));
          if (response.ok) session = await response.json();
        } catch (error) {
          console.error("yumemi shell: session read error", 502, error);
          return failure(503, "unavailable");
        }
        if (response.status >= 500) {
          console.error("yumemi shell: session read error", response.status, await response.text().catch(() => ""));
          return failure(503, "unavailable");
        }
      }
      const subject = session?.anonymous === true ? undefined : session?.subject;
      const found = source.name === "SubjectHandle" ? subject?.handle : subject?.id;
      if (typeof found === "string") value = field.optional ? new Some(found) : found;
      else if (field.optional) value = Option$None$const;
      else return failure(401, "unauthorized");
    } else {
      return failure(500, "invalid variable source");
    }
    vars[field.name] = value;
  }
  let value;
  for (const source of matched.spec.sources) {
    if (source.theme || !(source.service === live.service || source.root)) continue;
    let response;
    try {
      response = await readFromApp(env.APP, request, source.service, argsFor(vars, source.args));
    } catch (error) {
      console.error("yumemi shell: block read error", 502, error);
      return failure(503, "unavailable");
    }
    if (!response.ok) {
      if (response.status === 403) return failure(403, "forbidden");
      if (response.status === 404 && !source.root) { value = Option$None$const; continue; }
      if (response.status === 404) return failure(404, "not found");
      if (response.status >= 500) {
        console.error("yumemi shell: block read error", response.status, await response.text().catch(() => ""));
        return failure(503, "unavailable");
      }
      return failure(response.status, "block read failed");
    }
    if (source.service !== live.service) {
      await response.body?.cancel();
      continue;
    }
    const decoded = source.decoder(await response.json());
    value = source.optional ? new Some(decoded) : decoded;
  }
  if (live.service !== null && value === undefined) return failure(500, "block source is missing");
  const body = to_fragment_string(live.service === null ? live.render(vars) : live.render(vars, value));
  const html = body;
  return new Response(html, {status: 200, headers: {"content-type": "text/html; charset=utf-8", "cache-control": "no-store", "vary": "x-yumemi-block"}});
}

function addGivenAttributes(html, givens) {
  let output = html;
  for (const given of givens) {
    let searchFrom = 0;
    const marker = `<${given.tag} `;
    let markerOffset = output.indexOf(marker, searchFrom);
    while (markerOffset >= 0) {
      const tagEnd = output.indexOf(">", markerOffset + marker.length);
      if (tagEnd < 0) break;
      const tagText = output.slice(markerOffset, tagEnd);
      searchFrom = tagEnd + 1;
      if (tagText.includes("data-yumemi-given")) {
        markerOffset = output.indexOf(marker, searchFrom);
        continue;
      }
      const encoded = JSON.stringify(given.raw).replaceAll("&", "&amp;").replaceAll("\"", "&quot;").replaceAll("<", "&lt;");
      const before = output.slice(0, markerOffset);
      const fromMarker = output.slice(markerOffset);
      output = before + fromMarker.replace(marker, () => `<${given.tag} data-yumemi-given="${encoded}" `);
      searchFrom = markerOffset + `<${given.tag} data-yumemi-given="${encoded}" `.length;
      break;
    }
  }
  return output;
}

function htmlWithGridCss(html, layout) {
  const marker = "<style>";
  const offset = html.indexOf(marker);
  if (offset < 0) throw new Error("SSR stylesheet is missing");
  const insertion = offset + marker.length;
  const rendered = html.slice(0, insertion) + gridCssFromLayout(layout) + html.slice(insertion);
  return rendered.replace("</head>", '<script type="module" src="/_yumemi/client.mjs"></script></head>');
}



function renderBlocksPreview() {
  const html = to_document_string(blocksPreview.render());
  const withStyle = html.includes("<style>")
    ? html
    : html.replace("<head>", "<head><style></style>");
  return new Response(withStyle.replace("</head>", '<script type="module" src="/_yumemi/client.mjs"></script></head>'), {status: 200, headers: {"content-type": "text/html; charset=utf-8"}});
}

export default gate.serve(async (request, env, before) => {
  if (new URL(request.url).pathname === "/_blocks" && env.YUMEMI_DEV === "1") return renderBlocksPreview();
  const matched = matchPage(new URL(request.url).pathname);
  if (!matched) {
    if (env.SVELTE) return env.SVELTE.fetch(request);
    return failure(404, "not found");
  }
  // 0.14:Block の断片の口(0.14.1 から `Fixed` の Block も)。門は頁と同じ道を通った後(数える印は差さない)
  const block = request.headers.get("x-yumemi-block");
  if (block !== null) return renderBlock(request, env, matched, before.session, block);
  return renderPage(request, env, matched, before.session);
});
