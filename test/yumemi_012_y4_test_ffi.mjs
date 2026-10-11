import path from "node:path";
import { spawnSync } from "node:child_process";

/// 0.12(Y4)── navigate.mjs の `start` / `reload` を偽の Navigation API で(globals を替えるので子の node で走らせる)。
export function navigation_start() {
  const result = spawnSync(process.execPath, [path.resolve("test/yumemi_012_y4_start_check.mjs")], { encoding: "utf8", timeout: 60000 });
  return `${result.stdout}${result.stderr ? `\nSTDERR ${result.stderr}` : ""}`.trim();
}
