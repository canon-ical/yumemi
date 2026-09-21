export function fetchLike(dispatch) {
  return fetch("/api/article/like", { method: "POST" })
    .then((response) => response.json())
    .then((body) => dispatch(body.count));
}
