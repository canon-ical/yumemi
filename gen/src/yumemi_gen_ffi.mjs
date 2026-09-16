export function halt(code) {
  if (globalThis.process && typeof globalThis.process.exit === "function") {
    globalThis.process.exit(code);
  }
  return undefined;
}
