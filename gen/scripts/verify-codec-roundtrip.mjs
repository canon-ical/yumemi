#!/usr/bin/env node

import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath, pathToFileURL } from "node:url";

const genDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const repoRoot = path.resolve(genDir, "..");
const snapshotOut = process.argv[2] && path.resolve(process.argv[2]);
if (!snapshotOut) {
  throw new Error("usage: node scripts/verify-codec-roundtrip.mjs <snapshot output>");
}
process.chdir(genDir);

function run(command, args, cwd, log) {
  const result = spawnSync(command, args, { cwd, encoding: "utf8" });
  fs.writeFileSync(log, `${result.stdout ?? ""}${result.stderr ?? ""}`);
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed (${result.status}); see ${log}`);
  }
  return result.stdout ?? "";
}

// Exported by the generator test, which constructs an unrelated Choice sum.
run("gleam", ["test"], genDir, path.join(genDir, "build/y1e-p-codec-test.txt"));
const generatedTest = await import(
  pathToFileURL(path.join(genDir, "build/dev/javascript/yumemi_gen/yumemi_gen_test.mjs"))
);
const scratch = path.join(genDir, "build/y1e-p-codec-probe");
fs.rmSync(scratch, { recursive: true, force: true });
fs.mkdirSync(path.join(scratch, "src"), { recursive: true });
fs.writeFileSync(
  path.join(scratch, "gleam.toml"),
  `name = "codec_probe"\nversion = "0.1.0"\ntarget = "javascript"\n\n[dependencies]\ngleam_stdlib = ">= 0.44.0 and < 2.0.0"\ngleam_json = ">= 3.0.0 and < 4.0.0"\nyumemi = { path = "${repoRoot}" }\n`,
);
for (const [source, target] of [
  ["muses/src/gen/out/metrics_muse.gleam", "muse_metrics.gleam"],
  ["console/src/gen/out/metrics_store.gleam", "store_metrics.gleam"],
]) {
  fs.copyFileSync(path.join(snapshotOut, source), path.join(scratch, "src", target));
}
fs.writeFileSync(
  path.join(scratch, "src/codec_fixture.gleam"),
  generatedTest.codec_roundtrip_fixture(),
);
fs.writeFileSync(path.join(scratch, "src/probe.gleam"), `
import codec_fixture
import gleam/int
import gleam/json
import muse_metrics
import store_metrics

pub fn muse(raw: String) -> String {
  case json.parse(raw, muse_metrics.decoder()) {
    Ok(muse_metrics.Out(metrics: muse_metrics.Metrics(sources: [muse_metrics.SourceRow(source: source, ..)], ..), ..)) ->
      case source {
        muse_metrics.Tagged(key) -> "tagged:" <> key
        muse_metrics.External -> "external"
        muse_metrics.Internal -> "internal"
        muse_metrics.Direct -> "direct"
      }
    Ok(_) -> "WRONG_SHAPE"
    Error(_) -> "DECODE_ERROR"
  }
}

pub fn store(raw: String) -> String {
  case json.parse(raw, store_metrics.decoder()) {
    Ok(store_metrics.Out(metrics: store_metrics.Metrics(sources: [store_metrics.SourceRow(source: source, ..)], ..), ..)) ->
      case source {
        store_metrics.Tagged(key) -> "tagged:" <> key
        store_metrics.External -> "external"
        store_metrics.Internal -> "internal"
        store_metrics.Direct -> "direct"
      }
    Ok(_) -> "WRONG_SHAPE"
    Error(_) -> "DECODE_ERROR"
  }
}

pub fn generic(raw: String) -> String {
  case json.parse(raw, codec_fixture.decoder()) {
    Ok(codec_fixture.Out(choice: choice, value_box: codec_fixture.ValueBox(value: value), key_box: codec_fixture.KeyBox(key: key), pair: codec_fixture.Pair(first, second))) -> {
      let tag = case choice {
        codec_fixture.Named(name) -> "named:" <> name
        codec_fixture.Skipped -> "skipped"
        codec_fixture.HTTPReady -> "httpready"
      }
      tag <> "|" <> value <> "|" <> key <> "|" <> first <> "|" <> int.to_string(second)
    }
    Error(_) -> "DECODE_ERROR"
  }
}
`);
run(
  "gleam",
  ["build"],
  scratch,
  path.join(genDir, "build/y1e-p-codec-build.txt"),
);
const probe = await import(
  pathToFileURL(path.join(scratch, "build/dev/javascript/codec_probe/probe.mjs"))
);

// Copied from snapshot api/src/gen/codec.mjs:135-146. The class layout below
// matches Gleam JavaScript output: positional fields use numeric property keys.
class None {}
class Some { constructor(value) { this[0] = value; } }
class List extends Array {}
const tag = value => value.constructor.name.replace(/([a-z0-9])([A-Z])/g, "$1_$2").toLowerCase();
function encode(value) {
  if (value == null || typeof value !== "object") return value;
  if (value instanceof None) return null;
  if (value instanceof Some) return encode(value[0]);
  if (value instanceof List) return [...value].map(encode);
  if (Array.isArray(value)) return value.map(encode);
  if ("value" in value && Object.keys(value).length === 1) return encode(value.value);
  if ("key" in value && Object.keys(value).length === 1) return encode(value.key);
  if (!Object.keys(value).length) return tag(value);
  return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, encode(v)]));
}

class SourceKey { constructor(value) { this.value = value; } }
class Tagged { constructor(key) { this[0] = key; } }
class External {}
class Internal {}
class Direct {}
class Named { constructor(name) { this[0] = name; } }
class Skipped {}
class HTTPReady {}
class ValueBox { constructor(value) { this.value = value; } }
class KeyBox { constructor(key) { this.key = key; } }
class Pair { constructor(first, second) { this[0] = first; this[1] = second; } }

function metrics(source) {
  return {
    pv: 1, unique: 1, visits: 1, visits_2plus: 0,
    revisit_ratio: new None(), pages_median: new None(),
    distribution: [], daily: [], browsers: 1, returning: 0,
    sources: [{ source, visits: 1, unique: 1, visits_2plus: 0,
      revisit_ratio: new None(), pages_median: new None() }],
    transitions: [], peer_median: new None(),
  };
}

const sourceCases = [
  [new Tagged(new SourceKey("card")), "tagged:card", { "0": "card" }],
  [new External(), "external", "external"],
  [new Internal(), "internal", "internal"],
  [new Direct(), "direct", "direct"],
];
for (const [source, expected, wire] of sourceCases) {
  assert.deepEqual(encode(source), wire);
  const museWire = JSON.stringify(encode({
    metrics: metrics(source), circulation_rate: new None(), median: new None(),
  }));
  const storeWire = JSON.stringify(encode({
    metrics: metrics(source), breakdown: [],
    circulation_rate: new None(), median: new None(),
  }));
  assert.equal(probe.muse(museWire), expected);
  assert.equal(probe.store(storeWire), expected);
}
const genericCases = [
  [new Named("card"), "named:card"],
  [new Skipped(), "skipped"],
  [new HTTPReady(), "httpready"],
];
for (const [choice, expected] of genericCases) {
  const wire = JSON.stringify(encode({
    choice, value_box: new ValueBox("value"), key_box: new KeyBox("key"),
    pair: new Pair("first", 2),
  }));
  assert.equal(probe.generic(wire), `${expected}|value|key|first|2`);
}
const rowShape = JSON.stringify(encode({
  metrics: metrics({ source_kind: "tagged", source_key: "card" }),
  circulation_rate: new None(), median: new None(),
}));
assert.equal(probe.muse(rowShape), "DECODE_ERROR");
console.log("CODEC ROUNDTRIP: ALL PASS (muse 4, store 4, generic 3; generated decoders)");
