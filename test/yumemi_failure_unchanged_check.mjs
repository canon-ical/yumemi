// failure-page(0.14.3)── 失敗の頁を宣言しない面の生成物は 0.14.2 と同じ字。article と cms の fixture の写しを
// 生成器(compile 済みの `build/dev/javascript/yumemi/yumemi/gen.mjs`)で生成し直し、commit した fixture と file ごと
// に比べる。比べないのは `src/gen/reads/*.gleam`(0.14.1 より前から生成器の出力と字が違う、results-block-door)と
// 写しのために書き換えた `gleam.toml`・`build`・`node_modules`。1 行 1 件の ok / NG。写しは `build/failure-unchanged`。
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { pathToFileURL } from "node:url";

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const work = path.join(root, "build", "failure-unchanged");
const out = [];
const check = (name, ok, detail = "") => out.push(`${ok ? "ok" : "NG"} ${name}${ok || detail === "" ? "" : ` ── ${detail}`}`);

const skip = (relative) => /(^|\/)(build|node_modules)(\/|$)/.test(relative) || relative.endsWith("gleam.toml") || relative.startsWith("src/gen/reads/");
function files(dir, base = dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    const relative = path.relative(base, full);
    if (skip(relative)) return [];
    return entry.isDirectory() ? files(full, base) : [relative];
  });
}

fs.rmSync(work, { recursive: true, force: true });
fs.mkdirSync(work, { recursive: true });
const runner = path.join(work, "gen-run.mjs");
fs.writeFileSync(runner, `import { main } from ${JSON.stringify(pathToFileURL(path.join(root, "build/dev/javascript/yumemi/yumemi/gen.mjs")).href)};\nmain();\n`);
for (const name of ["article", "cms"]) {
  const fixture = path.join(root, "gen/fixtures", name);
  const app = path.join(work, name);
  fs.cpSync(fixture, app, { recursive: true });
  for (const face of ["public", "admin"]) {
    if (!fs.existsSync(path.join(app, face))) continue;
    fs.rmSync(path.join(app, face, "build"), { recursive: true, force: true });
    fs.rmSync(path.join(app, face, "node_modules"), { recursive: true, force: true });
    fs.mkdirSync(path.join(app, face, "node_modules/.bin"), { recursive: true });
    fs.symlinkSync(path.join(root, "node_modules/.bin/esbuild"), path.join(app, face, "node_modules/.bin/esbuild"));
    fs.symlinkSync(path.join(root, "node_modules/esbuild"), path.join(app, face, "node_modules/esbuild"));
    const toml = path.join(app, face, "gleam.toml");
    fs.writeFileSync(toml, fs.readFileSync(toml, "utf8").replace('path = "../../../.."', `path = ${JSON.stringify(root)}`));
  }
  const result = spawnSync(process.execPath, [runner, app, app], { cwd: root, encoding: "utf8", timeout: 300000 });
  const log = `${result.stdout ?? ""}${result.stderr ?? ""}`;
  fs.writeFileSync(path.join(work, `gen-${name}.txt`), log);
  check(`${name}: the generator runs with exit 0`, result.status === 0, log.slice(-400));
  const before = files(fixture).sort();
  const after = files(app).sort();
  const differ = after.filter((file) => !before.includes(file) || !fs.readFileSync(path.join(fixture, file)).equals(fs.readFileSync(path.join(app, file))));
  const missing = before.filter((file) => !after.includes(file));
  check(`${name}: every generated file is byte-identical to the committed fixture (${after.length} files)`, differ.length === 0 && missing.length === 0 && after.length > 20, JSON.stringify({ differ, missing }));
}

console.log(out.join("\n"));
process.exit(0);
