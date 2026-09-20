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

fn put_update_props(entity: model.Entity) -> List(model.Prop) {
  let constrained =
    entity.verbs
    |> list.flat_map(fn(rule) {
      case rule {
        model.UpdateRule(_, fields, model.Only(_)) -> fields
        _ -> []
      }
    })
  entity.props
  |> list.filter(fn(prop) {
    case model.field_for_prop(entity, prop.name) {
      None -> False
      Some(field) ->
        !list.contains(entity.key_props, prop.name)
        && !list.contains(entity.upsert_key, prop.name)
        && prop.name != "version"
        && !list.contains(constrained, prop.name)
        && case field.value {
          model.PhaseValue(_) -> False
          _ -> True
        }
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
  let body = case string.starts_with(function.name, "reorder_") {
    True ->
      string.concat([
        "  verb.compound(\n",
        "    fn(ctx) { stage(ctx, \"",
        function.name,
        "_stage\", ",
        function.input,
        ") },\n",
        "    fn(ctx, _) { stage(ctx, \"",
        function.name,
        "\", ",
        function.input,
        ") },\n",
        "  )\n",
      ])
    False ->
      string.concat([
        "  verb.staged(fn(ctx) { stage(ctx, \"",
        function.name,
        "\", ",
        function.input,
        ") })\n",
      ])
  }
  string.concat([
    "pub fn ",
    function.name,
    "(\n",
    arguments,
    ") -> ",
    render.ty(style, function.result),
    " {\n",
    body,
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
        "reorder_" <> entity.collection <> "_stage",
        reorder_stage_sql(entity, app, ordered),
      ),
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
  let fields = create_fields(entity)
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
  let fields = create_fields(entity)
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

/// 並べ替えの本番。stage で一時値へ退避済みの行に、要求の順で確定値を入れる。
/// 確定値は宣言の値域の下端から詰める(`Int` は 0 から、`Range(min:, max:)` は min から)。
fn reorder_sql(
  entity: model.Entity,
  app: model.App,
  ordered: model.OrderedBy,
) -> String {
  let within_column = prop_column(entity, ordered.within)
  let order_column = prop_column(entity, ordered.field)
  let key_column = first_key_column(entity)
  let #(first, _lo, _hi) = order_span(entity, app, ordered)
  "WITH positions AS (\n"
  <> " SELECT value"
  <> key_cast(app, entity)
  <> " AS id,("
  <> int.to_string(first)
  <> "+ord-1)::integer AS new_order,ord"
  <> "\n"
  <> " FROM jsonb_array_elements_text($2::jsonb) WITH ORDINALITY AS items(value,ord)\n"
  <> "), target AS MATERIALIZED (\n"
  <> " SELECT e."
  <> quoted(key_column)
  <> " AS id,p.new_order,p.ord FROM "
  <> table(entity)
  <> " e JOIN positions p ON e."
  <> quoted(key_column)
  <> "=p.id WHERE e."
  <> quoted(within_column)
  <> "=$1\n"
  <> "), changed AS (\n"
  <> " UPDATE "
  <> table(entity)
  <> " e SET "
  <> quoted(order_column)
  <> "=t.new_order\n"
  <> " FROM target t WHERE e."
  <> quoted(key_column)
  <> "=t.id AND e."
  <> quoted(within_column)
  <> "=$1\n RETURNING "
  <> returning_with_alias(entity, "e")
  <> ",e."
  <> quoted(order_column)
  <> "\n)\nSELECT "
  <> returning_with_alias(entity, "changed")
  <> "\nFROM changed ORDER BY changed."
  <> quoted(order_column)
  <> ",changed."
  <> quoted(key_column)
  <> ";\n"
}

/// 並べ替えの退避。要求の行を、**宣言の値域の中で今その範囲に無い値**へ一時退避する。
///
/// 一意制約(within, order)が deferrable でないとき、確定値を直接入れると行ごとの検査で
/// 衝突する。負の一時値は制限なし `Int` の実値と衝突し、非負 CHECK でも落ちる(柏木 P0-3)。
/// ここでは値域の上端から下へ、範囲(scope)の現在値と確定値の帯 [first, first+N) を避けて
/// N 個の空き値を選ぶ。窓は held + 2N + 1 個で、鳩の巣で必ず N 個以上の空きがある
/// (値域が窓より狭いときだけ足りず、そのときは退避せず確定へ進む ── 一意制約が無ければ通り、
/// あれば 23505 で rollback)。範囲の行は FOR UPDATE で押さえ、同一 scope の同時実行は直列になる。
/// 要求の id が範囲に無ければ 'conflict'。
fn reorder_stage_sql(
  entity: model.Entity,
  app: model.App,
  ordered: model.OrderedBy,
) -> String {
  let within_column = prop_column(entity, ordered.within)
  let order_column = prop_column(entity, ordered.field)
  let key_column = first_key_column(entity)
  let #(first, lo, hi) = order_span(entity, app, ordered)
  let first_text = int.to_string(first) <> "::bigint"
  let lo_text = int.to_string(lo) <> "::bigint"
  let hi_text = int.to_string(hi) <> "::bigint"
  "WITH positions AS (\n"
  <> " SELECT value"
  <> key_cast(app, entity)
  <> " AS id,ord\n"
  <> " FROM jsonb_array_elements_text($2::jsonb) WITH ORDINALITY AS items(value,ord)\n"
  <> "), scope AS MATERIALIZED (\n"
  <> " SELECT e."
  <> quoted(key_column)
  <> " AS id,e."
  <> quoted(order_column)
  <> " AS current FROM "
  <> table(entity)
  <> " e WHERE e."
  <> quoted(within_column)
  <> "=$1 FOR UPDATE\n"
  <> "), target AS MATERIALIZED (\n"
  <> " SELECT s.id,p.ord FROM scope s JOIN positions p ON s.id=p.id\n"
  <> "), counts AS MATERIALIZED (\n"
  <> " SELECT (SELECT count(*) FROM positions) AS expected,"
  <> "(SELECT count(*) FROM target) AS matched,"
  <> "(SELECT count(*) FROM scope) AS held\n"
  <> "), free AS MATERIALIZED (\n"
  <> " SELECT candidate::integer AS candidate,row_number() OVER (ORDER BY candidate DESC) AS slot\n"
  <> " FROM counts c,generate_series("
  <> hi_text
  <> ",GREATEST("
  <> lo_text
  <> ","
  <> hi_text
  <> "-(c.held+2*c.expected)),-1) AS candidate\n"
  <> " WHERE NOT EXISTS (SELECT 1 FROM scope s WHERE s.current=candidate)\n"
  <> "  AND candidate NOT BETWEEN "
  <> first_text
  <> " AND "
  <> first_text
  <> "+c.expected-1\n"
  <> " ORDER BY candidate DESC LIMIT (SELECT expected FROM counts)\n"
  <> "), staged AS (\n"
  <> " UPDATE "
  <> table(entity)
  <> " e SET "
  <> quoted(order_column)
  <> "=f.candidate\n"
  <> " FROM target t JOIN free f ON f.slot=t.ord\n"
  <> " WHERE e."
  <> quoted(key_column)
  <> "=t.id AND e."
  <> quoted(within_column)
  <> "=$1 AND (SELECT count(*) FROM free)=(SELECT expected FROM counts)\n"
  <> " RETURNING e."
  <> quoted(key_column)
  <> "\n)\nSELECT framework.require_rows("
  <> "CASE WHEN c.expected=c.matched THEN GREATEST(c.expected,1) ELSE 0 END,"
  <> "'conflict') AS ok,(SELECT count(*) FROM staged) AS staged,(SELECT count(*) FROM free) AS room FROM counts c;\n"
}

/// 順序列の(確定の起点, 値域の下端, 値域の上端)。reader が整数の列だけを通しているので、
/// ここで None になる宣言は無い ── 万一の場合は int4 の全域。
fn order_span(
  entity: model.Entity,
  app: model.App,
  ordered: model.OrderedBy,
) -> #(Int, Int, Int) {
  let bounds = case model.prop_by_name(entity, ordered.field) {
    Some(prop) -> model.order_bounds(prop, app.value_types)
    None -> None
  }
  case bounds {
    Some(#(lo, hi)) -> #(int.max(lo, 0), lo, hi)
    None -> #(0, -2_147_483_648, 2_147_483_647)
  }
}

fn key_cast(app: model.App, entity: model.Entity) -> String {
  let key_kind = case
    list.find(entity.fields, fn(field) {
      field.column == first_key_column(entity)
    })
  {
    Ok(field) -> sql_type(app, field.value)
    Error(_) -> "text"
  }
  case key_kind {
    "uuid" -> "::uuid"
    "integer" -> "::integer"
    _ -> ""
  }
}

fn put_sql(entity: model.Entity) -> String {
  let props = put_props(entity)
  let update_props = put_update_props(entity)
  let ordered =
    list.append(
      entity.upsert_key,
      props
        |> list.map(fn(prop) { prop.name })
        |> list.filter(fn(name) { !list.contains(entity.upsert_key, name) }),
    )
  let columns =
    list.map(ordered, fn(prop) { quoted(prop_column(entity, prop)) })
  let updates =
    list.map(update_props, fn(prop) {
      quoted(prop_column(entity, prop.name))
      <> "=EXCLUDED."
      <> quoted(prop_column(entity, prop.name))
    })
  let ordered_version = version_place(ordered)
  let updates = case has_version(entity), ordered_version {
    True, Some(_) ->
      list.append(updates, [
        "version=target.version+1",
      ])
    _, _ -> updates
  }
  let conflict = case updates {
    [] -> ") DO NOTHING\n"
    _ ->
      ") DO UPDATE SET "
      <> string.join(updates, ",")
      <> case ordered_version {
        Some(place) -> "\nWHERE " <> "target.version=$" <> int.to_string(place)
        None -> ""
      }
      <> "\n"
  }
  let body =
    "INSERT INTO "
    <> table(entity)
    <> " AS target("
    <> string.join(columns, ",")
    <> ")\nVALUES("
    <> string.join(placeholders(1, list.length(columns)), ",")
    <> ")\nON CONFLICT ("
    <> string.join(
      list.map(entity.upsert_key, fn(prop) { quoted(prop_column(entity, prop)) }),
      ",",
    )
    <> conflict
    <> "RETURNING "
    <> returning(entity)
    <> "\n"
  case ordered_version {
    Some(_) ->
      "WITH changed AS (\n"
      <> body
      <> ")\nSELECT framework.require_rows(count(*),'conflict') FROM changed;\n"
    None -> body <> ";"
  }
}

fn create_fields(entity: model.Entity) -> List(model.FieldDef) {
  persisted_fields(entity)
  |> list.filter(fn(field) {
    !list.contains(entity.auto_key, prop_for_field(entity, field.name))
  })
}

fn prop_for_field(entity: model.Entity, field_name: String) -> String {
  case
    list.find(entity.props, fn(prop) {
      case model.field_for_prop(entity, prop.name) {
        Some(field) -> field.name == field_name
        None -> False
      }
    })
  {
    Ok(prop) -> prop.name
    Error(_) -> field_name
  }
}

fn version_place(names: List(String)) -> Option(Int) {
  place_of(names, "version", 1)
}

fn place_of(names: List(String), wanted: String, place: Int) -> Option(Int) {
  case names {
    [] -> None
    [head, ..tail] ->
      case head == wanted {
        True -> Some(place)
        False -> place_of(tail, wanted, place + 1)
      }
  }
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
