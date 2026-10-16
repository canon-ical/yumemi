// yumemi-live-2 ── client の runtime(Playwright)と生成した shell の断片の口(node)を子の node で回す。
import path from "node:path";
import { spawnSync } from "node:child_process";

function child(file, timeout) {
  const result = spawnSync(process.execPath, [path.resolve(file)], { encoding: "utf8", timeout });
  return `${result.stdout}${result.stderr ? `\nSTDERR ${result.stderr}` : ""}`.trim();
}

/// `test/yumemi_live2_check.mjs` の出力(1 行 1 件の ok / NG)。
export function browser_check() {
  return child("test/yumemi_live2_check.mjs", 300000);
}

/// `test/yumemi_live2_shell_check.mjs` の出力。
export function shell_check() {
  return child("test/yumemi_live2_shell_check.mjs", 600000);
}
