import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createHash } from "node:crypto";
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

function dependencyCacheDirectory(sourceFace, face) {
  const toml = fs.readFileSync(path.join(sourceFace, "gleam.toml"), "utf8");
  const root = repositoryRoot(sourceFace, toml);
  if (root === null) return null;
  const sourceManifest = path.join(sourceFace, "manifest.toml");
  const manifest = fs.existsSync(sourceManifest)
    ? fs.readFileSync(sourceManifest, "utf8")
    : "";
  const rootToml = fs.readFileSync(path.join(root, "gleam.toml"), "utf8");
  const key = createHash("sha256")
    .update(path.resolve(sourceFace))
    .update("\n")
    .update(toml)
    .update("\n")
    .update(manifest)
    .update("\n")
    .update(rootToml)
    .digest("hex");
  const safeFace = face.replace(/[^A-Za-z0-9_.-]/g, "_");
  return path.join(process.cwd(), "build/yumemi-gen-front-cache", safeFace, key);
}

function restoreDependencyCache(tempFace, cacheDir) {
  if (cacheDir === null) return;
  const cachedPackages = path.join(cacheDir, "packages");
  if (!fs.existsSync(cachedPackages)) return;
  fs.cpSync(
    cachedPackages,
    path.join(tempFace, "build/packages"),
    { recursive: true, force: true },
  );
}

function persistDependencyCache(tempFace, cacheDir) {
  if (cacheDir === null) return;
  const builtPackages = path.join(tempFace, "build/packages");
  if (!fs.existsSync(builtPackages)) return;
  const cachedPackages = path.join(cacheDir, "packages");
  fs.mkdirSync(cacheDir, { recursive: true });
  fs.cpSync(builtPackages, cachedPackages, { recursive: true, force: true });
}

function manifestForPathDependency(manifest, root) {
  const newline = manifest.includes("\r\n") ? "\r\n" : "\n";
  const lines = manifest.split(/\r?\n/);
  const kept = [];
  let inPackages = false;
  const packageVersion =
    fs.readFileSync(path.join(root, "gleam.toml"), "utf8")
      .match(/^version\s*=\s*"([^"]+)"/m)?.[1];
  if (!packageVersion) {
    throw new Error("yumemi path dependency has no package version");
  }
  const localPath = root.replaceAll("\\", "\\\\");
  const packageNameField = /\bname\s*=\s*"yumemi"/;
  for (const line of lines) {
    if (/^\s*packages\s*=\s*\[/.test(line)) {
      inPackages = !/]\s*$/.test(line);
      kept.push(line);
      continue;
    }
    if (inPackages && /^\s*\]\s*,?\s*$/.test(line)) {
      inPackages = false;
      kept.push(line);
      continue;
    }
    if (
      inPackages
      && /^\s*\{/.test(line)
      && packageNameField.test(line)
    ) {
      let localPackage = line
        .replace(/version\s*=\s*"[^"]+"/, 'version = "' + packageVersion + '"')
        .replace(/,\s*otp_app\s*=\s*"[^"]+"/, "")
        .replace(/source\s*=\s*"[^"]+"/, 'source = "local"')
        .replace(/,\s*outer_checksum\s*=\s*"[^"]+"/, "");
      if (/path\s*=\s*"[^"]+"/.test(localPackage)) {
        localPackage = localPackage.replace(
          /path\s*=\s*"[^"]+"/,
          'path = "' + localPath + '"',
        );
      } else {
        localPackage = localPackage.replace(
          /\s*}\s*,?\s*$/,
          ', path = "' + localPath + '" },',
        );
      }
      kept.push(localPackage);
      continue;
    }
    if (!inPackages && /^\s*yumemi\s*=\s*\{/.test(line)) {
      const indentation = line.match(/^\s*/)?.[0] ?? "";
      kept.push(indentation + 'yumemi = { path = "' + localPath + '" }');
      continue;
    }
    kept.push(line);
  }
  return kept.join(newline);
}

export function prepareTemporaryPackage(sourceFace, tempFace) {
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
  const sourceManifest = path.join(sourceFace, "manifest.toml");
  const tempManifest = path.join(tempFace, "manifest.toml");
  if (root === null && fs.existsSync(sourceManifest)) {
    fs.copyFileSync(sourceManifest, tempManifest);
  } else if (root !== null && fs.existsSync(sourceManifest)) {
    fs.writeFileSync(
      tempManifest,
      manifestForPathDependency(
        fs.readFileSync(sourceManifest, "utf8"),
        root,
      ),
    );
  } else {
    fs.rmSync(tempManifest, { force: true });
  }
  return rewritten;
}

function diagnosticOutput(processResult, tempRoot) {
  const parts = [];
  if (processResult.error) {
    parts.push(processResult.error.message || String(processResult.error));
  }
  if (processResult.stdout) parts.push(processResult.stdout);
  if (processResult.stderr) parts.push(processResult.stderr);
  return parts
    .join("\n")
    .replaceAll(tempRoot, "<bundle-temp>")
    .trimEnd();
}

function diagnosticDetail(processResult, tempRoot, outputFace, face, stage) {
  const output = diagnosticOutput(processResult, tempRoot);
  const detail = output
    .split("\n")
    .slice(-12)
    .join(" ")
    .replace(/\s+/g, " ");
  const fileName = face + "-" + stage + ".txt";
  const relativePath = "_diagnostics/" + fileName;
  fs.mkdirSync(path.join(outputFace, "_diagnostics"), { recursive: true });
  fs.writeFileSync(
    path.join(outputFace, relativePath),
    (output || "No diagnostic output was produced.") + "\n",
  );
  return detail + "; 全文=" + relativePath;
}

function retainPackageContext(outputFace, face, stage, tempFace) {
  const diagnosticDir = path.join(outputFace, "_diagnostics");
  fs.mkdirSync(diagnosticDir, { recursive: true });
  for (const name of ["gleam.toml", "manifest.toml"]) {
    const source = path.join(tempFace, name);
    if (!fs.existsSync(source)) continue;
    fs.copyFileSync(
      source,
      path.join(diagnosticDir, face + "-" + stage + "-" + name),
    );
  }
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
  const dependencyCache = dependencyCacheDirectory(sourceFace, face);
  const toml = prepareTemporaryPackage(sourceFace, tempFace);
  restoreDependencyCache(tempFace, dependencyCache);
  const build = spawnSync("gleam", ["build", "--target", "javascript"], {
    cwd: tempFace,
    encoding: "utf8",
  });
  persistDependencyCache(tempFace, dependencyCache);
  if (build.status !== 0) {
    retainPackageContext(outputFace, face, "out-decoder", tempFace);
    const detail = diagnosticDetail(build, tempRoot, outputFace, face, "out-decoder");
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
    const dependencyCache = dependencyCacheDirectory(sourceFace, face);
    restoreDependencyCache(tempFace, dependencyCache);
    const name = packageName(rewritten);
    const source = fs.readFileSync(sourcePath, "utf8");
    const runtimeBuild = spawnSync("gleam", ["build", "--target", "javascript"], {
      cwd: tempFace,
      encoding: "utf8",
    });
    persistDependencyCache(tempFace, dependencyCache);
    if (runtimeBuild.status !== 0) {
      fs.rmSync(sourcePath, { force: true });
      const detail = diagnosticDetail(
        runtimeBuild,
        tempRoot,
        outputFace,
        face,
        "runtime",
      );
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
      const detail = diagnosticDetail(
        esbuild,
        tempRoot,
        outputFace,
        face,
        "esbuild",
      );
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
