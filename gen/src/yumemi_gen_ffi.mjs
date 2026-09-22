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

function repositoryRoot() {
  const cwd = process.cwd();
  return path.basename(cwd) === "gen" ? path.dirname(cwd) : cwd;
}

function fallbackClient(source, packageName_) {
  return source
    .replaceAll("__YUMEMI_BUILD__", "../../../build/dev/javascript")
    .replaceAll("__YUMEMI_FACE__", packageName_);
}

function warning(face, detail) {
  return `[exit 0 警告] ${face}/priv/static/_yumemi/client.mjs: ${detail}`;
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
    const tempFace = path.join(tempRoot, face);
    copyDirectoryContents(sourceFace, tempFace);
    copyDirectoryContents(outputFace, tempFace);

    const tomlPath = path.join(tempFace, "gleam.toml");
    const toml = fs.readFileSync(tomlPath, "utf8");
    const root = repositoryRoot();
    const rewritten = toml.replace(
      /yumemi\s*=\s*\{\s*path\s*=\s*"[^"]+"\s*\}/,
      `yumemi = { path = "${root.replaceAll('\\', '\\\\')}" }`,
    );
    fs.writeFileSync(tomlPath, rewritten);
    fs.rmSync(path.join(tempFace, "build"), { recursive: true, force: true });
    fs.rmSync(path.join(tempFace, "manifest.toml"), {
      force: true,
    });

    const name = packageName(rewritten);
    const source = fs.readFileSync(sourcePath, "utf8");
    const build = spawnSync("gleam", ["build", "--target", "javascript"], {
      cwd: tempFace,
      encoding: "utf8",
    });
    if (build.status !== 0) {
      fs.writeFileSync(sourcePath, fallbackClient(source, name));
      const detail = (build.stderr || build.stdout || "")
        .trim()
        .split("\n")
        .slice(-3)
        .join(" ");
      return warning(
        face,
        `Gleam の client bundle 用 build を起こせず素の entry を出した: ${detail}`,
      );
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
        `--outfile=${bundled}`,
      ],
      { cwd: tempRoot, encoding: "utf8" },
    );
    if (esbuild.status !== 0 || !fs.existsSync(bundled)) {
      fs.writeFileSync(sourcePath, fallbackClient(source, name));
      const detail = (esbuild.stderr || esbuild.stdout || "")
        .trim()
        .split("\n")
        .slice(-4)
        .join(" ");
      return warning(face, `esbuild を起こせず素の entry を出した: ${detail}`);
    }

    const header = source.split("\n", 1)[0];
    let body = fs.readFileSync(bundled, "utf8");
    if (body.startsWith(header)) body = body.slice(header.length).replace(/^\n/, "");
    fs.writeFileSync(sourcePath, `${header}\n${body}`);
    return null;
  } finally {
    fs.rmSync(tempRoot, { recursive: true, force: true });
  }
}

export function bundle_front(outDir, appDir, faces) {
  const warnings = [];
  const faceNames = faces?.toArray ? faces.toArray() : faces;
  for (const face of faceNames) {
    const result = bundleOne(outDir, appDir, face);
    if (result) warnings.push(result);
  }
  return toList(warnings);
}
