// yumemi-0131 r2 ── 病的な入力の読みと描きの時間(ms)。
export function timed(run) {
  const start = performance.now();
  const value = run();
  return [value, performance.now() - start];
}
