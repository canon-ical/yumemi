#!/usr/bin/env node
// Built route table と musearch の registry.mjs を、collection と動詞を
// 中心に突き合わせる。URL の prefix / 綴り / 末尾形 / root・鍵 / folded
// は別列へ残し、Service の分類は「正しく出る」か「止まる」の2値にする。

import fs from "node:fs";
import path from "node:path";

const [
  ,
  ,
  appDir,
  routeFile,
  registryFile,
  diagnosticsFile,
  serviceTableFile,
  compareFile,
] = process.argv;

if (!compareFile) {
  console.error(
    "usage: audit-route-registry.mjs <app> <built-route.gleam> <registry.mjs> <diagnostics> <service.tsv> <compare.tsv>",
  );
  process.exit(2);
}

const read = (file) => fs.readFileSync(file, "utf8");
const collectionPattern =
  /pub\s+const\s+collection\s*:\s*String\s*=\s*"([^"]+)"/;
const reservedVerbs = ["create", "read", "list", "delete", "put"];
const itemVerbs = ["read", "delete", "put"];

function gleamFiles(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith(".gleam"))
    .map((entry) => path.join(dir, entry.name))
    .sort();
}

function targetsIn(app) {
  const entities = gleamFiles(path.join(app, "src", "entity")).map((file) => {
    const found = read(file).match(collectionPattern);
    return {
      module: path.basename(file, ".gleam"),
      collection: found?.[1] ?? path.basename(file, ".gleam"),
      kind: "entity",
    };
  });
  const external = gleamFiles(path.join(app, "src"))
    .map((file) => {
      const found = read(file).match(collectionPattern);
      if (!found) return null;
      return {
        module: path.basename(file, ".gleam"),
        collection: found[1],
        kind: "external",
      };
    })
    .filter(Boolean);
  return [...entities, ...external].sort((left, right) =>
    left.module.localeCompare(right.module),
  );
}

function serviceNames(app) {
  return gleamFiles(path.join(app, "src", "service")).map((file) => ({
    name: path.basename(file, ".gleam"),
    system: read(file).includes("who: allow.System"),
  }));
}

function entitySuffixes(module) {
  const words = module.split("_");
  return words.map((_, index) => words.slice(index).join("_"));
}

function targetAliases(target) {
  const moduleSuffixes =
    target.kind === "entity" ? entitySuffixes(target.module) : [];
  return new Set([
    ...moduleSuffixes,
    target.module,
    target.collection,
    singular(target.collection),
    plural(target.collection),
  ]);
}

function sameTarget(left, right) {
  return left?.kind === right?.kind && left?.module === right?.module;
}

function targetMatches(service, target) {
  const candidates =
    target.kind === "entity" ? entitySuffixes(target.module) : [target.module];
  return candidates
    .filter((suffix) => service.startsWith(`${suffix}_`))
    .map((suffix) => ({
      target,
      suffix,
      wordCount: suffix.split("_").length,
    }));
}

function selectTarget(targets, service) {
  const matches = targets.flatMap((target) => targetMatches(service, target));
  const longest = Math.max(0, ...matches.map((match) => match.wordCount));
  const best = matches.filter((match) => match.wordCount === longest);
  if (best.length === 0) {
    return { kind: "no_match", reason: `対象が無い: ${service}` };
  }
  const bestTargets = [...new Map(best.map((match) => [
    `${match.target.kind}:${match.target.module}`,
    match,
  ])).values()];
  if (bestTargets.length > 1) {
    const candidates = bestTargets
      .map((match) => match.target.module)
      .sort()
      .join(" / ");
    return {
      kind: "ambiguous",
      reason: `対象が曖昧: ${service} -> 候補 ${candidates}`,
    };
  }
  const chosen = bestTargets[0];
  const verb = service.slice(chosen.suffix.length + 1);
  if (!verb) {
    return { kind: "empty_verb", reason: `動詞が空: ${service}` };
  }
  if (chosen.target.kind === "external" && itemVerbs.includes(verb)) {
    return {
      kind: "external_item",
      reason: `ER 外 collection に個体レベルの動詞: ${service} (${verb})`,
    };
  }
  const nested = targets.find(
    (target) =>
      target.kind === "entity" &&
      !sameTarget(target, chosen.target) &&
      entitySuffixes(target.module).some((suffix) =>
        reservedVerbs.some((reserved) => verb === `${suffix}_${reserved}`),
      ),
  );
  if (nested) {
    return {
      kind: "nested_reserved",
      reason: `動詞が Entity と予約動詞の入れ子: ${service} -> ${verb} (${nested.module})`,
    };
  }
  return {
    kind: "ok",
    target: chosen.target,
    suffix: chosen.suffix,
    verb,
  };
}

function routeRows(text) {
  const rows = [];
  const pattern =
    /^\s+Route\(face: "([^"]+)", method: "([^"]+)", path: "([^"]+)", service: "([^"]+)", path_keys: \[([^\]]*)\], credential: (Session|ApiKey)\),$/gm;
  for (const found of text.matchAll(pattern)) {
    rows.push({
      face: found[1],
      method: found[2],
      path: found[3],
      service: found[4],
      pathKeys: [...found[5].matchAll(/"([^"]+)"/g)].map((match) => match[1]),
      credential: found[6],
    });
  }
  return rows;
}

function registryRows(text) {
  return text
    .split("\n")
    .filter((line) => line.includes("{ name: "))
    .map((line) => ({
      name: line.match(/name: '([^']+)'/)?.[1] ?? "",
      method: line.match(/method: (null|'([^']+)')/)?.[2] ?? "",
      path: line.match(/path: (null|'([^']+)')/)?.[2] ?? "",
      target: line.match(/target: '([^']+)'/)?.[1] ?? "",
      folded: line.match(/folded: ([^,}]+)/)?.[1]?.trim() ?? "",
      entry: line.match(/entry: '([^']+)'/)?.[1] ?? "",
    }));
}

function diagnostics(text) {
  const found = new Map();
  for (const line of text.split("\n")) {
    const match = line.match(/service\.([^ ]+) face [^:]+: (.*)$/);
    if (!match) continue;
    if (!found.has(match[1])) found.set(match[1], new Set());
    found.get(match[1]).add(match[2]);
  }
  return found;
}

function singular(value) {
  if (value.endsWith("ies")) return `${value.slice(0, -3)}y`;
  if (value.endsWith("s")) return value.slice(0, -1);
  return value;
}

function plural(value) {
  if (value.endsWith("y")) return `${value.slice(0, -1)}ies`;
  if (value.endsWith("s")) return value;
  return `${value}s`;
}

function segments(routePath) {
  return routePath.split("/").filter(Boolean);
}

function isParameter(segment) {
  return segment.startsWith(":") || segment.startsWith("{");
}

function methodVerb(method) {
  return {
    GET: "list",
    POST: "create",
    DELETE: "delete",
    PUT: "put",
  }[method] ?? method.toLowerCase();
}

function pathTarget(pathParts, selected, targets) {
  if (selected?.target) {
    const aliases = targetAliases(selected.target);
    for (let index = pathParts.length - 1; index >= 0; index -= 1) {
      if (!isParameter(pathParts[index]) && aliases.has(pathParts[index])) {
        return { target: selected.target, index };
      }
    }
  }
  for (let index = pathParts.length - 1; index >= 0; index -= 1) {
    if (isParameter(pathParts[index])) continue;
    const candidates = targets.filter((target) =>
      targetAliases(target).has(pathParts[index]),
    );
    if (candidates.length > 0) {
      return { target: candidates[0], index };
    }
  }
  return null;
}

function registryShape(row, selected, targets) {
  if (!row.path) {
    return {
      collection: "",
      verb: "",
      target: null,
      targetIndex: -1,
      params: [],
      tail: [],
    };
  }
  const pathParts = segments(row.path);
  const found = pathTarget(pathParts, selected, targets);
  const targetIndex = found?.index ?? -1;
  const tail = targetIndex >= 0 ? pathParts.slice(targetIndex + 1) : [];
  const literalTail = tail.filter((part) => !isParameter(part));
  const params = pathParts
    .filter(isParameter)
    .map((part) => part.replace(/^[:{]|}$/g, ""));
  let verb;
  if (literalTail.length > 0) {
    verb = literalTail.join("_");
  } else if (targetIndex < 0) {
    const literal = pathParts.filter((part) => !isParameter(part));
    verb = literal[literal.length - 1] ?? methodVerb(row.method);
  } else if (tail.some(isParameter)) {
    verb = {
      GET: "read",
      DELETE: "delete",
      PUT: "put",
      POST: "update",
    }[row.method] ?? row.method.toLowerCase();
  } else {
    verb = methodVerb(row.method);
  }
  return {
    collection: targetIndex >= 0 ? pathParts[targetIndex] : "",
    verb,
    target: found?.target ?? null,
    targetIndex,
    params,
    tail,
  };
}

function normalizedPath(value) {
  return value.replace(/\{([^}]+)\}/g, ":$1");
}

function pickRoute(routes, registryPath) {
  return (
    routes.find((route) => normalizedPath(route.path) === registryPath) ??
    routes[0] ??
    null
  );
}

function generatedTargetIndex(route, selected) {
  if (!route || selected.kind !== "ok") return -1;
  const parts = segments(route.path);
  const aliases = targetAliases(selected.target);
  for (let index = parts.length - 1; index >= 0; index -= 1) {
    if (!isParameter(parts[index]) && aliases.has(parts[index])) return index;
  }
  return -1;
}

function isParentTarget(parent, target) {
  return (
    parent?.kind === "entity" &&
    target?.kind === "entity" &&
    target.module.startsWith(`${parent.module}_`)
  );
}

function logicalRegistryCollection(selected, shape) {
  if (selected.kind !== "ok") return "";
  if (
    !shape.target ||
    sameTarget(shape.target, selected.target) ||
    isParentTarget(shape.target, selected.target) ||
    targetAliases(selected.target).has(shape.collection)
  ) {
    return selected.target.collection;
  }
  return shape.target.collection;
}

function routeRuleMismatch(routes, selected) {
  if (selected.kind !== "ok" || routes.length === 0) return "";
  const mismatch = new Set();
  const aliases = targetAliases(selected.target);
  for (const route of routes) {
    const parts = segments(route.path);
    let targetIndex = -1;
    for (let index = parts.length - 1; index >= 0; index -= 1) {
      if (!isParameter(parts[index]) && parts[index] === selected.target.collection) {
        targetIndex = index;
        break;
      }
    }
    if (targetIndex < 0) {
      for (let index = parts.length - 1; index >= 0; index -= 1) {
        if (!isParameter(parts[index]) && aliases.has(parts[index])) {
          targetIndex = index;
          break;
        }
      }
    }
    if (targetIndex < 0) {
      mismatch.add("collection");
      continue;
    }
    const tail = parts
      .slice(targetIndex + 1)
      .filter((part) => !isParameter(part));
    const suffix = tail.join("_");
    if (suffix !== "" && suffix !== selected.verb) mismatch.add("動詞");
  }
  return [...mismatch].join(",");
}

function otherFields(routes, row, selected, shape) {
  const route = pickRoute(routes, row.path);
  if (!route) {
    return {
      prefix: "",
      spelling: "",
      suffix: "",
      rootKey: "",
      folded: row.folded,
      entry: row.entry,
    };
  }
  const generatedParts = segments(route.path);
  const registryParts = segments(row.path);
  const generatedIndex = generatedTargetIndex(route, selected);
  const generatedPrefix =
    generatedIndex >= 0 ? generatedParts.slice(0, generatedIndex).join("/") : "";
  const registryPrefix =
    shape.targetIndex >= 0
      ? registryParts.slice(0, shape.targetIndex).join("/")
      : registryParts.slice(0, 2).join("/");
  const prefix = generatedPrefix === registryPrefix ? "same" : "diff";
  const generatedCollection = selected.kind === "ok" ? selected.target.collection : "";
  const spelling =
    shape.collection && generatedCollection && generatedCollection !== shape.collection
      ? `${generatedCollection} != ${shape.collection}`
      : "";
  const suffix =
    selected.kind === "ok" && shape.verb && shape.verb !== selected.verb
      ? `registry=${shape.verb}, generated=${selected.verb}`
      : "";
  const generatedKeys = route.pathKeys;
  const registryKeys = shape.params;
  const rootKey =
    generatedKeys.join(",") === registryKeys.join(",")
      ? ""
      : `registry=${registryKeys.join(",") || "-"}, generated=${generatedKeys.join(",") || "-"}`;
  return {
    prefix,
    spelling,
    suffix,
    rootKey,
    folded: row.folded,
    entry: row.entry,
  };
}

function collectionCompare(selected, shape) {
  if (selected.kind !== "ok" || !shape.collection) return "不明";
  return targetAliases(selected.target).has(shape.collection) ? "一致" : "差";
}

function registryRowsFor(registry, service) {
  return registry.filter((row) => row.name === service || row.target === service);
}

function fields(values) {
  return values
    .map((value) => String(value ?? "").replaceAll(/[\t\r\n]/g, " "))
    .join("\t");
}

const targets = targetsIn(appDir);
const allServices = serviceNames(appDir);
const services = allServices.filter((service) => !service.system);
if (services.length !== 87) {
  throw new Error(`expected 87 non-system services, got ${services.length}`);
}
const routes = routeRows(read(routeFile));
const routeByService = new Map();
for (const route of routes) {
  if (!routeByService.has(route.service)) routeByService.set(route.service, []);
  routeByService.get(route.service).push(route);
}
const registry = registryRows(read(registryFile));
const notes = diagnostics(read(diagnosticsFile));

const serviceRows = [];
for (const serviceInfo of services) {
  const service = serviceInfo.name;
  const selected = selectTarget(targets, service);
  const serviceRoutes = routeByService.get(service) ?? [];
  const matchingRegistry = registryRowsFor(registry, service);
  const base =
    matchingRegistry.find((row) => row.name === service && !row.target) ??
    matchingRegistry.find((row) => row.method) ??
    matchingRegistry[0] ??
    null;
  const shape = base ? registryShape(base, selected.kind === "ok" ? selected : null, targets) : null;
  const other = base
    ? otherFields(serviceRoutes, base, selected, shape)
    : { prefix: "", spelling: "", suffix: "", rootKey: "", folded: "", entry: "" };
  const classification = serviceRoutes.length > 0 ? "正しく出る" : "止まる";
  const stopReason = serviceRoutes.length
    ? [...(notes.get(service) ?? [])].sort().join(" | ")
    : selected.reason ?? [...(notes.get(service) ?? [])].sort().join(" | ");
  const collection = selected.kind === "ok" ? selected.target.collection : "";
  const verb = selected.kind === "ok" ? selected.verb : "";
  const logicalCollection = base ? logicalRegistryCollection(selected, shape) : "";
  const collectionMatch =
    selected.kind === "ok" && base
      ? logicalCollection === collection
        ? "一致"
        : "差"
      : "不明";
  const verbMatch =
    serviceRoutes.length > 0 && shape?.verb
      ? shape.verb === verb
        ? "一致"
        : "差"
      : "-";
  const ruleMismatch = routeRuleMismatch(serviceRoutes, selected);
  const silentMismatch = [
    collectionMatch === "差" ? "collection" : "",
    ruleMismatch,
  ]
    .filter(Boolean)
    .join(",");
  serviceRows.push({
    service,
    classification,
    reason: stopReason,
    target_module: selected.target?.module ?? "",
    target_kind: selected.target?.kind ?? "",
    collection,
    verb,
    route_faces: serviceRoutes.map((route) => route.face).join(","),
    route_count: serviceRoutes.length,
    registry_names: matchingRegistry.map((row) => row.name).join(","),
    registry_collection: shape?.collection ?? "",
    registry_verb: shape?.verb ?? "",
    registry_logical_collection: logicalCollection,
    registry_logical_verb: selected.kind === "ok" ? selected.verb : "",
    collection_compare: collectionMatch,
    verb_compare: verbMatch,
    rule_mismatch: ruleMismatch,
    silent_mismatch: silentMismatch,
    other_prefix: other.prefix,
    other_plural_spelling: other.spelling,
    other_suffix_shape: other.suffix,
    other_root_key: other.rootKey,
    other_folded: other.folded,
    other_entry: other.entry,
  });
}

const serviceHeader = [
  "service", "classification", "reason", "target_module", "target_kind",
  "collection", "verb", "route_faces", "route_count", "registry_names",
  "registry_collection", "registry_verb", "registry_logical_collection",
  "registry_logical_verb", "collection_compare", "verb_compare", "rule_mismatch",
  "silent_mismatch", "other_prefix", "other_plural_spelling", "other_suffix_shape",
  "other_root_key", "other_folded", "other_entry",
];
fs.writeFileSync(
  serviceTableFile,
  `${fields(serviceHeader)}\n${serviceRows.map((row) => fields(serviceHeader.map((key) => row[key]))).join("\n")}\n`,
);

const serviceByName = new Map(serviceRows.map((row) => [row.service, row]));
const compareRows = registry.map((row) => {
  const service = row.target || row.name;
  const serviceInfo = serviceByName.get(service);
  const allService = allServices.find((item) => item.name === service);
  const selected = allService
    ? selectTarget(targets, service)
    : { kind: "registry_only", reason: "registry-only" };
  const serviceRoutes = routeByService.get(service) ?? [];
  const shape = registryShape(row, selected.kind === "ok" ? selected : null, targets);
  const route = pickRoute(serviceRoutes, row.path);
  const other = otherFields(serviceRoutes, row, selected, shape);
  const generatedCollection = selected.kind === "ok" ? selected.target.collection : "";
  const generatedVerb = selected.kind === "ok" ? selected.verb : "";
  const logicalCollection = serviceInfo
    ? logicalRegistryCollection(selected, shape)
    : "";
  const collectionMatch =
    serviceInfo && selected.kind === "ok"
      ? logicalCollection === generatedCollection
        ? "一致"
        : "差"
      : "不明";
  const verbMatch =
    serviceInfo && route && shape.verb
      ? shape.verb === generatedVerb
        ? "一致"
        : "差"
      : "-";
  const ruleMismatch = routeRuleMismatch(serviceRoutes, selected);
  const silentMismatch = [
    collectionMatch === "差" ? "collection" : "",
    ruleMismatch,
  ]
    .filter(Boolean)
    .join(",");
  const classification = serviceInfo ? serviceInfo.classification : "止まる";
  const reason = serviceInfo
    ? serviceInfo.classification === "止まる"
      ? serviceInfo.reason
      : ""
    : allService?.system
      ? "system-only (no HTTP route)"
      : "registry-only";
  return [
    row.name,
    service,
    allService ? (allService.system ? "system" : "service") : "registry-only",
    row.method,
    row.path,
    route?.face ?? "",
    route?.method ?? "",
    route?.path ?? "",
    selected.target?.module ?? "",
    selected.target?.kind ?? "",
    generatedCollection,
    generatedVerb,
    shape.collection,
    shape.verb,
    logicalCollection,
    serviceInfo && selected.kind === "ok" ? selected.verb : "",
    collectionMatch,
    verbMatch,
    ruleMismatch,
    silentMismatch,
    other.prefix,
    other.spelling,
    other.suffix,
    other.rootKey,
    other.folded,
    other.entry,
    classification,
    reason,
  ];
});

const compareHeader = [
  "registry_name", "service", "scope", "registry_method", "registry_path",
  "generated_face", "generated_method", "generated_path", "target_module", "target_kind",
  "generated_collection", "generated_verb", "registry_collection", "registry_verb",
  "registry_logical_collection", "registry_logical_verb", "collection_compare",
  "verb_compare", "rule_mismatch", "silent_mismatch", "other_prefix",
  "other_plural_spelling", "other_suffix_shape", "other_root_key", "other_folded",
  "other_entry", "classification", "reason",
];
fs.writeFileSync(
  compareFile,
  `${fields(compareHeader)}\n${compareRows.map((row) => fields(row)).join("\n")}\n`,
);

const counts = Object.fromEntries(
  ["正しく出る", "止まる"].map((classification) => [
    classification,
    serviceRows.filter((row) => row.classification === classification).length,
  ]),
);
const mismatchCounts = Object.fromEntries(
  ["collection", "動詞", "collection,動詞"].map((kind) => [
    kind,
    serviceRows.filter((row) => row.silent_mismatch === kind).length,
  ]),
);
const pathShapeCount = serviceRows.filter(
  (row) => row.other_suffix_shape !== "",
).length;
console.log(JSON.stringify({
  serviceCount: serviceRows.length,
  routeRowCount: routes.length,
  routeServiceCount: routeByService.size,
  registryRowCount: registry.length,
  classification: counts,
  silentMismatch: mismatchCounts,
  pathShapeDifferenceServiceCount: pathShapeCount,
}, null, 2));
