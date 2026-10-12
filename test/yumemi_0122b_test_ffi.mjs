// yumemi-0122b ── runtime の 2 つの柵を子の node で回す(globals を汚さない)。
import path from "node:path";
import { spawnSync } from "node:child_process";

/// `test/yumemi_0122b_check.mjs <which> <verb>` の出力(1 行 1 件の ok / NG)。`verb` は生成の verb の表の 1 行。
export function runtime_check(which, verb) {
  const result = spawnSync(process.execPath, [path.resolve("test/yumemi_0122b_check.mjs"), which, verb], { encoding: "utf8", timeout: 60000 });
  return `${result.stdout}${result.stderr ? `\nSTDERR ${result.stderr}` : ""}`.trim();
}
