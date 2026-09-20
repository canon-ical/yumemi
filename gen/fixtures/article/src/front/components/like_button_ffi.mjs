export function fetchLike() {
  return fetch("/api/article/like", { method: "POST" })
    .then((response) => response.json())
    .then((body) => body.count);
}
