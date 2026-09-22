// GENERATED from public/src/components/*.gleam and src/entry.gleam [sha256:4f2097e4dd4f] — 手で編集しない
export function send(method, path, body, onOk, onError) {
  fetch(path, {
    method,
    headers: { "content-type": "application/json" },
    body: method === "GET" ? undefined : JSON.stringify(body),
  })
    .then((response) =>
      response.ok
        ? response.json().then(onOk)
        : onError(undefined))
    .catch(() => onError(undefined));
  return undefined;
}
