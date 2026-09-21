export function postTag(tag, dispatch) {
  fetch("/api/article/tag", {
    method: "POST",
    headers: { "content-type": "text/plain; charset=utf-8" },
    body: tag,
  }).then((response) => {
    if (response.ok) dispatch(undefined);
  });
}
