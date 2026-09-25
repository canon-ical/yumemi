#!/usr/bin/env node

import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { spawn, spawnSync } from "node:child_process";
import { fileURLToPath, pathToFileURL } from "node:url";
import { makeEncode } from "./codec-encode.mjs";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const genDir = path.resolve(scriptDir, "..");
const repoRoot = path.resolve(genDir, "..");
const buildDir = path.join(genDir, "build");
const currentOutput = path.join(buildDir, "yd1-roundtrip.txt");
const v090Output = path.join(buildDir, "yd1-roundtrip-v090.txt");
process.chdir(genDir);
fs.mkdirSync(buildDir, { recursive: true });
fs.writeFileSync(currentOutput, "");

function run(command, args, cwd, logPath, options = {}) {
  const result = spawnSync(command, args, {
    cwd,
    encoding: "utf8",
    maxBuffer: 32 * 1024 * 1024,
    ...options,
  });
  const output = `${result.stdout ?? ""}${result.stderr ?? ""}`;
  fs.mkdirSync(path.dirname(logPath), { recursive: true });
  fs.writeFileSync(logPath, output);
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed (${result.status}); see ${logPath}`);
  }
  return output;
}

function findGeneratedSlug(root) {
  const matches = [];
  function visit(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const fullPath = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(fullPath);
      else if (entry.name === "slug.gleam" && fullPath.includes(`${path.sep}gen${path.sep}types${path.sep}`)) {
        matches.push(fullPath);
      }
    }
  }
  visit(root);
  if (matches.length !== 1) {
    throw new Error(`expected one generated gen/types/slug.gleam under ${root}; found ${matches.length}`);
  }
  return matches[0];
}

function unwrapSome(value, Some, label) {
  assert.ok(value instanceof Some, `${label} expected Some`);
  return value[0];
}

function expectList(value, List, expected, label) {
  assert.ok(value instanceof List, `${label} expected Gleam List`);
  assert.deepEqual([...value], expected, label);
}

const cases = [
  ["素の String", "string", (value, runtime) => unwrapSome(value, runtime.Some, "String") === "plain"],
  ["素の Int", "integer", (value, runtime) => unwrapSome(value, runtime.Some, "Int") === 42],
  ["素の Bool", "boolean", (value, runtime) => unwrapSome(value, runtime.Some, "Bool") === true],
  ["素の Float", "float", (value, runtime) => unwrapSome(value, runtime.Some, "Float") === 1.5],
  ["Option Some", "option", (value, runtime) => unwrapSome(unwrapSome(value, runtime.Some, "Option outer"), runtime.Some, "Option inner") === "optional"],
  ["Option None", "option_none", (value, runtime) => value instanceof runtime.None],
  ["List", "list", (value, runtime) => {
    expectList(unwrapSome(value, runtime.Some, "List outer"), runtime.List, ["one", "two"], "List");
    return true;
  }],
  ["gen/types value", "gen_type", (value, runtime) => unwrapSome(value, runtime.Some, "Slug") === "roundtrip-slug"],
  ["framework Blob", "blob", (value, runtime) => runtime.blob.to_string(unwrapSome(value, runtime.Some, "Blob")) === "blob-key"],
  ["framework Date", "date", (value, runtime) => runtime.time.date_to_string(unwrapSome(value, runtime.Some, "Date")) === "2026-09-25"],
  ["framework Datetime", "datetime", (value, runtime) => runtime.time.datetime_to_string(unwrapSome(value, runtime.Some, "Datetime")) === "2026-09-25T12:30:00Z"],
  ["framework Time", "time", (value, runtime) => runtime.time.time_to_string(unwrapSome(value, runtime.Some, "Time")) === "12:30"],
  ["framework PartyId", "party", (value, runtime) => runtime.party.to_string(unwrapSome(value, runtime.Some, "PartyId")) === "party-id"],
  ["Page", "page", (value, runtime) => {
    const page = unwrapSome(value, runtime.Some, "Page");
    expectList(page.items, runtime.List, ["page-one", "page-two"], "Page.items");
    return runtime.page.cursor_to_string(unwrapSome(page.next, runtime.Some, "Page.next")) === "cursor-value";
  }],
  ["Key", "key", (value, runtime) => runtime.er.to_string(unwrapSome(value, runtime.Some, "Key")) === "key-value"],
  ["Link", "link", (value, runtime) => runtime.er.to_string(unwrapSome(unwrapSome(value, runtime.Some, "Link outer"), runtime.Some, "Link inner")) === "link-value"],
  ["Has", "has", (value, runtime) => unwrapSome(value, runtime.Some, "Has").value === "has-value"],
  ["Held", "held", (value, runtime) => unwrapSome(value, runtime.Some, "Held").value === "held-value"],
  ["Multi", "multi", (value, runtime) => {
    const relation = unwrapSome(value, runtime.Some, "Multi");
    expectList(relation.values, runtime.List, ["multi-one", "multi-two"], "Multi.values");
    return true;
  }],
  ["{value} record", "value_record", (value, runtime) => unwrapSome(value, runtime.Some, "ValueBox").value === "boxed-value"],
  ["{key} record", "key_record", (value, runtime) => unwrapSome(value, runtime.Some, "KeyBox").key === "boxed-key"],
  ["位置の欄", "position", (value, runtime) => {
    const pair = unwrapSome(value, runtime.Some, "Pair");
    return pair[0] === "first" && pair[1] === 7;
  }],
  ["欄の無い enum", "enum", (value, runtime) => unwrapSome(value, runtime.Some, "Status").constructor.name === "HTTPReady"],
  ["enum kind: Articles", "kind_articles", (value, runtime) => {
    const [row] = [...unwrapSome(value, runtime.Some, "Row")];
    return row.constructor.name === "Articles" && row.kind === "articles" && row.slug === "articles";
  }],
  ["enum kind: HeavenDiary", "kind_heaven_diary", (value, runtime) => {
    const [row] = [...unwrapSome(value, runtime.Some, "Row")];
    return row.constructor.name === "HeavenDiary" && row.kind === "heaven_diary" && row.slug === "heaven-diary";
  }],
  ["String kind union: Article", "string_kind_article", (value, runtime) => {
    const [row] = [...unwrapSome(value, runtime.Some, "StringRow")];
    return row.constructor.name === "Article" && row.kind === "Article" && row.title === "article-title";
  }],
  ["String kind union: Summary", "string_kind_summary", (value, runtime) => {
    const [row] = [...unwrapSome(value, runtime.Some, "StringRow")];
    return row.constructor.name === "Summary" && row.kind === "Summary" && row.count === 3;
  }],
  ["欄で判別する union: title", "field_union_title", (value, runtime) => {
    const choice = unwrapSome(value, runtime.Some, "FieldUnion");
    return choice.constructor.name === "ByTitle" && choice.title === "title-value";
  }],
  ["欄で判別する union: count", "field_union_count", (value, runtime) => {
    const choice = unwrapSome(value, runtime.Some, "FieldUnion");
    return choice.constructor.name === "ByCount" && choice.count === 7;
  }],
];
let roundtripSources;

async function verifyCurrent() {
  const lines = [];
  const encodeCheck = run(
    process.execPath,
    [path.join(scriptDir, "verify-encode-copy.mjs")],
    repoRoot,
    path.join(buildDir, "yd1-encode-check-run.txt"),
  );
  lines.push(...encodeCheck.trimEnd().split("\n"));

  run("gleam", ["test"], genDir, path.join(buildDir, "yd1-roundtrip-gen-test.txt"));
  const testsPath = path.join(buildDir, "dev/javascript/yumemi_gen/yumemi_gen_test.mjs");
  const generatorTests = await import(pathToFileURL(testsPath));
  const serviceSource = generatorTests.codec_roundtrip_service_source();
  const kindSource = generatorTests.codec_roundtrip_kind_source();
  const decoderSource = generatorTests.codec_roundtrip_decoder_source();
  roundtripSources = { serviceSource, kindSource };

  const typeOutput = path.join(buildDir, "yd1-roundtrip-type-gen");
  fs.rmSync(typeOutput, { recursive: true, force: true });
  run(
    "gleam",
    ["run", "-m", "yumemi_gen", "--", "fixtures/article", typeOutput],
    genDir,
    path.join(buildDir, "yd1-roundtrip-type-gen.txt"),
  );
  const generatedSlug = findGeneratedSlug(typeOutput);

  const scratch = path.join(buildDir, "yd1-roundtrip-probe");
  fs.rmSync(scratch, { recursive: true, force: true });
  for (const relative of ["src/service", "src/entity", "src/gen/types", "src/gen/out"]) {
    fs.mkdirSync(path.join(scratch, relative), { recursive: true });
  }
  fs.writeFileSync(
    path.join(scratch, "gleam.toml"),
    `name = "yd1_roundtrip_probe"\nversion = "0.1.0"\ntarget = "javascript"\n\n[dependencies]\ngleam_stdlib = ">= 0.44.0 and < 2.0.0"\ngleam_json = ">= 3.0.0 and < 4.0.0"\nyumemi = { path = "${repoRoot}" }\n`,
  );
  fs.copyFileSync(path.join(repoRoot, "gen/fixtures/article/src/types.gleam"), path.join(scratch, "src/types.gleam"));
  fs.copyFileSync(generatedSlug, path.join(scratch, "src/gen/types/slug.gleam"));
  fs.writeFileSync(path.join(scratch, "src/entity/codec_kind.gleam"), kindSource);
  fs.writeFileSync(path.join(scratch, "src/service/widget_list.gleam"), serviceSource);
  fs.writeFileSync(path.join(scratch, "src/service/roundtrip_ffi.mjs"), "export function row(key) { return { key }; }\n");
  fs.writeFileSync(path.join(scratch, "src/gen/out/widget_list.gleam"), decoderSource);
  run("gleam", ["build", "--target", "javascript"], scratch, path.join(buildDir, "yd1-roundtrip-build.txt"));

  const output = path.join(scratch, "build/dev/javascript/yd1_roundtrip_probe");
  const prelude = await import(pathToFileURL(path.join(scratch, "build/dev/javascript/prelude.mjs")));
  const option = await import(pathToFileURL(path.join(scratch, "build/dev/javascript/gleam_stdlib/gleam/option.mjs")));
  const json = await import(pathToFileURL(path.join(scratch, "build/dev/javascript/gleam_json/gleam/json.mjs")));
  const back = await import(pathToFileURL(path.join(output, "service/widget_list.mjs")));
  const face = await import(pathToFileURL(path.join(output, "gen/out/widget_list.mjs")));
  const er = await import(pathToFileURL(path.join(scratch, "build/dev/javascript/yumemi/framework/er.mjs")));
  const blob = await import(pathToFileURL(path.join(scratch, "build/dev/javascript/yumemi/framework/blob.mjs")));
  const page = await import(pathToFileURL(path.join(scratch, "build/dev/javascript/yumemi/framework/page.mjs")));
  const party = await import(pathToFileURL(path.join(scratch, "build/dev/javascript/yumemi/framework/party.mjs")));
  const time = await import(pathToFileURL(path.join(scratch, "build/dev/javascript/yumemi/framework/time.mjs")));
  const encode = makeEncode({ Some: option.Some, None: option.None, List: prelude.List });
  const runtime = { ...prelude, ...option, er, blob, page, party, time };
  const passed = [];
  const failed = [];

  for (const [name, field, verify] of cases) {
    try {
      const backValue = back.sample(field);
      const wire = encode(backValue);
      const raw = JSON.stringify(wire);
      const parsed = json.parse(raw, face.decoder());
      assert.ok(parsed instanceof prelude.Ok, `decoder rejected encoded value: ${raw}`);
      const decoded = parsed[0];
      assert.equal(decoded.constructor.name, "Out", "decoder returned unexpected face type");
      const outputField = {
        string: "text",
        option: "maybe",
        option_none: "missing",
        list: "values",
        gen_type: "slug",
        page: "pagination",
        key: "relation_key",
        value_record: "value_box",
        key_record: "key_box",
        position: "pair",
        enum: "status",
        kind_articles: "rows",
        kind_heaven_diary: "rows",
        string_kind_article: "string_rows",
        string_kind_summary: "string_rows",
        field_union_title: "choice",
        field_union_count: "choice",
      }[field] ?? field;
      assert.equal(verify(decoded[outputField], runtime), true, `${outputField} did not match expected face value`);
      passed.push(name);
      if (["relation_key", "has", "held", "multi", "kind_articles", "kind_heaven_diary", "string_kind_article", "string_kind_summary", "position"].includes(field)) {
        lines.push(`WIRE ${field}: ${JSON.stringify(wire[outputField])}`);
      }
      lines.push(`PASS ${name}`);
    } catch (error) {
      failed.push(name);
      lines.push(`FAIL ${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  lines.push(`SUMMARY: ${passed.length} PASS / ${failed.length} FAIL / ${cases.length} total`);
  lines.push(`BUILD: ${path.join(buildDir, "yd1-roundtrip-build.txt")}`);
  fs.writeFileSync(currentOutput, `${lines.join("\n")}\n`);
  if (failed.length !== 0) throw new Error(`current round-trip failed: ${failed.join(", ")}; see ${currentOutput}`);
}

function archiveV090() {
  const destination = path.join(buildDir, "yd1-v090");
  fs.rmSync(destination, { recursive: true, force: true });
  fs.mkdirSync(destination, { recursive: true });
  const archive = spawnSync("git", ["archive", "v0.9.0"], {
    cwd: repoRoot,
    encoding: null,
    maxBuffer: 256 * 1024 * 1024,
  });
  if (archive.status !== 0) throw new Error("git archive v0.9.0 failed");
  const extract = spawnSync("tar", ["-x", "-C", destination], {
    cwd: repoRoot,
    input: archive.stdout,
    encoding: "utf8",
    maxBuffer: 16 * 1024 * 1024,
  });
  const report = [
    "command: git archive v0.9.0 | tar -x -C gen/build/yd1-v090",
    `git archive bytes: ${archive.stdout.length}`,
    `tar exit: ${extract.status}`,
    extract.stderr.trimEnd(),
  ].filter(Boolean).join("\n") + "\n";
  fs.writeFileSync(path.join(buildDir, "yd1-v090-archive.txt"), report);
  if (extract.status !== 0) throw new Error("tar extraction of v0.9.0 failed");
  return destination;
}

async function verifyV090() {
  const lines = ["generator: tag v0.9.0", "same Gleam Service values and encode factory as current probe"];
  const oldRoot = archiveV090();
  const oldGen = path.join(oldRoot, "gen");
  const oldTest = path.join(oldGen, "test/yumemi_gen_test.gleam");
  fs.appendFileSync(oldTest, [
    "",
    "pub fn yd1_roundtrip_decoder_source(service_source: String, kind_source: String) -> String {",
    "  synthetic_out_for(app(), \"widget_list\", service_source, [source_unit(\"entity/codec_kind\", kind_source)])",
    "}",
    "",
  ].join("\n"));
  run("gleam", ["format", "test/yumemi_gen_test.gleam"], oldGen, path.join(buildDir, "yd1-v090-format.txt"));
  run("gleam", ["test"], oldGen, path.join(buildDir, "yd1-v090-gen-test.txt"));

  const oldTestsPath = path.join(oldGen, "build/dev/javascript/yumemi_gen/yumemi_gen_test.mjs");
  const oldTests = await import(pathToFileURL(oldTestsPath));
  const decoderSource = oldTests.yd1_roundtrip_decoder_source(
    roundtripSources.serviceSource,
    roundtripSources.kindSource,
  );
  const typeOutput = path.join(oldGen, "build/yd1-v090-generated");
  fs.rmSync(typeOutput, { recursive: true, force: true });
  run(
    "gleam",
    ["run", "-m", "yumemi_gen", "--", "fixtures/article", typeOutput],
    oldGen,
    path.join(buildDir, "yd1-v090-type-gen.txt"),
  );
  const generatedSlug = findGeneratedSlug(typeOutput);

  const scratch = path.join(oldRoot, "probe");
  fs.rmSync(scratch, { recursive: true, force: true });
  for (const relative of ["src/service", "src/entity", "src/gen/types", "src/gen/out"]) {
    fs.mkdirSync(path.join(scratch, relative), { recursive: true });
  }
  const manifest = [
    'name = "yd1_roundtrip_probe"',
    'version = "0.1.0"',
    'target = "javascript"',
    "",
    "[dependencies]",
    'gleam_stdlib = ">= 0.44.0 and < 2.0.0"',
    'gleam_json = ">= 3.0.0 and < 4.0.0"',
    `yumemi = { path = "${oldRoot}" }`,
    "",
  ].join("\n");
  fs.writeFileSync(path.join(scratch, "gleam.toml"), manifest);
  fs.copyFileSync(path.join(oldGen, "fixtures/article/src/types.gleam"), path.join(scratch, "src/types.gleam"));
  fs.copyFileSync(generatedSlug, path.join(scratch, "src/gen/types/slug.gleam"));
  fs.writeFileSync(path.join(scratch, "src/entity/codec_kind.gleam"), roundtripSources.kindSource);
  fs.writeFileSync(path.join(scratch, "src/service/widget_list.gleam"), roundtripSources.serviceSource);
  fs.writeFileSync(path.join(scratch, "src/service/roundtrip_ffi.mjs"), "export function row(key) { return { key }; }\n");
  fs.writeFileSync(path.join(scratch, "src/gen/out/widget_list.gleam"), decoderSource);
  const buildLog = path.join(buildDir, "yd1-roundtrip-v090-build.txt");
  run("gleam", ["build", "--target", "javascript"], scratch, buildLog);

  const output = path.join(buildDir, "yd1-roundtrip-v090.txt");
  const packageRoot = path.join(scratch, "build/dev/javascript/yd1_roundtrip_probe");
  const javascript = path.join(scratch, "build/dev/javascript");
  const prelude = await import(pathToFileURL(path.join(javascript, "prelude.mjs")));
  const option = await import(pathToFileURL(path.join(javascript, "gleam_stdlib/gleam/option.mjs")));
  const json = await import(pathToFileURL(path.join(javascript, "gleam_json/gleam/json.mjs")));
  const back = await import(pathToFileURL(path.join(packageRoot, "service/widget_list.mjs")));
  const face = await import(pathToFileURL(path.join(packageRoot, "gen/out/widget_list.mjs")));
  const er = await import(pathToFileURL(path.join(javascript, "yumemi/framework/er.mjs")));
  const blob = await import(pathToFileURL(path.join(javascript, "yumemi/framework/blob.mjs")));
  const page = await import(pathToFileURL(path.join(javascript, "yumemi/framework/page.mjs")));
  const party = await import(pathToFileURL(path.join(javascript, "yumemi/framework/party.mjs")));
  const time = await import(pathToFileURL(path.join(javascript, "yumemi/framework/time.mjs")));
  const encode = makeEncode({ Some: option.Some, None: option.None, List: prelude.List });
  const runtime = { ...prelude, ...option, er, blob, page, party, time };
  const passed = [];
  const failed = [];
  const expectedFailures = new Set([
    "Has",
    "Held",
    "Multi",
    "enum kind: Articles",
    "enum kind: HeavenDiary",
  ]);
  for (const [name, field, verify] of cases) {
    try {
      const wire = encode(back.sample(field));
      const parsed = json.parse(JSON.stringify(wire), face.decoder());
      assert.ok(parsed instanceof prelude.Ok, `decoder rejected encoded value: ${JSON.stringify(wire)}`);
      const decoded = parsed[0];
      const outputField = {
        string: "text", option: "maybe", option_none: "missing", list: "values",
        gen_type: "slug", page: "pagination", key: "relation_key",
        value_record: "value_box", key_record: "key_box", position: "pair", enum: "status",
        kind_articles: "rows", kind_heaven_diary: "rows", string_kind_article: "string_rows",
        string_kind_summary: "string_rows", field_union_title: "choice", field_union_count: "choice",
      }[field] ?? field;
      assert.equal(verify(decoded[outputField], runtime), true, `${outputField} did not match expected face value`);
      passed.push(name);
      lines.push(`PASS ${name}`);
    } catch (error) {
      failed.push(name);
      lines.push(`FAIL ${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }
  lines.push(`SUMMARY: ${passed.length} PASS / ${failed.length} FAIL / ${cases.length} total`);
  lines.push(`BUILD: ${buildLog}`);
  lines.push(`EXPECTED FAILS: ${Array.from(expectedFailures).join(", ")}`);
  fs.writeFileSync(output, lines.join("\n") + "\n");
  const unexpected = failed.filter(name => !expectedFailures.has(name));
  const missing = Array.from(expectedFailures).filter(name => !failed.includes(name));
  if (unexpected.length || missing.length) {
    throw new Error(`v0.9.0 round-trip failure set mismatch; unexpected=[${unexpected.join(", ")}], missing=[${missing.join(", ")}]; see ${output}`);
  }
}

try {
  await verifyCurrent();
  await verifyV090();
  process.stdout.write(fs.readFileSync(currentOutput, "utf8"));
  process.stdout.write("\n--- v0.9.0 ---\n");
  process.stdout.write(fs.readFileSync(v090Output, "utf8"));
} catch (error) {
  const failure = `ERROR: ${error instanceof Error ? error.stack : String(error)}\n`;
  fs.appendFileSync(currentOutput, failure);
  process.stderr.write(failure);
  process.exitCode = 1;
}
