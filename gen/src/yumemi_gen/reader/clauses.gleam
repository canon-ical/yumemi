//// Service の allow 句(`who` / `at` / `owner`)を読む。読みへ allow 句を入れる判断
//// (`emit/sql`)だけが使う。Actor と `gen/allow` の生成(hw-2)とは別の口に置く。
////
//// 句の形は `allow.Clause(who: .., at: .., owner: ..)` と、`who` だけの略記
//// (`allow.Anyone` = `at: AnyPhase, owner: NoOwner`)。略記と読むのは、大文字で始まる
//// 構成子(`Anyone` / `allow.AsMuse`)と、allow の import の別名への参照
//// (`allow.staff`、`gen/allow/*` の句)だけ。定数の参照(`published_only`、
//// `other.clauses`)・関数呼び出し・spread・List でない `allow:` は、中身を読まずに
//// 「絞らない句」と取り違えると allow 句が SQL から黙って消えるので、捨てずに
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
          Some(glance.List(elements: elements, rest: None, ..)) ->
            Ok(#(last_segment(unit.path), list.map(elements, clause)))
          Some(glance.List(elements: elements, rest: Some(_), ..)) ->
            Ok(#(
              last_segment(unit.path),
              list.append(list.map(elements, clause), [
                model.UnreadClause("allow の spread(..)"),
              ]),
            ))
          Some(_) ->
            Ok(
              #(last_segment(unit.path), [
                model.UnreadClause("allow が List の literal でない"),
              ]),
            )
          None -> Error(Nil)
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
      case shorthand(expression) {
        True -> model.Clause(who: name, at: model.AnyPhaseAt, owner: "NoOwner")
        False -> model.UnreadClause("allow の句 " <> name)
      }
    None -> model.UnreadClause("allow の句")
  }
}

/// `who` だけの略記として読んでよい項か。大文字で始まる構成子(修飾の有無は問わない)と、
/// allow の import(別名は reader の `allow_module_of` どおり `allow`)の句の参照だけ。
fn shorthand(expression: glance.Expression) -> Bool {
  case expression {
    glance.Variable(name: name, ..) -> capitalised(name)
    glance.FieldAccess(container: glance.Variable(name: "allow", ..), ..) ->
      True
    glance.FieldAccess(label: label, ..) -> capitalised(label)
    _ -> False
  }
}

fn capitalised(name: String) -> Bool {
  case string.first(name) {
    Ok(head) -> string.uppercase(head) == head && string.lowercase(head) != head
    Error(_) -> False
  }
}

fn at_of(expression: glance.Expression) -> model.ClauseAt {
  case g.ctor_name(expression) {
    Some("AnyPhase") -> model.AnyPhaseAt
    Some("Only") ->
      case g.args(expression) {
        [glance.List(elements: elements, rest: None, ..)] -> {
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
