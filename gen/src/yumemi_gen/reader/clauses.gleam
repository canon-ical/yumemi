//// Service の allow 句(`who` / `at` / `owner`)を読む。読みへ allow 句を入れる判断
//// (`emit/sql`)だけが使う。Actor と `gen/allow` の生成(hw-2)とは別の口に置く。
////
//// 句の形は `allow.Clause(who: .., at: .., owner: ..)` と、`who` だけの略記
//// (`allow.Anyone` = `at: AnyPhase, owner: NoOwner`)。読めない句は捨てずに
//// `UnreadClause` で持つ ── 入れる時に exit 4 で名指しするため。

import glance
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import yumemi_gen/glance_util as g
import yumemi_gen/model
import yumemi_gen/source.{type Unit}

/// Service の module 名 -> allow 句。`service` const が無い、または allow が
/// List でない Service は載せない(その検査は reader の `subjects_of` が持つ)。
pub fn read(units: List(Unit)) -> List(#(String, List(model.Clause))) {
  units
  |> list.filter(fn(unit) { string.starts_with(unit.path, "service/") })
  |> list.filter_map(fn(unit) {
    let module = g.in_order(unit.module)
    case g.find_constant(module, "service") {
      None -> Error(Nil)
      Some(service) ->
        case g.labelled(service.value, "allow") {
          Some(glance.List(elements: elements, ..)) ->
            Ok(#(last_segment(unit.path), list.map(elements, clause)))
          _ -> Error(Nil)
        }
    }
  })
}

fn last_segment(path: String) -> String {
  case list.last(string.split(path, "/")) {
    Ok(segment) -> segment
    Error(_) -> path
  }
}

fn clause(expression: glance.Expression) -> model.Clause {
  case g.ctor_name(expression) {
    Some("Clause") ->
      case
        g.labelled(expression, "who") |> option.then(g.ctor_name),
        g.labelled(expression, "at"),
        g.labelled(expression, "owner") |> option.then(g.ctor_name)
      {
        Some(who), Some(at), Some(owner) ->
          model.Clause(who: who, at: at_of(at), owner: owner)
        _, _, _ -> model.UnreadClause("allow.Clause の who / at / owner")
      }
    Some(name) ->
      model.Clause(who: name, at: model.AnyPhaseAt, owner: "NoOwner")
    None -> model.UnreadClause("allow の句")
  }
}

fn at_of(expression: glance.Expression) -> model.ClauseAt {
  case g.ctor_name(expression) {
    Some("AnyPhase") -> model.AnyPhaseAt
    Some("Only") ->
      case g.args(expression) {
        [glance.List(elements: elements, ..)] -> {
          let names =
            list.filter_map(elements, fn(item) {
              g.ctor_name(item) |> option.to_result(Nil)
            })
          case list.length(names) == list.length(elements) {
            True -> model.OnlyAt(names)
            False -> model.UnreadAt("Only の相")
          }
        }
        _ -> model.UnreadAt("Only の引数")
      }
    Some(name) -> model.UnreadAt(name)
    None -> model.UnreadAt("at")
  }
}
