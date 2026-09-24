import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { bundle_front } from "./yumemi_gen_ffi.mjs";

function write(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, value);
}

function withBundle(sourceMarker, outputMarker, entry, check) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "yumemi-gen-bundle-test-"));
  try {
    const appDir = path.join(root, "app");
    const outDir = path.join(root, "out");
    const source = path.join(appDir, "public");
    const output = path.join(outDir, "public");
    write(path.join(source, "gleam.toml"), 'name = "public"\nversion = "0.1.0"\ntarget = "javascript"\n');
    write(path.join(source, "src/gen/marker.gleam"), sourceMarker);
    write(path.join(output, "src/gen/marker.gleam"), outputMarker);
    const client = path.join(output, "priv/static/_yumemi/client.mjs");
    write(client, `// GENERATED test entry\n${entry}\n`);
    const errors = bundle_front(outDir, appDir, ["public"]).toArray();
    return check(errors, client);
  } catch (error) {
    return `FAIL: ${error instanceof Error ? error.stack : String(error)}`;
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
}

export function bundle_uses_generated_module() {
  return withBundle(
    'pub const marker = "INPUT_SIDE_SENTINEL"\n',
    'pub const marker = "OUTPUT_SIDE_SENTINEL"\n',
    'import { marker } from "__YUMEMI_BUILD__/__YUMEMI_FACE__/gen/marker.mjs"; console.log(marker);',
    (errors, client) => {
      if (errors.length !== 0) return `FAIL: ${errors.join(" | ")}`;
      const body = fs.readFileSync(client, "utf8");
      if (!body.includes("OUTPUT_SIDE_SENTINEL")) return "FAIL: output marker missing";
      if (body.includes("INPUT_SIDE_SENTINEL")) return "FAIL: input marker leaked";
      return "PASS";
    },
  );
}

export function bundle_rejects_undefined_import() {
  return withBundle(
    'pub fn view() { Nil }\n',
    'pub fn view() { Nil }\n',
    'import { app } from "__YUMEMI_BUILD__/__YUMEMI_FACE__/gen/marker.mjs"; app();',
    (errors, client) => {
      if (errors.length !== 1 || !errors[0].includes("client bundle 用 esbuild に失敗")) {
        return `FAIL: expected one esbuild error, got ${errors.join(" | ")}`;
      }
      if (errors[0].includes("\n")) return "FAIL: diagnostic spans multiple lines";
      if (fs.existsSync(client)) return "FAIL: unbundled entry survived";
      return "PASS";
    },
  );
}
