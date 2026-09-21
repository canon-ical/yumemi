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
import yumemi_gen/stop

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
  let header = handwritten_header(app)
  [
    File(
      path: "src/gen/verb.gleam",
      text: string.concat([
        "//// GENERATED from entity declarations [sha256:",
        hashes.entities,
        "] — 手で編集しない\n",
        header,
        "\n",
        imports,
        "\n\n",
        "@external(javascript, \"../operations_ffi.mjs\", \"stage\")\n",
        "fn stage(ctx: Context, name: String, input: a) -> Promise(b)\n\n",
        body,
      ]),
    ),
  ]
}

/// 手書き札の照合。未一致は止めず、指定された名前ごとに1行の警告を返す。
pub fn notes(app: model.App) -> List(stop.Note) {
  let global_candidates =
    app.entities
    |> list.flat_map(candidate_names)
    |> list.unique
  let entity_notes =
    app.entities
    |> list.flat_map(fn(entity) {
      handwritten_notes(
        entity.module,
        entity.handwritten_verbs,
        candidate_names(entity),
      )
    })
  let external_notes =
    app.handwritten_verbs
    |> list.flat_map(fn(entry) {
      handwritten_notes(entry.0, entry.1, global_candidates)
    })
  list.append(entity_notes, external_notes)
}

fn handwritten_notes(
  module: String,
  names: List(String),
  candidates: List(String),
) -> List(stop.Note) {
  names
  |> list.unique
  |> list.filter_map(fn(name) {
    case list.contains(candidates, name) {
      True -> Error(Nil)
      False ->
        Ok(stop.Note(
          class: stop.Warning,
          text: module <> ": handwritten_verbs に生成名が無い: " <> name,
        ))
    }
  })
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

fn emits(app: model.App, entity: model.Entity, name: String) -> Bool {
  !list.contains(entity.handwritten_verbs, name)
  && !list.any(app.handwritten_verbs, fn(entry) { list.contains(entry.1, name) })
}

fn emits_reorder(app: model.App, entity: model.Entity, name: String) -> Bool {
  emits(app, entity, name)
  && !list.contains(entity.handwritten_verbs, name <> "_stage")
  && !list.any(app.handwritten_verbs, fn(entry) {
    list.contains(entry.1, name <> "_stage")
  })
}

fn handwritten_header(app: model.App) -> String {
  let names =
    list.unique(list.append(
      app.entities
        |> list.flat_map(fn(entity) { entity.handwritten_verbs }),
      app.handwritten_verbs
        |> list.flat_map(fn(entry) { entry.1 }),
    ))
  case names {
    [] -> ""
    _ -> "//// handwritten: " <> string.join(names, ", ") <> "\n"
  }
}

fn candidate_names(entity: model.Entity) -> List(String) {
  let generic_updates = case model.has_key(entity) {
    True ->
      list.map(writable_props(entity), fn(prop) {
        "update_" <> entity.module <> "_" <> prop.name
      })
    False -> []
  }
  let named_updates =
    entity.verbs
    |> list.filter_map(fn(rule) {
      case rule {
        model.UpdateRule(name, ..) -> Ok(update_name(entity, name))
        _ -> Error(Nil)
      }
    })
  let extras =
    entity.verbs
    |> list.flat_map(fn(rule) {
      case rule {
        model.DeleteWhereRule(field) ->
          case model.has_key(entity) {
            True -> ["delete_" <> entity.module <> "_by_" <> field]
            False -> []
          }
        model.CreateManyRule -> ["create_" <> entity.collection]
        _ -> []
      }
    })
  let lifecycle = case model.has_key(entity), model.has_transitions(entity) {
    True, True -> ["advance_" <> entity.module]
    _, _ -> []
  }
  let delete = case model.has_key(entity) {
    True -> ["delete_" <> entity.module]
    False -> []
  }
  let reorder = case model.has_key(entity), entity.ordered_by {
    True, Some(_) -> [
      "reorder_" <> entity.collection,
      "reorder_" <> entity.collection <> "_stage",
    ]
    _, _ -> []
  }
  let put = case model.has_key(entity), entity.upsert_key {
    True, [_first, ..] -> ["put_" <> entity.module]
    _, _ -> []
  }
  list.unique(
    list.flatten([
      ["create_" <> entity.module],
      generic_updates,
      named_updates,
      lifecycle,
      delete,
      extras,
      reorder,
      put,
    ]),
  )
}

// ── 関数 ─────────────────────────────────────────────────────────────────────

fn functions_for(entity: model.Entity, app: model.App) -> List(Fn) {
  let key = key_params(entity, app)
  let version = version_param(entity)
  let generic_updates = case model.has_key(entity) {
    False -> []
    True ->
      writable_props(entity)
      |> list.filter_map(fn(prop) {
        let name = "update_" <> entity.module <> "_" <> prop.name
        case emits(app, entity, name) {
          False -> Error(Nil)
          True -> {
            let params =
              list.append(list.append(key, version), [
                Param(label: prop.name, ty: prop_type(entity, app, prop.name)),
              ])
            Ok(Fn(
              name: name,
              params: params,
              result: verb(typing.TyRef(None, "Nil")),
              input: input_of(params),
            ))
          }
        }
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
            let name = update_name(entity, name)
            let lookup = update_lookup_props(entity, name)
            let lookup_params = key_params_for_props(entity, app, lookup)
            let version = update_version_params(entity, name)
            let params =
              list.append(
                list.append(lookup_params, version),
                list.map(fields, fn(field) {
                  Param(label: field, ty: prop_type(entity, app, field))
                }),
              )
            case emits(app, entity, name) {
              True ->
                Ok(Fn(
                  name: name,
                  params: params,
                  result: verb(typing.TyRef(None, "Nil")),
                  input: input_of(params),
                ))
              False -> Error(Nil)
            }
          }
          _ -> Error(Nil)
        }
      })
  }
  let advance = case model.has_key(entity), model.has_transitions(entity) {
    True, True -> {
      let name = "advance_" <> entity.module
      case emits(app, entity, name) {
        True -> [
          Fn(
            name: name,
            params: list.append(list.append(key, version), [
              Param(
                label: "step",
                ty: typing.TyRef(Some("gen/phase"), entity.name <> "Step"),
              ),
            ]),
            result: verb(typing.TyRef(None, "Nil")),
            input: input_of(
              list.append(list.append(key, version), [
                Param(
                  label: "step",
                  ty: typing.TyRef(None, entity.name <> "Step"),
                ),
              ]),
            ),
          ),
        ]
        False -> []
      }
    }
    _, _ -> []
  }
  let delete = case model.has_key(entity) {
    False -> []
    True -> {
      let name = "delete_" <> entity.module
      case emits(app, entity, name) {
        True -> [
          Fn(
            name: name,
            params: key,
            result: verb(typing.TyRef(None, "Nil")),
            input: input_of(key),
          ),
        ]
        False -> []
      }
    }
  }
  let extra =
    list.append(
      case emits(app, entity, "create_" <> entity.module) {
        True -> [create(entity)]
        False -> []
      },
      list.filter_map(entity.verbs, fn(rule) {
        case rule {
          model.DeleteWhereRule(field) ->
            case model.has_key(entity) {
              True -> {
                let name = "delete_" <> entity.module <> "_by_" <> field
                case emits(app, entity, name) {
                  True -> Ok(delete_where(entity, app, field))
                  False -> Error(Nil)
                }
              }
              False -> Error(Nil)
            }
          model.CreateManyRule -> {
            let name = "create_" <> entity.collection
            case emits(app, entity, name) {
              True -> Ok(create_many(entity))
              False -> Error(Nil)
            }
          }
          _ -> Error(Nil)
        }
      }),
    )
  let reorder = case model.has_key(entity), entity.ordered_by {
    True, Some(ordered) ->
      case emits_reorder(app, entity, "reorder_" <> entity.collection) {
        True -> [reorder(entity, app, ordered)]
        False -> []
      }
    _, _ -> []
  }
  let put = case model.has_key(entity), entity.upsert_key {
    True, [_first, ..] ->
      case emits(app, entity, "put_" <> entity.module) {
        True -> [put(entity, app)]
        False -> []
      }
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
  let params = case create_many_has_entered(entity) {
    True -> [
      Param(label: "input", ty: typing.list_of(draft)),
      Param(label: "at", ty: typing.datetime()),
    ]
    False -> [Param(label: "input", ty: typing.list_of(draft))]
  }
  Fn(
    name: "create_" <> entity.collection,
    params: params,
    result: verb(typing.list_of(created)),
    input: input_of(params),
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
  let key_type = key_type(entity, app)
  let within_params =
    list.map(ordered.within, fn(within) {
      Param(label: within, ty: reorder_within_type(entity, app, within))
    })
  let params =
    list.append(within_params, [
      Param(label: "ids", ty: typing.list_of(key_type)),
    ])
  Fn(
    name: "reorder_" <> entity.collection,
    params: params,
    result: verb(typing.TyRef(None, "Nil")),
    input: input_of(params),
  )
}

fn reorder_within_type(
  entity: model.Entity,
  app: model.App,
  name: String,
) -> typing.Ty {
  case model.field_for_prop(entity, name) {
    Some(field) -> {
      let base = case field.value {
        model.RelValue(target_module: target_module, target_type: target_type) ->
          typing.key_of(typing.TyRef(
            Some("entity/" <> target_module),
            target_type,
          ))
        _ -> prop_type(entity, app, name)
      }
      case field.optional {
        True -> typing.option(base)
        False -> base
      }
    }
    None -> prop_type(entity, app, name)
  }
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
  key_params_for_props(entity, app, entity.key_props)
}

fn key_params_for_props(
  entity: model.Entity,
  app: model.App,
  props: List(String),
) -> List(Param) {
  props
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
      |> list.filter_map(fn(prop) {
        let name = "update_" <> entity.module <> "_" <> prop.name
        case emits(app, entity, name) {
          True ->
            Ok(sql_file(
              entity,
              hashes,
              name,
              update_sql(entity, app, name, [prop.name], model.AnyPhase),
            ))
          False -> Error(Nil)
        }
      })
  }
  let named_updates = case model.has_key(entity) {
    False -> []
    True ->
      entity.verbs
      |> list.filter_map(fn(rule) {
        case rule {
          model.UpdateRule(name, fields, at) -> {
            let name = update_name(entity, name)
            case emits(app, entity, name) {
              True ->
                Ok(sql_file(
                  entity,
                  hashes,
                  name,
                  update_sql(entity, app, name, fields, at),
                ))
              False -> Error(Nil)
            }
          }
          _ -> Error(Nil)
        }
      })
  }
  let advance = case model.has_key(entity), model.has_transitions(entity) {
    True, True -> {
      let name = "advance_" <> entity.module
      case emits(app, entity, name) {
        True -> [
          sql_file(
            entity,
            hashes,
            name,
            advance_sql(entity, app, model.advance_bump(entity)),
          ),
        ]
        False -> []
      }
    }
    _, _ -> []
  }
  let delete = case model.has_key(entity) {
    False -> []
    True -> {
      let name = "delete_" <> entity.module
      case emits(app, entity, name) {
        True -> [sql_file(entity, hashes, name, delete_sql(entity, app))]
        False -> []
      }
    }
  }
  let extras =
    list.filter_map(entity.verbs, fn(rule) {
      case rule {
        model.DeleteWhereRule(field) ->
          case model.has_key(entity) {
            True -> {
              let name = "delete_" <> entity.module <> "_by_" <> field
              case emits(app, entity, name) {
                True ->
                  Ok(sql_file(
                    entity,
                    hashes,
                    name,
                    delete_where_sql(entity, app, field),
                  ))
                False -> Error(Nil)
              }
            }
            False -> Error(Nil)
          }
        model.CreateManyRule -> {
          let name = "create_" <> entity.collection
          case emits(app, entity, name) {
            True ->
              Ok(sql_file(entity, hashes, name, create_many_sql(entity, app)))
            False -> Error(Nil)
          }
        }
        _ -> Error(Nil)
      }
    })
  let reorder = case model.has_key(entity), entity.ordered_by {
    True, Some(ordered) -> {
      let name = "reorder_" <> entity.collection
      case emits_reorder(app, entity, name) {
        True -> [
          sql_file(
            entity,
            hashes,
            name <> "_stage",
            reorder_stage_sql(entity, app, ordered),
          ),
          sql_file(entity, hashes, name, reorder_sql(entity, app, ordered)),
        ]
        False -> []
      }
    }
    _, _ -> []
  }
  let put = case model.has_key(entity), entity.upsert_key {
    True, [_first, ..] -> {
      let name = "put_" <> entity.module
      case emits(app, entity, name) {
        True -> [sql_file(entity, hashes, name, put_sql(entity, app))]
        False -> []
      }
    }
    _, _ -> []
  }
  let create_files = case emits(app, entity, "create_" <> entity.module) {
    True -> [
      sql_file(
        entity,
        hashes,
        "create_" <> entity.module,
        create_sql(entity, app),
      ),
    ]
    False -> []
  }
  list.append(
    create_files,
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
    path: "db/queries/verb/" <> name <> ".sql",
    text: "-- GENERATED from entity."
      <> entity.module
      <> " [sha256:"
      <> hash.entity(hashes, entity.module)
      <> "] — 手で編集しない\n"
      <> body,
  )
}

fn create_sql(entity: model.Entity, app: model.App) -> String {
  case entity.ordered_by {
    Some(ordered) -> ordered_create_sql(entity, app, ordered)
    None -> plain_create_sql(entity, app)
  }
}

fn plain_create_sql(entity: model.Entity, app: model.App) -> String {
  let fields = create_fields(entity)
  case fields {
    [] ->
      "INSERT INTO "
      <> table(entity)
      <> " DEFAULT VALUES RETURNING "
      <> returning_created(app, entity)
      <> ";\n"
    _ ->
      "INSERT INTO "
      <> table(entity)
      <> "("
      <> string.join(
        list.map(fields, fn(field) { quoted(verb_field_column(app, field)) }),
        ",",
      )
      <> ")\nVALUES("
      <> string.join(create_values(app, entity, fields, 1), ",")
      <> ") RETURNING "
      <> returning_created(app, entity)
      <> ";\n"
  }
}

/// `ordered_by` のある Entity は、親を同じ文でロックしてから scope の末尾へ入れる。
/// `order` は入力 Draft から外し、親ロックに依存する LATERAL の集計で決める。
fn ordered_create_sql(
  entity: model.Entity,
  app: model.App,
  ordered: model.OrderedBy,
) -> String {
  let fields = create_fields(entity)
  let columns =
    fields
    |> list.map(fn(field) { quoted(verb_field_column(app, field)) })
    |> string.join(",")
  let values =
    ordered_create_values(app, entity, fields, ordered, 1)
    |> string.join(",")
  let order_column = quoted(verb_prop_column(app, entity, ordered.field))
  let conditions = ordered_create_conditions(app, entity, ordered)
  let condition_text = case conditions {
    [] -> "TRUE"
    _ -> string.join(conditions, "\n AND ")
  }
  let parent_cte = case ordered_parent(entity, app, ordered) {
    Some(parent) -> {
      case ordered.within {
        [first, ..] -> {
          let place = ordered_create_place(entity, ordered, first)
          "parent_lock AS MATERIALIZED (\n"
          <> " SELECT 1 AS locked\n"
          <> " FROM "
          <> table(parent)
          <> "\n WHERE "
          <> quoted(first_key_column(parent))
          <> "="
          <> parameter_for_prop_field(app, entity, first, place)
          <> " FOR UPDATE\n"
          <> "),\n"
        }
        [] -> ""
      }
    }
    None -> ""
  }
  let next_order_cte = case ordered_parent(entity, app, ordered) {
    Some(_) ->
      "next_order AS MATERIALIZED (\n"
      <> " SELECT next_value.next_order\n"
      <> " FROM parent_lock\n"
      <> " CROSS JOIN LATERAL (\n"
      <> "  SELECT COALESCE(max(existing."
      <> order_column
      <> ")+1,0) AS next_order\n"
      <> "  FROM "
      <> table(entity)
      <> " AS existing\n"
      <> "  WHERE "
      <> condition_text
      <> "\n"
      <> " ) AS next_value\n"
      <> "),\n"
    None ->
      "next_order AS MATERIALIZED (\n"
      <> " SELECT COALESCE(max(existing."
      <> order_column
      <> ")+1,0) AS next_order\n"
      <> " FROM "
      <> table(entity)
      <> " AS existing\n"
      <> " WHERE "
      <> condition_text
      <> "\n"
      <> "),\n"
  }
  "WITH "
  <> parent_cte
  <> next_order_cte
  <> "created AS (\n"
  <> " INSERT INTO "
  <> table(entity)
  <> "("
  <> columns
  <> ")\n"
  <> " SELECT "
  <> values
  <> "\n FROM next_order\n"
  <> " RETURNING "
  <> returning_created(app, entity)
  <> "\n)\nSELECT "
  <> returning_created(app, entity)
  <> " FROM created;\n"
}

fn ordered_parent(
  entity: model.Entity,
  app: model.App,
  ordered: model.OrderedBy,
) -> Option(model.Entity) {
  case ordered.within {
    [first, ..] ->
      case model.field_for_prop(entity, first) {
        Some(field) ->
          case field.value {
            model.RelValue(target_module: target_module, ..) ->
              model.entity_by_module(app.entities, target_module)
            _ -> None
          }
        None -> None
      }
    [] -> None
  }
}

fn ordered_create_conditions(
  app: model.App,
  entity: model.Entity,
  ordered: model.OrderedBy,
) -> List(String) {
  ordered.within
  |> list.map(fn(name) {
    let place = ordered_create_place(entity, ordered, name)
    "existing."
    <> quoted(verb_prop_column(app, entity, name))
    <> " IS NOT DISTINCT FROM "
    <> parameter_for_prop_field(app, entity, name, place)
  })
}

fn ordered_create_place(
  entity: model.Entity,
  ordered: model.OrderedBy,
  wanted: String,
) -> Int {
  create_place_in_fields(
    create_fields(entity),
    entity,
    ordered.field,
    wanted,
    1,
  )
}

fn create_place_in_fields(
  fields: List(model.FieldDef),
  entity: model.Entity,
  ordered_field: String,
  wanted: String,
  place: Int,
) -> Int {
  case fields {
    [] -> place
    [field, ..rest] -> {
      let is_order =
        field.column == ordered_field
        || prop_for_field(entity, field.name) == ordered_field
      case is_order {
        True ->
          create_place_in_fields(rest, entity, ordered_field, wanted, place)
        False ->
          case prop_for_field(entity, field.name) == wanted {
            True -> place
            False -> {
              let next_place = case field.column {
                "phase" -> place
                _ -> place + 1
              }
              create_place_in_fields(
                rest,
                entity,
                ordered_field,
                wanted,
                next_place,
              )
            }
          }
      }
    }
  }
}

fn ordered_create_values(
  app: model.App,
  entity: model.Entity,
  fields: List(model.FieldDef),
  ordered: model.OrderedBy,
  place: Int,
) -> List(String) {
  case fields {
    [] -> []
    [field, ..rest] -> {
      let is_order =
        field.column == ordered.field
        || prop_for_field(entity, field.name) == ordered.field
      let value = case is_order {
        True -> "next_order.next_order"
        False ->
          case field.column {
            "phase" -> initial_phase_literal(entity)
            _ -> parameter_value(app, field, place)
          }
      }
      let next_place = case is_order, field.column {
        True, _ -> place
        False, "phase" -> place
        False, _ -> place + 1
      }
      [value, ..ordered_create_values(app, entity, rest, ordered, next_place)]
    }
  }
}

fn create_many_sql(entity: model.Entity, app: model.App) -> String {
  case entity.ordered_by {
    Some(ordered) -> ordered_create_many_sql(entity, app, ordered)
    None -> plain_create_many_sql(entity, app)
  }
}

fn plain_create_many_sql(entity: model.Entity, app: model.App) -> String {
  let fields = create_fields(entity)
  case fields {
    [] -> create_sql(entity, app)
    _ -> {
      let selected =
        fields
        |> list.map(fn(field) { create_many_value(app, entity, field) })
        |> string.join(",")
      "INSERT INTO "
      <> table(entity)
      <> "("
      <> string.join(
        list.map(fields, fn(field) { quoted(verb_field_column(app, field)) }),
        ",",
      )
      <> ")\nSELECT "
      <> selected
      <> "\nFROM jsonb_array_elements($1::jsonb) AS item\nRETURNING "
      <> returning_created(app, entity)
      <> ";\n"
    }
  }
}

/// CreateMany の ordered create。入力 JSON は Draft の欄だけを読み、配列の
/// ordinality を scope ごとの row_number にして既存末尾へ足す。
fn ordered_create_many_sql(
  entity: model.Entity,
  app: model.App,
  ordered: model.OrderedBy,
) -> String {
  let fields = create_fields(entity)
  let input_fields =
    fields
    |> list.filter(fn(field) {
      !ordered_field(entity, ordered, field)
      && field.column != "phase"
      && !initial_entered_field(entity, field)
    })
  let input_rows =
    input_fields
    |> list.map(fn(field) {
      "  "
      <> json_value(app, entity, field)
      <> " AS "
      <> quoted(verb_field_column(app, field))
    })
    |> list.append(["  ord"])
    |> string.join(",\n")
  let within_columns =
    list.map(ordered.within, fn(name) { verb_prop_column(app, entity, name) })
  let scope_projection = case within_columns {
    [] -> "1 AS batch_scope"
    _ ->
      within_columns
      |> list.map(fn(column) { quoted(column) })
      |> string.join(",")
  }
  let order_column = quoted(verb_prop_column(app, entity, ordered.field))
  let existing_scope = scope_join("existing", "scope", within_columns)
  let input_scope = scope_join("next_order", "input_rows", within_columns)
  let parent_cte = case ordered_parent(entity, app, ordered), ordered.within {
    Some(parent), [first, ..] -> {
      let local_column = verb_prop_column(app, entity, first)
      let parent_column = first_key_column(parent)
      "parent_lock AS MATERIALIZED (\n"
      <> " SELECT parent."
      <> quoted(parent_column)
      <> " AS "
      <> quoted(local_column)
      <> "\n FROM "
      <> table(parent)
      <> " AS parent\n"
      <> " WHERE EXISTS (\n"
      <> "  SELECT 1 FROM scopes AS scope\n"
      <> "  WHERE parent."
      <> quoted(parent_column)
      <> " IS NOT DISTINCT FROM scope."
      <> quoted(local_column)
      <> "\n )\n ORDER BY parent."
      <> quoted(parent_column)
      <> "\n FOR UPDATE\n),\n"
    }
    _, _ -> ""
  }
  let parent_join = case ordered_parent(entity, app, ordered), ordered.within {
    Some(_), [first, ..] -> {
      let local_column = quoted(verb_prop_column(app, entity, first))
      " JOIN parent_lock AS parent\n"
      <> "  ON parent."
      <> local_column
      <> " IS NOT DISTINCT FROM scope."
      <> local_column
      <> "\n"
    }
    _, _ -> ""
  }
  let next_scope_columns = case within_columns {
    [] -> ""
    _ ->
      within_columns
      |> list.map(fn(column) { "scope." <> quoted(column) })
      |> string.join(",")
      |> fn(columns) { columns <> ",\n        " }
  }
  let group_by = case within_columns {
    [] -> ""
    _ -> "\n GROUP BY " <> qualified_columns("scope", within_columns)
  }
  let partition_by = case within_columns {
    [] -> ""
    _ ->
      "PARTITION BY " <> qualified_columns("input_rows", within_columns) <> " "
  }
  let order_cast = case model.field_for_prop(entity, ordered.field) {
    Some(field) -> explicit_cast_of(sql_type_field(app, field))
    None -> ""
  }
  let selected =
    fields
    |> list.map(fn(field) {
      case ordered_field(entity, ordered, field) {
        True -> "numbered.generated_order"
        False ->
          case field.column, initial_entered_field(entity, field) {
            "phase", _ -> initial_phase_literal(entity)
            _, True -> "$2::timestamptz"
            _, False -> "numbered." <> quoted(verb_field_column(app, field))
          }
      }
    })
    |> string.join(",")
  "WITH input_rows AS MATERIALIZED (\n"
  <> " SELECT\n"
  <> input_rows
  <> "\n FROM jsonb_array_elements($1::jsonb) WITH ORDINALITY AS items(item,ord)\n"
  <> "),\nscopes AS MATERIALIZED (\n"
  <> " SELECT DISTINCT "
  <> scope_projection
  <> "\n FROM input_rows\n),\n"
  <> parent_cte
  <> "next_order AS MATERIALIZED (\n"
  <> " SELECT "
  <> next_scope_columns
  <> "COALESCE(max(existing."
  <> order_column
  <> ")+1,0) AS next_order\n"
  <> " FROM scopes AS scope\n"
  <> parent_join
  <> " LEFT JOIN "
  <> table(entity)
  <> " AS existing\n"
  <> "  ON "
  <> existing_scope
  <> group_by
  <> "\n),\nnumbered AS MATERIALIZED (\n"
  <> " SELECT input_rows.*,\n"
  <> "  (next_order.next_order + row_number() OVER ("
  <> partition_by
  <> "ORDER BY input_rows.ord) - 1)"
  <> order_cast
  <> " AS generated_order\n"
  <> " FROM input_rows\n"
  <> " JOIN next_order ON "
  <> input_scope
  <> "\n)\nINSERT INTO "
  <> table(entity)
  <> "("
  <> field_columns(app, fields)
  <> ")\nSELECT "
  <> selected
  <> "\nFROM numbered\nORDER BY numbered.ord\nRETURNING "
  <> returning_created(app, entity)
  <> ";\n"
}

fn qualified_columns(alias: String, columns: List(String)) -> String {
  columns
  |> list.map(fn(column) { alias <> "." <> quoted(column) })
  |> string.join(",")
}

fn field_columns(app: model.App, fields: List(model.FieldDef)) -> String {
  fields
  |> list.map(fn(field) { quoted(verb_field_column(app, field)) })
  |> string.join(",")
}

fn scope_join(left: String, right: String, columns: List(String)) -> String {
  case columns {
    [] -> "TRUE"
    _ ->
      columns
      |> list.map(fn(column) {
        left
        <> "."
        <> quoted(column)
        <> " IS NOT DISTINCT FROM "
        <> right
        <> "."
        <> quoted(column)
      })
      |> string.join("\n AND ")
  }
}

fn ordered_field(
  entity: model.Entity,
  ordered: model.OrderedBy,
  field: model.FieldDef,
) -> Bool {
  field.column == ordered.field
  || prop_for_field(entity, field.name) == ordered.field
}

fn create_many_value(
  app: model.App,
  entity: model.Entity,
  field: model.FieldDef,
) -> String {
  case field.column, initial_entered_field(entity, field) {
    "phase", _ -> initial_phase_literal(entity)
    _, True -> "$2::timestamptz"
    _, False -> json_value(app, entity, field)
  }
}

fn create_values(
  app: model.App,
  entity: model.Entity,
  fields: List(model.FieldDef),
  place: Int,
) -> List(String) {
  case fields {
    [] -> []
    [field, ..rest] -> {
      let value = case field.column {
        "phase" -> initial_phase_literal(entity)
        _ -> parameter_value(app, field, place)
      }
      let next_place = case field.column {
        "phase" -> place
        _ -> place + 1
      }
      [value, ..create_values(app, entity, rest, next_place)]
    }
  }
}

fn parameter_value(
  app: model.App,
  field: model.FieldDef,
  place: Int,
) -> String {
  let placeholder = "$" <> int.to_string(place)
  case field.value {
    model.TypeValue(reference) if reference.name == "Sealed" ->
      "decode(" <> placeholder <> ",'hex')"
    _ -> placeholder <> cast_of(sql_type_field(app, field))
  }
}

fn json_value(
  app: model.App,
  entity: model.Entity,
  field: model.FieldDef,
) -> String {
  let input_name = prop_for_field(entity, field.name)
  case field.value {
    model.TypeValue(reference) if reference.name == "Sealed" ->
      "decode(item->>'" <> input_name <> "','hex')"
    _ ->
      "(item->>'"
      <> input_name
      <> "')"
      <> explicit_cast_of(sql_type_field(app, field))
  }
}

fn create_many_has_entered(entity: model.Entity) -> Bool {
  list.any(initial_phase_fields(entity), initial_entered_field(entity, _))
}

fn initial_entered_field(entity: model.Entity, field: model.FieldDef) -> Bool {
  case initial_phase(entity) {
    Some(phase) -> field.column == "entered_" <> naming.snake(phase)
    None -> False
  }
}

fn initial_phase_literal(entity: model.Entity) -> String {
  case initial_phase(entity) {
    Some(phase) -> "'" <> naming.snake(phase) <> "'"
    None -> "NULL"
  }
}

fn initial_phase(entity: model.Entity) -> Option(String) {
  case entity.edges {
    [#(from, _), ..] -> Some(from)
    [] -> option.from_result(list.first(entity.phases))
  }
}

fn update_sql(
  entity: model.Entity,
  app: model.App,
  name: String,
  props: List(String),
  gate: model.VerbGate,
) -> String {
  let lookup_props = update_lookup_props(entity, name)
  let version_offset = case update_bumps_version(entity, name) {
    True -> 1
    False -> 0
  }
  let first_value = list.length(lookup_props) + version_offset + 1
  let assignments =
    props
    |> list.index_map(fn(prop, index) {
      quoted(verb_prop_column(app, entity, prop))
      <> "="
      <> parameter_for_prop(app, entity, prop, first_value + index)
    })
  let assignments = case update_bumps_version(entity, name) {
    True -> list.append(assignments, ["version=version+1"])
    False -> assignments
  }
  let where =
    list.append(
      update_key_conditions(app, entity, lookup_props, 1),
      update_version_condition(entity, name, list.length(lookup_props) + 1),
    )
  let where = list.append(where, gate_condition(gate))
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

fn advance_sql(
  entity: model.Entity,
  app: model.App,
  bump: model.VerbBump,
) -> String {
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
      key_conditions(app, entity, 1, None),
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

fn delete_sql(entity: model.Entity, app: model.App) -> String {
  "DELETE FROM "
  <> table(entity)
  <> " WHERE "
  <> string.join(key_conditions(app, entity, 1, None), " AND ")
  <> ";\n"
}

fn delete_where_sql(
  entity: model.Entity,
  app: model.App,
  field: String,
) -> String {
  "DELETE FROM "
  <> table(entity)
  <> " WHERE "
  <> quoted(verb_prop_column(app, entity, field))
  <> "="
  <> parameter_for_prop(app, entity, field, 1)
  <> " RETURNING "
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
  let order_column = verb_prop_column(app, entity, ordered.field)
  let key_column = first_key_column(entity)
  let #(first, _lo, _hi) = order_span(entity, app, ordered)
  let ids_place = list.length(ordered.within) + 1
  let within = within_conditions(app, entity, ordered, Some("e"), 1)
  let within_text = string.join(within, " AND ")
  "WITH positions AS (\n"
  <> " SELECT value"
  <> key_cast(app, entity)
  <> " AS id,("
  <> int.to_string(first)
  <> "+ord-1)::integer AS new_order,ord"
  <> "\n"
  <> " FROM jsonb_array_elements_text($"
  <> int.to_string(ids_place)
  <> "::jsonb) WITH ORDINALITY AS items(value,ord)\n"
  <> "), target AS MATERIALIZED (\n"
  <> " SELECT e."
  <> quoted(key_column)
  <> " AS id,p.new_order,p.ord FROM "
  <> table(entity)
  <> " e JOIN positions p ON e."
  <> quoted(key_column)
  <> "=p.id WHERE "
  <> within_text
  <> "\n"
  <> "), changed AS (\n"
  <> " UPDATE "
  <> table(entity)
  <> " e SET "
  <> quoted(order_column)
  <> "=t.new_order\n"
  <> " FROM target t WHERE e."
  <> quoted(key_column)
  <> "=t.id AND "
  <> within_text
  <> "\n RETURNING "
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
  let order_column = verb_prop_column(app, entity, ordered.field)
  let key_column = first_key_column(entity)
  let #(first, lo, hi) = order_span(entity, app, ordered)
  let ids_place = list.length(ordered.within) + 1
  let within = within_conditions(app, entity, ordered, Some("e"), 1)
  let within_text = string.join(within, " AND ")
  let first_text = int.to_string(first) <> "::bigint"
  let lo_text = int.to_string(lo) <> "::bigint"
  let hi_text = int.to_string(hi) <> "::bigint"
  "WITH positions AS (\n"
  <> " SELECT value"
  <> key_cast(app, entity)
  <> " AS id,ord\n"
  <> " FROM jsonb_array_elements_text($"
  <> int.to_string(ids_place)
  <> "::jsonb) WITH ORDINALITY AS items(value,ord)\n"
  <> "), scope AS MATERIALIZED (\n"
  <> " SELECT e."
  <> quoted(key_column)
  <> " AS id,e."
  <> quoted(order_column)
  <> " AS current FROM "
  <> table(entity)
  <> " e WHERE "
  <> within_text
  <> " FOR UPDATE\n"
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
  <> "=t.id AND "
  <> within_text
  <> " AND (SELECT count(*) FROM free)=(SELECT expected FROM counts)\n"
  <> " RETURNING e."
  <> quoted(key_column)
  <> "\n)\nSELECT framework.require_rows("
  <> "CASE WHEN c.expected=c.matched THEN GREATEST(c.expected,1) ELSE 0 END,"
  <> "'conflict') AS ok,(SELECT count(*) FROM staged) AS staged,(SELECT count(*) FROM free) AS room FROM counts c;\n"
}

fn within_conditions(
  app: model.App,
  entity: model.Entity,
  ordered: model.OrderedBy,
  alias: Option(String),
  first_place: Int,
) -> List(String) {
  ordered.within
  |> list.index_map(fn(name, index) {
    let prefix = case alias {
      Some(value) -> value <> "."
      None -> ""
    }
    let column = quoted(verb_prop_column(app, entity, name))
    let place = first_place + index
    let parameter = parameter_for_prop_field(app, entity, name, place)
    case model.field_for_prop(entity, name) {
      Some(field) ->
        case field.optional {
          True -> prefix <> column <> " IS NOT DISTINCT FROM " <> parameter
          False -> prefix <> column <> "=" <> parameter
        }
      None -> prefix <> column <> "=" <> parameter
    }
  })
}

fn parameter_for_prop_field(
  app: model.App,
  entity: model.Entity,
  prop: String,
  place: Int,
) -> String {
  let placeholder = "$" <> int.to_string(place)
  case model.field_for_prop(entity, prop) {
    Some(field) -> placeholder <> cast_of(sql_type(app, field.value))
    None -> placeholder
  }
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
  cast_of(key_kind)
}

fn put_sql(entity: model.Entity, app: model.App) -> String {
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
    list.map(ordered, fn(prop) { quoted(verb_prop_column(app, entity, prop)) })
  let updates =
    list.map(update_props, fn(prop) {
      quoted(verb_prop_column(app, entity, prop.name))
      <> "=EXCLUDED."
      <> quoted(verb_prop_column(app, entity, prop.name))
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
    <> string.join(put_values(app, entity, ordered, 1), ",")
    <> ")\nON CONFLICT ("
    <> string.join(
      list.map(entity.upsert_key, fn(prop) {
        quoted(verb_prop_column(app, entity, prop))
      }),
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
  list.append(base_create_fields(entity), initial_phase_fields(entity))
}

fn base_create_fields(entity: model.Entity) -> List(model.FieldDef) {
  persisted_fields(entity)
  |> list.filter(fn(field) {
    !list.contains(entity.auto_key, prop_for_field(entity, field.name))
  })
}

fn initial_phase_fields(entity: model.Entity) -> List(model.FieldDef) {
  case initial_phase(entity) {
    None -> []
    Some(phase) ->
      entity.fields
      |> list.filter(fn(field) {
        field.column == "phase"
        || field.column == "entered_" <> naming.snake(phase)
      })
  }
}

fn put_values(
  app: model.App,
  entity: model.Entity,
  props: List(String),
  place: Int,
) -> List(String) {
  case props {
    [] -> []
    [prop, ..rest] -> [
      parameter_for_prop(app, entity, prop, place),
      ..put_values(app, entity, rest, place + 1)
    ]
  }
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
    model.Only([phase]) -> [
      "phase='" <> naming.snake(phase) <> "'",
    ]
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
  app: model.App,
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
    prefix
    <> quoted(column)
    <> "="
    <> parameter_for_column(app, entity, column, first_place + index)
  })
}

fn update_key_conditions(
  app: model.App,
  entity: model.Entity,
  props: List(String),
  first_place: Int,
) -> List(String) {
  props
  |> list.index_map(fn(prop, index) {
    quoted(verb_prop_column(app, entity, prop))
    <> "="
    <> parameter_for_prop(app, entity, prop, first_place + index)
  })
}

fn parameter_for_column(
  app: model.App,
  entity: model.Entity,
  column: String,
  place: Int,
) -> String {
  let placeholder = "$" <> int.to_string(place)
  case list.find(entity.fields, fn(field) { field.column == column }) {
    Ok(field) -> placeholder <> cast_of(sql_type_field(app, field))
    Error(_) -> placeholder
  }
}

fn parameter_for_prop(
  app: model.App,
  entity: model.Entity,
  prop: String,
  place: Int,
) -> String {
  case model.field_for_prop(entity, prop) {
    Some(field) -> parameter_value(app, field, place)
    None -> "$" <> int.to_string(place)
  }
}

fn update_name(entity: model.Entity, name: String) -> String {
  let prefix = "update_" <> entity.module <> "_"
  case string.starts_with(name, prefix) {
    True -> name
    False -> name <> "_" <> entity.module
  }
}

fn update_uses_upsert_key(entity: model.Entity, name: String) -> Bool {
  string.starts_with(name, "update_" <> entity.module <> "_by_")
  && entity.upsert_key != []
}

fn update_lookup_props(entity: model.Entity, name: String) -> List(String) {
  case update_uses_upsert_key(entity, name) {
    True -> entity.upsert_key
    False -> entity.key_props
  }
}

fn update_version_params(entity: model.Entity, name: String) -> List(Param) {
  case update_bumps_version(entity, name) {
    True -> version_param(entity)
    False -> []
  }
}

fn update_bumps_version(entity: model.Entity, name: String) -> Bool {
  has_version(entity) && !update_uses_upsert_key(entity, name)
}

fn update_version_condition(
  entity: model.Entity,
  name: String,
  place: Int,
) -> List(String) {
  case update_bumps_version(entity, name) {
    True -> version_condition(entity, place)
    False -> []
  }
}

fn persisted_fields(entity: model.Entity) -> List(model.FieldDef) {
  entity.props
  |> list.flat_map(fn(prop) {
    let main = case model.field_for_prop(entity, prop.name) {
      Some(field) -> [field]
      None -> []
    }
    let auxiliary_name = entity.name <> naming.pascal(prop.name) <> "KeyId"
    list.append(
      main,
      entity.verb_fields
        |> list.filter(fn(field) { field.name == auxiliary_name }),
    )
  })
  |> list.filter(fn(field) {
    field.column != "phase" && !string.starts_with(field.column, "entered_")
  })
}

fn verb_prop_column(
  app: model.App,
  entity: model.Entity,
  prop: String,
) -> String {
  case model.field_for_prop(entity, prop) {
    Some(field) -> verb_field_column(app, field)
    None -> prop
  }
}

fn verb_field_column(app: model.App, field: model.FieldDef) -> String {
  let _ = app
  case field.value {
    model.TypeValue(reference) ->
      case reference.module, reference.name {
        Some("ledger"), "LedgerStoreId" -> field.column <> "_id"
        _, _ -> field.column
      }
    _ -> field.column
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

fn returning_created(app: model.App, entity: model.Entity) -> String {
  let columns =
    created_fields(entity)
    |> list.map(fn(field) { verb_field_column(app, field) })
  case columns {
    [] -> "*"
    _ -> string.join(list.map(columns, quoted), ",")
  }
}

/// Draft/Created の同じ Property から戻り列を導く。verb_fields の補助列や phase は
/// draft の型に無いので RETURNING に混ぜない。
fn created_fields(entity: model.Entity) -> List(model.FieldDef) {
  entity.props
  |> list.filter_map(fn(prop) {
    case model.field_for_prop(entity, prop.name) {
      Some(field) -> Ok(field)
      None -> Error(Nil)
    }
  })
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
            False ->
              case path, reference.name {
                "ledger", "LedgerStoreId" -> "uuid"
                _, _ ->
                  case string.starts_with(path, "entity/") {
                    True -> "jsonb"
                    False -> "text"
                  }
              }
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

fn sql_type_field(app: model.App, field: model.FieldDef) -> String {
  case field.repeated, string.ends_with(field.name, "Kind") {
    True, _ -> "jsonb"
    False, True -> "text"
    False, False ->
      case enum_field(field) {
        True -> "text"
        False -> sql_type(app, field.value)
      }
  }
}

fn enum_field(field: model.FieldDef) -> Bool {
  case field.value {
    model.TypeValue(reference) ->
      case reference.module {
        Some(path) ->
          string.starts_with(path, "entity/")
          && string.ends_with(field.name, reference.name)
        None -> False
      }
    _ -> False
  }
}

fn cast_of(kind: String) -> String {
  case kind {
    "jsonb" | "uuid" | "date" | "timestamptz" | "boolean" -> "::" <> kind
    _ -> ""
  }
}

/// JSON text has to be converted explicitly for every non-text SQL type.
/// Keep this separate from cast_of: positional parameters intentionally rely
/// on PostgreSQL's target-type inference for integer and floating values.
fn explicit_cast_of(kind: String) -> String {
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
