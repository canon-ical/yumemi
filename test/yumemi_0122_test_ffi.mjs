// yumemi-0122 ── runtime の 2 つの柵を子の node で回す(globals を汚さない)と、生成物の import の行き先の検査。
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

/// `test/yumemi_0122_check.mjs <which>` の出力(1 行 1 件の ok / NG)。
export function runtime_check(which) {
  const result = spawnSync(process.execPath, [path.resolve("test/yumemi_0122_check.mjs"), which], { encoding: "utf8", timeout: 60000 });
  return `${result.stdout}${result.stderr ? `\nSTDERR ${result.stderr}` : ""}`.trim();
}

/// 生成物の相対の import(`.mjs` の `from '..'`、`.gleam` の `@external(javascript, "..", ..)`)のうち、
/// 行き先が生成物にも app の ★ にも無いものを `<file>: <行き先>` で返す。`src/` の外へ出る行き先
/// (yumemi の runtime、`../gleam.mjs` の prelude)は build の木で解けるので数えない。
export function unresolved_imports(dir, paths, texts) {
  const files = paths.toArray();
  const bodies = texts.toArray();
  const generated = new Set(files);
  const exists = (target) => {
    const gleam = target.replace(/\.mjs$/, ".gleam");
    return generated.has(target) || generated.has(gleam) || fs.existsSync(path.join(dir, target)) || fs.existsSync(path.join(dir, gleam));
  };
  const missing = [];
  files.forEach((file, index) => {
    const text = bodies[index];
    const specifiers = file.endsWith(".gleam")
      ? [...text.matchAll(/@external\(javascript,\s*"([^"]+)"/g)].map((m) => m[1])
      : file.endsWith(".mjs")
        ? [...text.matchAll(/\b(?:from|import)\s*['"]([^'"]+)['"]/g)].map((m) => m[1])
        : [];
    for (const specifier of specifiers) {
      if (!specifier.startsWith(".")) continue;
      const target = path.posix.normalize(path.posix.join(path.posix.dirname(file), specifier));
      if (!target.startsWith("src/") || target === "src/gleam.mjs") continue;
      if (!exists(target)) missing.push(`${file}: ${specifier}`);
    }
  });
  return missing.join("\n");
}
