// failure-page ── 生成した面の失敗の頁(node と Chromium)と、宣言の無い fixture の生成し直しを子の node で回す。
import path from "node:path";
import { spawnSync } from "node:child_process";

function child(file, timeout) {
  const result = spawnSync(process.execPath, [path.resolve(file)], { encoding: "utf8", timeout });
  return `${result.stdout}${result.stderr ? `\nSTDERR ${result.stderr}` : ""}`.trim();
}

/// `test/yumemi_failure_check.mjs` の出力(1 行 1 件の ok / NG)。shell の console.error は捨てる。
export function failure_check() {
  const result = spawnSync(process.execPath, [path.resolve("test/yumemi_failure_check.mjs")], { encoding: "utf8", timeout: 600000 });
  return `${result.stdout}`.trim() + (result.status === 0 ? "" : `\nNG exit ${result.status} ${result.stderr.slice(-600)}`);
}

/// `test/yumemi_failure_unchanged_check.mjs` の出力。
export function unchanged_check() {
  return child("test/yumemi_failure_unchanged_check.mjs", 600000);
}
