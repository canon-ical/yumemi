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
    service.queries != []
    || root_arrows(app, service) != []
    || manual_reads(app, service) != []
  })
  |> list.map(fn(service) {
    let file = one(app, service, hash.service(hashes, service.module))
    case manual_reads(app, service) {
      [] -> file
      manual -> with_manual(file, service, manual)
    }
  })
}

/// `server.reads` のうち Service の手書きの読み。
pub fn manual_reads(
  app: model.App,
  service: model.Service,
) -> List(model.ManualRead) {
  list.filter(app.server.reads, fn(read) { read.service == service.module })
}

/// 手書きの SQL の読みの口(WGy r3)。型は宣言の綴りのまま、行の写しは runtime が hook へ渡す。
fn with_manual(
  file: File,
  service: model.Service,
  manual: List(model.ManualRead),
) -> File {
  let wanted =
    list.flatten([
      [
        "framework/io.{type Context, type Promise}",
        "framework/step.{type Step}",
      ],
      list.flat_map(manual, fn(read) { read.imports }),
    ])
    |> list.unique
  let present = fn(line) {
    string.contains(file.text, "\nimport " <> line <> "\n")
  }
  let imports =
    wanted
    |> list.filter(fn(line) { !present(line) })
    |> list.map(fn(line) { "import " <> line <> "\n" })
    |> string.concat
  let port = case string.contains(file.text, "fn query(ctx: Context") {
    True -> ""
    False ->
      "\n@external(javascript, \"../operations_ffi.mjs\", \"read\")\n"
      <> "fn query(ctx: Context, name: String, input: a) -> Promise(b)\n"
  }
  let functions =
    manual
    |> list.map(fn(read) {
      let input = case read.args {
        [single] -> single.0
        many ->
          "#(" <> string.join(list.map(many, fn(arg) { arg.0 }), ", ") <> ")"
      }
      "\npub fn "
      <> read.query
      <> "(\n"
      <> string.concat(
        list.map(read.args, fn(arg) {
          "  " <> arg.0 <> " " <> arg.0 <> ": " <> arg.1 <> ",\n"
        }),
      )
      <> "  then then: fn("
      <> read.returns
      <> ") -> Step(out, err, state),\n) -> Step(out, err, state) {\n  step.read(fn(ctx) { query(ctx, \""
      <> read.query
      <> "\", "
      <> input
      <> ") }, then)\n}\n"
    })
    |> string.concat
  // 頭の行(header)の後の import の塊に宣言の import を足し、その後に FFI の口、末尾に読みの口を足す。
  let #(head, rest) = case string.split_once(file.text, "\n") {
    Ok(pair) -> pair
    Error(_) -> #(file.text, "")
  }
  let head = case string.contains(head, "manual") {
    True -> head
    False ->
      string.replace(
        head,
        " [sha256:",
        " + server.reads(" <> service.module <> ") [sha256:",
      )
  }
  let lines = string.split(string.trim_start(rest), "\n")
  let import_lines =
    list.take_while(lines, fn(line) {
      string.starts_with(line, "import ") || string.trim(line) == ""
    })
  let body =
    list.drop(lines, list.length(import_lines))
    |> string.join("\n")
  let import_block =
    list.filter(import_lines, fn(line) { string.trim(line) != "" })
    |> list.map(fn(line) { line <> "\n" })
    |> string.concat
  File(
    ..file,
    text: head
      <> "\n\n"
      <> import_block
      <> imports
      <> port
      <> "\n"
      <> body
      <> functions,
  )
}

fn one(app: model.App, service: model.Service, input_hash: String) -> File {
  let outs = list.map(service.queries, fn(query) { typing.out(app, query) })
  let picked =
    list.flat_map(service.queries, fn(query) {
      case query.select.columns {
        Some(_) ->
          list.flatten([
            list.map(typing.picked_fields(app, query), fn(pair) { pair.1 }),
            list.flat_map(typing.child_records(app, query), fn(record) {
              list.map(record.1, fn(pair) { pair.1 })
            }),
          ])
        None -> []
      }
    })
  let arrows = root_arrows(app, service)
  let arrow_outs = list.map(arrows, arrow_out(app, _))
  let params =
    list.flat_map(service.queries, fn(query) {
      typing.params(app, query.select)
    })
  // 戻りの型に現れる entity module は修飾、それ以外(Key の中身・穴の型)は非修飾。
  // 列を選んだ読みの record の欄も戻りの型に数える。
  let qualified =
    list.flatten([outs, picked, arrow_outs])
    |> list.flat_map(typing.entity_modules)
    |> list.unique
  let style = Style(qualified: qualified, aliases: [])
  let all_types =
    list.flatten([
      outs,
      picked,
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
      list.map(service.queries, fn(query) {
        picked_record(app, style, query) <> function(app, style, query)
      }),
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

/// 列を選んだ読み(`q.Pick`)の 1 行の record。欄の名と並びは SQL の SELECT 句と同じ
/// (`AS <欄の名>`)── 実行側は行の JSON の欄をこの名でそのまま record の欄へ写す。
/// with の子の列を選んだときは、子の 1 行の record も続けて置く(欄の名は
/// `jsonb_build_object` の key と同じ)。
fn picked_record(
  app: model.App,
  style: Style,
  query: model.NamedQuery,
) -> String {
  case query.select.columns {
    None -> ""
    Some(_) ->
      string.concat([
        record(
          style,
          "/// 列を選んだ読み " <> query.name <> " の 1 行。欄の名は SQL の `AS` と同じ。\n",
          typing.picked_name(query.name),
          typing.picked_fields(app, query),
        ),
        string.concat(
          list.map(typing.child_records(app, query), fn(child) {
            record(
              style,
              "/// 列を選んだ読み "
                <> query.name
                <> " の with の子の 1 行。欄の名は SQL の `jsonb_build_object` の key と同じ。\n",
              child.0,
              child.1,
            )
          }),
        ),
      ])
  }
}

fn record(
  style: Style,
  doc: String,
  name: String,
  fields: List(#(String, typing.Ty)),
) -> String {
  string.concat([
    doc,
    "pub type ",
    name,
    " {\n  ",
    name,
    "(\n",
    string.concat(
      list.map(fields, fn(pair) {
        "    " <> pair.0 <> ": " <> render.ty(style, pair.1) <> ",\n"
      }),
    ),
    "  )\n}\n\n",
  ])
}

fn function(app: model.App, style: Style, query: model.NamedQuery) -> String {
  let params = typing.params(app, query.select)
  let out = typing.out(app, query)
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
  typing.out(app, query)
}
