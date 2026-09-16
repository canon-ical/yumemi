//// 束3 ── `src/gen/reads/<service>.gleam`。名前付きクエリ値 1つにつき型付きの関数1本。
//// root 相対の矢印の read は出さない ── root Entity の決め方が ★ に無い(40 の穴 2)。

import gleam/list
import gleam/string
import yumemi_gen/emit/render.{type Style, Style}
import yumemi_gen/emit/types.{type File, File}
import yumemi_gen/emit/typing.{type Ty}
import yumemi_gen/model.{type App, type NamedQuery, type Service}

pub fn emit(app: App) -> List(File) {
  app.services
  |> list.filter(fn(service) { service.queries != [] })
  |> list.map(one(app, _))
}

fn one(app: App, service: Service) -> File {
  let outs =
    list.map(service.queries, fn(query) { typing.out(app, query.select) })
  let params =
    list.flat_map(service.queries, fn(query) {
      typing.params(app, query.select)
    })
  // 戻りの型に現れる entity module は修飾、それ以外(Key の中身・穴の型)は非修飾。
  let qualified =
    outs
    |> list.flat_map(typing.entity_modules)
    |> list.unique
  let style = Style(qualified: qualified)
  let all_types = list.append(outs, list.map(params, fn(param) { param.ty }))
  let imports =
    render.imports(style, all_types, [
      #("framework/io", ["Context", "Promise"]),
      #("framework/step", ["Step"]),
    ])
  let body =
    service.queries
    |> list.map(function(app, style, _))
    |> string.join("\n")
  File(
    path: "src/gen/reads/" <> service.module <> ".gleam",
    text: string.concat([
      header(service),
      "\n",
      imports,
      "\n\n",
      "@external(javascript, \"../operations_ffi.mjs\", \"read\")\n",
      "fn query(ctx: Context, name: String, input: a) -> Promise(b)\n",
      "\n",
      body,
    ]),
  )
}

fn header(service: Service) -> String {
  case service.queries {
    [single] ->
      "//// GENERATED from service."
      <> service.module
      <> "."
      <> single.name
      <> " — 手で編集しない\n"
    _ -> "//// GENERATED from service." <> service.module <> " — 手で編集しない\n"
  }
}

fn function(app: App, style: Style, query: NamedQuery) -> String {
  let params = typing.params(app, query.select)
  let out = typing.out(app, query.select)
  let arguments =
    list.map(params, fn(param) {
      "  "
      <> param.label
      <> " "
      <> param.label
      <> ": "
      <> render.ty(style, param.ty)
      <> ",\n"
    })
  let input = case list.map(params, fn(param) { param.label }) {
    [] -> "Nil"
    [single] -> single
    many -> "#(" <> string.join(many, ", ") <> ")"
  }
  string.concat([
    "pub fn ",
    query.name,
    "(\n",
    string.concat(arguments),
    "  then then: fn(",
    render.ty(style, out),
    ") -> Step(out, err, state),\n",
    ") -> Step(out, err, state) {\n",
    "  step.read(fn(ctx) { query(ctx, \"",
    query.name,
    "\", ",
    input,
    ") }, then)\n",
    "}\n",
  ])
}

/// 戻りの型の木(検算用に外へ出す)。
pub fn out_type(app: App, query: NamedQuery) -> Ty {
  typing.out(app, query.select)
}
