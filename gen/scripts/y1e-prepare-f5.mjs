import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { prepareTemporaryPackage } from "../build/dev/javascript/yumemi_gen/yumemi_gen_ffi.mjs";

const [runDirArg, snapshotArg, outputArg, tag] = process.argv.slice(2);
if (!runDirArg || !snapshotArg || !outputArg || !tag) {
  throw new Error(
    "usage: node y1e-prepare-f5.mjs <run-dir> <snapshot> <out-dir> <tag>",
  );
}

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDir, "../..");
const runDir = path.resolve(runDirArg);
const snapshot = path.resolve(snapshotArg);
const generated = path.resolve(outputArg);
const probeRoot = path.join(runDir, "ms-probe-f5-" + tag);

function isWithin(parent, child) {
  const relative = path.relative(parent, child);
  return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
}

function copyTree(source, destination) {
  fs.cpSync(source, destination, {
    recursive: true,
    force: true,
    filter: (entry) => {
      const name = path.basename(entry);
      return name !== "build" && name !== "node_modules" && name !== ".git";
    },
  });
}

function countFiles(directory) {
  let count = 0;
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) count += countFiles(entryPath);
    else count += 1;
  }
  return count;
}

function newestDependencyCache() {
  const cacheRoot = path.join(
    repositoryRoot,
    "gen/build/yumemi-gen-front-cache/public",
  );
  if (!fs.existsSync(cacheRoot)) {
    throw new Error("fixture path dependency cache is missing: " + cacheRoot);
  }
  const candidates = fs.readdirSync(cacheRoot)
    .map((name) => path.join(cacheRoot, name, "packages"))
    .filter((packages) =>
      fs.existsSync(path.join(packages, "yumemi.config_fingerprint")),
    )
    .sort((left, right) =>
      fs.statSync(path.join(right, "yumemi.config_fingerprint")).mtimeMs
      - fs.statSync(path.join(left, "yumemi.config_fingerprint")).mtimeMs
    );
  if (candidates.length === 0) {
    throw new Error("no cached yumemi path dependency fingerprint exists");
  }
  return candidates[0];
}

if (!isWithin(runDir, probeRoot)) {
  throw new Error("probe output escaped the supplied run directory");
}
if (!fs.existsSync(snapshot) || !fs.existsSync(generated)) {
  throw new Error("snapshot or generated output directory is missing");
}

fs.rmSync(probeRoot, { recursive: true, force: true });
const dependencyPackages = newestDependencyCache();
for (const face of ["www", "muses", "console"]) {
  const sourceFace = path.join(snapshot, face);
  const generatedFace = path.join(generated, face);
  const probeFace = path.join(probeRoot, face);
  if (!fs.existsSync(sourceFace) || !fs.existsSync(generatedFace)) {
    throw new Error("missing source or generated face: " + face);
  }
  copyTree(sourceFace, probeFace);
  fs.rmSync(path.join(probeFace, "src/gen"), { recursive: true, force: true });
  fs.rmSync(path.join(probeFace, "build"), { recursive: true, force: true });
  copyTree(generatedFace, probeFace);

  const tomlPath = path.join(probeFace, "gleam.toml");
  const toml = fs.readFileSync(tomlPath, "utf8");
  if (!/^\s*yumemi\s*=/m.test(toml)) {
    throw new Error(face + " gleam.toml has no yumemi dependency");
  }
  fs.writeFileSync(
    tomlPath,
    toml.replace(
      /^\s*yumemi\s*=.*$/m,
      'yumemi = { path = "' + repositoryRoot + '" }',
    ),
  );
  prepareTemporaryPackage(probeFace, probeFace);

  const buildPackages = path.join(probeFace, "build/packages");
  fs.mkdirSync(path.dirname(buildPackages), { recursive: true });
  fs.cpSync(dependencyPackages, buildPackages, { recursive: true, force: true });
  console.log(face + ": prepared " + countFiles(probeFace) + " files");
}

console.log("probe: " + probeRoot);
