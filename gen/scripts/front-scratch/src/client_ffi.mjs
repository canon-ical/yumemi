export function listenReload(tag, callback) {
  document.querySelectorAll(tag).forEach((element) => {
    element.addEventListener("yumemi-done", () => callback(undefined));
  });
}

export function reloadPage() {
  globalThis.location.assign(globalThis.location.href);
}
