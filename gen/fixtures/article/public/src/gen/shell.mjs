// GENERATED from public/src/{gen/route.gleam,gen/load/**,pages/**,layout.gleam,shell.gleam} [sha256:656c43d408ff] — 手で編集しない

import * as api from "./api.mjs";
import * as blocksPreview from "./blocks_preview.mjs";
import * as frontCss from "../../yumemi/framework/front/css.mjs";
import * as layoutDefinition from "../layout.mjs";
import * as out_article_create from "./out/article_create.mjs";
import * as out_article_list from "./out/article_list.mjs";
import * as out_article_publish from "./out/article_publish.mjs";
import * as out_article_read from "./out/article_read.mjs";
import * as out_widget_list from "./out/widget_list.mjs";
import * as pageDefinition0 from "../pages/article/arg_slug/page.mjs";
import * as pageLoader0 from "./load/article/arg_slug/page.mjs";
import * as route from "./route.mjs";
import * as service from "./service.mjs";
import {Ok} from "../gleam.mjs";
import {Some, Option$None$const} from "../../gleam_stdlib/gleam/option.mjs";
import {run as decodeRun} from "../../gleam_stdlib/gleam/dynamic/decode.mjs";
import {to_document_string} from "../../lustre/lustre/element.mjs";

const pageRoutes = [...route.routes];
const pages = new Map([
  ["/article/:slug", pageDefinition0.page],
]);
const pageSpecs = new Map([
  ["/article/:slug", {
    loader: pageLoader0,
    layout: layoutDefinition.public$,
    givens: [
      { tag: "pick-tag", service: service.Service$ArticleList$const, decoder: decodeArticleList },
    ],
    sources: [
      { service: service.Service$WidgetList$const, decoder: decodeWidgetList, widget: "article_feed", optional: true, root: false },
      { service: service.Service$ArticleRead$const, decoder: decodeArticleRead, optional: false, root: true },
      { service: service.Service$WidgetList$const, decoder: decodeWidgetList, widget: "article_kinds", optional: true, root: false },
      { theme: true },
    ],
  }],
]);

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

function gridCssFromLayout(layout) {
  const spAreas = [...layout.sp.areas];
  const pcFrame = frameValue(layout.pc, {areas: spAreas});
  const tabletFrame = frameValue(layout.tablet, {areas: spAreas});
  const pcAreas = [...pcFrame.areas];
  const tabletAreas = [...tabletFrame.areas];
  const extras = [...pcAreas, ...tabletAreas].filter((area, index, all) =>
    all.findIndex((candidate) => candidate.name === area.name) === index &&
    !spAreas.some((candidate) => candidate.name === area.name),
  );
  const baseRules = [
    ...spAreas.map((area) => areaRule(area, "normal")),
    ...extras.map((area) => areaRule(area, "hidden")),
  ].join("\n");
  let css = "\n[data-yumemi-grid=\"layout\"] {\n"
    + "  display: grid;\n"
    + "  grid-template-columns: minmax(0, 1fr);\n"
    + "  grid-template-areas: " + gridTemplateAreas(spAreas) + ";\n"
    + "  gap: 0;\n}\n"
    + baseRules + "\n";
  if (layout.tablet instanceof Some) {
    const tabletRules = tabletAreas.map((area) => areaRule(area, spAreas.some((candidate) => candidate.name === area.name) ? "normal" : "visible")).join("\n");
    css += mediaBlock("tablet", "  [data-yumemi-grid=\"layout\"] {\n"
      + "    grid-template-columns: minmax(0, 1fr) minmax(12rem, 20rem);\n"
      + "    grid-template-areas: " + gridTemplateAreas(tabletAreas) + ";\n  }\n"
      + tabletRules);
  }
  if (layout.pc instanceof Some) {
    const pcRules = pcAreas.map((area) => areaRule(area, spAreas.some((candidate) => candidate.name === area.name) ? "normal" : "visible")).join("\n");
    css += mediaBlock("pc", "  [data-yumemi-grid=\"layout\"] {\n"
      + "    grid-template-columns: minmax(0, 1fr) minmax(12rem, 20rem);\n"
      + "    grid-template-areas: " + pcGridTemplateAreas(spAreas, pcAreas) + ";\n  }\n"
      + pcRules);
  }
  return css;
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

function widgetNameFor(definition, serviceValue) {
  const placement = [...definition.sp.placements].find((candidate) => candidate.of === serviceValue && candidate.name !== undefined);
  return placement?.name ?? null;
}

async function readFromApp(app, request, definition, serviceValue, params, sourceWidget) {
  const path = apiPathFor(serviceValue).replace(/:([A-Za-z0-9_]+)/g, (_, name) => encodeURIComponent(params[name] ?? ""));
  const target = new URL(path, request.url);
  const widgetName = sourceWidget ?? widgetNameFor(definition, serviceValue);
  if (widgetName !== null) target.searchParams.set("widget", widgetName);
  return app.fetch(new Request(target, request));
}

function pageTheme(definition, root) {
  if (!(definition.theme instanceof Some)) return Option$None$const;
  return root[definition.theme[0]] ?? Option$None$const;
}

function failure(status, body) {
  return new Response(body, {status, headers: {"content-type": "text/plain; charset=utf-8"}});
}

async function renderPage(request, env, matched) {
  const values = [];
  let root = null;
  for (const source of matched.spec.sources) {
    if (source.theme) {
      values.push(pageTheme(matched.definition, root));
      continue;
    }
    const response = await readFromApp(env.APP, request, matched.definition, source.service, matched.params, source.widget);
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
    const response = await readFromApp(env.APP, request, matched.definition, given.service, matched.params, null);
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
    const marker = `<${given.tag} `;
    const encoded = JSON.stringify(given.raw).replaceAll("&", "&amp;").replaceAll("\"", "&quot;");
    output = output.replace(marker, `<${given.tag} data-yumemi-given="${encoded}" `);
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

export default {
  async fetch(request, env) {
    if (new URL(request.url).pathname === "/_blocks" && env.YUMEMI_DEV === "1") return renderBlocksPreview();
    const matched = matchPage(new URL(request.url).pathname);
    if (!matched) {
      if (env.SVELTE) return env.SVELTE.fetch(request);
      return failure(404, "page not found");
    }
    return renderPage(request, env, matched);
  },
};
