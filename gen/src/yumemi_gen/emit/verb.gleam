//// 束5 ── Entity の verb 宣言から src/gen/verb.gleam と verb SQL を出す。
//// Service の apply 呼び出しは読まない。SQL に Service 名も出さない。

import framework/schema
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import yumemi_gen/emit/hash
import yumemi_gen/emit/render.{type Style, Style}
import yumemi_gen/emit/types.{type File, File}
import yumemi_gen/emit/typing
import yumemi_gen/model
import yumemi_gen/naming

type Param {
  Param(label: String, ty: typing.Ty)
}

type Fn {
  Fn(name: String, params: List(Param), result: typing.Ty, input: String)
}

pub fn emit(app: model.App, hashes: hash.Hashes) -> List(File) {
  let entities = entities_in_order(app)
  let functions = list.flat_map(entities, functions_for(_, app))
  let draft_paths =
    entities
    |> list.map(fn(entity) { "gen/draft/" <> entity.module })
  let entity_paths =
    entities
    |> list.map(fn(entity) { "entity/" <> entity.module })
  let aliases =
    list.append(
      list.map(entities, fn(entity) {
        #("gen/draft/" <> entity.module, "draft_" <> entity.module)
      }),
      list.map(entities, fn(entity) {
        #("entity/" <> entity.module, "entity_" <> entity.module)
      }),
    )
  let style =
    Style(qualified: list.append(draft_paths, entity_paths), aliases: aliases)
  let all_types =
    list.flat_map(functions, fn(function) {
      list.append(list.map(function.params, fn(param) { param.ty }), [
        function.result,
      ])
    })
  let imports =
    render.imports(style, all_types, [
      #("framework/io", ["Context", "Promise"]),
    ])
  let body =
    functions
    |> list.map(render_function(_, style))
    |> string.join("\n")
  [
    File(
      path: "src/gen/verb.gleam",
      text: string.concat([
        "//// GENERATED from entity declarations [sha256:",
        hashes.entities,
        "] — 手で編集しない\n\n",
        imports,
        "\n\n",
        "@external(javascript, \"../operations_ffi.mjs\", \"stage\")\n",
        "fn stage(ctx: Context, name: String, input: a) -> Promise(b)\n\n",
        body,
      ]),
    ),
  ]
}

pub fn sql(app: model.App, hashes: hash.Hashes) -> List(File) {
  app.entities
  |> list.sort(fn(left, right) { string.compare(left.module, right.module) })
  |> list.flat_map(sql_files(_, app, hashes))
}

fn entities_in_order(app: model.App) -> List(model.Entity) {
  app.entities
  |> list.sort(fn(left, right) { string.compare(left.module, right.module) })
}

// ── 関数 ─────────────────────────────────────────────────────────────────────

fn functions_for(entity: model.Entity, app: model.App) -> List(Fn) {
  let key = key_params(entity, app)
  let version = version_param(entity)
  let generic_updates = case model.has_key(entity) {
    False -> []
    True ->
      writable_props(entity)
      |> list.map(fn(prop) {
        let params =
          list.append(list.append(key, version), [
            Param(label: prop.name, ty: prop_type(entity, app, prop.name)),
          ])
        Fn(
          name: "update_" <> entity.module <> "_" <> prop.name,
          params: params,
          result: verb(typing.TyRef(None, "Nil")),
          input: input_of(params),
        )
      })
  }
  let named_updates = case model.has_key(entity) {
    False -> []
    True ->
      entity.verbs
      |> list.filter_map(fn(rule) {
        case rule {
          model.UpdateRule(name, fields, ignored) -> {
            let _ = ignored
            let params =
              list.append(
                list.append(key, version),
                list.map(fields, fn(field) {
                  Param(label: field, ty: prop_type(entity, app, field))
                }),
              )
            Ok(Fn(
              name: name <> "_" <> entity.module,
              params: params,
              result: verb(typing.TyRef(None, "Nil")),
              input: input_of(params),
            ))
          }
          _ -> Error(Nil)
        }
      })
  }
  let advance = case model.has_key(entity), model.has_transitions(entity) {
    True, True -> [
      Fn(
        name: "advance_" <> entity.module,
        params: list.append(list.append(key, version), [
          Param(
            label: "step",
            ty: typing.TyRef(Some("gen/phase"), entity.name <> "Step"),
          ),
        ]),
        result: verb(typing.TyRef(None, "Nil")),
        input: input_of(
          list.append(list.append(key, version), [
            Param(label: "step", ty: typing.TyRef(None, entity.name <> "Step")),
          ]),
        ),
      ),
    ]
    _, _ -> []
  }
  let delete = case model.has_key(entity) {
    False -> []
    True -> [
      Fn(
        name: "delete_" <> entity.module,
        params: key,
        result: verb(typing.TyRef(None, "Nil")),
        input: input_of(key),
      ),
    ]
  }
  let extra = [
    create(entity),
    ..list.filter_map(entity.verbs, fn(rule) {
      case rule {
        model.DeleteWhereRule(field) ->
          case model.has_key(entity) {
            True -> Ok(delete_where(entity, app, field))
            False -> Error(Nil)
          }
        model.CreateManyRule -> Ok(create_many(entity))
        _ -> Error(Nil)
      }
    })
  ]
  let reorder = case model.has_key(entity), entity.ordered_by {
    True, Some(ordered) -> [reorder(entity, app, ordered)]
    _, _ -> []
  }
  let put = case model.has_key(entity), entity.upsert_key {
    True, [_first, ..] -> [put(entity, app)]
    _, _ -> []
  }
  list.append(
    list.append(list.append(extra, generic_updates), named_updates),
    list.append(list.append(advance, delete), list.append(reorder, put)),
  )
}

fn create(entity: model.Entity) -> Fn {
  let draft =
    typing.TyRef(Some("gen/draft/" <> entity.module), entity.name <> "Draft")
  let created =
    typing.TyRef(Some("gen/draft/" <> entity.module), entity.name <> "Created")
  Fn(
    name: "create_" <> entity.module,
    params: [Param(label: "input", ty: draft)],
    result: verb(created),
    input: "input",
  )
}

fn create_many(entity: model.Entity) -> Fn {
  let draft =
    typing.TyRef(Some("gen/draft/" <> entity.module), entity.name <> "Draft")
  let created =
    typing.TyRef(Some("gen/draft/" <> entity.module), entity.name <> "Created")
  Fn(
    name: "create_" <> entity.collection,
    params: [Param(label: "input", ty: typing.list_of(draft))],
    result: verb(typing.list_of(created)),
    input: "input",
  )
}

fn delete_where(entity: model.Entity, app: model.App, field: String) -> Fn {
  let param = Param(label: field, ty: prop_type(entity, app, field))
  Fn(
    name: "delete_" <> entity.module <> "_by_" <> field,
    params: [param],
    result: verb(typing.TyRef(None, "Nil")),
    input: field,
  )
}

fn reorder(
  entity: model.Entity,
  app: model.App,
  ordered: model.OrderedBy,
) -> Fn {
  let within_type = case model.field_for_prop(entity, ordered.within) {
    Some(model.FieldDef(
      value: model.RelValue(
        target_module: target_module,
        target_type: target_type,
      ),
      ..,
    )) ->
      typing.key_of(typing.TyRef(Some("entity/" <> target_module), target_type))
    _ -> prop_type(entity, app, ordered.within)
  }
  let key_type = key_type(entity, app)
  let params = [
    Param(label: ordered.within, ty: within_type),
    Param(label: "ids", ty: typing.list_of(key_type)),
  ]
  Fn(
    name: "reorder_" <> entity.collection,
    params: params,
    result: verb(typing.TyRef(None, "Nil")),
    input: input_of(params),
  )
}

fn put(entity: model.Entity, app: model.App) -> Fn {
  let props = put_props(entity)
  let ordered =
    list.append(
      entity.upsert_key,
      props
        |> list.map(fn(prop) { prop.name })
        |> list.filter(fn(name) { !list.contains(entity.upsert_key, name) }),
    )
  let params =
    list.map(ordered, fn(name) {
      Param(label: name, ty: prop_type(entity, app, name))
    })
  Fn(
    name: "put_" <> entity.module,
    params: params,
    result: verb(typing.TyRef(None, "Nil")),
    input: input_of(params),
  )
}

fn verb(inner: typing.Ty) -> typing.Ty {
  typing.TyApp(typing.TyRef(Some("framework/verb"), "Verb"), [inner])
}

fn key_params(entity: model.Entity, app: model.App) -> List(Param) {
  entity.key_props
  |> list.filter_map(fn(prop) {
    case model.field_for_prop(entity, prop) {
      Some(field) ->
        Ok(Param(label: prop, ty: typing.field_base(app, field.name)))
      None -> Error(Nil)
    }
  })
}

fn key_type(entity: model.Entity, app: model.App) -> typing.Ty {
  let types =
    key_params(entity, app)
    |> list.map(fn(param) { param.ty })
  case types {
    [single] -> single
    many -> typing.TyTuple(many)
  }
}

fn version_param(entity: model.Entity) -> List(Param) {
  case has_version(entity) {
    True -> [Param(label: "version", ty: typing.int_ty)]
    False -> []
  }
}

fn has_version(entity: model.Entity) -> Bool {
  !list.contains(entity.key_props, "version")
  && case model.prop_by_name(entity, "version") {
    Some(model.Prop(
      optional: False,
      repeated: False,
      kind: model.ValueProp(model.TypeRef(
        module: None,
        name: "Int",
        parameters: [],
      )),
      ..,
    )) -> True
    _ -> False
  }
}

fn writable_props(entity: model.Entity) -> List(model.Prop) {
  let constrained =
    entity.verbs
    |> list.flat_map(fn(rule) {
      case rule {
        model.UpdateRule(ignored_name, fields, ignored_at) -> {
          let _ = ignored_name
          let _ = ignored_at
          fields
        }
        _ -> []
      }
    })
  entity.props
  |> list.filter(fn(prop) {
    case prop.kind {
      model.ValueProp(_) ->
        prop.name != "version"
        && !list.contains(entity.key_props, prop.name)
        && !list.contains(constrained, prop.name)
      _ -> False
    }
  })
}

fn put_props(entity: model.Entity) -> List(model.Prop) {
  entity.props
  |> list.filter(fn(prop) {
    case model.field_for_prop(entity, prop.name) {
      Some(_) -> True
      None -> False
    }
  })
}

fn prop_type(entity: model.Entity, app: model.App, name: String) -> typing.Ty {
  case model.field_for_prop(entity, name) {
    Some(field) -> typing.field_base(app, field.name)
    None ->
      case model.prop_by_name(entity, name) {
        Some(model.Prop(kind: model.ValueProp(reference), ..)) ->
          typing.type_ref(reference)
        Some(model.Prop(kind: model.SumProp(reference, ..), ..)) ->
          typing.type_ref(reference)
        _ -> typing.TyRef(None, "String")
      }
  }
}

fn input_of(params: List(Param)) -> String {
  case list.map(params, fn(param) { param.label }) {
    [] -> "Nil"
    [single] -> single
    many -> "#(" <> string.join(many, ", ") <> ")"
  }
}

fn render_function(function: Fn, style: Style) -> String {
  let arguments =
    function.params
    |> list.map(fn(param) {
      "  " <> param.label <> ": " <> render.ty(style, param.ty) <> ",\n"
    })
    |> string.concat
  string.concat([
    "pub fn ",
    function.name,
    "(\n",
    arguments,
    ") -> ",
    render.ty(style, function.result),
    " {\n",
    "  verb.staged(fn(ctx) { stage(ctx, \"",
    function.name,
    "\", ",
    function.input,
    ") })\n",
    "}\n",
  ])
}

// ── SQL ──────────────────────────────────────────────────────────────────────

fn sql_files(
  entity: model.Entity,
  app: model.App,
  hashes: hash.Hashes,
) -> List(File) {
  let generic_updates = case model.has_key(entity) {
    False -> []
    True ->
      writable_props(entity)
      |> list.map(fn(prop) {
        sql_file(
          entity,
          hashes,
          "update_" <> entity.module <> "_" <> prop.name,
          update_sql(entity, app, [prop.name], model.AnyPhase),
        )
      })
  }
  let named_updates = case model.has_key(entity) {
    False -> []
    True ->
      entity.verbs
      |> list.filter_map(fn(rule) {
        case rule {
          model.UpdateRule(name, fields, at) ->
            Ok(sql_file(
              entity,
              hashes,
              name <> "_" <> entity.module,
              update_sql(entity, app, fields, at),
            ))
          _ -> Error(Nil)
        }
      })
  }
  let advance = case model.has_key(entity), model.has_transitions(entity) {
    True, True -> [
      sql_file(
        entity,
        hashes,
        "advance_" <> entity.module,
        advance_sql(entity, model.advance_bump(entity)),
      ),
    ]
    _, _ -> []
  }
  let delete = case model.has_key(entity) {
    False -> []
    True -> [
      sql_file(entity, hashes, "delete_" <> entity.module, delete_sql(entity)),
    ]
  }
  let extras =
    list.filter_map(entity.verbs, fn(rule) {
      case rule {
        model.DeleteWhereRule(field) ->
          case model.has_key(entity) {
            True ->
              Ok(sql_file(
                entity,
                hashes,
                "delete_" <> entity.module <> "_by_" <> field,
                delete_where_sql(entity, field),
              ))
            False -> Error(Nil)
          }
        model.CreateManyRule ->
          Ok(sql_file(
            entity,
            hashes,
            "create_" <> entity.collection,
            create_many_sql(entity, app),
          ))
        _ -> Error(Nil)
      }
    })
  let reorder = case model.has_key(entity), entity.ordered_by {
    True, Some(ordered) -> [
      sql_file(
        entity,
        hashes,
        "reorder_" <> entity.collection,
        reorder_sql(entity, app, ordered),
      ),
    ]
    _, _ -> []
  }
  let put = case model.has_key(entity), entity.upsert_key {
    True, [_first, ..] -> [
      sql_file(entity, hashes, "put_" <> entity.module, put_sql(entity)),
    ]
    _, _ -> []
  }
  list.append(
    [
      sql_file(entity, hashes, "create_" <> entity.module, create_sql(entity)),
    ],
    list.append(
      list.append(generic_updates, named_updates),
      list.append(
        list.append(advance, delete),
        list.append(list.append(extras, reorder), put),
      ),
    ),
  )
}

fn sql_file(
  entity: model.Entity,
  hashes: hash.Hashes,
  name: String,
  body: String,
) -> File {
  File(
    path: "gen/sql/queries/verb/" <> name <> ".sql",
    text: "-- GENERATED from entity."
      <> entity.module
      <> " [sha256:"
      <> hash.entity(hashes, entity.module)
      <> "] — 手で編集しない\n"
      <> body,
  )
}

fn create_sql(entity: model.Entity) -> String {
  let fields = persisted_fields(entity)
  case fields {
    [] ->
      "INSERT INTO "
      <> table(entity)
      <> " DEFAULT VALUES RETURNING "
      <> returning(entity)
      <> ";\n"
    _ ->
      "INSERT INTO "
      <> table(entity)
      <> "("
      <> string.join(list.map(fields, fn(field) { quoted(field.column) }), ",")
      <> ")\nVALUES("
      <> string.join(placeholders(1, list.length(fields)), ",")
      <> ") RETURNING "
      <> returning(entity)
      <> ";\n"
  }
}

fn create_many_sql(entity: model.Entity, app: model.App) -> String {
  let fields = persisted_fields(entity)
  case fields {
    [] -> create_sql(entity)
    _ -> {
      let selected =
        fields
        |> list.map(fn(field) {
          "(item->>'"
          <> field.column
          <> "')"
          <> cast_for_json(sql_type(app, field.value))
        })
        |> string.join(",")
      "INSERT INTO "
      <> table(entity)
      <> "("
      <> string.join(list.map(fields, fn(field) { quoted(field.column) }), ",")
      <> ")\nSELECT "
      <> selected
      <> "\nFROM jsonb_array_elements($1::jsonb) AS item\nRETURNING "
      <> returning(entity)
      <> ";\n"
    }
  }
}

fn update_sql(
  entity: model.Entity,
  app: model.App,
  props: List(String),
  gate: model.VerbGate,
) -> String {
  let version_offset = case has_version(entity) {
    True -> 1
    False -> 0
  }
  let first_value = list.length(entity.key_columns) + version_offset + 1
  let assignments =
    props
    |> list.index_map(fn(prop, index) {
      quoted(prop_column(entity, prop))
      <> "=$"
      <> int.to_string(first_value + index)
    })
  let assignments = case has_version(entity) {
    True -> list.append(assignments, ["version=version+1"])
    False -> assignments
  }
  let where =
    list.append(
      key_conditions(entity, 1, None),
      version_condition(entity, list.length(entity.key_columns) + 1),
    )
  let where = list.append(where, gate_condition(gate))
  let _ = app
  "WITH changed AS (UPDATE "
  <> table(entity)
  <> " SET "
  <> string.join(assignments, ",")
  <> "\nWHERE "
  <> string.join(where, " AND ")
  <> " RETURNING "
  <> returning(entity)
  <> ")\nSELECT framework.require_rows(count(*),'conflict') FROM changed;\n"
}

fn advance_sql(entity: model.Entity, bump: model.VerbBump) -> String {
  let key_count = list.length(entity.key_columns)
  let version_place = key_count + 1
  let version_offset = case has_version(entity) {
    True -> 1
    False -> 0
  }
  let from_place = version_place + version_offset
  let to_place = from_place + 1
  let at_place = to_place + 1
  let assignments = ["phase=$" <> int.to_string(to_place)]
  let assignments = case has_version(entity) {
    True ->
      list.append(assignments, [
        "version=version+" <> bump_sql(bump, from_place, to_place),
      ])
    False -> assignments
  }
  let assignments =
    list.append(
      assignments,
      list.map(entity.phases, fn(phase) {
        let column = "entered_" <> naming.snake(phase)
        quoted(column)
        <> "=CASE WHEN $"
        <> int.to_string(to_place)
        <> "='"
        <> naming.snake(phase)
        <> "' THEN $"
        <> int.to_string(at_place)
        <> "::timestamptz ELSE "
        <> quoted(column)
        <> " END"
      }),
    )
  let where =
    list.append(
      key_conditions(entity, 1, None),
      list.append(version_condition(entity, version_place), [
        "phase=$" <> int.to_string(from_place),
      ]),
    )
  "WITH changed AS (UPDATE "
  <> table(entity)
  <> " SET "
  <> string.join(assignments, ",\n")
  <> "\nWHERE "
  <> string.join(where, " AND ")
  <> " RETURNING "
  <> returning(entity)
  <> ")\nSELECT framework.require_rows(count(*),'conflict') FROM changed;\n"
}

fn bump_sql(bump: model.VerbBump, from_place: Int, to_place: Int) -> String {
  case bump {
    model.Always -> "1"
    model.BumpUnless(from: from, to: to) ->
      "CASE WHEN $"
      <> int.to_string(from_place)
      <> "='"
      <> naming.snake(from)
      <> "' AND $"
      <> int.to_string(to_place)
      <> "='"
      <> naming.snake(to)
      <> "' THEN 0 ELSE 1 END"
  }
}

fn delete_sql(entity: model.Entity) -> String {
  "DELETE FROM "
  <> table(entity)
  <> " WHERE "
  <> string.join(key_conditions(entity, 1, None), " AND ")
  <> " RETURNING "
  <> returning(entity)
  <> ";\n"
}

fn delete_where_sql(entity: model.Entity, field: String) -> String {
  "DELETE FROM "
  <> table(entity)
  <> " WHERE "
  <> quoted(prop_column(entity, field))
  <> "=$1 RETURNING "
  <> returning(entity)
  <> ";\n"
}

fn reorder_sql(
  entity: model.Entity,
  app: model.App,
  ordered: model.OrderedBy,
) -> String {
  let key_kind = case
    list.find(entity.fields, fn(field) {
      field.column == first_key_column(entity)
    })
  {
    Ok(field) -> sql_type(app, field.value)
    Error(_) -> "text"
  }
  let within_column = prop_column(entity, ordered.within)
  let order_column = prop_column(entity, ordered.field)
  let key_column = first_key_column(entity)
  let id_cast = case key_kind {
    "uuid" -> "::uuid"
    "integer" -> "::integer"
    _ -> ""
  }
  "WITH positions AS (\n"
  <> " SELECT value"
  <> id_cast
  <> " AS id,(ord-1)::integer AS "
  <> quoted("order")
  <> "\n"
  <> " FROM jsonb_array_elements_text($2::jsonb) WITH ORDINALITY AS items(value,ord)\n"
  <> "), changed AS (\n"
  <> " UPDATE "
  <> table(entity)
  <> " e SET "
  <> quoted(order_column)
  <> "=p."
  <> quoted("order")
  <> "\n FROM positions p WHERE e."
  <> quoted(key_column)
  <> "=p.id AND e."
  <> quoted(within_column)
  <> "=$1\n RETURNING "
  <> returning_with_alias(entity, "e")
  <> "\n)\nSELECT "
  <> returning(entity)
  <> "\nFROM changed ORDER BY "
  <> quoted("order")
  <> ","
  <> returning(entity)
  <> ";\n"
}

fn put_sql(entity: model.Entity) -> String {
  let props = put_props(entity)
  let ordered =
    list.append(
      entity.upsert_key,
      props
        |> list.map(fn(prop) { prop.name })
        |> list.filter(fn(name) { !list.contains(entity.upsert_key, name) }),
    )
  let columns =
    list.map(ordered, fn(prop) { quoted(prop_column(entity, prop)) })
  let rest =
    ordered
    |> list.drop(list.length(entity.upsert_key))
  let first_key = case entity.upsert_key {
    [first, ..] -> first
    [] -> ""
  }
  let updates = case rest {
    [] -> [
      quoted(prop_column(entity, first_key))
      <> "=EXCLUDED."
      <> quoted(prop_column(entity, first_key)),
    ]
    _ ->
      list.map(rest, fn(prop) {
        quoted(prop_column(entity, prop))
        <> "=EXCLUDED."
        <> quoted(prop_column(entity, prop))
      })
  }
  "INSERT INTO "
  <> table(entity)
  <> "("
  <> string.join(columns, ",")
  <> ")\nVALUES("
  <> string.join(placeholders(1, list.length(columns)), ",")
  <> ")\nON CONFLICT ("
  <> string.join(
    list.map(entity.upsert_key, fn(prop) { quoted(prop_column(entity, prop)) }),
    ",",
  )
  <> ") DO UPDATE SET "
  <> string.join(updates, ",")
  <> "\nRETURNING "
  <> returning(entity)
  <> ";\n"
}

fn version_condition(entity: model.Entity, place: Int) -> List(String) {
  case has_version(entity) {
    True -> ["version=$" <> int.to_string(place)]
    False -> []
  }
}

fn gate_condition(gate: model.VerbGate) -> List(String) {
  case gate {
    model.AnyPhase -> []
    model.Only(phases) -> [
      "phase IN ("
      <> string.join(
        list.map(phases, fn(phase) { "'" <> naming.snake(phase) <> "'" }),
        ",",
      )
      <> ")",
    ]
  }
}

fn key_conditions(
  entity: model.Entity,
  first_place: Int,
  alias: Option(String),
) -> List(String) {
  entity.key_columns
  |> list.index_map(fn(column, index) {
    let prefix = case alias {
      Some(value) -> value <> "."
      None -> ""
    }
    prefix <> quoted(column) <> "=$" <> int.to_string(first_place + index)
  })
}

fn persisted_fields(entity: model.Entity) -> List(model.FieldDef) {
  entity.props
  |> list.filter_map(fn(prop) {
    model.field_for_prop(entity, prop.name)
    |> option.to_result(Nil)
  })
}

fn prop_column(entity: model.Entity, prop: String) -> String {
  case model.field_for_prop(entity, prop) {
    Some(field) -> field.column
    None -> prop
  }
}

fn first_key_column(entity: model.Entity) -> String {
  case entity.key_columns {
    [first, ..] -> first
    [] -> entity.key_column
  }
}

fn table(entity: model.Entity) -> String {
  schema.app <> "." <> entity.table
}

fn returning(entity: model.Entity) -> String {
  case returned_columns(entity) {
    [] -> "*"
    columns -> string.join(list.map(columns, quoted), ",")
  }
}

fn returning_with_alias(entity: model.Entity, alias: String) -> String {
  case returned_columns(entity) {
    [] -> alias <> ".*"
    columns ->
      columns
      |> list.map(fn(column) { alias <> "." <> quoted(column) })
      |> string.join(",")
  }
}

fn returned_columns(entity: model.Entity) -> List(String) {
  case entity.key_columns {
    [] -> list.map(persisted_fields(entity), fn(field) { field.column })
    columns -> columns
  }
}

fn placeholders(first: Int, count: Int) -> List(String) {
  case count {
    0 -> []
    _ -> ["$" <> int.to_string(first), ..placeholders(first + 1, count - 1)]
  }
}

fn sql_type(app: model.App, value: model.FieldValue) -> String {
  case value {
    model.PhaseValue(_) -> "text"
    model.DatetimeValue -> "timestamptz"
    model.RelValue(target_module: target_module, ..) ->
      case model.entity_by_module(app.entities, target_module) {
        Some(target) ->
          case
            list.find(target.fields, fn(field) {
              field.column == target.key_column
            })
          {
            Ok(field) -> sql_type(app, field.value)
            Error(_) -> "text"
          }
        None -> "text"
      }
    model.TypeValue(reference) ->
      case reference.module {
        Some("framework/time") ->
          case reference.name {
            "Datetime" -> "timestamptz"
            "Date" -> "date"
            "Time" -> "time"
            _ -> "text"
          }
        Some("framework/vector") -> "public.vector"
        Some(path) ->
          case string.starts_with(path, "gen/types/") {
            True ->
              case model.value_type_by_name(app.value_types, reference.name) {
                Some(value) ->
                  case value.spec {
                    "Uuid" -> "uuid"
                    "Range" -> "integer"
                    _ -> "text"
                  }
                None -> "text"
              }
            False -> "text"
          }
        None ->
          case reference.name {
            "Int" -> "integer"
            "Bool" -> "boolean"
            "Float" -> "double precision"
            _ -> "text"
          }
      }
  }
}

fn cast_for_json(kind: String) -> String {
  case kind {
    "text" -> ""
    _ -> "::" <> kind
  }
}

fn quoted(column: String) -> String {
  case
    list.contains(
      [
        "order", "user", "group", "limit", "offset", "select", "from", "where",
        "table", "column", "default", "check", "references", "primary", "key",
        "end", "all", "any", "as", "case", "cast", "constraint", "create", "do",
        "else", "for", "foreign", "grant", "having", "in", "into", "is", "join",
        "left", "like", "natural", "not", "null", "on", "only", "or", "outer",
        "right", "some", "then", "to", "true", "false", "union", "unique",
        "using", "when", "with", "desc", "asc", "distinct", "values", "window",
        "returning",
      ],
      column,
    )
  {
    True -> "\"" <> column <> "\""
    False -> column
  }
}
