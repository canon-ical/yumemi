// GENERATED from public/src/{gen/route.gleam,gen/load/**,pages/**,layout.gleam,shell.gleam} [sha256:fdeb89ab8602] — 手で編集しない

import * as api from "./api.mjs";
import * as blocksPreview from "./blocks_preview.mjs";
import * as frontCss from "../../yumemi/framework/front/css.mjs";
import * as gate from "./gate.mjs";
import * as layoutDefinition from "../layout.mjs";
import * as out_article_blob_save from "./out/article_blob_save.mjs";
import * as out_article_create from "./out/article_create.mjs";
import * as out_article_list from "./out/article_list.mjs";
import * as out_article_publish from "./out/article_publish.mjs";
import * as out_article_read from "./out/article_read.mjs";
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
import {to_document_string} from "../../lustre/lustre/element.mjs";

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
      { tag: "pick-tag", service: service.Service$ArticleList$const, args: [], decoder: decodeArticleList },
    ],
    sources: [
      { service: service.Service$WidgetList$const, args: [["widget", "widget", true], ["slug", "slug", true]], decoder: decodeWidgetList, optional: true, root: false },
      { service: service.Service$ArticleRead$const, args: [["slug", "slug", false]], decoder: decodeArticleRead, optional: false, root: true },
      { theme: true },
    ],
  }],
  ["/status", {
    loader: pageLoader1,
    layout: layoutDefinition.public$,
    vars: [
      { name: "www_origin", optional: false, from: { type: "origin", name: "public" } },
      { name: "auth_origin", optional: false, from: { type: "auth-origin" } },
    ],
    givens: [
      { tag: "pick-tag", service: service.Service$ArticleList$const, args: [], decoder: decodeArticleList },
    ],
    sources: [
      { service: service.Service$WidgetList$const, args: [], decoder: decodeWidgetList, optional: true, root: false },
    ],
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
function decodeArticleList(raw) {
  const decoded = decodeRun(raw, out_article_list.decoder());
  if (!(decoded instanceof Ok)) throw new Error("invalid article_list response");
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
  return "\n[data-yumemi-grid=\"layout\"] {\n  display: grid;\n  grid-template-columns: minmax(0, 1fr);\n  grid-template-areas: \"header\" \"page\" \"footer\";\n  gap: 0;\n}\n[data-yumemi-grid=\"layout\"] > [data-yumemi-area=\"header\"] {\n  grid-area: header;\n  position: sticky;\n  top: env(safe-area-inset-top);\n  z-index: 3;\n}\n[data-yumemi-grid=\"layout\"] > [data-yumemi-area=\"page\"] {\n  grid-area: page;\n}\n[data-yumemi-grid=\"layout\"] > [data-yumemi-area=\"footer\"] {\n  grid-area: footer;\n  position: sticky;\n  bottom: env(safe-area-inset-bottom);\n  z-index: 3;\n}\n[data-yumemi-grid=\"layout\"] > [data-yumemi-area=\"aside\"] {\n  grid-area: aside;\n  display: none;\n}\n@media (min-width: 1024px) {\n  [data-yumemi-grid=\"layout\"] {\n    grid-template-columns: minmax(0, 1fr) minmax(12rem, 20rem);\n    grid-template-areas: \"header header\" \"page aside\" \"footer footer\";\n  }\n[data-yumemi-grid=\"layout\"] > [data-yumemi-area=\"header\"] {\n  grid-area: header;\n  position: sticky;\n  top: env(safe-area-inset-top);\n  z-index: 3;\n}\n[data-yumemi-grid=\"layout\"] > [data-yumemi-area=\"page\"] {\n  grid-area: page;\n}\n[data-yumemi-grid=\"layout\"] > [data-yumemi-area=\"aside\"] {\n  grid-area: aside;\n  display: block;\n}\n[data-yumemi-grid=\"layout\"] > [data-yumemi-area=\"footer\"] {\n  grid-area: footer;\n  position: sticky;\n  bottom: env(safe-area-inset-bottom);\n  z-index: 3;\n}\n}\n\n[data-yumemi-grid=\"page:pages/article/arg_slug/page\"] {\n  display: grid;\n  grid-template-columns: minmax(0, 1fr);\n  grid-template-areas: \"page\" \"rail\";\n  gap: 0;\n}\n[data-yumemi-grid=\"page:pages/article/arg_slug/page\"] > [data-yumemi-area=\"page\"] {\n  grid-area: page;\n}\n[data-yumemi-grid=\"page:pages/article/arg_slug/page\"] > [data-yumemi-area=\"rail\"] {\n  grid-area: rail;\n}\n[data-yumemi-grid=\"page:pages/article/arg_slug/page\"] > [data-yumemi-area=\"aside\"] {\n  grid-area: aside;\n  display: none;\n}\n@media (min-width: 1024px) {\n  [data-yumemi-grid=\"page:pages/article/arg_slug/page\"] {\n    grid-template-columns: minmax(0, 1fr) minmax(12rem, 20rem);\n    grid-template-areas: \"page page\" \"rail aside\";\n  }\n[data-yumemi-grid=\"page:pages/article/arg_slug/page\"] > [data-yumemi-area=\"page\"] {\n  grid-area: page;\n}\n[data-yumemi-grid=\"page:pages/article/arg_slug/page\"] > [data-yumemi-area=\"rail\"] {\n  grid-area: rail;\n}\n[data-yumemi-grid=\"page:pages/article/arg_slug/page\"] > [data-yumemi-area=\"aside\"] {\n  grid-area: aside;\n  display: block;\n}\n}\n\n[data-yumemi-grid=\"page:pages/status/page\"] {\n  display: grid;\n  grid-template-columns: minmax(0, 1fr);\n  grid-template-areas: \"page\";\n  gap: 0;\n}\n[data-yumemi-grid=\"page:pages/status/page\"] > [data-yumemi-area=\"page\"] {\n  grid-area: page;\n}\n[data-yumemi-badge] {\n  position: absolute;\n  inset-block-start: 0;\n  inset-inline-end: 0;\n  display: inline-flex;\n  align-items: center;\n  justify-content: center;\n  min-width: 1.25rem;\n  height: 1.25rem;\n  padding-inline: 0.25rem;\n  border-radius: 999px;\n  color: var(--bg);\n  background: var(--accent);\n  font: 600 0.75rem/1 system-ui, sans-serif;\n}\n[data-yumemi-badge][data-count=\"\"],\n[data-yumemi-badge][data-count=\"0\"] { display: none; }\n[popover]::backdrop { background: rgba(0, 0, 0, 0.45); }\n";
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

function pageTheme(definition, root) {
  if (!(definition.theme instanceof Some)) return Option$None$const;
  return root[definition.theme[0]] ?? Option$None$const;
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
      value = found === null || found === "" ? Option$None$const : new Some(found);
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
        try {
          const target = new URL("/api/session", request.url);
          const response = await env.APP.fetch(new Request(target, request));
          if (response.ok) session = await response.json();
        } catch (_) {
          session = null;
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
  let root = null;
  for (const source of matched.spec.sources) {
    if (source.theme) {
      values.push(pageTheme(matched.definition, root));
      continue;
    }
    const response = await readFromApp(env.APP, request, source.service, argsFor(vars, source.args));
    if (!response.ok) {
      if (response.status === 403) return failure(403, "adult declaration required");
      if (response.status === 404 && !source.root) { values.push(Option$None$const); continue; }
      if (response.status === 404) return failure(404, "muse not found");
      return failure(response.status, source.root ? "root read failed" : "widget read failed");
    }
    const decoded = source.decoder(await response.json());
    if (source.root) root = decoded;
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
    return failure(404, "page not found");
  }
  return renderPage(request, env, matched, before.session);
});
