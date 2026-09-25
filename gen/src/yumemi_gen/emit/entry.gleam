//// 入口束 ── `src/gen/face.gleam` と `src/gen/entry/http.gleam`。
//// Service × Face の route は entry の prefix と Entity / Args の型から導く。

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import gleam/string
import yumemi_gen/emit/hash
import yumemi_gen/emit/root
import yumemi_gen/emit/types.{type File, File}
import yumemi_gen/model.{
  type App, type Arg, type Collection, type Effect, type Entity, type Entry,
  type Service, type TypeShape,
}
import yumemi_gen/stop

pub type Output {
  Output(files: List(File), notes: List(stop.Note))
}

/// 入口 1 つ × Service 1 つの口。`path` は `{name}` の変数を持つ(registry の `:name` の手前の綴り)。
pub type Route {
  Route(
    face: String,
    method: String,
    path: String,
    service: String,
    path_keys: List(String),
    credential: String,
  )
}

type RouteError {
  RouteError(text: String)
}

type Target {
  EntityTarget(Entity)
  CollectionTarget(Collection)
}

type Match {
  Match(target: Target, suffix: String, word_count: Int)
}

const individual_verbs = ["read", "delete", "put", "edit", "remove"]

pub fn emit(app: App, hashes: hash.Hashes) -> Output {
  case app.entries {
    [] -> Output(files: [], notes: [])
    _ -> {
      let #(routes, notes) = collect(app)
      Output(
        files: [
          File(
            path: "src/gen/face.gleam",
            text: face_text(app.entries, hash.entry(hashes)),
          ),
          File(
            path: "src/gen/entry/http.gleam",
            text: http_text(routes, hash.entry(hashes)),
          ),
        ],
        notes: list.append(notes, route_overlap_notes(routes)),
      )
    }
  }
}

/// 全入口の口(service → face の順に並べる)。面の `api.gleam` と back の `registry.mjs` が同じ表を読む。
pub fn routes(app: App) -> List(Route) {
  collect(app).0
}

fn collect(app: App) -> #(List(Route), List(stop.Note)) {
  case app.entries {
    [] -> #([], [])
    _ -> {
      let #(routes, notes) =
        list.fold(app.services, #([], []), fn(acc, service) {
          let #(routes, notes) = acc
          case system_only(service) {
            True -> #(routes, notes)
            False ->
              list.fold(
                service.faces,
                #(routes, notes),
                fn(face_acc, face_name) {
                  let #(face_routes, face_notes) = face_acc
                  case find_entry(app.entries, face_name) {
                    None -> #(face_routes, face_notes)
                    Some(entry) ->
                      case entry_allows(entry, service.effect) {
                        False -> #(face_routes, face_notes)
                        True ->
                          case route_for(app, service, entry) {
                            Ok(Some(route)) -> #(
                              [route, ..face_routes],
                              face_notes,
                            )
                            Ok(None) -> #(face_routes, face_notes)
                            Error(RouteError(text: detail)) -> #(face_routes, [
                              stop.Note(
                                class: stop.Conflict,
                                text: "service."
                                  <> service.module
                                  <> " face "
                                  <> face_name
                                  <> ": "
                                  <> detail,
                              ),
                              ..face_notes
                            ])
                          }
                      }
                  }
                },
              )
          }
        })
      #(list.sort(routes, route_compare), list.reverse(notes))
    }
  }
}

fn face_text(entries: List(Entry), input_hash: String) -> String {
  let variants =
    entries
    |> list.map(fn(entry) { "  " <> pascal(entry.name) })
    |> string.join("\n")
  "//// GENERATED from entry.gleam [sha256:"
  <> input_hash
  <> "] — 手で編集しない\n\n"
  <> "pub type Face {\n"
  <> variants
  <> "\n}\n"
}

fn http_text(routes: List(Route), input_hash: String) -> String {
  let rows =
    routes
    |> list.map(route_text)
    |> string.join("\n")
  "//// GENERATED from entry.gleam / service declarations [sha256:"
  <> input_hash
  <> "] — 手で編集しない\n\n"
  <> "pub type Credential {\n  Session\n  ApiKey\n}\n\n"
  <> "pub type Route {\n"
  <> "  Route(face: String, method: String, path: String, service: String,\n"
  <> "        path_keys: List(String), credential: Credential)\n"
  <> "}\n\n"
  <> "pub const routes: List(Route) = [\n"
  <> rows
  <> "\n]\n"
}

fn route_text(route: Route) -> String {
  "  Route(face: \""
  <> route.face
  <> "\", method: \""
  <> route.method
  <> "\", path: \""
  <> route.path
  <> "\", service: \""
  <> route.service
  <> "\", path_keys: ["
  <> string.join(
    list.map(route.path_keys, fn(key) { "\"" <> key <> "\"" }),
    ", ",
  )
  <> "], credential: "
  <> route.credential
  <> "),"
}

fn route_compare(left: Route, right: Route) -> order.Order {
  case string.compare(left.service, right.service) {
    order.Eq -> string.compare(left.face, right.face)
    other -> other
  }
}

fn route_overlap_notes(routes: List(Route)) -> List(stop.Note) {
  case routes {
    [] -> []
    [route, ..rest] -> {
      let overlaps =
        list.filter_map(rest, fn(other) {
          case
            route.face == other.face
            && route.method == other.method
            && route_path_shape(route.path) == route_path_shape(other.path)
          {
            True ->
              Ok(stop.Note(
                class: stop.Conflict,
                text: "HTTP route が重複: "
                  <> route.face
                  <> " "
                  <> route.method
                  <> " "
                  <> route.path
                  <> " ("
                  <> route.service
                  <> " / "
                  <> other.service
                  <> ")",
              ))
            False -> Error(Nil)
          }
        })
      list.append(overlaps, route_overlap_notes(rest))
    }
  }
}

fn route_path_shape(path: String) -> String {
  path
  |> string.split("/")
  |> list.map(fn(segment) {
    case string.starts_with(segment, "{") && string.ends_with(segment, "}") {
      True -> "{}"
      False -> segment
    }
  })
  |> string.join("/")
}

fn system_only(service: Service) -> Bool {
  service.subjects != []
  && list.all(service.subjects, fn(subject) {
    case subject {
      model.SubjectSystem -> True
      _ -> False
    }
  })
}

fn find_entry(entries: List(Entry), name: String) -> Option(Entry) {
  case list.find(entries, fn(entry) { pascal(entry.name) == name }) {
    Ok(entry) -> Some(entry)
    Error(_) -> None
  }
}

fn entry_allows(entry: Entry, effect: Effect) -> Bool {
  case entry.services, effect {
    model.ReadOnlyServices, model.ReadEffect -> True
    model.ReadOnlyServices, model.WriteEffect -> False
    model.AllServices, _ -> True
  }
}

/// `src/server.gleam` の上書きがあればそれを使い、無ければ導出する。上書きの口は媒体の合う入口だけが持ち、
/// `Internal` は口を持たない。
fn route_for(
  app: App,
  service: Service,
  entry: Entry,
) -> Result(Option(Route), RouteError) {
  case model.server_route(app.server, service.module) {
    Some(model.InternalRoute(..)) -> Ok(None)
    Some(model.OverrideRoute(method: method, path: path, credential: via, ..)) ->
      case credential_matches(entry.credential, via) {
        False -> Ok(None)
        True -> {
          let braced = braced_path(path)
          Ok(
            Some(Route(
              face: entry.name,
              method: method,
              path: braced,
              service: service.module,
              path_keys: path_variables(braced),
              credential: credential_text(entry.credential),
            )),
          )
        }
      }
    None -> derived_route(app, service, entry) |> result.map(Some)
  }
}

fn credential_matches(
  credential: model.Credential,
  via: Option(String),
) -> Bool {
  case credential, via {
    model.ApiKeyCredential, Some("api_key") -> True
    model.ApiKeyCredential, _ -> False
    model.SessionCredential, Some("api_key") -> False
    model.SessionCredential, _ -> True
  }
}

/// `:name` → `{name}`。
fn braced_path(path: String) -> String {
  path
  |> string.split("/")
  |> list.map(fn(segment) {
    case string.starts_with(segment, ":") {
      True -> "{" <> string.drop_start(segment, 1) <> "}"
      False -> segment
    }
  })
  |> string.join("/")
}

fn path_variables(path: String) -> List(String) {
  path
  |> string.split("/")
  |> list.filter_map(fn(segment) {
    case string.starts_with(segment, "{") && string.ends_with(segment, "}") {
      True -> Ok(segment |> string.drop_start(1) |> string.drop_end(1))
      False -> Error(Nil)
    }
  })
}

fn derived_route(
  app: App,
  service: Service,
  entry: Entry,
) -> Result(Route, RouteError) {
  let root_entity = root.root_for(app, service)
  case target_for(app, service) {
    Error(error) -> Error(error)
    Ok(#(target, suffix)) -> {
      let verb = verb_for(service.module, suffix)
      case verb {
        "" -> Error(RouteError("動詞が空: " <> service.module))
        _ ->
          case nested_reserved_entity(app, target, verb) {
            Some(entity) ->
              Error(RouteError(
                "動詞が Entity と予約動詞の入れ子: "
                <> service.module
                <> " -> "
                <> verb
                <> " ("
                <> entity
                <> ")",
              ))
            None ->
              case target {
                CollectionTarget(_) ->
                  case list.contains(individual_verbs, verb) {
                    True ->
                      Error(RouteError(
                        "ER 外 collection に個体レベルの動詞: "
                        <> service.module
                        <> " ("
                        <> verb
                        <> ")",
                      ))
                    False ->
                      route_for_target(
                        service,
                        entry,
                        root_entity,
                        target,
                        verb,
                      )
                  }
                _ -> route_for_target(service, entry, root_entity, target, verb)
              }
          }
      }
    }
  }
}

fn route_for_target(
  service: Service,
  entry: Entry,
  root_entity: Option(Entity),
  target: Target,
  verb: String,
) -> Result(Route, RouteError) {
  let root_args = case root_entity, target {
    Some(root), EntityTarget(target) if root.module != target.module ->
      matching_args(root, service.args)
    Some(root), CollectionTarget(_) -> matching_args(root, service.args)
    _, _ -> []
  }
  let available_args =
    list.filter(service.args, fn(arg) {
      !list.any(root_args, fn(root_arg) { root_arg.name == arg.name })
    })
  let target_args = case target {
    EntityTarget(entity) -> matching_args(entity, available_args)
    CollectionTarget(_) -> []
  }
  let individual =
    target_args != [] && verb != "create" && verb != "list" && verb != "add"
  case individual, list.length(target_args) {
    True, count if count > 1 ->
      Error(RouteError(
        "対象のパス変数が2個以上: "
        <> string.join(list.map(target_args, fn(arg) { arg.name }), ", "),
      ))
    _, _ -> {
      let root_path = case root_entity, target {
        Some(root), EntityTarget(target) if root.module != target.module ->
          path_with_args(entry.prefix, root.collection, root_args)
        Some(root), CollectionTarget(_) ->
          path_with_args(entry.prefix, root.collection, root_args)
        _, _ -> entry.prefix
      }
      let target_path = append_segment(root_path, target_collection(target))
      let path_count =
        list.length(root_args)
        + case individual {
          True -> 1
          False -> 0
        }
      case path_count >= 3 {
        True -> Error(RouteError("パス変数が3個以上"))
        False -> {
          let #(path, path_keys) = case individual {
            True -> {
              let assert [arg] = target_args
              #(append_variable(target_path, arg.name), names(root_args, [arg]))
            }
            False -> #(target_path, names(root_args, []))
          }
          let method = method_for(service.effect, verb, individual)
          let final_path = suffix_for(path, service.effect, verb, individual)
          Ok(Route(
            face: entry.name,
            method: method,
            path: final_path,
            service: service.module,
            path_keys: path_keys,
            credential: credential_text(entry.credential),
          ))
        }
      }
    }
  }
}

fn target_for(
  app: App,
  service: Service,
) -> Result(#(Target, String), RouteError) {
  let matches =
    all_targets(app)
    |> list.flat_map(fn(target) { matches_for(service.module, target) })
  case best_matches(matches), allow_entity(app, service) {
    [], Some(entity) -> Ok(#(EntityTarget(entity), last_word_prefix(service)))
    [], None -> Error(RouteError("対象が無い: " <> service.module))
    [Match(target: target, suffix: suffix, ..)], _ -> Ok(#(target, suffix))
    ambiguous, allow ->
      case by_allow_entity(ambiguous, allow) {
        [Match(target: target, suffix: suffix, ..)] -> Ok(#(target, suffix))
        _ -> Error(ambiguous_error(service, ambiguous))
      }
  }
}

/// 名前の前置きで決まらない Service の対象は、allow の Entity(root の候補)から解く。改名しない
/// (2b-7 の裁定 2)── `schedule_*` は allow の Entity か、それを held で指す候補を採る。
fn allow_entity(app: App, service: Service) -> Option(Entity) {
  case service.allow_module {
    None -> None
    Some(path) ->
      model.entity_by_module(
        app.entities,
        path |> string.split("/") |> list.last |> result.unwrap(""),
      )
  }
}

fn by_allow_entity(matches: List(Match), allow: Option(Entity)) -> List(Match) {
  case allow {
    None -> []
    Some(entity) -> {
      let same =
        list.filter(matches, fn(found) {
          target_module(found.target) == entity.module
        })
      case same {
        [] ->
          list.filter(matches, fn(found) {
            case found.target {
              EntityTarget(candidate) ->
                list.any(candidate.props, fn(prop) {
                  case prop.kind {
                    model.RelProp(kind: model.Held, target_module: module, ..) ->
                      last_path(module) == entity.module
                    _ -> False
                  }
                })
              CollectionTarget(_) -> False
            }
          })
        _ -> same
      }
    }
  }
}

fn last_path(module: String) -> String {
  module |> string.split("/") |> list.last |> result.unwrap(module)
}

/// 前置きが Entity に当たらない名(`pageview_record`)は、最後の語を動詞にする。
fn last_word_prefix(service: Service) -> String {
  let words = string.split(service.module, "_")
  words |> list.take(list.length(words) - 1) |> string.join("_")
}

fn ambiguous_error(service: Service, ambiguous: List(Match)) -> RouteError {
  RouteError(
    "対象が曖昧: "
    <> service.module
    <> " -> 候補 "
    <> string.join(
      list.map(ambiguous, fn(found) { target_module(found.target) }),
      " / ",
    ),
  )
}

fn all_targets(app: App) -> List(Target) {
  list.append(
    list.map(app.entities, fn(entity) { EntityTarget(entity) }),
    list.map(app.collections, fn(collection) { CollectionTarget(collection) }),
  )
}

fn matches_for(service_module: String, target: Target) -> List(Match) {
  case target {
    EntityTarget(entity) ->
      entity_suffixes(entity.module)
      |> list.filter_map(fn(suffix) {
        case string.starts_with(service_module, suffix <> "_") {
          True ->
            Ok(Match(
              target: target,
              suffix: suffix,
              word_count: list.length(string.split(suffix, "_")),
            ))
          False -> Error(Nil)
        }
      })
    CollectionTarget(collection) ->
      case string.starts_with(service_module, collection.module <> "_") {
        True -> [
          Match(
            target: target,
            suffix: collection.module,
            word_count: list.length(string.split(collection.module, "_")),
          ),
        ]
        False -> []
      }
  }
}

fn best_matches(matches: List(Match)) -> List(Match) {
  let longest =
    list.fold(matches, 0, fn(current, found) {
      int.max(current, found.word_count)
    })
  list.filter(matches, fn(found) { found.word_count == longest })
}

fn entity_suffixes(module: String) -> List(String) {
  let words = string.split(module, "_")
  entity_suffixes_from(words)
}

fn entity_suffixes_from(words: List(String)) -> List(String) {
  case words {
    [] -> []
    [_first, ..rest] -> [string.join(words, "_"), ..entity_suffixes_from(rest)]
  }
}

fn verb_for(service_module: String, suffix: String) -> String {
  let prefix = suffix <> "_"
  case string.starts_with(service_module, prefix) {
    True -> string.drop_start(service_module, string.length(prefix))
    False -> ""
  }
}

fn nested_reserved_entity(
  app: App,
  target: Target,
  verb: String,
) -> Option(String) {
  let target_module = target_module(target)
  case
    list.find(app.entities, fn(entity) {
      entity.module != target_module
      && list.any(entity_suffixes(entity.module), fn(suffix) {
        list.any(reserved_verbs(), fn(reserved) {
          verb == suffix <> "_" <> reserved
        })
      })
    })
  {
    Ok(entity) -> Some(entity.module)
    Error(_) -> None
  }
}

fn reserved_verbs() -> List(String) {
  ["create", "read", "list", "delete", "put", "add", "edit", "remove"]
}

fn target_module(target: Target) -> String {
  case target {
    EntityTarget(entity) -> entity.module
    CollectionTarget(collection) -> collection.module
  }
}

fn target_collection(target: Target) -> String {
  case target {
    EntityTarget(entity) -> entity.collection
    CollectionTarget(collection) -> collection.collection
  }
}

fn matching_args(entity: Entity, args: List(Arg)) -> List(Arg) {
  let shapes =
    list.append(
      option_shapes(entity.key_type),
      option_shapes(entity.path_key_type),
    )
  list.filter(args, fn(arg) {
    list.any(shapes, fn(shape) { shape == arg.type_ })
  })
}

fn option_shapes(shape: Option(TypeShape)) -> List(TypeShape) {
  case shape {
    None -> []
    Some(value) -> flatten_shape(value)
  }
}

fn flatten_shape(shape: TypeShape) -> List(TypeShape) {
  case shape {
    model.TupleShape(items) -> list.flat_map(items, flatten_shape)
    _ -> [shape]
  }
}

fn path_with_args(
  prefix: String,
  collection: String,
  args: List(Arg),
) -> String {
  let path = append_segment(prefix, collection)
  list.fold(args, path, fn(acc, arg) { append_variable(acc, arg.name) })
}

fn names(root_args: List(Arg), target_args: List(Arg)) -> List(String) {
  list.append(
    list.map(root_args, fn(arg) { arg.name }),
    list.map(target_args, fn(arg) { arg.name }),
  )
}

fn append_segment(base: String, segment: String) -> String {
  case base {
    "" -> "/" <> segment
    "/" -> "/" <> segment
    _ ->
      case string.ends_with(base, "/") {
        True -> base <> segment
        False -> base <> "/" <> segment
      }
  }
}

fn append_variable(base: String, name: String) -> String {
  base <> "/{" <> name <> "}"
}

fn method_for(effect: Effect, verb: String, individual: Bool) -> String {
  case effect, verb, individual {
    model.WriteEffect, "create", False -> "POST"
    model.WriteEffect, "add", False -> "POST"
    model.ReadEffect, "read", True -> "GET"
    model.ReadEffect, "list", False -> "GET"
    model.WriteEffect, "delete", True -> "DELETE"
    model.WriteEffect, "remove", _ -> "DELETE"
    model.WriteEffect, "put", True -> "PUT"
    model.WriteEffect, "edit", _ -> "PUT"
    model.WriteEffect, _, _ -> "POST"
    model.ReadEffect, _, _ -> "GET"
  }
}

fn suffix_for(
  path: String,
  effect: Effect,
  verb: String,
  individual: Bool,
) -> String {
  case effect, verb, individual {
    model.WriteEffect, "create", False -> path
    model.WriteEffect, "add", False -> path
    model.ReadEffect, "read", True -> path
    model.ReadEffect, "list", False -> path
    model.WriteEffect, "delete", True -> path
    model.WriteEffect, "put", True -> path
    model.WriteEffect, "edit", _ -> path
    model.WriteEffect, "remove", _ -> path
    _, _, _ -> append_segment(path, verb)
  }
}

fn credential_text(credential: model.Credential) -> String {
  case credential {
    model.SessionCredential -> "Session"
    model.ApiKeyCredential -> "ApiKey"
  }
}

fn pascal(name: String) -> String {
  name
  |> string.split("_")
  |> list.map(fn(word) {
    case string.pop_grapheme(word) {
      Ok(#(head, rest)) -> string.uppercase(head) <> rest
      Error(_) -> word
    }
  })
  |> string.concat
}
