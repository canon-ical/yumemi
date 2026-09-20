//// 束3 ── `src/gen/reads/<service>.gleam`。名前付きクエリ値 1つにつき型付きの関数1本。
//// root Entity がある Service には、そこから出る矢印の read も同じ module に出す。

import gleam/list
import gleam/option.{None, Some}
import gleam/string
import yumemi_gen/emit/hash
import yumemi_gen/emit/render.{type Style, Style}
import yumemi_gen/emit/root
import yumemi_gen/emit/types.{type File, File}
import yumemi_gen/emit/typing
import yumemi_gen/model
import yumemi_gen/naming

pub fn emit(app: model.App, hashes: hash.Hashes) -> List(File) {
  app.services
  |> list.filter(fn(service) {
    service.queries != [] || root_arrows(app, service) != []
  })
  |> list.map(fn(service) {
    one(app, service, hash.service(hashes, service.module))
  })
}

fn one(app: model.App, service: model.Service, input_hash: String) -> File {
  let outs =
    list.map(service.queries, fn(query) { typing.out(app, query.select) })
  let arrows = root_arrows(app, service)
  let arrow_outs = list.map(arrows, arrow_out(app, _))
  let params =
    list.flat_map(service.queries, fn(query) {
      typing.params(app, query.select)
    })
  // 戻りの型に現れる entity module は修飾、それ以外(Key の中身・穴の型)は非修飾。
  let qualified =
    list.append(outs, arrow_outs)
    |> list.flat_map(typing.entity_modules)
    |> list.unique
  let style = Style(qualified: qualified, aliases: [])
  let all_types =
    list.flatten([
      outs,
      arrow_outs,
      list.map(params, fn(param) { param.ty }),
    ])
  let extra =
    list.append(
      [
        #("framework/step", ["Step"]),
        #("gen/root/" <> service.module, ["Root"]),
      ],
      case service.queries != [], arrows != [] {
        True, _ | _, True -> [#("framework/io", ["Context", "Promise"])]
        False, False -> []
      },
    )
  // 矢印の read は関係値から鍵を取り出す(`er.of` / `er.of_held` / `er.of_multi`)。
  // Option の関係は `option.map`、Multi は `list.map` で鍵の列にする。
  let extra = case arrows {
    [] -> extra
    _ ->
      list.append(extra, [
        #("framework/er", []),
        ..list.append(
          case list.any(arrows, fn(arrow) { arrow_shape(arrow) == Optional }) {
            True -> [#("gleam/option", [])]
            False -> []
          },
          case list.any(arrows, fn(arrow) { arrow_shape(arrow) == Many }) {
            True -> [#("gleam/list", [])]
            False -> []
          },
        )
      ])
  }
  let imports = render.imports(style, all_types, extra)
  let root_module = case root.root_for(app, service) {
    Some(entity) -> entity.module
    None -> ""
  }
  let body =
    list.append(
      list.map(service.queries, function(app, style, _)),
      list.map(arrows, arrow_function(
        app,
        style,
        service.module,
        root_module,
        _,
      )),
    )
    |> string.join("\n")
  File(
    path: "src/gen/reads/" <> service.module <> ".gleam",
    text: string.concat([
      header(service, input_hash),
      "\n",
      imports,
      "\n\n",
      case service.queries {
        [] -> ""
        _ ->
          "@external(javascript, \"../operations_ffi.mjs\", \"read\")\n"
          <> "fn query(ctx: Context, name: String, input: a) -> Promise(b)\n"
      },
      "\n",
      "\n",
      body,
    ]),
  )
}

fn header(service: model.Service, input_hash: String) -> String {
  let stamp = " [sha256:" <> input_hash <> "] — 手で編集しない\n"
  case service.queries {
    [single] ->
      "//// GENERATED from service."
      <> service.module
      <> "."
      <> single.name
      <> stamp
    _ -> "//// GENERATED from service." <> service.module <> stamp
  }
}

pub fn root_arrows(
  app: model.App,
  service: model.Service,
) -> List(model.Arrow) {
  case root.root_for(app, service) {
    None -> []
    Some(entity) ->
      list.filter(app.arrows, fn(arrow) { arrow.from_entity == entity.name })
  }
}

fn arrow_out(app: model.App, arrow: model.Arrow) -> typing.Ty {
  let base = case model.entity_by_name(app.entities, arrow.target_entity) {
    Some(entity) ->
      typing.TyRef(
        module: Some("entity/" <> entity.module),
        name: entity.type_name,
      )
    None -> typing.TyRef(module: None, name: arrow.target_entity)
  }
  case arrow.kind {
    model.Multi -> typing.list_of(base)
    model.Link -> typing.option(base)
    _ ->
      case arrow.optional {
        True -> typing.option(base)
        False -> base
      }
  }
}

/// 矢印の出力の形。`arrow_out` と同じ規則で決める(Multi -> List、Link / Option -> Option)。
pub type Shape {
  One
  Optional
  Many
}

pub fn arrow_shape(arrow: model.Arrow) -> Shape {
  case arrow.kind {
    model.Multi -> Many
    model.Link -> Optional
    _ ->
      case arrow.optional {
        True -> Optional
        False -> One
      }
  }
}

/// 生成 SQL の名。`db/queries/<service>/<query>.sql`、実行側の SQL 表の鍵は `<service>/<query>`。
pub fn arrow_query(arrow: model.Arrow) -> String {
  "to_" <> naming.snake(arrow.prop)
}

/// 関係値から鍵の文字列(の列)を取り出す式。root の欄は型付きで参照する ── 名前を実行時に推測しない。
fn key_expression(root_module: String, arrow: model.Arrow) -> String {
  let value = "it." <> root_module <> "." <> arrow.prop
  let of = case arrow.kind {
    model.Has -> "er.of"
    model.Held -> "er.of_held"
    _ -> "er.of"
  }
  case arrow_shape(arrow) {
    One -> "er.to_string(" <> of <> "(" <> value <> "))"
    Optional ->
      case arrow.kind {
        // Link(e) は Option(Key(e)) そのもの。
        model.Link -> "option.map(" <> value <> ", er.to_string)"
        _ ->
          "option.map("
          <> value
          <> ", fn(held) { er.to_string("
          <> of
          <> "(held)) })"
      }
    Many -> "list.map(er.of_multi(" <> value <> "), er.to_string)"
  }
}

fn arrow_function(
  app: model.App,
  style: Style,
  service: String,
  root_module: String,
  arrow: model.Arrow,
) -> String {
  let out = arrow_out(app, arrow)
  let target_module = case
    model.entity_by_name(app.entities, arrow.target_entity)
  {
    Some(entity) -> entity.module
    None -> naming.snake(arrow.target_entity)
  }
  let read = case arrow_shape(arrow) {
    One -> "io.relation_one"
    Optional -> "io.relation_option"
    Many -> "io.relation_many"
  }
  let name = "to_" <> naming.snake(arrow.prop)
  string.concat([
    "/// 矢印 ",
    arrow.name,
    "(",
    root_module,
    ".",
    arrow.prop,
    " -> ",
    target_module,
    ")。関係先の取得と復号は Context の契約 `relation`。\n",
    "const ",
    name,
    "_relation = io.Relation(\n",
    "  service: \"",
    service,
    "\",\n",
    "  query: \"",
    arrow_query(arrow),
    "\",\n",
    "  arrow: \"",
    arrow.name,
    "\",\n",
    "  from: \"",
    root_module,
    "\",\n",
    "  prop: \"",
    arrow.prop,
    "\",\n",
    "  target: \"",
    target_module,
    "\",\n",
    ")\n\n",
    "pub fn ",
    name,
    "(\n",
    "  it: Root,\n",
    "  then: fn(",
    render.ty(style, out),
    ") -> Step(out, err, state),\n",
    ") -> Step(out, err, state) {\n",
    "  step.read(\n",
    "    fn(ctx) {\n",
    "      ",
    read,
    "(\n",
    "        ctx,\n",
    "        ",
    name,
    "_relation,\n",
    "        ",
    key_expression(root_module, arrow),
    ",\n",
    "      )\n",
    "    },\n",
    "    then,\n",
    "  )\n",
    "}\n",
  ])
}

fn function(app: model.App, style: Style, query: model.NamedQuery) -> String {
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
pub fn out_type(app: model.App, query: model.NamedQuery) -> typing.Ty {
  typing.out(app, query.select)
}
