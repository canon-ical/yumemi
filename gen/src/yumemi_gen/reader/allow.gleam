//// allow の句を読む口。★ の Service が `import gen/allow/<m> as allow` で使う構成子と判定を、
//// allow module ごとに集める。`gen/allow/<m>` の生成(`emit/allow`)だけが使う ──
//// model の Service には載せない(reader.gleam の `subjects` は root の Actor を決める分だけ)。
////
//// 読むもの:
//// - `service` 定数の `allow: [...]` の各句。`Clause(who:, at:, owner:)` の構成子名と、
////   `Only([...])` の要素の module(= その phase を持つ Entity)
//// - 略記の句。大文字(`allow.Anyone`)は who の名、小文字(`allow.staff`)は句の定数
//// - module 全体(コメントを除く)の `allow.<name>(` の呼び出し ── `is_self` / `is_<entity>` / `party_of`

import glance
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import glexer
import glexer/token
import yumemi_gen/glance_util as g
import yumemi_gen/naming
import yumemi_gen/source.{type Unit}

pub type Usage {
  Usage(
    /// "gen/allow/muse"
    path: String,
    /// この allow module を `as allow` で import する Service の module 名
    services: List(String),
    /// who に書かれた構成子。初出の順
    whos: List(String),
    /// owner に書かれた構成子(`NoOwner` / `Self` / `Via<Entity>Party`)。初出の順
    owners: List(String),
    /// `Only([...])` の要素の module(`entity/` を落とした名)。初出の順
    phase_modules: List(String),
    /// 小文字の略記の句(`allow.staff`)
    shorthands: List(String),
    /// ★ が呼ぶ判定の名(`is_self` / `is_staff` / `party_of` …)
    calls: List(String),
  )
}

/// owner の名から party への道。`Via<Entity>Party` はその Entity の `party` 欄。
/// それ以外(`NoOwner` / `Self`)は None。
pub fn owner_entity(owner: String) -> Option(String) {
  case string.starts_with(owner, "Via"), string.ends_with(owner, "Party") {
    True, True -> {
      let middle = owner |> string.drop_start(3) |> string.drop_end(5)
      case middle {
        "" -> None
        _ -> Some(middle)
      }
    }
    _, _ -> None
  }
}

pub fn read(units: List(Unit)) -> List(Usage) {
  units
  |> list.filter(fn(unit) { string.starts_with(unit.path, "service/") })
  |> list.filter_map(fn(unit) {
    case allow_import(unit.module) {
      Some(path) -> Ok(#(path, unit_usage(unit, path)))
      None -> Error(Nil)
    }
  })
  |> list.fold([], fn(acc, item) {
    let #(path, usage) = item
    case list.key_find(acc, path) {
      Ok(found) -> list.key_set(acc, path, merge(found, usage))
      Error(_) -> list.append(acc, [#(path, usage)])
    }
  })
  |> list.map(fn(item) { item.1 })
}

pub fn find(usages: List(Usage), path: String) -> Usage {
  case list.find(usages, fn(usage) { usage.path == path }) {
    Ok(usage) -> usage
    Error(_) ->
      Usage(
        path: path,
        services: [],
        whos: [],
        owners: [],
        phase_modules: [],
        shorthands: [],
        calls: [],
      )
  }
}

fn merge(left: Usage, right: Usage) -> Usage {
  Usage(
    path: left.path,
    services: list.append(left.services, right.services),
    whos: union(left.whos, right.whos),
    owners: union(left.owners, right.owners),
    phase_modules: union(left.phase_modules, right.phase_modules),
    shorthands: union(left.shorthands, right.shorthands),
    calls: union(left.calls, right.calls),
  )
}

/// 初出の順を保った和。
fn union(left: List(String), right: List(String)) -> List(String) {
  list.unique(list.append(left, right))
}

/// reader.gleam の `allow_module_of` と同じ条件 ── `gen/allow/` の下を `allow` の名で import。
fn allow_import(module: glance.Module) -> Option(String) {
  case
    list.find_map(module.imports, fn(definition) {
      let import_ = definition.definition
      case string.starts_with(import_.module, "gen/allow/"), local(import_) {
        True, "allow" -> Ok(import_.module)
        _, _ -> Error(Nil)
      }
    })
  {
    Ok(path) -> Some(path)
    Error(_) -> None
  }
}

fn local(import_: glance.Import) -> String {
  case import_.alias {
    Some(glance.Named(name)) -> name
    _ -> last_segment(import_.module)
  }
}

fn unit_usage(unit: Unit, path: String) -> Usage {
  let module = g.in_order(unit.module)
  let service = string.drop_start(unit.path, string.length("service/"))
  let clauses = case g.find_constant(module, "service") {
    None -> []
    Some(constant) ->
      case g.labelled(constant.value, "allow") {
        Some(value) -> g.list_elements(value)
        None -> []
      }
  }
  let aliases =
    list.map(module.imports, fn(definition) {
      #(local(definition.definition), definition.definition.module)
    })
  let empty =
    Usage(
      path: path,
      services: [service],
      whos: [],
      owners: [],
      phase_modules: [],
      shorthands: [],
      calls: calls(unit.text),
    )
  list.fold(clauses, empty, fn(usage, clause) {
    clause_usage(usage, clause, aliases)
  })
}

fn clause_usage(
  usage: Usage,
  clause: glance.Expression,
  aliases: List(#(String, String)),
) -> Usage {
  case g.ctor_name(clause) {
    Some("Clause") -> {
      let who = option.then(g.labelled(clause, "who"), g.ctor_name)
      let owner = option.then(g.labelled(clause, "owner"), g.ctor_name)
      let phases = case g.labelled(clause, "at") {
        Some(at) ->
          case g.ctor_name(at), g.args(at) {
            Some("Only"), [items] ->
              g.list_elements(items)
              |> list.filter_map(fn(item) {
                case g.ctor_module(item) {
                  Some(alias) -> Ok(phase_module(alias, aliases))
                  None -> Error(Nil)
                }
              })
            _, _ -> []
          }
        None -> []
      }
      Usage(
        ..usage,
        whos: union(usage.whos, option.values([who])),
        owners: union(usage.owners, option.values([owner])),
        phase_modules: union(usage.phase_modules, phases),
      )
    }
    Some(name) ->
      case is_upper(name) {
        True -> Usage(..usage, whos: union(usage.whos, [name]))
        False ->
          Usage(
            ..usage,
            whos: union(usage.whos, [naming.pascal(name)]),
            shorthands: union(usage.shorthands, [name]),
          )
      }
    None -> usage
  }
}

fn phase_module(alias: String, aliases: List(#(String, String))) -> String {
  case list.key_find(aliases, alias) {
    Ok(path) ->
      case string.starts_with(path, "entity/") {
        True -> string.drop_start(path, string.length("entity/"))
        False -> path
      }
    Error(_) -> alias
  }
}

/// `allow.<name>(` の呼び出し。コメントは token の段で落とす。
fn calls(text: String) -> List(String) {
  glexer.new(text)
  |> glexer.lex
  |> list.map(fn(entry) { entry.0 })
  |> list.filter(fn(item) {
    case item {
      token.Space(_)
      | token.CommentDoc(_)
      | token.CommentNormal(_)
      | token.CommentModule(_) -> False
      _ -> True
    }
  })
  |> scan_calls([])
}

fn scan_calls(tokens: List(token.Token), found: List(String)) -> List(String) {
  case tokens {
    [token.Name("allow"), token.Dot, token.Name(name), token.LeftParen, ..rest] ->
      scan_calls(rest, union(found, [name]))
    [_, ..rest] -> scan_calls(rest, found)
    [] -> found
  }
}

fn is_upper(name: String) -> Bool {
  case string.first(name) {
    Ok(first) ->
      string.uppercase(first) == first && string.lowercase(first) != first
    Error(_) -> False
  }
}

fn last_segment(path: String) -> String {
  case list.last(string.split(path, "/")) {
    Ok(segment) -> segment
    Error(_) -> path
  }
}
