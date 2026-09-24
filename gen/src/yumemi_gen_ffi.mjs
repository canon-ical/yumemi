import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { toList } from "./gleam.mjs";

export function halt(code) {
  if (globalThis.process && typeof globalThis.process.exit === "function") {
    globalThis.process.exit(code);
  }
  return undefined;
}

export function format_gleam(outDir, files) {
  const paths = files?.toArray ? files.toArray() : files;
  const absolutePaths = paths.map((file) => path.resolve(outDir, file));
  if (absolutePaths.length === 0) return "";

  let formatted;
  try {
    formatted = spawnSync("gleam", ["format", ...absolutePaths], {
      cwd: path.resolve(outDir),
      encoding: "utf8",
    });
  } catch (error) {
    return `spawn error: ${error instanceof Error ? error.message : String(error)}`;
  }
  if (formatted.status === 0) return "";
  const detail = (formatted.error?.message || formatted.stderr || formatted.stdout || "")
    .trim()
    .split("\n")
    .slice(-6)
    .join(" ");
  return `status=${formatted.status}: ${detail || "no formatter output"}`;
}

function copyDirectoryContents(source, destination) {
  fs.mkdirSync(destination, { recursive: true });
  for (const name of fs.readdirSync(source)) {
    if (name === "build" || name === "node_modules" || name === ".git") continue;
    fs.cpSync(path.join(source, name), path.join(destination, name), {
      recursive: true,
      force: true,
    });
  }
}

function packageName(toml) {
  return toml.match(/^name\s*=\s*"([^"]+)"/m)?.[1] ?? "public";
}

function repositoryRoot(faceDir, toml) {
  const dependency = toml.match(
    /^\s*yumemi\s*=\s*\{\s*path\s*=\s*"([^"]+)"\s*\}\s*$/m,
  );
  return dependency ? path.resolve(faceDir, dependency[1]) : null;
}

function prepareTemporaryPackage(sourceFace, tempFace) {
  const tomlPath = path.join(tempFace, "gleam.toml");
  const toml = fs.readFileSync(path.join(sourceFace, "gleam.toml"), "utf8");
  const root = repositoryRoot(sourceFace, toml);
  const rewritten = root === null
    ? toml
    : toml.replace(
        /yumemi\s*=\s*\{\s*path\s*=\s*"[^"]+"\s*\}/,
        `yumemi = { path = "${root.replaceAll('\\', '\\\\')}" }`,
      );
  fs.writeFileSync(tomlPath, rewritten);
  fs.rmSync(path.join(tempFace, "build"), { recursive: true, force: true });
  const sourceManifest = path.join(sourceFace, "manifest.toml");
  const tempManifest = path.join(tempFace, "manifest.toml");
  if (root === null && fs.existsSync(sourceManifest)) {
    fs.copyFileSync(sourceManifest, tempManifest);
  } else {
    fs.rmSync(tempManifest, { force: true });
  }
  return rewritten;
}

function diagnosticDetail(processResult, tempRoot) {
  return (processResult.error?.message || processResult.stderr || processResult.stdout || "")
    .trim()
    .split("\n")
    .slice(-12)
    .join(" ")
    .replaceAll(tempRoot, "<bundle-temp>")
    .replace(/\s+/g, " ");
}

function compileCurrentOutDecoders(sourceFace, outputFace, tempRoot, face) {
  const outDir = path.join(outputFace, "src/gen/out");
  if (!fs.existsSync(outDir)) return { error: null, modules: 0 };

  const tempFace = path.join(tempRoot, `${face}-out-check`);
  fs.mkdirSync(tempFace, { recursive: true });
  fs.copyFileSync(
    path.join(sourceFace, "gleam.toml"),
    path.join(tempFace, "gleam.toml"),
  );
  const tempOutDir = path.join(tempFace, "src/gen/out");
  copyDirectoryContents(outDir, tempOutDir);
  const modules = fs.readdirSync(tempOutDir, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith(".gleam"))
    .map((entry) => entry.name.slice(0, -".gleam".length))
    .filter((name) => {
      const source = fs.readFileSync(path.join(tempOutDir, `${name}.gleam`), "utf8");
      return source.includes("pub fn decoder() -> decode.Decoder(Out)");
    })
    .sort();
  const imports = modules
    .map((name, index) => `import gen/out/${name} as client_out_${index}`)
    .join("\n");
  const calls = modules
    .map((_, index) => `  let _ = client_out_${index}.decoder()`)
    .join("\n");
  const probe = `${imports}\n\npub fn check() -> Nil {\n${calls}\n  Nil\n}\n`;
  fs.writeFileSync(path.join(tempFace, "src/client_probe.gleam"), probe);
  const toml = prepareTemporaryPackage(sourceFace, tempFace);
  const build = spawnSync("gleam", ["build", "--target", "javascript"], {
    cwd: tempFace,
    encoding: "utf8",
  });
  if (build.status !== 0) {
    const detail = diagnosticDetail(build, tempRoot);
    return {
      error: `${face}: client Out decoder 用 Gleam build に失敗した (status=${build.status}): ${detail}`,
      modules: modules.length,
      name: packageName(toml),
    };
  }
  return { error: null, modules: modules.length, name: packageName(toml) };
}

function bundleOne(outDir, appDir, face) {
  const cwd = process.cwd();
  const appPath = path.resolve(cwd, appDir);
  const sourceFace = fs.existsSync(path.join(appPath, face))
    ? path.join(appPath, face)
    : path.resolve(path.dirname(appPath), face);
  const outputFace = path.resolve(outDir, face);
  const sourcePath = path.join(
    outputFace,
    "priv/static/_yumemi/client.mjs",
  );
  if (!fs.existsSync(sourcePath)) return null;

  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "yumemi-gen-front-"));
  try {
    const outCheck = compileCurrentOutDecoders(sourceFace, outputFace, tempRoot, face);
    if (outCheck.error !== null) {
      fs.rmSync(sourcePath, { force: true });
      return outCheck.error;
    }

    const tempFace = path.join(tempRoot, face);
    copyDirectoryContents(sourceFace, tempFace);
    copyDirectoryContents(outputFace, tempFace);
    const rewritten = prepareTemporaryPackage(sourceFace, tempFace);
    const name = packageName(rewritten);
    const source = fs.readFileSync(sourcePath, "utf8");
    const runtimeBuild = spawnSync("gleam", ["build", "--target", "javascript"], {
      cwd: tempFace,
      encoding: "utf8",
    });
    if (runtimeBuild.status !== 0) {
      fs.rmSync(sourcePath, { force: true });
      const detail = diagnosticDetail(runtimeBuild, tempRoot);
      return `${face}: client runtime 用 Gleam build に失敗した (status=${runtimeBuild.status}): ${detail}`;
    }

    const buildRoot = path.join(tempFace, "build/dev/javascript");
    const entry = path.join(tempRoot, "client-entry.mjs");
    const entryText = source
      .replaceAll("__YUMEMI_BUILD__", buildRoot)
      .replaceAll("__YUMEMI_FACE__", name);
    fs.writeFileSync(entry, entryText);
    const bundled = path.join(tempRoot, "client-bundled.mjs");
    const esbuild = spawnSync(
      "npx",
      [
        "--yes",
        "esbuild",
        entry,
        "--bundle",
        "--format=esm",
        "--log-override:import-is-undefined=error",
        `--outfile=${bundled}`,
      ],
      { cwd: tempRoot, encoding: "utf8" },
    );
    if (esbuild.status !== 0 || !fs.existsSync(bundled)) {
      fs.rmSync(sourcePath, { force: true });
      const detail = diagnosticDetail(esbuild, tempRoot);
      return `${face}: client bundle 用 esbuild に失敗した (status=${esbuild.status}): ${detail || "bundle output missing"}`;
    }

    const header = source.split("\n", 1)[0];
    let body = fs.readFileSync(bundled, "utf8");
    if (body.startsWith(header)) body = body.slice(header.length).replace(/^\n/, "");
    fs.writeFileSync(sourcePath, `${header}\n${body}`);
    console.log(
      `${face}: client Out decoder build PASS (${outCheck.modules} modules); runtime build and esbuild PASS`,
    );
    return null;
  } finally {
    fs.rmSync(tempRoot, { recursive: true, force: true });
  }
}

export function bundle_front(outDir, appDir, faces) {
  const errors = [];
  const faceNames = faces?.toArray ? faces.toArray() : faces;
  for (const face of faceNames) {
    const result = bundleOne(outDir, appDir, face);
    if (result) errors.push(result);
  }
  return toList(errors);
}
