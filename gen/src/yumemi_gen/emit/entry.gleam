//// 入口束 ── `src/gen/face.gleam` と `src/gen/entry/http.gleam`。
//// Service × Face の route は entry の prefix と Entity / Args の型から導く。

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/string
import yumemi_gen/emit/hash
import yumemi_gen/emit/root
import yumemi_gen/emit/types.{type File, File}
import yumemi_gen/model.{
  type App, type Arg, type Effect, type Entity, type Entry, type Service,
  type TypeShape,
}
import yumemi_gen/stop

pub type Output {
  Output(files: List(File), notes: List(stop.Note))
}

type Route {
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

pub fn emit(app: App, hashes: hash.Hashes) -> Output {
  case app.entries {
    [] -> Output(files: [], notes: [])
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
                            Ok(route) -> #([route, ..face_routes], face_notes)
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
      let routes = list.sort(routes, route_compare)
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
        notes: list.reverse(notes),
      )
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

fn route_for(
  app: App,
  service: Service,
  entry: Entry,
) -> Result(Route, RouteError) {
  let root_entity = root.root_for(app, service)
  let #(target_entity, matched) = target_for(app, service)
  case target_entity {
    None -> Error(RouteError("対象 Entity が無い"))
    Some(target) -> {
      let verb = verb_for(service.module, target, matched)
      case verb {
        "" -> Error(RouteError("動詞が空なので route 無し"))
        _ -> {
          let root_args = case root_entity, target_entity {
            Some(root), Some(target) if root.module != target.module ->
              matching_args(root, service.args)
            _, _ -> []
          }
          let available_args =
            list.filter(service.args, fn(arg) {
              !list.any(root_args, fn(root_arg) { root_arg.name == arg.name })
            })
          let target_args = matching_args(target, available_args)
          let individual =
            target_args != [] && verb != "create" && verb != "list"
          case individual, list.length(target_args) {
            True, count if count > 1 ->
              Error(RouteError(
                "対象のパス変数が2個以上: "
                <> string.join(
                  list.map(target_args, fn(arg) { arg.name }),
                  ", ",
                ),
              ))
            _, _ -> {
              let root_path = case root_entity, target_entity {
                Some(root), Some(target) if root.module != target.module ->
                  path_with_args(entry.prefix, root.collection, root_args)
                _, _ -> entry.prefix
              }
              let target_path = append_segment(root_path, target.collection)
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
                      #(
                        append_variable(target_path, arg.name),
                        names(root_args, [arg]),
                      )
                    }
                    False -> #(target_path, names(root_args, []))
                  }
                  let method = method_for(service.effect, verb, individual)
                  let final_path =
                    suffix_for(path, service.effect, verb, individual)
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
      }
    }
  }
}

fn target_for(app: App, service: Service) -> #(Option(Entity), Bool) {
  let matches =
    list.filter(app.entities, fn(entity) {
      entity.module == service.module
      || string.starts_with(service.module, entity.module <> "_")
    })
  case longest(matches) {
    Some(entity) -> #(Some(entity), True)
    None -> #(root.root_for(app, service), False)
  }
}

fn longest(entities: List(Entity)) -> Option(Entity) {
  case entities {
    [] -> None
    [first, ..rest] -> Some(longest_from(first, rest))
  }
}

fn longest_from(current: Entity, entities: List(Entity)) -> Entity {
  case entities {
    [] -> current
    [candidate, ..rest] ->
      case string.length(candidate.module) > string.length(current.module) {
        True -> longest_from(candidate, rest)
        False -> longest_from(current, rest)
      }
  }
}

fn verb_for(service_module: String, target: Entity, matched: Bool) -> String {
  case matched {
    False -> service_module
    True -> {
      let prefix = target.module <> "_"
      case string.starts_with(service_module, prefix) {
        True -> string.drop_start(service_module, string.length(prefix))
        False -> ""
      }
    }
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
    model.ReadEffect, "read", True -> "GET"
    model.ReadEffect, "list", False -> "GET"
    model.WriteEffect, "delete", True -> "DELETE"
    model.WriteEffect, "put", True -> "PUT"
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
    model.ReadEffect, "read", True -> path
    model.ReadEffect, "list", False -> path
    model.WriteEffect, "delete", True -> path
    model.WriteEffect, "put", True -> path
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
