// yumemi-live-1 ── 合図の器・札・socket の口を workerd で回す(`test/yumemi_live_check.mjs`、子の node)。
import path from "node:path";
import { spawnSync } from "node:child_process";

/// `test/yumemi_live_check.mjs` の出力(1 行 1 件の ok / NG)。
export function live_check() {
  const result = spawnSync(process.execPath, [path.resolve("test/yumemi_live_check.mjs")], { encoding: "utf8", timeout: 120000 });
  return `${result.stdout}${result.stderr ? `\nSTDERR ${result.stderr}` : ""}`.trim();
}
