//// Verification worker. The fixture front remains the view source; this file
//// only supplies the HTTP and SSR adapter needed by workerd.

import conversation.{type JsRequest, type JsResponse, type ResponseBody, Text}
import front/blocks/article
import front/blocks/summary
import gleam/http
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/list
import gleam/string
import lustre/attribute
import lustre/element as raw_element
import lustre/element/html as raw_html
import sketch
import sketch/lustre as sketch_lustre
import sketch/lustre/element

pub type Env

@external(javascript, "./worker_ffi.mjs", "bumpLikeCount")
fn bump_like_count() -> Int

pub fn fetch(js_req: JsRequest, _env: Env) -> Promise(JsResponse) {
  let req = conversation.to_gleam_request(js_req)
  let path = segments(req.path)
  promise.resolve(conversation.to_js_response(route(req, path)))
}

fn segments(path: String) -> List(String) {
  path
  |> string.split("/")
  |> list.filter(fn(segment) { segment != "" })
}

fn route(
  req: request.Request(conversation.RequestBody),
  path: List(String),
) -> Response(ResponseBody) {
  case req.method, path {
    http.Get, ["article", "first"] ->
      page(fn() { article.view(article.sample) })
    http.Get, ["article", "second"] ->
      page(fn() { summary.view(summary.sample) })
    http.Get, ["article", _id] -> page(fn() { article.view(article.sample) })
    http.Post, ["api", "article", "like"] -> like()
    _, _ -> text(404, "not found")
  }
}

fn page(body: fn() -> element.Element(Nil)) -> Response(ResponseBody) {
  let assert Ok(stylesheet) = sketch_lustre.setup()
  let doc = render_doc(stylesheet, body)
  let out = raw_element.to_document_string(doc)
  let assert Ok(_) = sketch_lustre.teardown(stylesheet)

  response.new(200)
  |> response.set_header("content-type", "text/html; charset=utf-8")
  |> response.set_body(Text(out))
}

fn render_doc(
  stylesheet: sketch.StyleSheet,
  body: fn() -> element.Element(Nil),
) -> raw_element.Element(Nil) {
  let styled_body =
    sketch_lustre.render(stylesheet, in: [sketch_lustre.node()], after: body)

  raw_html.html([attribute.attribute("lang", "ja")], [
    raw_html.head([], [
      raw_html.meta([attribute.attribute("charset", "utf-8")]),
      raw_html.title([], "yumemi front fixture"),
      raw_html.script(
        [
          attribute.attribute("type", "module"),
          attribute.src("/client.mjs"),
        ],
        "",
      ),
    ]),
    raw_html.body([], [styled_body]),
  ])
}

fn like() -> Response(ResponseBody) {
  let count = bump_like_count()
  response.new(200)
  |> response.set_header("content-type", "application/json")
  |> response.set_body(
    Text(json.to_string(json.object([#("count", json.int(count))]))),
  )
}

fn text(status: Int, body: String) -> Response(ResponseBody) {
  response.new(status)
  |> response.set_header("content-type", "text/plain; charset=utf-8")
  |> response.set_body(Text(body))
}
