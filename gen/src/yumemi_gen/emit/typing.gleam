//// クエリ値から戻りの型と穴の型を静的に導く。判断は入らない(20「規則は7つ」)。

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import yumemi_gen/model.{type App, type NamedQuery, type Select}
import yumemi_gen/naming
import yumemi_gen/relation

/// 型の木。module は import の道。render で修飾するかを決める。
pub type Ty {
  TyRef(module: Option(String), name: String)
  TyApp(head: Ty, args: List(Ty))
  TyTuple(List(Ty))
}

pub fn option(inner: Ty) -> Ty {
  TyApp(TyRef(Some("gleam/option"), "Option"), [inner])
}

pub fn list_of(inner: Ty) -> Ty {
  TyApp(TyRef(None, "List"), [inner])
}

pub fn page(inner: Ty) -> Ty {
  TyApp(TyRef(Some("framework/page"), "Page"), [inner])
}

pub fn key_of(inner: Ty) -> Ty {
  TyApp(TyRef(Some("framework/er"), "Key"), [inner])
}

pub const int_ty = TyRef(None, "Int")

pub const float_ty = TyRef(None, "Float")

/// model の型参照を出力用の型木へ戻す。Property の型引数もここで保持する。
pub fn type_ref(reference: model.TypeRef) -> Ty {
  let head = TyRef(reference.module, reference.name)
  apply(head, list.map(reference.parameters, type_shape))
}

fn type_shape(shape: model.TypeShape) -> Ty {
  case shape {
    model.NamedShape(module: module, name: name, parameters: parameters) ->
      apply(TyRef(module, name), list.map(parameters, type_shape))
    model.TupleShape(items) -> TyTuple(list.map(items, type_shape))
  }
}

fn apply(head: Ty, args: List(Ty)) -> Ty {
  case args {
    [] -> head
    _ -> TyApp(head, args)
  }
}

pub fn datetime() -> Ty {
  TyRef(Some("framework/time"), "Datetime")
}

pub fn date() -> Ty {
  TyRef(Some("framework/time"), "Date")
}

pub fn cursor() -> Ty {
  TyRef(Some("framework/page"), "Cursor")
}

/// 木に現れる module の道を全部集める。
pub fn modules(ty: Ty) -> List(String) {
  case ty {
    TyRef(module: Some(path), ..) -> [path]
    TyRef(module: None, ..) -> []
    TyApp(head: head, args: args) ->
      list.append(modules(head), list.flat_map(args, modules))
    TyTuple(items) -> list.flat_map(items, modules)
  }
}

/// entity/* の道だけ。修飾の判断に使う。
pub fn entity_modules(ty: Ty) -> List(String) {
  modules(ty) |> list.filter(string.starts_with(_, "entity/"))
}

// ── 列 → 型 ─────────────────────────────────────────────────────────────────

/// 列の基底型。Option は剥がした形。
pub fn field_base(app: App, field_name: String) -> Ty {
  case model.field_by_name(app.entities, field_name) {
    None -> TyRef(None, "String")
    Some(field) ->
      case field.value {
        model.RelValue(target_module: target_module, target_type: target_type) ->
          key_of(TyRef(Some("entity/" <> target_module), target_type))
        model.TypeValue(reference) -> type_ref(reference)
        model.PhaseValue(module) -> TyRef(Some("entity/" <> module), "Phase")
        model.DatetimeValue -> datetime()
      }
  }
}

pub fn field_optional(app: App, field_name: String) -> Bool {
  case model.field_by_name(app.entities, field_name) {
    Some(field) -> field.optional
    None -> False
  }
}

// ── 行の型 ──────────────────────────────────────────────────────────────────

fn entity_ty(app: App, entity_name: String) -> Option(Ty) {
  case model.entity_by_name(app.entities, entity_name) {
    Some(entity) ->
      Some(TyRef(Some("entity/" <> entity.module), entity.type_name))
    None -> None
  }
}

fn entity_row(app: App, entity_name: String) -> List(Ty) {
  case model.entity_by_name(app.entities, entity_name) {
    None -> []
    Some(entity) -> {
      let base = TyRef(Some("entity/" <> entity.module), entity.type_name)
      case model.has_lifecycle(entity) {
        True -> [base, TyRef(Some("entity/" <> entity.module), "Phase")]
        False -> [base]
      }
    }
  }
}

/// 1行の型。from の Entity(Lifecycle があれば相を添える)+ join した Entity +
/// with で畳んだ子の List + along の値。並びは SQL の SELECT 句と同じ。
/// 列を選んだ読み(`q.Pick`)は、選んだ列の record(`picked_name`)。
/// join / with の項は SQL 層と同じ `relation` で解く。解けない項はここでは落とすが、
/// SQL 層が同じ理由で exit 4 / 1 を出す(片方だけ通ることは無い)。
pub fn row(app: App, query: NamedQuery) -> Ty {
  case query.select.columns {
    Some(_) -> TyRef(None, picked_name(query.name))
    None -> whole_row(app, query.select)
  }
}

fn whole_row(app: App, select: Select) -> Ty {
  let base = entity_row(app, select.from)
  let joined =
    list.flat_map(select.join, fn(arrow_name) {
      case relation.join_arrow(app, arrow_name) {
        Ok(arrow) -> entity_row(app, arrow.target_entity)
        Error(_) -> []
      }
    })
  let children = with_types(app, select)
  let added = along_types(app, select)
  case
    list.flatten([base, joined, list.map(children, fn(pair) { pair.1 }), added])
  {
    [single] -> single
    items -> TyTuple(items)
  }
}

/// with で畳んだ子。欄の名(SQL の `AS`)と `List(子)`。
pub fn with_types(app: App, select: Select) -> List(#(String, Ty)) {
  case model.entity_by_name(app.entities, select.from) {
    None -> []
    Some(from) ->
      list.filter_map(select.with, fn(name) {
        case relation.with_arrow(app.entities, app.arrows, from, name) {
          Ok(arrow) ->
            case entity_ty(app, arrow.target_entity) {
              Some(child) ->
                Ok(#(relation.with_output(from, name), list_of(child)))
              None -> Error(Nil)
            }
          Error(_) -> Error(Nil)
        }
      })
  }
}

fn along_types(app: App, select: Select) -> List(Ty) {
  list.map(select.along, fn(along) {
    case along {
      model.LDistance -> float_ty
      model.LRank -> int_ty
      model.LRunning(value) -> agg_base(app, value)
    }
  })
}

// ── 列の選択(`q.Pick`)───────────────────────────────────────────────────────

/// 列を選んだ読みの record 型の名。`listed` -> `ListedRow`。reads module に置く。
pub fn picked_name(query_name: String) -> String {
  naming.pascal(query_name) <> "Row"
}

/// 選んだ列の欄の名。from の列は Property の名(`RosterName` -> `name`)、
/// join した Entity の列は Entity の名を前に付ける(`StoreName` -> `store_name`)。
/// SQL は同じ名で `AS` を付けて返す ── 行の JSON の欄名と record の欄名は一致する。
pub fn picked_label(app: App, select: Select, field_name: String) -> String {
  case model.field_by_name(app.entities, field_name) {
    Some(field) ->
      case field.entity_name == select.from {
        True ->
          naming.snake(string.drop_start(
            field.name,
            string.length(field.entity_name),
          ))
        False -> naming.snake(field.name)
      }
    None -> naming.snake(field_name)
  }
}

/// 列の型。Option / List の列はその形のまま。
pub fn column_ty(app: App, field_name: String) -> Ty {
  let base = field_base(app, field_name)
  case model.field_by_name(app.entities, field_name) {
    Some(field) -> {
      let repeated = case field.repeated {
        True -> list_of(base)
        False -> base
      }
      case field.optional {
        True -> option(repeated)
        False -> repeated
      }
    }
    None -> base
  }
}

/// record の欄(名と型)。選んだ列 + with の子 + along の値の順。SQL の SELECT 句と同じ並び。
pub fn picked_fields(app: App, select: Select) -> List(#(String, Ty)) {
  let columns =
    option.unwrap(select.columns, [])
    |> list.map(fn(field_name) {
      #(picked_label(app, select, field_name), column_ty(app, field_name))
    })
  let alongs =
    list.map(select.along, fn(along) {
      case along {
        model.LDistance -> #("distance", float_ty)
        model.LRank -> #("rank", int_ty)
        model.LRunning(value) -> #("running", agg_base(app, value))
      }
    })
  list.flatten([columns, with_types(app, select), alongs])
}

fn agg_base(app: App, value: model.Agg) -> Ty {
  case value {
    model.ACount -> int_ty
    model.ASum(field) -> field_base(app, field)
    model.AMin(field) -> field_base(app, field)
    model.AMax(field) -> field_base(app, field)
    model.AAvg(_) -> float_ty
  }
}

/// 集約の型。Count だけ空集合でも 0 なので Option を被せない。
pub fn agg_ty(app: App, value: model.Agg) -> Ty {
  case value {
    model.ACount -> int_ty
    _ -> option(agg_base(app, value))
  }
}

fn group_ty(app: App, value: model.Group) -> Ty {
  case value {
    model.GByField(field) ->
      case field_optional(app, field) {
        True -> option(field_base(app, field))
        False -> field_base(app, field)
      }
    model.GBucket(..) -> date()
    model.GVia(arrow_name) ->
      case model.arrow_by_name(app.arrows, arrow_name) {
        Some(arrow) ->
          option.unwrap(
            entity_ty(app, arrow.target_entity),
            TyRef(None, "String"),
          )
        None -> TyRef(None, "String")
      }
  }
}

/// 戻りの型。20「read 関数の戻りの型はクエリ値から静的に導く」の表そのまま。
pub fn out(app: App, query: NamedQuery) -> Ty {
  let select = query.select
  case select.group, select.agg {
    [], [] -> {
      let single = row(app, query)
      case select.limit {
        model.LPaged(..) -> page(single)
        model.LFirst(1) -> option(single)
        model.LFirst(_) -> list_of(single)
        model.LNoLimit -> list_of(single)
        model.LFirstPerGroup(_, by) ->
          list_of(TyTuple([group_ty(app, by), list_of(single)]))
      }
    }
    [], aggs ->
      case aggs {
        [single] -> agg_ty(app, single)
        many -> TyTuple(list.map(many, agg_ty(app, _)))
      }
    groups, aggs ->
      list_of(
        TyTuple(list.append(
          list.map(groups, group_ty(app, _)),
          list.map(aggs, agg_ty(app, _)),
        )),
      )
  }
}

// ── 穴の型 ──────────────────────────────────────────────────────────────────

pub type Param {
  Param(label: String, ty: Ty)
}

/// 穴の並びは、クエリ値の中で最初に現れた順。P の宣言順ではない。
pub fn params(app: App, select: Select) -> List(Param) {
  let found =
    list.flatten([
      list.flat_map(select.where, cond_params(app, _)),
      list.flat_map(select.having, fn(entry) {
        let #(_, value, operand) = entry
        case operand {
          model.OpParam(name) -> [Param(naming.snake(name), agg_ty(app, value))]
          _ -> []
        }
      }),
      list.flat_map(select.order, fn(order) {
        case order {
          model.ONearest(field, model.OpParam(name)) -> [
            Param(naming.snake(name), field_base(app, field)),
          ]
          _ -> []
        }
      }),
      limit_params(app, select.limit),
    ])
  dedupe(found, [])
}

fn limit_params(app: App, limit: model.Limit) -> List(Param) {
  case limit {
    model.LPaged(size: size, after: after) ->
      list.flatten([
        case size {
          model.OpParam(name) -> [Param(naming.snake(name), int_ty)]
          _ -> []
        },
        case after {
          model.OpParam(name) -> [Param(naming.snake(name), option(cursor()))]
          _ -> []
        },
      ])
    _ -> {
      let _ = app
      []
    }
  }
}

fn cond_params(app: App, cond: model.Cond) -> List(Param) {
  case cond {
    model.CEq(field, operand)
    | model.CNe(field, operand)
    | model.CLt(field, operand)
    | model.CLe(field, operand)
    | model.CGt(field, operand)
    | model.CGe(field, operand)
    | model.CIn(field, operand)
    | model.CContains(field, operand) ->
      case operand {
        model.OpParam(name) -> [
          Param(naming.snake(name), field_base(app, field)),
        ]
        _ -> []
      }
    model.CEqOrNull(field, operand) ->
      case operand {
        model.OpParam(name) -> [
          Param(naming.snake(name), option(field_base(app, field))),
        ]
        _ -> []
      }
    model.CHas(_, inner) | model.CHasNone(_, inner) ->
      list.flat_map(inner, cond_params(app, _))
    _ -> []
  }
}

fn dedupe(remaining: List(Param), seen: List(String)) -> List(Param) {
  case remaining {
    [] -> []
    [first, ..rest] ->
      case list.contains(seen, first.label) {
        True -> dedupe(rest, seen)
        False -> [first, ..dedupe(rest, [first.label, ..seen])]
      }
  }
}
