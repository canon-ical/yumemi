//// クエリ値から戻りの型と穴の型を静的に導く。判断は入らない(20「規則は7つ」)。

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import yumemi_gen/model.{type App, type Select}
import yumemi_gen/naming

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
        model.TypeValue(reference) ->
          TyRef(module: reference.module, name: reference.name)
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

/// 1行の型。from の Entity(Lifecycle があれば相を添える)+ join した Entity + along の値。
pub fn row(app: App, select: Select) -> Ty {
  let base = entity_row(app, select.from)
  let joined =
    list.flat_map(select.join, fn(arrow_name) {
      case model.arrow_by_name(app.arrows, arrow_name) {
        Some(arrow) -> entity_row(app, arrow.target_entity)
        None -> []
      }
    })
  let added =
    list.map(select.along, fn(along) {
      case along {
        model.LDistance -> float_ty
        model.LRank -> int_ty
        model.LRunning(value) -> agg_base(app, value)
      }
    })
  case list.flatten([base, joined, added]) {
    [single] -> single
    items -> TyTuple(items)
  }
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
pub fn out(app: App, select: Select) -> Ty {
  case select.group, select.agg {
    [], [] -> {
      let single = row(app, select)
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
        TyTuple(
          list.append(
            list.map(groups, group_ty(app, _)),
            list.map(aggs, agg_ty(app, _)),
          ),
        ),
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
