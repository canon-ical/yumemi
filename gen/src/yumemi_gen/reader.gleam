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
import yumemi_gen/source.{type Unit}

pub type Error {
  NoTypesModule
  NoKeyFunction(module: String)
  NoEntityType(module: String)
  Unsupported(where: String, detail: String)
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
fn module_of_type(
  annotation: glance.Type,
  imports: Imports,
) -> Option(String) {
  case annotation {
    glance.NamedType(name: name, module: module, ..) ->
      case module {
        Some(local) -> dict.get(imports.qualified, local) |> option.from_result
        None -> dict.get(imports.unqualified, name) |> option.from_result
      }
    _ -> None
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
  let table = registry(units)
  units
  |> list.filter(fn(unit) { string.starts_with(unit.path, "entity/") })
  |> list.try_map(entity_of(_, table))
}

fn entity_of(unit: Unit, table: Registry) -> Result(Entity, Error) {
  let module = g.in_order(unit.module)
  let imports = imports_of(module)
  let name = last_segment(unit.path)
  use key_fn <- result.try(
    g.find_function(module, "key")
    |> option.to_result(NoKeyFunction(unit.path)),
  )
  use record_name <- result.try(case key_fn.parameters {
    [glance.FunctionParameter(type_: Some(annotation), ..), ..] ->
      g.type_name(annotation) |> option.to_result(NoEntityType(unit.path))
    _ -> Error(NoEntityType(unit.path))
  })
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
          Ok(prop_of(label, g.variant_field_type(field), imports, table, unit))
        None -> Error(Nil)
      }
    })
  let phases = case g.find_custom_type(module, "Phase") {
    Some(phase) -> list.map(phase.variants, fn(variant) { variant.name })
    None -> []
  }
  let key_prop = key_property(key_fn)
  let entity_name = naming.pascal(name)
  let fields = fields_of(entity_name, name, props, phases)
  let key_column = column_of(props, key_prop)
  let collection = case g.find_constant(module, "collection") {
    Some(constant) -> option.unwrap(g.string_value(constant.value), name)
    None -> name
  }
  Ok(model.Entity(
    module: name,
    name: entity_name,
    type_name: record_name,
    table: name,
    props: props,
    fields: fields,
    phases: phases,
    key_prop: key_prop,
    key_column: key_column,
    collection: collection,
    subject: g.find_constant(module, "subject") != None,
  ))
}

fn key_property(key_fn: glance.Function) -> String {
  case key_fn.body {
    [glance.Expression(glance.FieldAccess(label: label, ..))] -> label
    [glance.Expression(glance.Tuple(elements: [first, ..], ..))] ->
      case first {
        glance.FieldAccess(label: label, ..) -> label
        _ -> "id"
      }
    _ -> "id"
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
      let reference = model.TypeRef(module: module, name: name)
      let owner = case module {
        Some(path) -> path
        None -> unit.path
      }
      let reference = case module {
        Some(_) -> reference
        None ->
          case dict.get(table, unit.path <> "." <> name) {
            Ok(_) -> model.TypeRef(module: Some(unit.path), name: name)
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
    _ -> #(optional, repeated, model.ValueProp(
      model.TypeRef(module: None, name: "String"),
    ))
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
) -> List(model.FieldDef) {
  let from_props =
    list.flat_map(props, fn(prop) {
      let base = entity_name <> naming.pascal(prop.name)
      case prop.kind {
        model.RelProp(kind: model.Multi, ..) -> []
        model.RelProp(target_module: target_module, target_type: target_type, ..) -> [
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
            column: prop.name,
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

fn column_of(props: List(Prop), name: String) -> String {
  case list.find(props, fn(prop) { prop.name == name }) {
    Ok(model.Prop(kind: model.RelProp(..), ..)) -> name <> "_id"
    _ -> name
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

// ── service/*.gleam ──────────────────────────────────────────────────────────

pub fn services(units: List(Unit)) -> Result(List(model.Service), Error) {
  units
  |> list.filter(fn(unit) { string.starts_with(unit.path, "service/") })
  |> list.try_map(service_of)
}

fn service_of(unit: Unit) -> Result(model.Service, Error) {
  let module = g.in_order(unit.module)
  let params = case g.find_custom_type(module, "P") {
    Some(custom) -> list.map(custom.variants, fn(variant) { variant.name })
    None -> []
  }
  use queries <- result.try(
    module.constants
    |> list.filter(fn(definition) {
      let constant = definition.definition
      case constant.publicity, constant.annotation {
        glance.Public, Some(annotation) -> g.type_name(annotation) == Some(
          "Select",
        )
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
    params: params,
    queries: queries,
  ))
}

fn parse_select(
  expression: glance.Expression,
  where: String,
) -> Result(model.Select, Error) {
  case g.ctor_name(expression) {
    Some("Select") -> {
      use from <- result.try(
        g.labelled(expression, "from")
        |> option.then(g.ctor_name)
        |> option.to_result(Unsupported(where, "from が読めない")),
      )
      Ok(model.Select(
        from: from,
        join: arrow_names(expression, "join"),
        where: conds(expression, "where"),
        group: groups(expression, "group"),
        having: havings(expression, "having"),
        agg: aggs(expression, "agg"),
        along: alongs(expression, "along"),
        with: arrow_names(expression, "with"),
        order: orders(expression, "order"),
        limit: limit(expression),
      ))
    }
    _ -> Error(Unsupported(where, "Select の構成子でない"))
  }
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

fn arrow_names(
  expression: glance.Expression,
  label: String,
) -> List(String) {
  labelled_list(expression, label)
  |> list.filter_map(fn(item) { g.ctor_name(item) |> option.to_result(Nil) })
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
      case string.starts_with(name, "PhaseOf"), string.starts_with(name, "KeyOf") {
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
  g.list_elements(expression) |> list.filter_map(fn(item) {
    cond(item) |> option.to_result(Nil)
  })
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
                |> option.then(fn(text) { int.parse(text) |> option.from_result })
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
  use entity_list <- result.try(entities(units))
  use service_list <- result.try(services(units))
  Ok(model.App(
    value_types: types,
    entities: entity_list,
    services: service_list,
    arrows: arrows(entity_list),
  ))
}
