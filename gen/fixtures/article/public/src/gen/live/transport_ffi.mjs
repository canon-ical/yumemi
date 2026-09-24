// GENERATED from public/src/components/*.gleam and src/entry.gleam [sha256:8fde9ebb404a] — 手で編集しない
const selectedFiles = new Map();
const uploadedFiles = new Map();
const pendingUploads = new Map();

export function file_token(event) {
  const input = event.currentTarget ?? event.target;
  if (!(input instanceof HTMLInputElement)) return "";
  const previous = input.dataset.yumemiFileToken;
  if (previous) { selectedFiles.delete(previous); uploadedFiles.delete(previous); }
  const file = input.files?.[0];
  if (!file) { delete input.dataset.yumemiFileToken; return ""; }
  const token = `~yumemi-file:${crypto.randomUUID()}`;
  selectedFiles.set(token, file);
  input.dataset.yumemiFileToken = token;
  return token;
}

async function uploadToken(token, method = "POST", path = "/api/blobs") {
  if (uploadedFiles.has(token)) return uploadedFiles.get(token);
  const file = selectedFiles.get(token);
  if (!file) throw new Error("unknown file token");
  if (pendingUploads.has(token)) return pendingUploads.get(token);
  const upload = fetch(path, {
    method,
    headers: { "content-type": file.type || "application/octet-stream" },
    body: file,
  }).then(async (response) => {
    if (!response.ok) throw new Error("blob upload failed");
    const result = await response.json();
    if (typeof result?.key !== "string" || result.key === "") throw new Error("blob response has no key");
    selectedFiles.delete(token);
    uploadedFiles.set(token, result.key);
    return result.key;
  }).catch(() => { throw new Error("file upload failed"); })
    .finally(() => pendingUploads.delete(token));
  pendingUploads.set(token, upload);
  return upload;
}

export function send(method, path, body, blobFields, onOk, onError) {
  Promise.resolve().then(async () => {
    const nextBody = { ...body };
    for (const field of blobFields) {
      const value = nextBody[field];
      if (typeof value !== "string") continue;
      if (selectedFiles.has(value) || uploadedFiles.has(value)) nextBody[field] = await uploadToken(value);
    }
    const response = await fetch(path, {
      method,
      headers: { "content-type": "application/json" },
      body: method === "GET" ? undefined : JSON.stringify(nextBody),
    });
    return response;
  }).then((response) => {
    if (response.ok) {
      response.json().then(onOk).catch(() => onError({ code: "invalid_response" }));
    } else {
      response.json().then(onError).catch(() => onError({ code: "request_failed" }));
    }
  }).catch((error) => onError({ code: error?.message ?? "network_error" }));
  return undefined;
}

export function upload_file(method, path, token, onOk, onError) {
  if (!selectedFiles.has(token) && !uploadedFiles.has(token)) { onError(undefined); return undefined; }
  uploadToken(token, method, path)
    .then(onOk)
    .catch(() => onError(undefined));
  return undefined;
}
