// yumemi-0131 ── 入口の失敗の log を子の node で回す(globals を汚さない)。
import path from "node:path";
import { spawnSync } from "node:child_process";

/// `test/yumemi_0131_check.mjs <which>` の出力(1 行 1 件の ok / NG)。
export function check(which) {
  const result = spawnSync(process.execPath, [path.resolve("test/yumemi_0131_check.mjs"), which], { encoding: "utf8", timeout: 60000 });
  return `${result.stdout}${result.stderr ? `\nSTDERR ${result.stderr}` : ""}`.trim();
}
