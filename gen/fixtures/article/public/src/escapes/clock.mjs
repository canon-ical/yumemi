// ★ 名前付きの逃げ道(0.12)。決まった口は mount 1 つ、戻り値は外すときの関数。
export function mount(element) {
  element.textContent = "mounted";
  element.dataset.mounted = String(Number(globalThis.__yumemiClockMounts ?? 0) + 1);
  globalThis.__yumemiClockMounts = Number(globalThis.__yumemiClockMounts ?? 0) + 1;
  return () => {
    globalThis.__yumemiClockUnmounts = Number(globalThis.__yumemiClockUnmounts ?? 0) + 1;
  };
}
