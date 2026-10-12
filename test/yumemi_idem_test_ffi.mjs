// yumemi-idem ── 冪等キーの runtime・入口・client・cron を子の node で回す(globals を汚さない)。
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

/// `test/yumemi_idem_check.mjs <which>` の出力(1 行 1 件の ok / NG)。`which` は server / client / purge。
export function idem_check(which) {
  const result = spawnSync(process.execPath, [path.resolve("test/yumemi_idem_check.mjs"), which], { encoding: "utf8", timeout: 60000 });
  return `${result.stdout}${result.stderr ? `\nSTDERR ${result.stderr}` : ""}`.trim();
}

/// fixture の写しに 1 file を置く(★ の SQL が既定に勝つかを見る)。
export function write(dir, file, text) {
  const target = path.join(dir, file);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, text);
}
