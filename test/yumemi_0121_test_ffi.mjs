// yumemi-0121 ── runtime の 2 つの柵を子の node で回す(globals を汚さない)。1 行 1 件の ok / NG。
import path from "node:path";
import { spawnSync } from "node:child_process";

function child(file) {
  const result = spawnSync(process.execPath, [path.resolve(file)], { encoding: "utf8", timeout: 60000 });
  return `${result.stdout}${result.stderr ? `\nSTDERR ${result.stderr}` : ""}`.trim();
}

/// 同じ名の読みを 2 本 import した Service の `ctx.read`(runtime.mjs)。
export function runtime_read() {
  return child("test/yumemi_0121_read_check.mjs");
}

/// 断りと失敗の状態(interactive.mjs)。
export function runtime_states() {
  return child("test/yumemi_0121_state_check.mjs");
}

/// 0.14.2 の `[hidden]` の規則を Chromium で(`css` は生成の style.css の全文を stdin で渡す)。
export function hidden_in_chromium(css) {
  const result = spawnSync(process.execPath, [path.resolve("test/yumemi_0142_hidden_check.mjs")], { input: css, encoding: "utf8", timeout: 120000 });
  return `${result.stdout}${result.stderr ? `\nSTDERR ${result.stderr}` : ""}`.trim();
}
