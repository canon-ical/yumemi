//// `join:` / `with:` の項を矢印へ解く規則。SQL 層(`emit/sql`)と型の層(`emit/typing`・
//// `gen/query.gleam` の `Arrow`)は同じ関数で解く ── 片方だけ出る形を作らないため。
////
//// `with:` の逆向きの名は `<親>To<子の短い名の複数形>`(`RosterToPhotos` = RosterPhoto の
//// `roster` の逆、`LinkImportToCandidates` = LinkImportCandidate の `link_import` の逆)。
//// 子の名が親の名で始まればその分を落として短い名にする。名が合わなければ解かない。

import gleam/list
import gleam/option.{None, Some}
import gleam/string
import yumemi_gen/model.{type App, type Arrow, type Entity}
import yumemi_gen/naming
import yumemi_gen/stop

/// 解けなかった理由。`class` は 20 の exit code 表へそのまま写る。
pub type Miss {
  Miss(class: stop.Class, text: String)
}

/// `join:` の項。順向きの矢印で、先が 1 行に決まるもの(Multi は中間表に居て列が無い)。
pub fn join_arrow(app: App, name: String) -> Result(Arrow, Miss) {
  case model.arrow_by_name(app.arrows, name) {
    Some(arrow) ->
      case arrow.kind {
        model.Multi ->
          Error(Miss(stop.Conflict, "join の矢印が Multi(列が無い): " <> name))
        _ -> Ok(arrow)
      }
    None ->
      case model.arrow_by_name(app.reverse_arrows, name) {
        Some(_) ->
          Error(Miss(stop.Conflict, "join に逆向きの矢印は書けない(with へ): " <> name))
        None -> Error(Miss(stop.Conflict, "矢印が無い: " <> name))
      }
  }
}

/// `with:` の項。`from` を親とする Held の逆向きに解き、逆向きの矢印(親 -> 子)を返す。
pub fn with_arrow(
  entities: List(Entity),
  arrows: List(Arrow),
  from: Entity,
  name: String,
) -> Result(Arrow, Miss) {
  case model.arrow_by_name(arrows, name) {
    Some(arrow) if arrow.from_entity == from.name ->
      Error(Miss(stop.NotImplemented, "with の順方向は未対応: " <> name))
    _ -> reverse(entities, arrows, from, name)
  }
}

fn reverse(
  entities: List(Entity),
  arrows: List(Arrow),
  from: Entity,
  name: String,
) -> Result(Arrow, Miss) {
  let named =
    arrows
    |> list.filter(fn(arrow) { arrow.target_entity == from.name })
    |> list.filter_map(fn(arrow) {
      case model.entity_by_name(entities, arrow.from_entity) {
        Some(child) ->
          case name_matches(name, from, child) {
            True -> Ok(#(child, arrow))
            False -> Error(Nil)
          }
        None -> Error(Nil)
      }
    })
  case named {
    [#(child, arrow)] ->
      case arrow.kind {
        model.Held ->
          Ok(model.Arrow(
            name: name,
            from_entity: from.name,
            prop: arrow.prop,
            target_entity: child.name,
            kind: model.Held,
            optional: False,
          ))
        model.Has | model.Link | model.Multi ->
          Error(Miss(stop.NotImplemented, "with の逆向きは Held の関係だけ対応: " <> name))
      }
    [] ->
      Error(Miss(
        stop.Conflict,
        "with の逆向きが無い: " <> name <> "(名は " <> from.name <> "To<子の短い名の複数形>)",
      ))
    _ -> Error(Miss(stop.Conflict, "with の逆向きが複数: " <> name))
  }
}

/// 逆向きの名の規則。`from` の名で始まる子はその分を落とし、複数形にして比べる。
pub fn name_matches(name: String, from: Entity, child: Entity) -> Bool {
  let prefix = from.name <> "To"
  case string.starts_with(name, prefix) {
    False -> False
    True -> {
      let requested = string.drop_start(name, string.length(prefix))
      let short = case string.starts_with(child.name, from.name) {
        True -> string.drop_start(child.name, string.length(from.name))
        False -> child.name
      }
      requested == plural(short)
    }
  }
}

fn plural(word: String) -> String {
  case string.ends_with(word, "y") {
    True -> string.drop_end(word, 1) <> "ies"
    False ->
      case
        string.ends_with(word, "s")
        || string.ends_with(word, "x")
        || string.ends_with(word, "ch")
        || string.ends_with(word, "sh")
      {
        True -> word <> "es"
        False -> word <> "s"
      }
  }
}

/// 行の欄の名(SQL の `AS` と、型の層の組の位置の説明に使う)。`RosterToPhotos` -> `photos`。
pub fn with_output(from: Entity, name: String) -> String {
  let prefix = from.name <> "To"
  case string.starts_with(name, prefix) {
    True -> naming.snake(string.drop_start(name, string.length(prefix)))
    False -> naming.snake(name)
  }
}

/// `with:` に書かれ、解けた逆向きの矢印。`gen/query.gleam` の `Arrow` に出す。
/// 親の Entity の並び、同じ親の中は名の順。
pub fn reverse_arrows(
  entities: List(Entity),
  arrows: List(Arrow),
  services: List(model.Service),
) -> List(Arrow) {
  let found =
    list.flat_map(services, fn(service) {
      list.flat_map(service.queries, fn(query) {
        case model.entity_by_name(entities, query.select.from) {
          None -> []
          Some(from) ->
            list.filter_map(query.select.with, fn(name) {
              with_arrow(entities, arrows, from, name)
            })
        }
      })
    })
  list.flat_map(entities, fn(entity) {
    found
    |> list.filter(fn(arrow) { arrow.from_entity == entity.name })
    |> list.map(fn(arrow) { arrow.name })
    |> list.unique
    |> list.sort(string.compare)
    |> list.filter_map(fn(name) {
      list.find(found, fn(arrow) { arrow.name == name })
    })
  })
}
