//// back の束(WGy、0.11.1)── `src/server.gleam` を宣言した app に、`api/src/gen` の宣言から導ける
//// 部分を書く。framework の固定の JS(`framework/server/*.mjs`、yumemi の package に載る)は写さず、
//// 生成物は表と配線だけを持つ。宣言から導けない業務の行は `hooks` に名を宣言した ★ だけを import する。
////
//// | file | 入力 |
//// |---|---|
//// | `src/gen/registry.mjs` | Service の宣言・entry・`server.routes` / `server.aliases`、`folded` は Service の source を生成時に判定 |
//// | `src/gen/sql.mjs` | app の `db/queries/**` と、この回に生成した SQL のうち app に無い道 |
//// | `src/gen/subject.gleam` | `subject: True` の Entity |
//// | `src/gen/key.gleam` | key が値型 1 つの Entity |
//// | `src/gen/<sum>.mjs` | payload を持つ sum の Property(`entity.visit.Source` -> `source.mjs`) |
//// | `src/gen/queue_runtime.mjs` | Service が `queue.<kind>` で呼ぶ kind と、その Service の Args / root |
//// | `src/gen/cron_runtime.mjs` | `server.cron` |
//// | `src/gen/shell.mjs` | `server.cron` / `server.durable_objects` |
//// | `src/gen/operations_ffi.mjs` | with の逆向き矢印(root の子の List) |
//// | `src/gen/entry/{auth,queue,system}.gleam` | framework の session / outbox の契約(固定) |

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import yumemi_gen/digest
import yumemi_gen/emit/codec
import yumemi_gen/emit/entry
import yumemi_gen/emit/hash
import yumemi_gen/emit/root
import yumemi_gen/emit/types.{type File, File}
import yumemi_gen/glance_util as g
import yumemi_gen/model.{type App, type Entity, type Service}
import yumemi_gen/naming
import yumemi_gen/source.{type Unit}
import yumemi_gen/stop

@external(javascript, "../../yumemi_gen_ffi.mjs", "foldable")
fn foldable(source: String, kinds: List(String)) -> Bool

@external(javascript, "../../yumemi_gen_ffi.mjs", "queue_calls")
fn queue_calls(source: String) -> List(String)

@external(javascript, "../../yumemi_gen_ffi.mjs", "json_string")
fn json_string(text: String) -> String

const framework = "../../yumemi/framework/server/"

pub type Output {
  Output(files: List(File), notes: List(stop.Note))
}

/// `app_queries` は app の `db/queries/**`(道は `.sql` 無し)、`generated` はこの回の生成物全部。
pub fn emit(
  app: App,
  units: List(Unit),
  hashes: hash.Hashes,
  app_queries: List(#(String, String)),
  generated: List(File),
) -> Output {
  case app.server.declared {
    False -> Output(files: [], notes: [])
    True -> {
      let input = back_hash(units, hashes)
      let queries = bundle(app_queries, generated)
      let kinds = queue_kinds(app, units)
      let #(queue_file, queue_notes) =
        queue_text(app, units, kinds, queries, input)
      let #(cron_file, cron_notes) = cron_text(app, input)
      let files =
        list.flatten([
          [
            File(
              path: "src/gen/registry.mjs",
              text: registry_text(app, units, input),
            ),
            File(path: "src/gen/sql.mjs", text: sql_text(queries, input)),
            File(path: "src/gen/codec.mjs", text: codec.text(app, units, input)),
            File(path: "src/gen/shell.mjs", text: shell_text(app, input)),
            File(
              path: "src/gen/operations_ffi.mjs",
              text: operations_text(app, input),
            ),
            File(path: "src/gen/entry/auth.gleam", text: auth_text(input)),
            File(
              path: "src/gen/entry/queue.gleam",
              text: queue_entry_text(input),
            ),
            File(path: "src/gen/entry/system.gleam", text: system_text(input)),
          ],
          subject_file(app, input),
          key_file(app, input),
          sum_files(app, units, input),
          queue_file,
          cron_file,
        ])
      Output(files: files, notes: list.append(queue_notes, cron_notes))
    }
  }
}

fn back_hash(units: List(Unit), hashes: hash.Hashes) -> String {
  let server =
    units
    |> list.filter(fn(unit) { unit.path == "server" })
    |> list.map(fn(unit) { unit.text })
    |> string.concat
  digest.short(hash.entry(hashes) <> hashes.entities <> server)
}

/// back の JS は api の既存の頭(`////`、Gleam の生成物と同じ 4 本)に揃える。
fn js_header(source: String, input: String) -> String {
  "//// GENERATED from " <> source <> " [sha256:" <> input <> "] — 手で編集しない\n"
}

fn gleam_header(source: String, input: String) -> String {
  "//// GENERATED from " <> source <> " [sha256:" <> input <> "] — 手で編集しない\n\n"
}

fn quoted(text: String) -> String {
  "'" <> text <> "'"
}

fn js_list(items: List(String)) -> String {
  "[" <> string.join(list.map(items, quoted), ", ") <> "]"
}

fn camel(snake: String) -> String {
  case string.split(snake, "_") {
    [] -> snake
    [first, ..rest] -> first <> string.concat(list.map(rest, naming.pascal))
  }
}

fn service_source(units: List(Unit), module: String) -> String {
  case list.find(units, fn(unit) { unit.path == "service/" <> module }) {
    Ok(unit) -> unit.text
    Error(_) -> ""
  }
}

fn sorted_services(app: App) -> List(Service) {
  list.sort(app.services, fn(left, right) {
    string.compare(left.module, right.module)
  })
}

// ── registry ────────────────────────────────────────────────────────────────

type Pair {
  Pair(method: String, path: String, credential: Option(String))
}

/// Service の (method, path)。上書き → Session の入口の導出 → ApiKey の入口の導出、の順。
/// 口が無ければ None(queue・cron・Service からの呼び出しだけの Service)。
fn pair_of(
  app: App,
  routes: List(entry.Route),
  service: Service,
) -> Option(Pair) {
  case model.server_route(app.server, service.module) {
    Some(model.InternalRoute(..)) -> None
    Some(model.OverrideRoute(method: method, path: path, credential: via, ..)) ->
      Some(Pair(method: method, path: path, credential: via))
    None -> {
      let mine =
        list.filter(routes, fn(route) { route.service == service.module })
      case
        list.find(mine, fn(route) { route.credential == "Session" }),
        list.find(mine, fn(route) { route.credential == "ApiKey" })
      {
        Ok(route), _ -> Some(Pair(route.method, colon(route.path), None))
        Error(_), Ok(route) ->
          Some(Pair(route.method, colon(route.path), Some("api_key")))
        Error(_), Error(_) -> None
      }
    }
  }
}

/// Session の入口どうしで口が違う(prefix の違う面)Service は、先頭の面の口を本体の行に、残りの面の口を
/// `<service>_<入口>` の別名の行(`target` が本体)にする。musearch の面は prefix が全部 `/api` で当たらない。
fn face_aliases(
  app: App,
  routes: List(entry.Route),
  service: Service,
) -> List(String) {
  case model.server_route(app.server, service.module) {
    Some(_) -> []
    None -> {
      let mine =
        list.filter(routes, fn(route) {
          route.service == service.module && route.credential == "Session"
        })
      case mine {
        [] -> []
        [first, ..rest] ->
          rest
          |> list.filter(fn(route) {
            route.method != first.method || route.path != first.path
          })
          |> list.fold([], fn(acc: List(entry.Route), route) {
            case
              list.any(acc, fn(other) {
                other.method == route.method && other.path == route.path
              })
            {
              True -> acc
              False -> list.append(acc, [route])
            }
          })
          |> list.map(fn(route) {
            "  { name: "
            <> quoted(service.module <> "_" <> route.face)
            <> ", module: "
            <> service.module
            <> ", root: root_"
            <> service.module
            <> ", method: "
            <> quoted(route.method)
            <> ", path: "
            <> quoted(colon(route.path))
            <> ", fields: "
            <> fields_of(service)
            <> ", folded: null, target: "
            <> quoted(service.module)
            <> " },\n"
          })
      }
    }
  }
}

fn colon(path: String) -> String {
  path |> string.replace("{", ":") |> string.replace("}", "")
}

fn folded_of(units: List(Unit), service: Service) -> String {
  let source = service_source(units, service.module)
  let kinds = queue_calls(source)
  case kinds != [] && foldable(source, kinds) {
    True -> "{ point: 1, kinds: " <> js_list(kinds) <> " }"
    False -> "null"
  }
}

/// 面を 1 つだけ宣言した Service は、その入口の外で検査 7 が 403 にする(`entry`)。
fn only_entry(app: App, service: Service) -> Option(String) {
  case service.faces_declared, service.faces {
    True, [face] ->
      list.find(app.entries, fn(entry) { naming.pascal(entry.name) == face })
      |> result.map(fn(entry) { entry.name })
      |> option.from_result
    _, _ -> None
  }
}

fn fields_of(service: Service) -> String {
  js_list(list.map(service.args, fn(arg) { arg.name }))
}

fn registry_text(app: App, units: List(Unit), input: String) -> String {
  let routes = entry.routes(app)
  let services = sorted_services(app)
  let imports =
    services
    |> list.map(fn(service) {
      "import * as "
      <> service.module
      <> " from '../service/"
      <> service.module
      <> ".mjs';\nimport * as root_"
      <> service.module
      <> " from './root/"
      <> service.module
      <> ".mjs';\n"
    })
    |> string.concat
  let rows =
    list.map(services, fn(service) {
      let #(method, path, credential) = case pair_of(app, routes, service) {
        Some(Pair(method, path, credential)) -> #(
          quoted(method),
          quoted(path),
          credential,
        )
        None -> #("null", "null", None)
      }
      "  { name: "
      <> quoted(service.module)
      <> ", module: "
      <> service.module
      <> ", root: root_"
      <> service.module
      <> ", method: "
      <> method
      <> ", path: "
      <> path
      <> ", fields: "
      <> fields_of(service)
      <> ", folded: "
      <> folded_of(units, service)
      <> case credential {
        Some(value) -> ", credential: " <> quoted(value)
        None -> ""
      }
      <> case only_entry(app, service) {
        Some(name) -> ", entry: " <> quoted(name)
        None -> ""
      }
      <> " },\n"
    })
  let face_rows =
    list.flat_map(services, fn(service) { face_aliases(app, routes, service) })
  let alias_rows =
    list.filter_map(app.server.aliases, fn(alias) {
      case alias {
        model.ServiceAlias(
          name: name,
          service: target,
          method: method,
          path: path,
          credential: credential,
          external_id: external_id,
        ) ->
          case
            list.find(app.services, fn(service) { service.module == target })
          {
            Error(_) -> Error(Nil)
            Ok(service) ->
              Ok(
                "  { name: "
                <> quoted(name)
                <> ", module: "
                <> target
                <> ", root: root_"
                <> target
                <> ", method: "
                <> quoted(method)
                <> ", path: "
                <> quoted(path)
                <> ", fields: "
                <> fields_of(service)
                <> ", folded: null, credential: "
                <> quoted(credential)
                <> ", target: "
                <> quoted(target)
                <> case external_id {
                  True -> ", externalId: true"
                  False -> ""
                }
                <> " },\n",
              )
          }
        model.AttachedAlias(
          name: name,
          attached: target,
          method: method,
          path: path,
          credential: credential,
          who: who,
        ) ->
          Ok(
            "  { name: "
            <> quoted(name)
            <> ", module: null, root: null, method: "
            <> quoted(method)
            <> ", path: "
            <> quoted(path)
            <> ", fields: [], folded: null, credential: "
            <> quoted(credential)
            <> ", target: "
            <> quoted(target)
            <> ", who: "
            <> quoted(who)
            <> " },\n",
          )
      }
    })
  js_header("service declarations / entry.gleam / server.gleam", input)
  <> "import { validateWho } from '"
  <> framework
  <> "contracts.mjs';\n\n"
  <> imports
  <> "\nexport const registry = [\n"
  <> string.concat(rows)
  <> string.concat(face_rows)
  <> string.concat(alias_rows)
  <> "];\n\n"
  <> "export const byName = Object.fromEntries(registry.filter((record) => !record.target && record.module).map((record) => [record.name, record]));\n\n"
  <> "for (const record of registry) if(record.module) validateWho([...record.module.service.allow]);\n"
}

// ── sql ─────────────────────────────────────────────────────────────────────

/// app の `db/queries/**`(★ の SQL と、採用済みの生成 SQL)に、この回に生成した SQL のうち app に無い道を
/// 足す。同じ道は app の file が勝つ ── 実行側の穴の契約は app が採った SQL に合っているため。生成 SQL を
/// 採る(`db/queries` に置く)と、その回から sql.mjs もそれに揃う。道の順に並べる。
fn bundle(
  app_queries: List(#(String, String)),
  generated: List(File),
) -> List(#(String, String)) {
  let made =
    list.filter_map(generated, fn(file) {
      case
        string.starts_with(file.path, "db/queries/")
        && string.ends_with(file.path, ".sql")
      {
        True ->
          Ok(#(
            file.path |> string.drop_start(11) |> string.drop_end(4),
            file.text,
          ))
        False -> Error(Nil)
      }
    })
  let fresh =
    list.filter(made, fn(pair) {
      !list.any(app_queries, fn(m) { m.0 == pair.0 })
    })
  list.append(app_queries, fresh)
  |> list.sort(fn(left, right) { string.compare(left.0, right.0) })
}

fn sql_text(queries: List(#(String, String)), input: String) -> String {
  js_header("db/queries/**", input)
  <> "export const SQL = {\n"
  <> string.concat(
    list.map(queries, fn(pair) {
      "  " <> json_string(pair.0) <> ": " <> json_string(pair.1) <> ",\n"
    }),
  )
  <> "};\n"
}

// ── subject / key ───────────────────────────────────────────────────────────

fn subject_file(app: App, input: String) -> List(File) {
  let subjects = list.filter(app.entities, fn(entity) { entity.subject })
  case subjects {
    [] -> []
    _ -> [
      File(
        path: "src/gen/subject.gleam",
        text: gleam_header(
          string.join(
            list.map(subjects, fn(entity) {
              "entity." <> entity.module <> ".subject"
            }),
            " / ",
          ),
          input,
        )
          <> "pub type Subject {\n"
          <> string.concat(
          list.map(subjects, fn(entity) { "  " <> entity.name <> "\n" }),
        )
          <> "}\n",
      ),
    ]
  }
}

/// key が値型 1 つ(`gen/types/<id>`、文字列の値)の Entity の `Key` を作る関数。
fn key_file(app: App, input: String) -> List(File) {
  let keyed =
    list.filter_map(app.entities, fn(entity) {
      case entity.key_type {
        Some(model.NamedShape(module: Some(path), name: name, parameters: [])) ->
          case string.starts_with(path, "gen/types/") {
            False -> Error(Nil)
            True ->
              case model.value_type_by_name(app.value_types, name) {
                Some(model.ValueType(backing: model.StringValue, ..)) ->
                  Ok(#(entity, path, name))
                _ -> Error(Nil)
              }
          }
        _ -> Error(Nil)
      }
    })
  case keyed {
    [] -> []
    _ -> {
      let entity_imports =
        keyed
        |> list.map(fn(item) { "import entity/" <> { item.0 }.module <> "\n" })
      let type_imports =
        keyed
        |> list.map(fn(item) {
          "import " <> item.1 <> ".{type " <> item.2 <> "}\n"
        })
      let imports =
        list.flatten([
          entity_imports,
          ["import framework/er.{type Key}\n"],
          type_imports,
        ])
        |> list.unique
        |> list.sort(string.compare)
      let functions =
        list.map(keyed, fn(item) {
          let #(entity, path, name) = item
          let value_module = last_path(path)
          "pub fn "
          <> entity.module
          <> "(id: "
          <> name
          <> ") -> Key("
          <> entity.module
          <> "."
          <> entity.type_name
          <> ") {\n  er.key("
          <> value_module
          <> ".to_string(id))\n}\n"
        })
      [
        File(
          path: "src/gen/key.gleam",
          text: gleam_header("entity declarations", input)
            <> string.concat(imports)
            <> "\n"
            <> string.join(functions, "\n"),
        ),
      ]
    }
  }
}

fn last_path(path: String) -> String {
  path |> string.split("/") |> list.last |> result.unwrap(path)
}

// ── sum の codec ────────────────────────────────────────────────────────────

type Variant {
  Variant(name: String, payload: Option(String))
}

/// payload を持つ sum の Property(`<prop>_kind` と payload の列)を行と値の間で写す。
/// 型ごとに 1 file(`src/gen/<snake(型)>.mjs`、`encode<型>` / `decode<型>`)。
fn sum_files(app: App, units: List(Unit), input: String) -> List(File) {
  app.entities
  |> list.flat_map(fn(entity) {
    list.filter_map(entity.props, fn(prop) {
      case prop.kind {
        model.SumProp(
          type_ref: model.TypeRef(module: Some(module), name: name, ..),
          payloads: [_, ..],
        ) -> Ok(#(entity, prop.name, module, name))
        _ -> Error(Nil)
      }
    })
  })
  |> list.unique
  |> list.filter_map(fn(item) {
    let #(_entity, prop, module, name) = item
    use variants <- result.try(variants_of(units, module, name))
    Ok(File(
      path: "src/gen/" <> naming.snake(name) <> ".mjs",
      text: sum_text(prop, module, name, variants, input),
    ))
  })
}

fn variants_of(
  units: List(Unit),
  module: String,
  name: String,
) -> Result(List(Variant), Nil) {
  use unit <- result.try(list.find(units, fn(unit) { unit.path == module }))
  use custom <- result.try(
    g.find_custom_type(unit.module, name) |> option.to_result(Nil),
  )
  list.try_map(custom.variants, fn(variant) {
    case variant.fields {
      [] -> Ok(Variant(variant.name, None))
      [field] ->
        case g.type_name(g.variant_field_type(field)) {
          Some(payload) -> Ok(Variant(variant.name, Some(payload)))
          None -> Error(Nil)
        }
      _ -> Error(Nil)
    }
  })
}

fn sum_text(
  prop: String,
  module: String,
  name: String,
  variants: List(Variant),
  input: String,
) -> String {
  let entity_alias = last_path(module)
  let payloads =
    variants
    |> list.filter_map(fn(variant) { option.to_result(variant.payload, Nil) })
    |> list.unique
  let payload_imports =
    list.map(payloads, fn(payload) {
      "import * as "
      <> camel(naming.snake(payload))
      <> " from './types/"
      <> naming.snake(payload)
      <> ".mjs';\n"
    })
  let kind = prop <> "_kind"
  let encode_rows =
    list.map(variants, fn(variant) {
      let tag = naming.snake(variant.name)
      " if("
      <> prop
      <> " instanceof "
      <> entity_alias
      <> "."
      <> variant.name
      <> ")return {"
      <> kind
      <> ":"
      <> quoted(tag)
      <> string.concat(
        list.map(payloads, fn(payload) {
          ","
          <> naming.snake(payload)
          <> ":"
          <> case variant.payload == Some(payload) {
            True ->
              camel(naming.snake(payload)) <> ".to_string(" <> prop <> "[0])"
            False -> "null"
          }
        }),
      )
      <> "};\n"
    })
  let decode_payload =
    list.filter_map(variants, fn(variant) {
      case variant.payload {
        Some(payload) ->
          Ok(
            " if(row."
            <> kind
            <> "==="
            <> quoted(naming.snake(variant.name))
            <> ") {const key="
            <> camel(naming.snake(payload))
            <> ".parse(row."
            <> naming.snake(payload)
            <> ");if(!key.isOk())throw new Error('invalid "
            <> string.replace(naming.snake(payload), "_", " ")
            <> "');return new "
            <> entity_alias
            <> "."
            <> variant.name
            <> "(key[0]);}\n",
          )
        None -> Error(Nil)
      }
    })
  let plain = list.filter(variants, fn(variant) { variant.payload == None })
  js_header(string.replace(module, "/", ".") <> "." <> name, input)
  <> "import * as "
  <> entity_alias
  <> " from '../"
  <> module
  <> ".mjs';\n"
  <> string.concat(payload_imports)
  <> "export function encode"
  <> name
  <> "("
  <> prop
  <> ") {\n"
  <> string.concat(encode_rows)
  <> " throw new Error('invalid "
  <> prop
  <> "');\n}\n"
  <> "export function decode"
  <> name
  <> "(row) {\n"
  <> string.concat(decode_payload)
  <> string.concat(
    list.map(payloads, fn(payload) {
      " if(row."
      <> naming.snake(payload)
      <> "!==null)throw new Error('unexpected "
      <> string.replace(naming.snake(payload), "_", " ")
      <> "');\n"
    }),
  )
  <> " const Constructor={"
  <> string.join(
    list.map(plain, fn(variant) {
      naming.snake(variant.name) <> ":" <> entity_alias <> "." <> variant.name
    }),
    ",",
  )
  <> "}[row."
  <> kind
  <> "];\n if(!Constructor)throw new Error('invalid "
  <> prop
  <> " kind');return new Constructor();\n}\n"
}

// ── queue ───────────────────────────────────────────────────────────────────

/// Service の source が `step.call_write(queue.<kind>(` で呼ぶ kind。kind は同じ名の Service。
fn queue_kinds(app: App, units: List(Unit)) -> List(String) {
  app.services
  |> list.flat_map(fn(service) {
    queue_calls(service_source(units, service.module))
  })
  |> list.unique
  |> list.filter(fn(kind) {
    list.any(app.services, fn(service) { service.module == kind })
  })
  |> list.sort(string.compare)
}

fn service_named(app: App, name: String) -> Option(Service) {
  list.find(app.services, fn(service) { service.module == name })
  |> option.from_result
}

/// Args の 1 つ目の型から scalar の名(`ArticleId` -> `article_id`)。
fn first_scalar(service: Service) -> Option(String) {
  case service.args {
    [model.Arg(type_: model.NamedShape(name: name, ..), ..), ..] ->
      Some(naming.snake(name))
    _ -> None
  }
}

fn queue_text(
  app: App,
  units: List(Unit),
  kinds: List(String),
  queries: List(#(String, String)),
  input: String,
) -> #(List(File), List(stop.Note)) {
  case kinds {
    [] -> #([], [])
    _ -> {
      let rooted = fn(name) {
        list.any(queries, fn(pair) { pair.0 == name <> "/root" })
      }
      let ids =
        list.filter_map(kinds, fn(kind) {
          use service <- result.try(
            service_named(app, kind) |> option.to_result(Nil),
          )
          use id <- result.try(first_scalar(service) |> option.to_result(Nil))
          let versioned = case service.args {
            [_, model.Arg(name: "version", ..), ..] -> ",versioned:true"
            _ -> ""
          }
          Ok(" " <> kind <> ":{id:" <> quoted(id) <> versioned <> "},\n")
        })
      let consumers =
        list.filter_map(kinds, fn(kind) {
          case rooted(kind), service_named(app, kind) {
            True, _ | _, None -> Error(Nil)
            False, Some(service) -> Ok(consumer_of(app, units, service, rooted))
          }
        })
      let notes =
        list.filter_map(consumers, fn(item) {
          case item {
            Error(text) -> Ok(stop.Note(class: stop.Conflict, text: text))
            Ok(_) -> Error(Nil)
          }
        })
      let consumers = list.filter_map(consumers, fn(item) { item })
      let imports =
        list.flat_map(consumers, fn(consumer) { consumer.imports })
        |> list.unique
      #(
        [
          File(
            path: "src/gen/queue_runtime.mjs",
            text: js_header("service queue calls / framework outbox", input)
              <> "import { outbox } from '"
              <> framework
              <> "outbox.mjs';\n"
              <> "import * as registry from './registry.mjs';\n"
              <> "import * as c from './codec.mjs';\n"
              <> "import * as runtime from './runtime.mjs';\n"
              <> string.concat(imports)
              <> "export const registeredKinds="
              <> "["
              <> string.join(list.map(kinds, quoted), ",")
              <> "];\n"
              <> "const ids={\n"
              <> string.concat(ids)
              <> "};\n"
              <> "const consumers={\n"
              <> string.concat(
              list.map(consumers, fn(consumer) { consumer.row }),
            )
              <> "};\n"
              <> "const queue=outbox({kinds:registeredKinds,ids,consumers,registry,codec:c,runtime});\n"
              <> "export const sweep=(db,env)=>queue.sweep(db,env);\n"
              <> "export const consume=(message,db,env,connectors)=>queue.consume(message,db,env,connectors);\n",
          ),
        ],
        notes,
      )
    }
  }
}

type Consumer {
  Consumer(imports: List(String), row: String)
}

/// root の 1 文を持たない consumer は、root の 1 文を持ち自分を queue で呼ぶ Service(名の順で先頭)の
/// root を借りる。借りた root の Entity(その Service の root Entity)と相だけを写す。
fn consumer_of(
  app: App,
  units: List(Unit),
  service: Service,
  rooted: fn(String) -> Bool,
) -> Result(Consumer, String) {
  let base =
    sorted_services(app)
    |> list.find(fn(other) {
      other.module != service.module
      && rooted(other.module)
      && list.contains(
        queue_calls(service_source(units, other.module)),
        service.module,
      )
    })
  let entity = case base {
    Ok(base) ->
      case root.root_for(app, base) {
        Some(entity) -> Some(entity)
        None -> allow_entity(app, base)
      }
    Error(_) -> None
  }
  case entity, base, service.allow_module {
    Some(entity), Ok(base), Some(allow) -> {
      let name = camel(service.module)
      let allow_alias = "allow" <> naming.pascal(last_path(allow))
      let staff_root =
        list.all(clauses_of(app, base.module), fn(clause) {
          case clause {
            model.Clause(who: who, ..) -> string.ends_with(who, "Staff")
            _ -> False
          }
        })
      Ok(Consumer(
        imports: [
          "import * as "
            <> name
            <> " from '../service/"
            <> service.module
            <> ".mjs';\n",
          "import * as root"
            <> naming.pascal(service.module)
            <> " from './root/"
            <> service.module
            <> ".mjs';\n",
          "import * as "
            <> allow_alias
            <> " from './"
            <> string.drop_start(allow, 4)
            <> ".mjs';\n",
        ],
        row: " "
          <> service.module
          <> ":{base:"
          <> quoted(base.module)
          <> ",module:"
          <> name
          <> ",root:root"
          <> naming.pascal(service.module)
          <> ",actor:()=>new "
          <> allow_alias
          <> ".SystemActor(),field:"
          <> quoted(entity.module)
          <> case staff_root {
          True -> ",staffRoot:true"
          False -> ""
        }
          <> "},\n",
      ))
    }
    _, _, _ ->
      Error(
        "queue の consumer "
        <> service.module
        <> " の root を借りる Service が無い(root の 1 文を持ち、自分を queue で呼ぶ Service)",
      )
  }
}

fn clauses_of(app: App, module: String) -> List(model.Clause) {
  list.key_find(app.clauses, module) |> result.unwrap([])
}

fn allow_entity(app: App, service: Service) -> Option(Entity) {
  case service.allow_module {
    Some(path) -> model.entity_by_module(app.entities, last_path(path))
    None -> None
  }
}

// ── cron ────────────────────────────────────────────────────────────────────

/// 仕事の JS の名。`EachDue(article_release, due)` -> `releaseDue`(Service の頭の語を落とした動詞 + 読み)、
/// `Hooked(metrics_rollup, ..)` -> `rollupMetrics`(動詞 + 頭の語)。
fn job_name(job: model.CronJob) -> String {
  case job {
    model.EachDue(service: service, query: query) ->
      camel(verb_of(service) <> "_" <> query)
    model.HookedJob(service: service, ..) ->
      camel(verb_of(service) <> "_" <> first_word(service))
  }
}

fn verb_of(service: String) -> String {
  case string.split(service, "_") {
    [_, ..rest] if rest != [] -> string.join(rest, "_")
    _ -> service
  }
}

fn first_word(service: String) -> String {
  string.split(service, "_") |> list.first |> result.unwrap(service)
}

fn jobs(app: App) -> List(model.CronJob) {
  app.server.cron
  |> list.flat_map(fn(cron) { cron.jobs })
  |> list.unique
}

fn hook_module(app: App, name: String) -> Option(String) {
  list.find(app.server.hooks, fn(hook) { hook.name == name })
  |> result.map(fn(hook) { hook.module })
  |> option.from_result
}

fn cron_text(app: App, input: String) -> #(List(File), List(stop.Note)) {
  case jobs(app) {
    [] -> #([], [])
    all -> {
      let hook_imports =
        list.filter_map(all, fn(job) {
          case job {
            model.HookedJob(hook: hook, ..) ->
              case hook_module(app, hook) {
                Some(module) ->
                  Ok(
                    "import { "
                    <> camel(hook)
                    <> " } from '../"
                    <> module
                    <> ".mjs';\n",
                  )
                None -> Error(Nil)
              }
            model.EachDue(..) -> Error(Nil)
          }
        })
        |> list.unique
      let functions =
        list.map(all, fn(job) {
          case job {
            model.EachDue(service: service, query: query) -> {
              let id =
                service_named(app, service)
                |> option.then(first_scalar)
                |> option.unwrap("id")
              "export async function "
              <> job_name(job)
              <> "(db,env,at=new Date().toISOString(),invokeImpl=invoke,sweepImpl=sweep) {\n"
              <> " return cron.eachDue({record:byName."
              <> service
              <> ",query:"
              <> quoted(service <> "/" <> query)
              <> ",idKey:"
              <> quoted(id)
              <> ",db,env,at,run,invoke:invokeImpl,sweep:sweepImpl,codec:c});\n}\n"
            }
            model.HookedJob(service: service, hook: hook) ->
              "export async function "
              <> job_name(job)
              <> "(db,env,at=new Date().toISOString(),invokeImpl=invoke) {\n"
              <> " const record=byName."
              <> service
              <> ";\n const {args,report}="
              <> camel(hook)
              <> "(at,record.module,c);\n"
              <> " await cron.hooked({record,args,db,env,at,invoke:invokeImpl});\n"
              <> " return report;\n}\n"
          }
        })
      #(
        [
          File(
            path: "src/gen/cron_runtime.mjs",
            text: js_header("server.cron / framework cron", input)
              <> "import * as cron from '"
              <> framework
              <> "cron.mjs';\n"
              <> "import { byName } from './registry.mjs';\n"
              <> "import * as c from './codec.mjs';\n"
              <> "import { run, invoke } from './runtime.mjs';\n"
              <> "import { sweep } from './queue_runtime.mjs';\n"
              <> string.concat(hook_imports)
              <> string.join(functions, "\n"),
          ),
        ],
        [],
      )
    }
  }
}

// ── shell ───────────────────────────────────────────────────────────────────

fn shell_text(app: App, input: String) -> String {
  let cron_imports = case jobs(app) {
    [] -> ""
    all ->
      "import { "
      <> string.join(list.map(all, job_name), ", ")
      <> " } from './cron_runtime.mjs';\n"
  }
  let object_imports =
    list.map(app.server.durable_objects, fn(object) {
      "import { "
      <> object.adapter
      <> " } from '../"
      <> object.module
      <> ".mjs';\n"
    })
    |> list.unique
  let branches =
    list.map(app.server.cron, fn(cron) {
      "  if(controller.cron==="
      <> quoted(cron.schedule)
      <> ") execution.waitUntil(Promise.all(["
      <> string.join(
        list.map(cron.jobs, fn(job) { job_name(job) <> "(db,env)" }),
        ",",
      )
      <> "]));\n  else"
    })
  let objects =
    list.map(app.server.durable_objects, fn(object) {
      "export const "
      <> object.class
      <> "=durableObject("
      <> object.adapter
      <> ","
      <> "["
      <> string.join(list.map(object.methods, quoted), ",")
      <> "]);\n"
    })
  js_header(
    "entry.entries / server.gleam / framework Cloudflare adapter",
    input,
  )
  <> "import { handlers, appSystem, durableObject } from '"
  <> framework
  <> "worker.mjs';\n"
  <> "import { database } from '"
  <> framework
  <> "driver.mjs';\n"
  <> "import { dispatch } from './entry/http.mjs';\n"
  <> "import { issueSession,resolveSession,revokeParty,run } from './runtime.mjs';\n"
  <> cron_imports
  <> "import { sweep,consume } from './queue_runtime.mjs';\n"
  <> string.concat(object_imports)
  <> "const observe=event=>console.log(JSON.stringify({component:'database',...event}));\n"
  <> "const worker=handlers({dispatch,database,observe,sweep,consume});\n"
  <> "export default {\n"
  <> " fetch: worker.fetch,\n"
  <> " queue: worker.queue,\n"
  <> " async scheduled(controller,env,execution) {\n"
  <> "  const db=database(env,observe);\n"
  <> case branches {
    [] -> "  "
    _ -> string.concat(branches) <> " "
  }
  <> "execution.waitUntil(sweep(db,env));\n"
  <> " }\n};\n"
  <> "export const AppSystem=appSystem({database,observe,issueSession,revokeParty,resolveSession,run});\n"
  <> string.concat(objects)
}

// ── operations / entry ──────────────────────────────────────────────────────

/// connector / verb / reads の FFI の口(framework)と、root の子の List(with の逆向き矢印)を読む口。
fn operations_text(app: App, input: String) -> String {
  let children =
    app.reverse_arrows
    |> list.filter_map(fn(arrow) {
      case string.split(arrow.name, "To") {
        [_, plural] -> Ok(naming.snake(plural))
        _ -> Error(Nil)
      }
    })
    |> list.unique
    |> list.sort(string.compare)
  js_header("verb / reads / connector operations", input)
  <> "export { stage, read, call, enqueue } from '"
  <> framework
  <> "operations.mjs';\n"
  <> string.concat(
    list.map(children, fn(child) {
      "export const root"
      <> naming.pascal(child)
      <> " = root => root."
      <> child
      <> " ?? [];\n"
    }),
  )
}

fn auth_text(input: String) -> String {
  gleam_header("framework session contract", input)
  <> "import framework/io.{type Promise}\n\n"
  <> "pub type Database\n\n"
  <> "pub type Resolved\n\n"
  <> "@external(javascript, \"../runtime.mjs\", \"resolveSession\")\n"
  <> "pub fn resolve(database: Database, id: String, at: String) -> Promise(Resolved)\n"
}

fn queue_entry_text(input: String) -> String {
  gleam_header("service commit continuations / framework outbox", input)
  <> "import framework/io.{type Context, type Promise}\n"
  <> "import framework/step.{type Committed, type Outcome, type Step}\n\n"
  <> "pub fn resume(\n  continuation: Step(out, err, Committed),\n  context: Context,\n) -> Promise(Outcome(out, err)) {\n  step.resume(continuation, context)\n}\n"
}

fn system_text(input: String) -> String {
  gleam_header("framework session / credential_floor contract", input)
  <> "import framework/io.{type Promise}\n"
  <> "import gen/entry/auth.{type Database}\n\n"
  <> "pub type Issued\n\n"
  <> "@external(javascript, \"../runtime.mjs\", \"issueSession\")\n"
  <> "pub fn session(\n  database: Database,\n  party: String,\n  expires_at: String,\n  credential_version: Int,\n) -> Promise(Issued)\n\n"
  <> "@external(javascript, \"../runtime.mjs\", \"revokeParty\")\n"
  <> "pub fn revoke(database: Database, party: String, floor: Int) -> Promise(Int)\n"
}
