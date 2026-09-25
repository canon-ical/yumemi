//// ★ の読み取り。types.gleam / entity/*.gleam / service/*.gleam から model を起こす。
//// ここに現れる名前は全部 ★ から来る ── アプリ固有の綴りは1つも持たない。

import glance
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import yumemi_gen/glance_util as g
import yumemi_gen/model.{type App, type Entity, type Prop, type ValueType}
import yumemi_gen/naming
import yumemi_gen/reader/clauses
import yumemi_gen/relation
import yumemi_gen/source.{type Unit}
import yumemi_gen/stop

pub type Error {
  NoTypesModule
  NoKeyFunction(module: String)
  NoEntityType(module: String)
  Unsupported(where: String, detail: String)
  Vocabulary(where: String, detail: String)
  Internal(where: String, detail: String)
}

/// import の解決表。
type Imports {
  Imports(qualified: Dict(String, String), unqualified: Dict(String, String))
}

fn imports_of(module: glance.Module) -> Imports {
  list.fold(
    module.imports,
    Imports(dict.new(), dict.new()),
    fn(acc, definition) {
      let import_ = definition.definition
      let local = case import_.alias {
        Some(glance.Named(name)) -> name
        _ -> last_segment(import_.module)
      }
      let qualified = dict.insert(acc.qualified, local, import_.module)
      let unqualified =
        list.fold(import_.unqualified_types, acc.unqualified, fn(map, entry) {
          let key = case entry.alias {
            Some(alias) -> alias
            None -> entry.name
          }
          dict.insert(map, key, import_.module)
        })
      Imports(qualified: qualified, unqualified: unqualified)
    },
  )
}

fn last_segment(path: String) -> String {
  case list.last(string.split(path, "/")) {
    Ok(segment) -> segment
    Error(_) -> path
  }
}

/// 型の在処。同じ module の型は None を返す。
fn module_of_type(annotation: glance.Type, imports: Imports) -> Option(String) {
  case annotation {
    glance.NamedType(name: name, module: module, ..) ->
      case module {
        Some(local) -> dict.get(imports.qualified, local) |> option.from_result
        None -> dict.get(imports.unqualified, name) |> option.from_result
      }
    _ -> None
  }
}

fn type_shape(annotation: glance.Type, imports: Imports) -> model.TypeShape {
  case annotation {
    glance.NamedType(name: name, module: module, parameters: parameters, ..) ->
      model.NamedShape(
        module: case module {
          Some(local) ->
            dict.get(imports.qualified, local) |> option.from_result
          None -> dict.get(imports.unqualified, name) |> option.from_result
        },
        name: name,
        parameters: list.map(parameters, type_shape(_, imports)),
      )
    glance.TupleType(elements: elements, ..) ->
      model.TupleShape(list.map(elements, type_shape(_, imports)))
    _ -> model.NamedShape(module: None, name: "Unknown", parameters: [])
  }
}

// ── types.gleam ──────────────────────────────────────────────────────────────

pub fn value_types(units: List(Unit)) -> Result(List(ValueType), Error) {
  case list.find(units, fn(unit) { unit.path == "types" }) {
    Error(_) -> Error(NoTypesModule)
    Ok(unit) -> {
      let module = g.in_order(unit.module)
      Ok(
        list.filter_map(module.constants, fn(definition) {
          let constant = definition.definition
          case constant.publicity, constant.annotation {
            glance.Public, Some(annotation) ->
              case g.type_name(annotation) {
                Some("Spec") ->
                  case g.ctor_name(constant.value) {
                    Some(spec) ->
                      Ok(model.ValueType(
                        name: constant.name,
                        type_name: naming.pascal(constant.name),
                        spec: spec,
                        backing: model.backing_of(spec),
                        range: range_of(constant.value),
                      ))
                    None -> Error(Nil)
                  }
                _ -> Error(Nil)
              }
            _, _ -> Error(Nil)
          }
        }),
      )
    }
  }
}

/// `Range(min: 0, max: 2_147_483_647)` の両端。Gleam の桁区切り `_` は落として読む。
fn range_of(expression: glance.Expression) -> Option(#(Int, Int)) {
  case g.ctor_name(expression) {
    Some("Range") ->
      case
        option.then(g.labelled(expression, "min"), int_literal),
        option.then(g.labelled(expression, "max"), int_literal)
      {
        Some(min), Some(max) -> Some(#(min, max))
        _, _ -> None
      }
    _ -> None
  }
}

fn int_literal(expression: glance.Expression) -> Option(Int) {
  case expression {
    glance.NegateInt(value: inner, ..) ->
      int_literal(inner) |> option.map(fn(value) { 0 - value })
    _ ->
      case g.int_value(expression) {
        Some(raw) ->
          int.parse(string.replace(raw, "_", "")) |> option.from_result
        None -> None
      }
  }
}

// ── entity/*.gleam ───────────────────────────────────────────────────────────

/// module 全体の custom type 台帳。"entity/consent.Kind" で引く。
type Registry =
  Dict(String, glance.CustomType)

fn registry(units: List(Unit)) -> Registry {
  list.fold(units, dict.new(), fn(acc, unit) {
    list.fold(unit.module.custom_types, acc, fn(map, definition) {
      dict.insert(map, unit.path <> "." <> definition.definition.name, {
        definition.definition
      })
    })
  })
}

pub fn entities(units: List(Unit)) -> Result(List(Entity), Error) {
  use collection_list <- result.try(collections(units))
  entities_with_collections(units, collection_list)
}

fn entities_with_collections(
  units: List(Unit),
  collection_list: List(model.Collection),
) -> Result(List(Entity), Error) {
  let table = registry(units)
  use candidates <- result.try(
    units
    |> list.filter(fn(unit) { string.starts_with(unit.path, "entity/") })
    |> list.try_map(entity_of(_, table, collection_list)),
  )
  Ok(
    list.filter_map(candidates, fn(candidate) {
      case candidate {
        Some(entity) -> Ok(entity)
        None -> Error(Nil)
      }
    }),
  )
}

/// Entity でないトップレベル module の `pub const collection: String`。
/// `entity/` と `service/` の下は ER / Service の読み取りが所有するため、
/// ここでは拾わない。
pub fn collections(units: List(Unit)) -> Result(List(model.Collection), Error) {
  units
  |> list.filter(fn(unit) { !string.contains(unit.path, "/") })
  |> list.try_map(collection_of)
  |> result.map(fn(found) {
    list.filter_map(found, fn(item) {
      case item {
        Some(collection) -> Ok(collection)
        None -> Error(Nil)
      }
    })
  })
}

fn collection_of(unit: Unit) -> Result(Option(model.Collection), Error) {
  let module = g.in_order(unit.module)
  case public_constant(module, "collection") {
    None -> Ok(None)
    Some(constant) ->
      case constant.annotation, g.string_value(constant.value) {
        Some(annotation), Some(collection) ->
          case g.type_name(annotation) {
            Some("String") -> {
              use handwritten_verbs <- result.try(handwritten_verbs_of(
                module,
                unit.path,
              ))
              use manual_verbs <- result.try(manual_verbs_of(module, unit.path))
              Ok(
                Some(model.Collection(
                  module: unit.path,
                  collection: collection,
                  handwritten_verbs: handwritten_verbs,
                  manual_verbs: manual_verbs,
                )),
              )
            }
            _ -> Error(Unsupported(unit.path, "collection が String でない"))
          }
        _, _ -> Error(Unsupported(unit.path, "collection が String でない"))
      }
  }
}

fn handwritten_verbs_of(
  module: glance.Module,
  where: String,
) -> Result(List(String), Error) {
  verb_names_of(module, where, "handwritten_verbs")
}

/// 生成候補を持たない手書き verb(`pub const manual_verbs: List(String)`)。
fn manual_verbs_of(
  module: glance.Module,
  where: String,
) -> Result(List(String), Error) {
  verb_names_of(module, where, "manual_verbs")
}

fn verb_names_of(
  module: glance.Module,
  where: String,
  name: String,
) -> Result(List(String), Error) {
  case public_constant(module, name) {
    None -> Ok([])
    Some(constant) -> {
      use expressions <- result.try(expression_list(constant.value, where, name))
      list.try_map(expressions, fn(expression) {
        string_expression(expression, where, name <> " の verb 名")
      })
    }
  }
}

/// key が無くても通常のレコード型なら Entity として読み続ける。
/// レコード型の無い型置き場(例: entity/ledger)は Entity にはしない。
fn entity_of(
  unit: Unit,
  table: Registry,
  collection_list: List(model.Collection),
) -> Result(Option(Entity), Error) {
  let module = g.in_order(unit.module)
  let imports = imports_of(module)
  let name = last_segment(unit.path)
  let key_fn = case g.find_function(module, "key") {
    Some(function) -> Some(function)
    None -> g.find_function(module, "path_key")
  }
  use record_name <- result.try(record_name_of(
    module,
    key_fn,
    naming.pascal(name),
    unit.path,
  ))
  case record_name {
    None -> Ok(None)
    Some(record_name) -> {
      use record <- result.try(
        g.find_custom_type(module, record_name)
        |> option.to_result(NoEntityType(unit.path)),
      )
      use variant <- result.try(case record.variants {
        [variant] -> Ok(variant)
        _ -> Error(NoEntityType(unit.path))
      })
      let props =
        list.filter_map(variant.fields, fn(field) {
          case g.variant_field_label(field) {
            Some(label) ->
              Ok(prop_of(
                label,
                g.variant_field_type(field),
                imports,
                table,
                unit,
              ))
            None -> Error(Nil)
          }
        })
      let phases = case g.find_custom_type(module, "Phase") {
        Some(phase) -> list.map(phase.variants, fn(variant) { variant.name })
        None -> []
      }
      let raw_key_props = case key_fn {
        Some(function) -> key_properties(function, unit.path)
        None -> Ok([])
      }
      use key_props <- result.try(raw_key_props)
      let entity_name = naming.pascal(name)
      let fields = fields_of(entity_name, name, props, phases, collection_list)
      let verb_fields = verb_fields_of(entity_name, props)
      use key_columns <- result.try(
        list.try_map(key_props, fn(key_prop) {
          case list.find(props, fn(prop) { prop.name == key_prop }) {
            Ok(_) -> Ok(column_of(props, key_prop, collection_list))
            Error(_) ->
              Error(Unsupported(
                unit.path,
                "key が Entity の Property でない: " <> key_prop,
              ))
          }
        }),
      )
      use _ <- result.try(validate_key_fields(
        entity_name,
        key_props,
        fields,
        unit.path,
      ))
      let key_prop = result.unwrap(list.first(key_props), "")
      let key_column = result.unwrap(list.first(key_columns), "")
      let key_type = case key_fn {
        Some(function) ->
          case function.return {
            Some(annotation) -> Some(type_shape(annotation, imports))
            None -> None
          }
        None -> None
      }
      let path_key_type = case g.find_function(module, "path_key") {
        Some(function) ->
          case function.return {
            Some(annotation) -> Some(type_shape(annotation, imports))
            None -> None
          }
        None -> None
      }
      let collection = case g.find_constant(module, "collection") {
        Some(constant) -> option.unwrap(g.string_value(constant.value), name)
        None -> name
      }
      use handwritten_verbs <- result.try(handwritten_verbs_of(
        module,
        unit.path,
      ))
      use manual_verbs <- result.try(manual_verbs_of(module, unit.path))
      use #(verbs, ordered_by, upsert_key) <- result.try(declarations(
        module,
        phases,
        props,
        key_props,
        entity_name,
        unit.path,
      ))
      use auto_key <- result.try(auto_key_of(
        module,
        key_props,
        props,
        unit.path,
      ))
      use edges <- result.try(edges_of(module, phases, unit.path))
      Ok(
        Some(model.Entity(
          module: name,
          name: entity_name,
          type_name: record_name,
          table: name,
          props: props,
          fields: fields,
          verb_fields: verb_fields,
          phases: phases,
          key_prop: key_prop,
          key_column: key_column,
          key_props: key_props,
          key_columns: key_columns,
          key_type: key_type,
          path_key_type: path_key_type,
          collection: collection,
          subject: g.find_constant(module, "subject") != None,
          edges: edges,
          verbs: verbs,
          handwritten_verbs: handwritten_verbs,
          manual_verbs: manual_verbs,
          ordered_by: ordered_by,
          upsert_key: upsert_key,
          auto_key: auto_key,
        )),
      )
    }
  }
}

fn record_name_of(
  module: glance.Module,
  key_fn: Option(glance.Function),
  fallback: String,
  where: String,
) -> Result(Option(String), Error) {
  case key_fn {
    Some(function) ->
      case function.parameters {
        [glance.FunctionParameter(type_: Some(annotation), ..), ..] ->
          g.type_name(annotation)
          |> option.to_result(NoEntityType(where))
          |> result.map(Some)
        _ -> Error(NoEntityType(where))
      }
    None ->
      case g.find_custom_type(module, fallback) {
        Some(_) -> Ok(Some(fallback))
        None -> Ok(None)
      }
  }
}

pub fn missing_key_notes(units: List(Unit)) -> List(stop.Note) {
  units
  |> list.filter(fn(unit) { string.starts_with(unit.path, "entity/") })
  |> list.filter_map(fn(unit) {
    let module = g.in_order(unit.module)
    case g.find_function(module, "key"), g.find_function(module, "path_key") {
      None, None ->
        Ok(stop.Note(
          class: stop.Missing,
          text: unit.path
            <> ": key 関数が無い ── ER の外の型だけの宣言は src/types.gleam へ(src/entity/** は Entity だけ)",
        ))
      _, _ -> Error(Nil)
    }
  })
}

fn key_properties(
  key_fn: glance.Function,
  where: String,
) -> Result(List(String), Error) {
  case key_fn.body {
    [glance.Expression(glance.FieldAccess(label: label, ..))] -> Ok([label])
    [glance.Expression(glance.Tuple(elements: elements, ..))] ->
      case elements {
        [] -> Error(Internal(where, "key の組が空"))
        _ ->
          list.try_map(elements, fn(element) {
            case element {
              glance.FieldAccess(label: label, ..) -> Ok(label)
              _ -> Error(Internal(where, "key の組に Property 以外がある"))
            }
          })
      }
    _ -> Error(Internal(where, "key の本体を Property または組として読めない"))
  }
}

fn validate_key_fields(
  entity_name: String,
  key_props: List(String),
  fields: List(model.FieldDef),
  where: String,
) -> Result(Nil, Error) {
  case
    list.find(key_props, fn(prop) {
      let expected = entity_name <> naming.pascal(prop)
      !list.any(fields, fn(field) { field.name == expected })
    })
  {
    Ok(prop) -> Error(Internal(where, "key Property の SQL 列を読めない: " <> prop))
    Error(_) ->
      case list.length(list.unique(key_props)) == list.length(key_props) {
        True -> Ok(Nil)
        False -> Error(Internal(where, "key に重複した Property がある"))
      }
  }
}

fn public_constant(
  module: glance.Module,
  name: String,
) -> Option(glance.Constant) {
  case g.find_constant(module, name) {
    Some(constant) ->
      case constant.publicity {
        glance.Public -> Some(constant)
        glance.Private -> None
      }
    None -> None
  }
}

fn expression_list(
  expression: glance.Expression,
  where: String,
  label: String,
) -> Result(List(glance.Expression), Error) {
  case expression {
    glance.List(elements: elements, ..) -> Ok(elements)
    _ -> Error(Unsupported(where, label <> " が List でない"))
  }
}

fn string_expression(
  expression: glance.Expression,
  where: String,
  label: String,
) -> Result(String, Error) {
  g.string_value(expression)
  |> option.to_result(Unsupported(where, label <> " が文字列でない"))
}

fn constructor_expression(
  expression: glance.Expression,
  where: String,
  label: String,
) -> Result(String, Error) {
  g.ctor_name(expression)
  |> option.to_result(Unsupported(where, label <> " の構成子が読めない"))
}

fn declaration_list(
  module: glance.Module,
  name: String,
  where: String,
) -> Result(List(glance.Expression), Error) {
  case public_constant(module, name) {
    None -> Ok([])
    Some(constant) -> expression_list(constant.value, where, name)
  }
}

fn auto_key_of(
  module: glance.Module,
  key_props: List(String),
  props: List(Prop),
  where: String,
) -> Result(List(String), Error) {
  case public_constant(module, "auto_key") {
    None -> Ok([])
    Some(constant) -> {
      use expressions <- result.try(expression_list(
        constant.value,
        where,
        "auto_key",
      ))
      use names <- result.try(
        list.try_map(expressions, fn(expression) {
          string_expression(expression, where, "auto_key の Property")
        }),
      )
      case
        list.find(names, fn(name) {
          !list.contains(key_props, name)
          || !list.any(props, fn(prop) { prop.name == name })
        })
      {
        Ok(name) ->
          Error(Unsupported(where, "auto_key の Property が key に無い: " <> name))
        Error(_) ->
          case list.length(list.unique(names)) == list.length(names) {
            True -> Ok(names)
            False -> Error(Unsupported(where, "auto_key に重複した Property がある"))
          }
      }
    }
  }
}

fn declarations(
  module: glance.Module,
  phases: List(String),
  props: List(Prop),
  key_props: List(String),
  entity_name: String,
  where: String,
) -> Result(
  #(List(model.VerbRule), Option(model.OrderedBy), List(String)),
  Error,
) {
  use expressions <- result.try(declaration_list(module, "verbs", where))
  use verbs <- result.try(
    list.try_map(expressions, fn(expression) {
      parse_rule(expression, phases, props, key_props, where)
    }),
  )
  let ordered_by = case public_constant(module, "ordered_by") {
    None -> Ok(None)
    Some(constant) ->
      parse_order(constant.value, phases, props, key_props, entity_name, where)
  }
  use ordered_by <- result.try(ordered_by)
  let upsert_key = case public_constant(module, "upsert_key") {
    None -> Ok([])
    Some(constant) -> {
      use expressions <- result.try(expression_list(
        constant.value,
        where,
        "upsert_key",
      ))
      list.try_map(expressions, fn(expression) {
        string_expression(expression, where, "upsert_key の列")
      })
    }
  }
  use upsert_key <- result.try(upsert_key)
  use _ <- result.try(validate_upsert_key(upsert_key, props, where))
  Ok(#(verbs, ordered_by, upsert_key))
}

fn parse_rule(
  expression: glance.Expression,
  phases: List(String),
  props: List(Prop),
  key_props: List(String),
  where: String,
) -> Result(model.VerbRule, Error) {
  use name <- result.try(constructor_expression(expression, where, "verbs の規則"))
  case name {
    "Update" -> {
      use update_name_expression <- result.try(
        g.labelled(expression, "name")
        |> option.to_result(Unsupported(where, "Update.name が無い")),
      )
      use update_name <- result.try(string_expression(
        update_name_expression,
        where,
        "Update.name",
      ))
      use fields_expression <- result.try(
        g.labelled(expression, "fields")
        |> option.to_result(Unsupported(where, "Update.fields が無い")),
      )
      use fields <- result.try(expression_list(
        fields_expression,
        where,
        "Update.fields",
      ))
      use fields <- result.try(
        list.try_map(fields, fn(field) {
          string_expression(field, where, "Update.fields の Property")
        }),
      )
      use at <- result.try(parse_gate(expression, phases, where))
      use _ <- result.try(validate_update(
        update_name,
        fields,
        props,
        key_props,
        where,
      ))
      Ok(model.UpdateRule(name: update_name, fields: fields, at: at))
    }
    "Advance" -> {
      use bump <- result.try(parse_bump(expression, phases, where))
      case phases {
        [] -> Error(Unsupported(where, "Advance は Lifecycle のある Entity だけ"))
        _ -> Ok(model.AdvanceRule(bump: bump))
      }
    }
    "DeleteWhere" -> {
      use field_expression <- result.try(
        g.labelled(expression, "field")
        |> option.to_result(Unsupported(where, "DeleteWhere.field が無い")),
      )
      use field <- result.try(string_expression(
        field_expression,
        where,
        "DeleteWhere.field",
      ))
      use _ <- result.try(validate_delete_where(field, props, where))
      Ok(model.DeleteWhereRule(field))
    }
    "CreateMany" -> Ok(model.CreateManyRule)
    "AdvanceAll" ->
      Error(Vocabulary(
        where,
        "AdvanceAll は語彙の不足。集合レベルの advance は System Service で分割して掃く(10-model:258)",
      ))
    _ -> Error(Unsupported(where, "未知の verb 規則: " <> name))
  }
}

fn parse_gate(
  expression: glance.Expression,
  phases: List(String),
  where: String,
) -> Result(model.VerbGate, Error) {
  case g.labelled(expression, "at") {
    None -> Ok(model.AnyPhase)
    Some(value) ->
      case constructor_expression(value, where, "Update.at") {
        Ok("AnyPhase") -> Ok(model.AnyPhase)
        Ok("Only") ->
          case g.args(value) {
            [phase_list] -> {
              use names <- result.try(expression_list(phase_list, where, "Only"))
              use names <- result.try(
                list.try_map(names, fn(item) {
                  constructor_expression(item, where, "Only の phase")
                }),
              )
              use _ <- result.try(validate_phases(names, phases, where))
              Ok(model.Only(names))
            }
            _ -> Error(Unsupported(where, "Only の引数が読めない"))
          }
        Ok(name) -> Error(Unsupported(where, "未知の Gate: " <> name))
        Error(error) -> Error(error)
      }
  }
}

fn parse_bump(
  expression: glance.Expression,
  phases: List(String),
  where: String,
) -> Result(model.VerbBump, Error) {
  case g.labelled(expression, "bump") {
    None -> Ok(model.Always)
    Some(value) ->
      case constructor_expression(value, where, "Advance.bump") {
        Ok("Always") -> Ok(model.Always)
        Ok("BumpUnless") ->
          case g.args(value) {
            [from, to] -> {
              use from <- result.try(constructor_expression(
                from,
                where,
                "BumpUnless.from",
              ))
              use to <- result.try(constructor_expression(
                to,
                where,
                "BumpUnless.to",
              ))
              use _ <- result.try(validate_phases([from, to], phases, where))
              Ok(model.BumpUnless(from: from, to: to))
            }
            _ -> Error(Unsupported(where, "BumpUnless の引数が2つでない"))
          }
        Ok(name) -> Error(Unsupported(where, "未知の Bump: " <> name))
        Error(error) -> Error(error)
      }
  }
}

fn parse_order(
  expression: glance.Expression,
  phases: List(String),
  props: List(Prop),
  key_props: List(String),
  entity_name: String,
  where: String,
) -> Result(Option(model.OrderedBy), Error) {
  use name <- result.try(constructor_expression(expression, where, "ordered_by"))
  case name {
    "Order" -> {
      use field_expression <- result.try(
        g.labelled(expression, "field")
        |> option.to_result(Unsupported(where, "ordered_by.field が無い")),
      )
      use field <- result.try(string_expression(
        field_expression,
        where,
        "ordered_by.field",
      ))
      use within_expression <- result.try(
        g.labelled(expression, "within")
        |> option.to_result(Unsupported(where, "ordered_by.within が無い")),
      )
      use within_expressions <- result.try(expression_list(
        within_expression,
        where,
        "ordered_by.within",
      ))
      use within <- result.try(
        list.try_map(within_expressions, fn(item) {
          string_expression(item, where, "ordered_by.within の Property")
        }),
      )
      use _ <- result.try(case within {
        [] -> Error(Unsupported(where, "ordered_by.within が空"))
        _ -> validate_order(field, within, props, where)
      })
      use _ <- result.try(case list.length(key_props) > 1 {
        True ->
          Error(Internal(where, entity_name <> " の複合 key に対する reorder は未実装"))
        False -> Ok(Nil)
      })
      let _ = phases
      Ok(Some(model.OrderedBy(field: field, within: within)))
    }
    _ -> Error(Unsupported(where, "ordered_by が Order でない"))
  }
}

fn validate_phases(
  names: List(String),
  phases: List(String),
  where: String,
) -> Result(Nil, Error) {
  case list.find(names, fn(name) { !list.contains(phases, name) }) {
    Ok(name) -> Error(Unsupported(where, "宣言の phase が無い: " <> name))
    Error(_) -> Ok(Nil)
  }
}

fn validate_update(
  name: String,
  fields: List(String),
  props: List(Prop),
  key_props: List(String),
  where: String,
) -> Result(Nil, Error) {
  case name {
    "" -> Error(Unsupported(where, "Update.name が空"))
    _ ->
      case
        list.find(fields, fn(field) {
          case list.find(props, fn(prop) { prop.name == field }) {
            Error(_) -> True
            Ok(prop) ->
              list.contains(key_props, field)
              || prop.name == "version"
              || is_relation(prop)
          }
        })
      {
        Ok(field) ->
          Error(Unsupported(
            where,
            "Update.fields の Property が書き換え可能でない: " <> field,
          ))
        Error(_) -> Ok(Nil)
      }
  }
}

fn validate_delete_where(
  field: String,
  props: List(Prop),
  where: String,
) -> Result(Nil, Error) {
  case list.find(props, fn(prop) { prop.name == field }) {
    Error(_) ->
      Error(Unsupported(where, "DeleteWhere.field の Property が無い: " <> field))
    Ok(prop) ->
      case is_relation(prop) {
        True -> Error(Unsupported(where, "DeleteWhere.field が親の列: " <> field))
        False -> Ok(Nil)
      }
  }
}

fn validate_order(
  field: String,
  within: List(String),
  props: List(Prop),
  where: String,
) -> Result(Nil, Error) {
  use order_prop <- result.try(
    list.find(props, fn(prop) { prop.name == field })
    |> result.map_error(fn(_) {
      Unsupported(where, "ordered_by.field の Property が無い: " <> field)
    }),
  )
  case is_relation(order_prop) {
    True -> Error(Unsupported(where, "ordered_by.field が親の関係列: " <> field))
    False -> {
      use _ <- result.try(
        list.try_each(within, fn(name) {
          use prop <- result.try(
            list.find(props, fn(prop) { prop.name == name })
            |> result.map_error(fn(_) {
              Unsupported(where, "ordered_by.within の Property が無い: " <> name)
            }),
          )
          case is_relation(prop), prop.repeated {
            True, False -> Ok(Nil)
            True, True ->
              Error(Unsupported(where, "ordered_by.within が複数の関係列: " <> name))
            False, _ ->
              Error(Unsupported(where, "ordered_by.within が範囲の関係列でない: " <> name))
          }
        }),
      )
      Ok(Nil)
    }
  }
}

fn validate_upsert_key(
  fields: List(String),
  props: List(Prop),
  where: String,
) -> Result(Nil, Error) {
  case
    list.find(fields, fn(field) {
      case list.find(props, fn(prop) { prop.name == field }) {
        Ok(prop) -> prop.repeated && is_multi(prop)
        Error(_) -> True
      }
    })
  {
    Ok(field) ->
      Error(Unsupported(where, "upsert_key の Property が無いか複合列: " <> field))
    Error(_) ->
      case list.length(list.unique(fields)) == list.length(fields) {
        True -> Ok(Nil)
        False -> Error(Unsupported(where, "upsert_key に重複した Property がある"))
      }
  }
}

fn is_relation(prop: Prop) -> Bool {
  case prop.kind {
    model.RelProp(..) -> True
    _ -> False
  }
}

fn is_multi(prop: Prop) -> Bool {
  case prop.kind {
    model.RelProp(kind: model.Multi, ..) -> True
    _ -> False
  }
}

fn edges_of(
  module: glance.Module,
  phases: List(String),
  where: String,
) -> Result(List(#(String, String)), Error) {
  case public_constant(module, "edges") {
    None -> Ok([])
    Some(constant) -> {
      use expressions <- result.try(expression_list(
        constant.value,
        where,
        "edges",
      ))
      list.try_map(expressions, fn(expression) {
        case expression {
          glance.Tuple(elements: [from, to], ..) -> {
            use from <- result.try(constructor_expression(
              from,
              where,
              "edges.from",
            ))
            use to <- result.try(constructor_expression(to, where, "edges.to"))
            use _ <- result.try(validate_phases([from, to], phases, where))
            Ok(#(from, to))
          }
          _ -> Error(Unsupported(where, "edges の要素が (from, to) の組でない"))
        }
      })
    }
  }
}

fn prop_of(
  label: String,
  annotation: glance.Type,
  imports: Imports,
  table: Registry,
  unit: Unit,
) -> Prop {
  let #(optional, repeated, kind) =
    prop_kind(annotation, imports, table, unit, False, False)
  model.Prop(name: label, optional: optional, repeated: repeated, kind: kind)
}

fn prop_kind(
  annotation: glance.Type,
  imports: Imports,
  table: Registry,
  unit: Unit,
  optional: Bool,
  repeated: Bool,
) -> #(Bool, Bool, model.PropKind) {
  case annotation {
    glance.NamedType(name: "Option", parameters: [inner], ..) ->
      prop_kind(inner, imports, table, unit, True, repeated)
    glance.NamedType(name: "List", parameters: [inner], ..) ->
      prop_kind(inner, imports, table, unit, optional, True)
    glance.NamedType(name: "Has", parameters: [inner], ..) -> #(
      optional,
      repeated,
      relation(model.Has, inner, imports),
    )
    glance.NamedType(name: "Held", parameters: [inner], ..) -> #(
      optional,
      repeated,
      relation(model.Held, inner, imports),
    )
    glance.NamedType(name: "Link", parameters: [inner], ..) -> #(
      True,
      repeated,
      relation(model.Link, inner, imports),
    )
    glance.NamedType(name: "Multi", parameters: [inner], ..) -> #(
      optional,
      True,
      relation(model.Multi, inner, imports),
    )
    glance.NamedType(name: name, ..) -> {
      let module = module_of_type(annotation, imports)
      let parameters =
        g.type_params(annotation)
        |> list.map(type_shape(_, imports))
      let reference =
        model.TypeRef(module: module, name: name, parameters: parameters)
      let owner = case module {
        Some(path) -> path
        None -> unit.path
      }
      let reference = case module {
        Some(_) -> reference
        None ->
          case dict.get(table, unit.path <> "." <> name) {
            Ok(_) ->
              model.TypeRef(
                module: Some(unit.path),
                name: name,
                parameters: parameters,
              )
            Error(_) -> reference
          }
      }
      let kind = case dict.get(table, owner <> "." <> name) {
        Ok(custom) -> {
          let payloads =
            list.flat_map(custom.variants, fn(variant) {
              list.map(variant.fields, fn(field) {
                let item = g.variant_field_type(field)
                model.TypeRef(
                  module: module_of_type(item, imports),
                  name: option.unwrap(g.type_name(item), "String"),
                  parameters: list.map(g.type_params(item), type_shape(
                    _,
                    imports,
                  )),
                )
              })
            })
          case payloads, custom.variants {
            [], _ -> model.ValueProp(reference)
            _, [_] -> model.ValueProp(reference)
            _, _ -> model.SumProp(reference, payloads)
          }
        }
        Error(_) -> model.ValueProp(reference)
      }
      #(optional, repeated, kind)
    }
    _ -> #(
      optional,
      repeated,
      model.ValueProp(
        model.TypeRef(module: None, name: "String", parameters: []),
      ),
    )
  }
}

fn relation(
  kind: model.RelKind,
  inner: glance.Type,
  imports: Imports,
) -> model.PropKind {
  let target_type = option.unwrap(g.type_name(inner), "Unknown")
  let target_module = case module_of_type(inner, imports) {
    Some(path) -> last_segment(path)
    None -> naming.snake(target_type)
  }
  model.RelProp(
    kind: kind,
    target_module: target_module,
    target_type: target_type,
  )
}

/// Property から列を起こす。関係は `<prop>_id`、構成子を持つ sum は `<prop>_kind` + payload 1本ずつ。
fn fields_of(
  entity_name: String,
  entity_module: String,
  props: List(Prop),
  phases: List(String),
  collection_list: List(model.Collection),
) -> List(model.FieldDef) {
  let from_props =
    list.flat_map(props, fn(prop) {
      let base = entity_name <> naming.pascal(prop.name)
      case prop.kind {
        model.RelProp(kind: model.Multi, ..) -> []
        model.RelProp(
          target_module: target_module,
          target_type: target_type,
          ..,
        ) -> [
          model.FieldDef(
            name: base,
            entity_name: entity_name,
            column: prop.name <> "_id",
            optional: prop.optional,
            repeated: prop.repeated,
            value: model.RelValue(
              target_module: target_module,
              target_type: target_type,
            ),
          ),
        ]
        model.ValueProp(reference) -> [
          model.FieldDef(
            name: base,
            entity_name: entity_name,
            column: property_column(collection_list, prop),
            optional: prop.optional,
            repeated: prop.repeated,
            value: model.TypeValue(reference),
          ),
        ]
        model.SumProp(reference, payloads) -> [
          model.FieldDef(
            name: base <> "Kind",
            entity_name: entity_name,
            column: prop.name <> "_kind",
            optional: prop.optional,
            repeated: False,
            value: model.TypeValue(reference),
          ),
          ..list.map(payloads, fn(payload) {
            model.FieldDef(
              name: entity_name <> payload.name,
              entity_name: entity_name,
              column: naming.snake(payload.name),
              optional: True,
              repeated: False,
              value: model.TypeValue(payload),
            )
          })
        ]
      }
    })
  case phases {
    [] -> from_props
    _ ->
      list.append(from_props, [
        model.FieldDef(
          name: entity_name <> "Phase",
          entity_name: entity_name,
          column: "phase",
          optional: False,
          repeated: False,
          value: model.PhaseValue(entity_module),
        ),
        ..list.map(phases, fn(phase) {
          model.FieldDef(
            name: entity_name <> "Entered" <> phase,
            entity_name: entity_name,
            column: "entered_" <> naming.snake(phase),
            optional: False,
            repeated: False,
            value: model.DatetimeValue,
          )
        })
      ])
  }
}

fn column_of(
  props: List(Prop),
  name: String,
  collection_list: List(model.Collection),
) -> String {
  case list.find(props, fn(prop) { prop.name == name }) {
    Ok(prop) -> property_column(collection_list, prop)
    Error(_) -> name
  }
}

fn verb_fields_of(
  entity_name: String,
  props: List(Prop),
) -> List(model.FieldDef) {
  props
  |> list.filter_map(fn(prop) {
    case prop.kind {
      model.ValueProp(reference) ->
        case reference.name, reference.parameters {
          "Sealed", [_, key] ->
            Ok(model.FieldDef(
              name: entity_name <> naming.pascal(prop.name) <> "KeyId",
              entity_name: entity_name,
              column: prop.name <> "_key_id",
              optional: prop.optional,
              repeated: False,
              value: model.TypeValue(type_ref_of_shape(key)),
            ))
          _, _ -> Error(Nil)
        }
      _ -> Error(Nil)
    }
  })
}

fn type_ref_of_shape(shape: model.TypeShape) -> model.TypeRef {
  case shape {
    model.NamedShape(module: module, name: name, parameters: parameters) ->
      model.TypeRef(module: module, name: name, parameters: parameters)
    model.TupleShape(items) ->
      model.TypeRef(module: None, name: "Tuple", parameters: items)
  }
}

fn property_column(
  collection_list: List(model.Collection),
  prop: Prop,
) -> String {
  case prop.kind {
    model.RelProp(..) -> prop.name <> "_id"
    model.ValueProp(reference) ->
      case is_collection_id_type(collection_list, reference) {
        True -> prop.name <> "_id"
        False -> prop.name
      }
    model.SumProp(..) -> prop.name
  }
}

fn is_collection_id_type(
  collection_list: List(model.Collection),
  reference: model.TypeRef,
) -> Bool {
  case reference.module {
    Some(module) ->
      string.ends_with(reference.name, "Id")
      && list.any(collection_list, fn(collection) {
        collection.module == module
      })
    None -> False
  }
}

/// 矢印。関係 Property 1つにつき1本。逆向きは作らない(20:681)。
pub fn arrows(entities: List(Entity)) -> List(model.Arrow) {
  list.flat_map(entities, fn(entity) {
    list.filter_map(entity.props, fn(prop) {
      case prop.kind {
        model.RelProp(kind: kind, target_module: target, ..) ->
          Ok(model.Arrow(
            name: entity.name <> "To" <> naming.pascal(prop.name),
            from_entity: entity.name,
            prop: prop.name,
            target_entity: naming.pascal(target),
            kind: kind,
            optional: prop.optional,
          ))
        _ -> Error(Nil)
      }
    })
  })
}

// ── entry.gleam ──────────────────────────────────────────────────────────────

/// 入口は無い古い fixture も reader の他の束を検査できるように、entry.gleam が無ければ
/// 空で返す。entry.gleam がある場合は `entries` を全て読み、route 束はそこからだけ導く。
pub fn entry_declarations(
  units: List(Unit),
) -> Result(List(model.Entry), Error) {
  case list.find(units, fn(unit) { unit.path == "entry" }) {
    Error(_) -> Ok([])
    Ok(unit) -> {
      let module = g.in_order(unit.module)
      case public_constant(module, "entries") {
        None -> Error(Unsupported("entry", "pub const entries が無い"))
        Some(constant) -> {
          use expressions <- result.try(expression_list(
            constant.value,
            "entry",
            "entries",
          ))
          list.try_map(expressions, entry_of(_, "entry"))
        }
      }
    }
  }
}

fn entry_of(
  expression: glance.Expression,
  where: String,
) -> Result(model.Entry, Error) {
  case g.ctor_name(expression) {
    Some("Http") -> entry_http(expression, where, model.SessionCredential)
    Some("HttpApi") -> {
      use raw_credential <- result.try(required_expression(
        expression,
        "credential",
        where,
      ))
      use credential <- result.try(credential_of(raw_credential, where))
      entry_http(expression, where, credential)
    }
    Some(name) -> Error(Unsupported(where, "入口の構成子が不明: " <> name))
    None -> Error(Unsupported(where, "入口の構成子が読めない"))
  }
}

fn entry_http(
  expression: glance.Expression,
  where: String,
  credential: model.Credential,
) -> Result(model.Entry, Error) {
  use name <- result.try(required_string(expression, "name", where))
  // 欠落時も全 Service の faces 診断まで集めるため、ここでは空文字として保持する。
  // `entry_notes` が entry 名付きの宣言矛盾にし、exit 0 では通さない。
  use prefix <- result.try(prefix_of(expression, where))
  use admit_expression <- result.try(required_expression(
    expression,
    "admit",
    where,
  ))
  use admit <- result.try(admit_of(admit_expression, where))
  use subject_expression <- result.try(required_expression(
    expression,
    "subject",
    where,
  ))
  use subject <- result.try(entry_subject_of(subject_expression, where))
  use services_expression <- result.try(required_expression(
    expression,
    "services",
    where,
  ))
  use services <- result.try(entry_services_of(services_expression, where))
  Ok(model.Entry(
    name: name,
    prefix: prefix,
    admit: admit,
    subject: subject,
    services: services,
    credential: credential,
  ))
}

fn required_string(
  expression: glance.Expression,
  label: String,
  where: String,
) -> Result(String, Error) {
  case g.labelled(expression, label) {
    Some(value) ->
      g.string_value(value)
      |> option.to_result(Unsupported(where, "入口." <> label <> " が String でない"))
    None -> Error(Unsupported(where, "入口." <> label <> " が無い"))
  }
}

fn required_expression(
  expression: glance.Expression,
  label: String,
  where: String,
) -> Result(glance.Expression, Error) {
  g.labelled(expression, label)
  |> option.to_result(Unsupported(where, "入口." <> label <> " が無い"))
}

fn prefix_of(
  expression: glance.Expression,
  where: String,
) -> Result(String, Error) {
  case g.labelled(expression, "prefix") {
    None -> Ok("")
    Some(value) ->
      g.string_value(value)
      |> option.to_result(Unsupported(where, "入口.prefix が String でない"))
  }
}

fn credential_of(
  expression: glance.Expression,
  where: String,
) -> Result(model.Credential, Error) {
  case g.ctor_name(expression) {
    Some("Session") -> Ok(model.SessionCredential)
    Some("ApiKey") -> Ok(model.ApiKeyCredential)
    Some(name) -> Error(Unsupported(where, "credential が不明: " <> name))
    None -> Error(Unsupported(where, "credential が読めない"))
  }
}

fn admit_of(
  expression: glance.Expression,
  where: String,
) -> Result(model.Admit, Error) {
  case g.ctor_name(expression) {
    Some("Anonymous") -> Ok(model.AnonymousAdmit)
    Some("Authenticated") -> Ok(model.AuthenticatedAdmit)
    Some(name) -> Error(Unsupported(where, "admit が不明: " <> name))
    None -> Error(Unsupported(where, "admit が読めない"))
  }
}

fn entry_subject_of(
  expression: glance.Expression,
  where: String,
) -> Result(model.EntrySubjects, Error) {
  case g.ctor_name(expression) {
    Some("AnySubject") -> Ok(model.AnyEntrySubject)
    Some("Subjects") ->
      case g.args(expression) {
        [list_expression] -> {
          let elements = g.list_elements(list_expression)
          use names <- result.try(
            list.try_map(elements, fn(element) {
              g.ctor_name(element)
              |> option.to_result(Unsupported(where, "Subjects の構成子名が読めない"))
            }),
          )
          Ok(model.NamedEntrySubjects(names))
        }
        _ -> Error(Unsupported(where, "Subjects の引数が List でない"))
      }
    Some(name) -> Error(Unsupported(where, "subject が不明: " <> name))
    None -> Error(Unsupported(where, "subject が読めない"))
  }
}

fn entry_services_of(
  expression: glance.Expression,
  where: String,
) -> Result(model.EntryServices, Error) {
  case g.ctor_name(expression) {
    Some("ReadOnly") -> Ok(model.ReadOnlyServices)
    Some("All") -> Ok(model.AllServices)
    Some(name) -> Error(Unsupported(where, "services が不明: " <> name))
    None -> Error(Unsupported(where, "services が読めない"))
  }
}

// ── service/*.gleam ──────────────────────────────────────────────────────────

pub fn services(units: List(Unit)) -> Result(List(model.Service), Error) {
  units
  |> list.filter(fn(unit) { string.starts_with(unit.path, "service/") })
  |> list.try_map(service_of)
}

fn service_of(unit: Unit) -> Result(model.Service, Error) {
  let module = g.in_order(unit.module)
  let imports = imports_of(module)
  let params = case g.find_custom_type(module, "P") {
    Some(custom) -> list.map(custom.variants, fn(variant) { variant.name })
    None -> []
  }
  use effect <- result.try(effect_of(module, unit.path))
  use #(faces, faces_declared) <- result.try(faces_of(module, unit.path))
  use args <- result.try(args_of(module, imports, unit.path))
  use subjects <- result.try(subjects_of(module, unit.path))
  use queries <- result.try(
    module.constants
    |> list.filter(fn(definition) {
      let constant = definition.definition
      case constant.publicity, constant.annotation {
        glance.Public, Some(annotation) ->
          g.type_name(annotation) == Some("Select")
        _, _ -> False
      }
    })
    |> list.try_map(fn(definition) {
      let constant = definition.definition
      use select <- result.try(parse_select(constant.value, unit.path))
      Ok(model.NamedQuery(name: constant.name, select: select))
    }),
  )
  Ok(model.Service(
    module: last_segment(unit.path),
    out_type: service_out_type(module, unit.path),
    params: params,
    queries: queries,
    args: args,
    allow_module: allow_module_of(module),
    subjects: subjects,
    effect: effect,
    faces: faces,
    faces_declared: faces_declared,
  ))
}

fn service_out_type(
  module: glance.Module,
  unit_path: String,
) -> Option(model.TypeRef) {
  case g.find_constant(module, "service") {
    Some(constant) ->
      case constant.annotation {
        Some(glance.NamedType(name: "Service", parameters: [_, out, _], ..)) ->
          case out {
            glance.NamedType(name: name, parameters: parameters, ..) -> {
              let imports = imports_of(module)
              let path =
                module_of_type(out, imports)
                |> option.unwrap(unit_path)
              Some(model.TypeRef(
                module: Some(path),
                name: name,
                parameters: list.map(parameters, type_shape(_, imports)),
              ))
            }
            _ -> None
          }
        _ -> None
      }
    None -> None
  }
}

fn effect_of(
  module: glance.Module,
  where: String,
) -> Result(model.Effect, Error) {
  case public_constant(module, "effect") {
    None -> Error(Unsupported(where, "Service.effect が無い"))
    Some(constant) ->
      case g.ctor_name(constant.value) {
        Some("Read") -> Ok(model.ReadEffect)
        Some("Write") -> Ok(model.WriteEffect)
        Some(name) -> Error(Unsupported(where, "Service.effect が不明: " <> name))
        None -> Error(Unsupported(where, "Service.effect が読めない"))
      }
  }
}

/// `faces` は ★ の Service に必須。ただし不足は全 Service を診断へ載せるため、ここでは
/// 空の値と「宣言があったか」を分けて返し、矛盾の検査は `entry_notes` でまとめて行う。
fn faces_of(
  module: glance.Module,
  where: String,
) -> Result(#(List(String), Bool), Error) {
  case public_constant(module, "faces") {
    None -> Ok(#([], False))
    Some(constant) ->
      case constant.value {
        glance.List(elements: elements, ..) -> {
          use names <- result.try(
            list.try_map(elements, fn(element) {
              case g.ctor_name(element) {
                Some(name) -> Ok(name)
                None -> Error(Unsupported(where, "Service.faces の面名が読めない"))
              }
            }),
          )
          Ok(#(names, True))
        }
        _ -> Error(Unsupported(where, "Service.faces が List でない"))
      }
  }
}

fn allow_module_of(module: glance.Module) -> Option(String) {
  case
    list.find_map(module.imports, fn(definition) {
      let import_ = definition.definition
      let local = case import_.alias {
        Some(glance.Named(name)) -> name
        _ -> last_segment(import_.module)
      }
      case string.starts_with(import_.module, "gen/allow/"), local == "allow" {
        True, True -> Ok(import_.module)
        _, _ -> Error(Nil)
      }
    })
  {
    Ok(path) -> Some(path)
    Error(_) -> None
  }
}

fn args_of(
  module: glance.Module,
  imports: Imports,
  where: String,
) -> Result(List(model.Arg), Error) {
  case g.find_custom_type(module, "Args") {
    None -> Ok([])
    Some(custom) ->
      case custom.variants {
        [variant] ->
          list.try_map(variant.fields, fn(field) {
            case g.variant_field_label(field) {
              Some(name) ->
                Ok(model.Arg(
                  name: name,
                  type_: type_shape(g.variant_field_type(field), imports),
                ))
              None -> Error(Unsupported(where, "Args の欄に名前が無い"))
            }
          })
        _ -> Error(Unsupported(where, "Args が1構成子でない"))
      }
  }
}

fn subjects_of(
  module: glance.Module,
  where: String,
) -> Result(List(model.Subject), Error) {
  case g.find_constant(module, "service") {
    None -> Ok([])
    Some(service) ->
      case g.labelled(service.value, "allow") {
        None -> Error(Unsupported(where, "Service.allow が無い"))
        Some(value) ->
          case value {
            glance.List(elements: elements, ..) ->
              elements |> list.try_map(subject_of(_, where))
            _ -> Error(Unsupported(where, "Service.allow が List でない"))
          }
      }
  }
}

fn subject_of(
  expression: glance.Expression,
  where: String,
) -> Result(model.Subject, Error) {
  case g.ctor_name(expression) {
    Some("Clause") ->
      case g.labelled(expression, "who") {
        Some(who) -> who_subject(who, where)
        None -> Error(Unsupported(where, "allow.Clause.who が無い"))
      }
    Some(name) -> shorthand_subject(name, where)
    None -> Error(Unsupported(where, "allow の句が読めない"))
  }
}

fn who_subject(
  expression: glance.Expression,
  where: String,
) -> Result(model.Subject, Error) {
  case g.ctor_name(expression) {
    Some("Anyone") -> Ok(model.SubjectAnonymous)
    Some("Party") -> Ok(model.SubjectParty)
    Some("System") -> Ok(model.SubjectSystem)
    Some(name) ->
      case string.starts_with(name, "As") {
        True -> {
          let rest = string.drop_start(name, 2)
          Ok(model.SubjectEntity(
            module: naming.snake(rest),
            type_name: naming.pascal(rest),
          ))
        }
        False ->
          Ok(model.SubjectEntity(
            module: naming.snake(name),
            type_name: naming.pascal(name),
          ))
      }
    None -> Error(Unsupported(where, "allow.Clause.who が読めない"))
  }
}

fn shorthand_subject(
  name: String,
  _where: String,
) -> Result(model.Subject, Error) {
  case name {
    "Anyone" -> Ok(model.SubjectAnonymous)
    "Party" -> Ok(model.SubjectParty)
    "System" -> Ok(model.SubjectSystem)
    _ ->
      Ok(model.SubjectEntity(
        module: naming.snake(name),
        type_name: naming.pascal(name),
      ))
  }
}

/// 入口と Service の結びを検査する。faces の不足は Service ごとに名指しするため、
/// reader の単一 Result ではなく全件の Note として返す。
pub fn entry_notes(app: model.App) -> List(stop.Note) {
  list.append(
    list.filter_map(app.entries, prefix_note),
    list.flat_map(app.services, fn(service) {
      case service.faces_declared {
        False -> [
          stop.Note(
            class: stop.Conflict,
            text: "service." <> service.module <> ": faces const が無い",
          ),
        ]
        True -> face_notes(app.entries, service)
      }
    }),
  )
}

fn prefix_note(entry: model.Entry) -> Result(stop.Note, Nil) {
  case entry.prefix {
    "" ->
      Ok(stop.Note(
        class: stop.Conflict,
        text: "entry." <> entry.name <> ": prefix が無い",
      ))
    prefix ->
      case valid_prefix(prefix) {
        True -> Error(Nil)
        False ->
          Ok(stop.Note(
            class: stop.Conflict,
            text: "entry."
              <> entry.name
              <> ": prefix が不正(`/` で始まる空白の無い1語が必要): "
              <> prefix,
          ))
      }
  }
}

fn valid_prefix(prefix: String) -> Bool {
  string.starts_with(prefix, "/")
  && !string.contains(prefix, " ")
  && !string.contains(prefix, "\t")
  && !string.contains(prefix, "\n")
  && !string.contains(prefix, "\r")
}

fn face_notes(
  entries: List(model.Entry),
  service: model.Service,
) -> List(stop.Note) {
  let known =
    list.filter(service.faces, fn(face) { entry_by_name(entries, face) != None })
  let unknown =
    list.filter(service.faces, fn(face) { entry_by_name(entries, face) == None })
  let unknown_notes =
    list.map(unknown, fn(face) {
      stop.Note(
        class: stop.Conflict,
        text: "service." <> service.module <> ": 未知の面名: " <> face,
      )
    })
  let system_only =
    service.subjects != []
    && list.all(service.subjects, fn(subject) {
      case subject {
        model.SubjectSystem -> True
        _ -> False
      }
    })
  let empty_notes = case service.faces {
    [] ->
      case system_only {
        True -> []
        False -> [
          stop.Note(
            class: stop.Conflict,
            text: "service."
              <> service.module
              <> ": System でない Service の faces が []",
          ),
        ]
      }
    _ ->
      case system_only {
        True -> [
          stop.Note(
            class: stop.Conflict,
            text: "service."
              <> service.module
              <> ": System-only Service が面を名指し: "
              <> string.join(service.faces, ", "),
          ),
        ]
        False -> []
      }
  }
  let subject_notes =
    list.filter_map(service.subjects, fn(subject) {
      case subject {
        model.SubjectEntity(type_name: type_name, ..) ->
          case
            list.any(known, fn(face) {
              case entry_by_name(entries, face) {
                Some(entry) -> entry_accepts(entry.subject, type_name)
                None -> False
              }
            })
          {
            True -> Error(Nil)
            False ->
              Ok(stop.Note(
                class: stop.Conflict,
                text: "service."
                  <> service.module
                  <> ": who As"
                  <> type_name
                  <> " に対応する面が無い: "
                  <> string.join(service.faces, ", "),
              ))
          }
        _ -> Error(Nil)
      }
    })
  let read_only_note = case service.effect, service.faces {
    model.WriteEffect, [_first, ..] ->
      case
        list.filter_map(known, fn(face) {
          case entry_by_name(entries, face) {
            Some(entry) -> Ok(entry)
            None -> Error(Nil)
          }
        })
      {
        [] -> None
        face_entries ->
          case
            list.all(face_entries, fn(entry) {
              entry.services == model.ReadOnlyServices
            })
          {
            True ->
              Some(stop.Note(
                class: stop.Warning,
                text: "service."
                  <> service.module
                  <> ": Write Service の faces が ReadOnly の面だけなので route 0 本: "
                  <> string.join(service.faces, ", "),
              ))
            False -> None
          }
      }
    _, _ -> None
  }
  list.append(
    list.append(unknown_notes, empty_notes),
    list.append(subject_notes, case read_only_note {
      Some(note) -> [note]
      None -> []
    }),
  )
}

fn entry_by_name(
  entries: List(model.Entry),
  name: String,
) -> Option(model.Entry) {
  case list.find(entries, fn(entry) { naming.pascal(entry.name) == name }) {
    Ok(entry) -> Some(entry)
    Error(_) -> None
  }
}

fn entry_accepts(subject: model.EntrySubjects, type_name: String) -> Bool {
  case subject {
    model.AnyEntrySubject -> True
    model.NamedEntrySubjects(names) -> list.contains(names, type_name)
  }
}

fn parse_select(
  expression: glance.Expression,
  where: String,
) -> Result(model.Select, Error) {
  case g.ctor_name(expression) {
    Some("Select") -> plain_select(expression, where)
    // 列の選択。`q.Pick(columns: [q.RosterName, ..], select: q.Select(..))`。
    // select は q.Select を直に書く(const の参照・Pick の入れ子は読まない)。
    Some("Pick") -> {
      use inner <- result.try(
        g.labelled(expression, "select")
        |> option.to_result(Unsupported(where, "Pick の select が無い")),
      )
      use select <- result.try(case g.ctor_name(inner) {
        Some("Select") -> plain_select(inner, where)
        _ -> Error(Unsupported(where, "Pick の select は q.Select(..) を直に書く"))
      })
      use items <- result.try(
        g.labelled(expression, "columns")
        |> option.to_result(Unsupported(where, "Pick の columns が無い")),
      )
      let columns_unread = case items {
        glance.List(rest: Some(_), ..) -> ["columns の spread(..)"]
        _ -> []
      }
      use columns <- result.try(
        g.list_elements(items)
        |> list.try_map(fn(item) {
          g.ctor_name(item)
          |> option.to_result(Unsupported(where, "Pick の columns の項が Field でない"))
        }),
      )
      Ok(
        model.Select(
          ..select,
          columns: Some(columns),
          unshaped: list.append(select.unshaped, columns_unread),
        ),
      )
    }
    _ -> Error(Unsupported(where, "Select の構成子でない"))
  }
}

fn plain_select(
  expression: glance.Expression,
  where: String,
) -> Result(model.Select, Error) {
  use from <- result.try(
    g.labelled(expression, "from")
    |> option.then(g.ctor_name)
    |> option.to_result(Unsupported(where, "from が読めない")),
  )
  let #(join, join_unread) = arrow_names(expression, "join")
  let #(with, with_unread) = arrow_names(expression, "with")
  let shape_unread =
    list.flat_map(select_lists, fn(label) { literal_unread(expression, label) })
  Ok(model.Select(
    from: from,
    join: join,
    where: conds(expression, "where"),
    group: groups(expression, "group"),
    having: havings(expression, "having"),
    agg: aggs(expression, "agg"),
    along: alongs(expression, "along"),
    with: with,
    order: orders(expression, "order"),
    limit: limit(expression),
    unread: list.append(join_unread, with_unread),
    unshaped: list.append(shape_unread, where_unread(expression)),
    columns: None,
  ))
}

/// Select の List の欄。
const select_lists = [
  "join", "where", "group", "having", "agg", "along", "with", "order",
]

/// 欄が List の literal でない(定数の参照など)か、spread(`..rest`)を持つ。
/// 読みは literal の項しか辿れないので、そのまま読むと項が黙って落ちる ──
/// `where` なら絞りが消えて返る行が増え、`join` / `with` なら欄が消える。
/// 捨てずに `unshaped` に残し、SQL 層で exit 4 にする。
fn literal_unread(
  expression: glance.Expression,
  label: String,
) -> List(String) {
  case g.labelled(expression, label) {
    None -> []
    Some(glance.List(rest: None, ..)) -> []
    Some(glance.List(rest: Some(_), ..)) -> [label <> " の spread(..)"]
    Some(_) -> [label <> " が List の literal でない"]
  }
}

/// `where` の項のうち条件として読めないもの。`Has` / `HasNone` の中の List も辿る。
/// 読めない条件を落とすと絞りが緩むので、捨てずに名指しする。
fn where_unread(expression: glance.Expression) -> List(String) {
  case g.labelled(expression, "where") {
    Some(glance.List(elements: elements, ..)) -> cond_unread(elements, "where")
    _ -> []
  }
}

fn cond_unread(items: List(glance.Expression), place: String) -> List(String) {
  items
  |> list.index_map(fn(item, index) {
    let here = place <> " の " <> int.to_string(index + 1) <> " 番目"
    case cond(item) {
      None -> [here <> "(条件として読めない)"]
      Some(_) ->
        case g.ctor_name(item), g.args(item) {
          Some("Has"), [_, inner] | Some("HasNone"), [_, inner] ->
            case inner {
              glance.List(elements: elements, rest: None, ..) ->
                cond_unread(elements, here)
              glance.List(rest: Some(_), ..) -> [here <> " の spread(..)"]
              _ -> [here <> " の条件が List の literal でない"]
            }
          _, _ -> []
        }
    }
  })
  |> list.flatten
}

fn labelled_list(
  expression: glance.Expression,
  label: String,
) -> List(glance.Expression) {
  case g.labelled(expression, label) {
    Some(item) -> g.list_elements(item)
    None -> []
  }
}

/// 矢印の名と、矢印として読めなかった項(`<label> <位置>番目` の形)。
/// 読めない項は捨てずに返す ── SQL 層と型の層のどちらでも exit 4 で名指しするため。
fn arrow_names(
  expression: glance.Expression,
  label: String,
) -> #(List(String), List(String)) {
  labelled_list(expression, label)
  |> list.index_map(fn(item, index) { #(item, index) })
  |> list.fold(#([], []), fn(acc, entry) {
    let #(names, unread) = acc
    let #(item, index) = entry
    let constructor = case item {
      glance.FieldAccess(..) | glance.Variable(..) ->
        g.ctor_name(item)
        |> option.then(fn(name) {
          case naming.capitalise(name) == name {
            True -> Some(name)
            False -> None
          }
        })
      _ -> None
    }
    case constructor {
      Some(name) -> #(list.append(names, [name]), unread)
      None -> #(
        names,
        list.append(unread, [
          label <> " の " <> int.to_string(index + 1) <> " 番目",
        ]),
      )
    }
  })
}

fn field_name(expression: glance.Expression) -> String {
  option.unwrap(g.ctor_name(expression), "Unknown")
}

fn operand(expression: glance.Expression) -> model.Operand {
  let name = option.unwrap(g.ctor_name(expression), "Unknown")
  let arguments = g.args(expression)
  case name, arguments {
    "Param", [item] -> model.OpParam(field_name(item))
    "Num", [item] ->
      model.OpNum(
        g.int_value(item)
        |> option.then(fn(text) { int.parse(text) |> option.from_result })
        |> option.unwrap(0),
      )
    "Str", [item] -> model.OpStr(option.unwrap(g.string_value(item), ""))
    "At", [item] -> model.OpAt(field_name(item))
    "Col", [item] -> model.OpCol(field_name(item))
    _, [item] ->
      case
        string.starts_with(name, "PhaseOf"),
        string.starts_with(name, "KeyOf")
      {
        True, _ ->
          model.OpPhase(
            entity: string.drop_start(name, 7),
            variant: option.unwrap(g.ctor_name(item), "Unknown"),
          )
        _, True -> model.OpKey(entity: string.drop_start(name, 5))
        _, _ -> model.OpStr("")
      }
    _, _ -> model.OpStr("")
  }
}

fn cond(expression: glance.Expression) -> Option(model.Cond) {
  let name = option.unwrap(g.ctor_name(expression), "Unknown")
  case name, g.args(expression) {
    "Eq", [field, value] -> Some(model.CEq(field_name(field), operand(value)))
    "Ne", [field, value] -> Some(model.CNe(field_name(field), operand(value)))
    "Lt", [field, value] -> Some(model.CLt(field_name(field), operand(value)))
    "Le", [field, value] -> Some(model.CLe(field_name(field), operand(value)))
    "Gt", [field, value] -> Some(model.CGt(field_name(field), operand(value)))
    "Ge", [field, value] -> Some(model.CGe(field_name(field), operand(value)))
    "In", [field, value] -> Some(model.CIn(field_name(field), operand(value)))
    "Contains", [field, value] ->
      Some(model.CContains(field_name(field), operand(value)))
    "IsNull", [field] -> Some(model.CIsNull(field_name(field)))
    "NotNull", [field] -> Some(model.CNotNull(field_name(field)))
    "IsTrue", [field] -> Some(model.CIsTrue(field_name(field)))
    "EqOrNull", [field, value] ->
      Some(model.CEqOrNull(field_name(field), operand(value)))
    "CurrentVersion", [left, right] ->
      Some(model.CCurrentVersion(field_name(left), field_name(right)))
    "Has", [arrow, inner] ->
      Some(model.CHas(field_name(arrow), conds_of(inner)))
    "HasNone", [arrow, inner] ->
      Some(model.CHasNone(field_name(arrow), conds_of(inner)))
    _, _ -> None
  }
}

fn conds_of(expression: glance.Expression) -> List(model.Cond) {
  g.list_elements(expression)
  |> list.filter_map(fn(item) { cond(item) |> option.to_result(Nil) })
}

fn conds(expression: glance.Expression, label: String) -> List(model.Cond) {
  labelled_list(expression, label)
  |> list.filter_map(fn(item) { cond(item) |> option.to_result(Nil) })
}

fn agg(expression: glance.Expression) -> model.Agg {
  case option.unwrap(g.ctor_name(expression), "Count"), g.args(expression) {
    "Count", _ -> model.ACount
    "Sum", [field] -> model.ASum(field_name(field))
    "Min", [field] -> model.AMin(field_name(field))
    "Max", [field] -> model.AMax(field_name(field))
    "Avg", [field] -> model.AAvg(field_name(field))
    _, _ -> model.ACount
  }
}

fn aggs(expression: glance.Expression, label: String) -> List(model.Agg) {
  labelled_list(expression, label) |> list.map(agg)
}

fn group(expression: glance.Expression) -> Option(model.Group) {
  case option.unwrap(g.ctor_name(expression), ""), g.args(expression) {
    "ByField", [field] -> Some(model.GByField(field_name(field)))
    "Bucket", [field, unit] ->
      Some(model.GBucket(field_name(field), field_name(unit)))
    "Via", [arrow] -> Some(model.GVia(field_name(arrow)))
    _, _ -> None
  }
}

fn groups(expression: glance.Expression, label: String) -> List(model.Group) {
  labelled_list(expression, label)
  |> list.filter_map(fn(item) { group(item) |> option.to_result(Nil) })
}

fn havings(
  expression: glance.Expression,
  label: String,
) -> List(#(String, model.Agg, model.Operand)) {
  labelled_list(expression, label)
  |> list.filter_map(fn(item) {
    case option.unwrap(g.ctor_name(item), ""), g.args(item) {
      name, [left, right] -> Ok(#(name, agg(left), operand(right)))
      _, _ -> Error(Nil)
    }
  })
}

fn orders(expression: glance.Expression, label: String) -> List(model.Order) {
  labelled_list(expression, label)
  |> list.filter_map(fn(item) {
    case option.unwrap(g.ctor_name(item), ""), g.args(item) {
      "Asc", [field] -> Ok(model.OAsc(field_name(field)))
      "Desc", [field] -> Ok(model.ODesc(field_name(field)))
      "AscAgg", [value] -> Ok(model.OAscAgg(agg(value)))
      "DescAgg", [value] -> Ok(model.ODescAgg(agg(value)))
      "Nearest", [field, value] ->
        Ok(model.ONearest(field_name(field), operand(value)))
      _, _ -> Error(Nil)
    }
  })
}

fn alongs(expression: glance.Expression, label: String) -> List(model.Along) {
  labelled_list(expression, label)
  |> list.filter_map(fn(item) {
    case option.unwrap(g.ctor_name(item), ""), g.args(item) {
      "Distance", _ -> Ok(model.LDistance)
      "Rank", _ -> Ok(model.LRank)
      "Running", [value, ..] -> Ok(model.LRunning(agg(value)))
      _, _ -> Error(Nil)
    }
  })
}

fn limit(expression: glance.Expression) -> model.Limit {
  case g.labelled(expression, "limit") {
    None -> model.LNoLimit
    Some(item) ->
      case option.unwrap(g.ctor_name(item), "NoLimit") {
        "NoLimit" -> model.LNoLimit
        "Paged" -> {
          let size =
            g.labelled(item, "size")
            |> option.map(operand)
            |> option.unwrap(model.OpNum(20))
          let after =
            g.labelled(item, "after")
            |> option.map(operand)
            |> option.unwrap(model.OpNum(0))
          model.LPaged(size: size, after: after)
        }
        "First" ->
          case g.args(item) {
            [value] ->
              model.LFirst(
                g.int_value(value)
                |> option.then(fn(text) {
                  int.parse(text) |> option.from_result
                })
                |> option.unwrap(1),
              )
            _ -> model.LFirst(1)
          }
        "FirstPerGroup" ->
          case g.args(item) {
            [value, by] ->
              model.LFirstPerGroup(
                g.int_value(value)
                  |> option.then(fn(text) {
                    int.parse(text) |> option.from_result
                  })
                  |> option.unwrap(1),
                option.unwrap(group(by), model.GByField("Unknown")),
              )
            _ -> model.LNoLimit
          }
        _ -> model.LNoLimit
      }
  }
}

// ── 全体 ────────────────────────────────────────────────────────────────────

pub fn read(units: List(Unit)) -> Result(App, Error) {
  use types <- result.try(value_types(units))
  use collection_list <- result.try(collections(units))
  use entity_list <- result.try(entities_with_collections(
    units,
    collection_list,
  ))
  use _ <- result.try(validate_order_columns(entity_list, types))
  use _ <- result.try(validate_relation_shapes(entity_list))
  use service_list <- result.try(services(units))
  use entry_list <- result.try(entry_declarations(units))
  use external_handwritten <- result.try(external_handwritten_verbs(
    units,
    entity_list,
  ))
  use external_manual <- result.try(external_manual_verbs(units, entity_list))
  let arrow_list = arrows(entity_list)
  Ok(model.App(
    value_types: types,
    entities: entity_list,
    collections: collection_list,
    services: service_list,
    arrows: arrow_list,
    reverse_arrows: relation.reverse_arrows(
      entity_list,
      arrow_list,
      service_list,
    ),
    clauses: clauses.read(units),
    entries: entry_list,
    attached: [],
    handwritten_verbs: external_handwritten,
    manual_verbs: external_manual,
  ))
}

/// ER の外のトップレベル module の `manual_verbs`。
fn external_manual_verbs(
  units: List(Unit),
  entities: List(Entity),
) -> Result(List(#(String, List(String))), Error) {
  let entity_names = list.map(entities, fn(entity) { entity.module })
  units
  |> list.filter(fn(unit) {
    !string.contains(unit.path, "/") && !list.contains(entity_names, unit.path)
  })
  |> list.try_map(fn(unit) {
    let module = g.in_order(unit.module)
    use verbs <- result.try(manual_verbs_of(module, unit.path))
    Ok(#(unit.path, verbs))
  })
  |> result.map(fn(entries) {
    entries
    |> list.filter(fn(entry) { entry.1 != [] })
  })
}

fn external_handwritten_verbs(
  units: List(Unit),
  entities: List(Entity),
) -> Result(List(#(String, List(String))), Error) {
  let entity_names = list.map(entities, fn(entity) { entity.module })
  units
  |> list.filter(fn(unit) {
    !string.contains(unit.path, "/") && !list.contains(entity_names, unit.path)
  })
  |> list.try_map(fn(unit) {
    let module = g.in_order(unit.module)
    use verbs <- result.try(handwritten_verbs_of(module, unit.path))
    Ok(#(unit.path, verbs))
  })
  |> result.map(fn(entries) {
    entries
    |> list.filter(fn(entry) { entry.1 != [] })
  })
}

/// `ordered_by.field` は整数の列に限る(`Int` か `Range` の値型、Option / List でない)。
/// reorder は宣言の値域の中で一時値を選ぶので、値域が読めない列には SQL を出さず名指しで止める。
fn validate_order_columns(
  entities: List(Entity),
  types: List(ValueType),
) -> Result(Nil, Error) {
  list.try_each(entities, fn(entity) {
    case entity.ordered_by {
      None -> Ok(Nil)
      Some(ordered) -> {
        let where = "entity/" <> entity.module
        case model.prop_by_name(entity, ordered.field) {
          None ->
            Error(Unsupported(
              where,
              "ordered_by.field の Property が無い: " <> ordered.field,
            ))
          Some(prop) ->
            case prop.optional, prop.repeated, model.order_bounds(prop, types) {
              True, _, _ ->
                Error(Unsupported(
                  where,
                  "ordered_by.field が Option の列: "
                    <> ordered.field
                    <> "(順序列は必須の整数に限る)",
                ))
              _, True, _ ->
                Error(Unsupported(
                  where,
                  "ordered_by.field が List の列: "
                    <> ordered.field
                    <> "(順序列は必須の整数に限る)",
                ))
              False, False, Some(#(lo, hi)) ->
                case hi >= int.max(lo, 0) {
                  True -> Ok(Nil)
                  False ->
                    Error(Unsupported(
                      where,
                      "ordered_by.field の値域に確定値の起点が無い: "
                        <> ordered.field
                        <> "(Range の max が "
                        <> int.to_string(int.max(lo, 0))
                        <> " より小さい)",
                    ))
                }
              False, False, None ->
                Error(Unsupported(
                  where,
                  "ordered_by.field が整数の列でない: "
                    <> ordered.field
                    <> "("
                    <> prop_type_label(prop)
                    <> ")── reorder は Int か Range の値型にだけ出せる",
                ))
            }
        }
      }
    }
  })
}

fn prop_type_label(prop: Prop) -> String {
  case prop.kind {
    model.ValueProp(type_ref: reference)
    | model.SumProp(type_ref: reference, ..) -> reference.name
    model.RelProp(target_type: target, ..) -> target
  }
}

/// 関係の List は `Multi` で宣言する。`List(Has(..))` / `List(Held(..))` / `List(Link(..))` は矢印の 3 形
/// (必須 / 任意 / 複数)のどれにも写らないので、生成せずに名指しで止める。
fn validate_relation_shapes(entities: List(Entity)) -> Result(Nil, Error) {
  list.try_each(entities, fn(entity) {
    list.try_each(entity.props, fn(prop) {
      case prop.repeated, prop.kind {
        True, model.RelProp(kind: kind, ..) if kind != model.Multi ->
          Error(Unsupported(
            "entity/" <> entity.module,
            "関係の List は Multi で宣言する: " <> prop.name,
          ))
        _, _ -> Ok(Nil)
      }
    })
  })
}
