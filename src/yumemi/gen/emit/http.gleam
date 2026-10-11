//// `src/gen/http_runtime.mjs`(WGy r3)── HTTP の入口の表。検査 1〜10 の機関は yumemi の
//// `yumemi/server/http.mjs`(`http(spec)`)で、ここは宣言から導いた表だけを書く。
////
//// - hosts:入口(`src/entry.gleam`)の名 -> env の `<NAME>_HOST`
//// - args:Service の `Args` の欄の型から decode の語彙(値型・整数・日付・blob・cursor・色・列挙・Option・List)。
////   型から導けない欄は ★ hook `arg_<service>_<key>` / `arg_<key>`(宣言した名がそのまま勝つ)
//// - phaseGates:root を持たず、句が全部 `As<Entity>` で相を絞る Service(主体の相で門を閉じる)
//// - accepted:Accepted の応答の欄(root の Entity の名)
//// - ports:attached の口のうち、機関を framework が持つ役(`attached_roles` の `Declare` /
////   `ReadSession` / `SwitchSubject`)でないものは ★ hook `attached_<name>`
//// - roles / browserCookie:`attached_roles` と `browser` の宣言をそのまま(framework は app の口の名も
////   cookie の名も申告の種類の名も知らない ── WGy r4、0.12)。種類を持つ役は `declare:<kind>` / `needs_declared:<kind>`
//// - pageviews:面の門の数える口(0.12)。入口の名 -> `{only, fields, sink}`。`ToService` の sink は Service が
////   印を root に運ぶか(`Carried(.., "browser", ..)`)を `browser` に持つ ── 運ばない Service では印の cookie を焼かない
//// - hooks:業務の行(`args_before` / `api_encode` / `failure_status` / `failure` / `respond` / `route_skip` /
////   `origin` / `early` / `judge` / `raw_body` / `attached_args` / `external_id` / `db_error` / `write_gate`)

import glance
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import yumemi/gen/emit/root
import yumemi/gen/glance_util as g
import yumemi/gen/model.{type App, type Service}
import yumemi/gen/naming
import yumemi/gen/source.{type Unit}
import yumemi/gen/stop

const framework = "../../yumemi/yumemi/server/"

/// 機関を framework の JS が持ち、★ hook `attached_<name>` の要らない役(`attached_roles` の宣言)。
const framework_roles = ["declare", "read_session", "switch_subject"]

const business_hooks = [
  "args_before", "api_encode", "failure_status", "failure", "respond",
  "route_skip", "origin", "origin_always", "early", "judge", "raw_body",
  "attached_args", "external_id", "db_error", "write_gate", "api_key_pattern",
]

pub fn text(
  app: App,
  units: List(Unit),
  header: String,
) -> #(String, List(stop.Note)) {
  let hook_names = list.map(app.server.hooks, fn(hook) { hook.name })
  let rows =
    app.services
    |> list.map(fn(service) {
      #(
        service,
        list.map(service.args, fn(arg) {
          #(arg, arg_type(app, units, hook_names, service, arg))
        }),
      )
    })
  let missing =
    list.flat_map(rows, fn(row) {
      list.filter_map(row.1, fn(pair) {
        case pair.1 {
          Error(detail) ->
            Ok(
              "http: "
              <> row.0.module
              <> "."
              <> { pair.0 }.name
              <> " の型から decode を導けない("
              <> detail
              <> ")── hook arg_"
              <> row.0.module
              <> "_"
              <> { pair.0 }.name
              <> " か arg_"
              <> { pair.0 }.name
              <> " を宣言する",
            )
          Ok(_) -> Error(Nil)
        }
      })
    })
  let attached_names =
    list.map(app.attached, fn(route) { naming.snake(route.name) })
  let framework_attached =
    app.server.attached_roles
    |> list.filter(fn(row) { list.contains(framework_roles, row.role) })
    |> list.map(fn(row) { row.attached })
  let port_missing =
    attached_names
    |> list.filter(fn(name) {
      !list.contains(framework_attached, name)
      && !list.contains(hook_names, "attached_" <> name)
    })
    |> list.map(fn(name) {
      "http: attached の口 "
      <> name
      <> " の hook attached_"
      <> name
      <> " が hooks に無い"
    })
  let notes =
    list.map(list.append(missing, port_missing), fn(text) {
      stop.Note(class: stop.Conflict, text: text)
    })
  let enum_modules =
    rows
    |> list.flat_map(fn(row) {
      list.filter_map(row.1, fn(pair) {
        case pair.1 {
          Ok(#(_, modules)) -> Ok(modules)
          Error(_) -> Error(Nil)
        }
      })
    })
    |> list.flatten
    |> list.unique
    |> list.sort(string.compare)
  let used_hooks =
    hook_names
    |> list.filter(fn(name) {
      list.contains(business_hooks, name)
      || string.starts_with(name, "arg_")
      || string.starts_with(name, "attached_")
      || string.starts_with(name, "service_")
    })
  let hook_imports =
    app.server.hooks
    |> list.filter(fn(hook) { list.contains(used_hooks, hook.name) })
    |> list.map(fn(hook) {
      "import { "
      <> camel(hook.name)
      <> " as h_"
      <> camel(hook.name)
      <> " } from '../"
      <> hook.module
      <> ".mjs';\n"
    })
    |> string.concat
  let imports =
    string.concat([
      "import { Ok, Error } from '../gleam.mjs';\n",
      "import { registry } from './registry.mjs';\n",
      "import { attached } from './attached.mjs';\n",
      "import * as c from './codec.mjs';\n",
      "import * as runtime from './runtime.mjs';\n",
      "import { http } from '" <> framework <> "http.mjs';\n",
      list.map(enum_modules, fn(path) {
        "import * as "
        <> module_alias(path)
        <> " from '../"
        <> path
        <> ".mjs';\n"
      })
        |> string.concat,
      hook_imports,
    ])
  let hosts =
    app.entries
    |> list.map(fn(entry) {
      entry.name <> ":" <> quoted(string.uppercase(entry.name) <> "_HOST")
    })
  let args =
    rows
    |> list.map(fn(row) {
      " "
      <> row.0.module
      <> ":["
      <> string.join(
        list.filter_map(row.1, fn(pair) {
          case pair.1 {
            Ok(#(text, _)) ->
              Ok("[" <> quoted({ pair.0 }.name) <> "," <> text <> "]")
            Error(_) ->
              Ok(
                "["
                <> quoted({ pair.0 }.name)
                <> ",['hook',"
                <> quoted("arg_" <> row.0.module <> "_" <> { pair.0 }.name)
                <> "]]",
              )
          }
        }),
        ",",
      )
      <> "],\n"
    })
  let modules =
    list.map(enum_modules, fn(path) {
      quoted(path) <> ":" <> module_alias(path)
    })
  let gates =
    app.services
    |> list.filter_map(fn(service) { phase_gate(app, service) })
  let accepted =
    app.services
    |> list.filter_map(fn(service) {
      case root.root_for(app, service) {
        Some(entity) -> Ok(service.module <> ":" <> quoted(entity.module))
        None -> Error(Nil)
      }
    })
  let ports =
    attached_names
    |> list.filter(fn(name) { !list.contains(framework_attached, name) })
    |> list.filter(fn(name) { list.contains(hook_names, "attached_" <> name) })
    |> list.map(fn(name) { name <> ":h_" <> camel("attached_" <> name) })
  // DO の器に在る Entity の Service のように、invoke でなく ★ の口で応える Service(`service_<name>`)
  let ports =
    list.append(
      ports,
      app.services
        |> list.filter(fn(service) {
          list.contains(hook_names, "service_" <> service.module)
        })
        |> list.map(fn(service) {
          service.module <> ":h_" <> camel("service_" <> service.module)
        }),
    )
  let hooks =
    used_hooks
    |> list.filter(fn(name) {
      !string.starts_with(name, "attached_")
      && !string.starts_with(name, "service_")
      && name != "api_key_pattern"
    })
    |> list.map(fn(name) { name <> ":h_" <> camel(name) })
  let subjects =
    app.entities
    |> list.filter(fn(entity) { entity.subject })
    |> list.map(fn(entity) { quoted(entity.module) })
  let roles =
    app.server.attached_roles
    |> list.map(fn(row) { row.attached })
    |> list.unique
    |> list.map(fn(name) {
      name
      <> ":["
      <> string.join(
        app.server.attached_roles
          |> list.filter(fn(row) { row.attached == name })
          |> list.map(fn(row) {
            case row.kind {
              "" -> quoted(row.role)
              kind -> quoted(row.role <> ":" <> kind)
            }
          }),
        ",",
      )
      <> "]"
    })
  let browser_cookie = case app.server.browser {
    None -> "null"
    Some(declared) ->
      "{cookie:"
      <> quoted(declared.cookie)
      <> ",binding:"
      <> quoted(declared.key_binding)
      <> ",maxAgeDays:"
      <> int.to_string(declared.max_age_days)
      <> ",declarations:["
      <> string.join(
        list.map(declared.declarations, fn(d) {
          "{kind:"
          <> quoted(d.kind)
          <> ",claim:"
          <> quoted(d.claim)
          <> ",maxAgeDays:"
          <> int.to_string(d.max_age_days)
          <> "}"
        }),
        ",",
      )
      <> "]}"
  }
  let pageviews =
    list.map(app.server.counted, fn(counted) { pageview_js(app, counted) })
  let body =
    string.concat([
      "const hosts={",
      string.join(hosts, ","),
      "};\n",
      "const args={\n",
      string.concat(args),
      "};\n",
      "const modules={",
      string.join(modules, ","),
      "};\n",
      "const phaseGates={",
      string.join(gates, ","),
      "};\n",
      "const accepted={",
      string.join(accepted, ","),
      "};\n",
      "const ports={",
      string.join(ports, ","),
      "};\n",
      "const hooks={",
      string.join(hooks, ","),
      "};\n",
      "const subjects=[",
      string.join(subjects, ","),
      "];\n",
      "const roles={",
      string.join(roles, ","),
      "};\n",
      "const browserCookie=",
      browser_cookie,
      ";\n",
      "const pageviews={",
      string.join(pageviews, ","),
      "};\n",
      "const subjectFree=[",
      string.join(list.map(app.server.subject_free, quoted), ","),
      "];\n",
      "const keyPattern=",
      case list.contains(hook_names, "api_key_pattern") {
        True -> "h_apiKeyPattern"
        False -> "'[0-9a-f]{64}'"
      },
      ";\n",
      "export const {sessionCookie,cookies,signBrowser,verifyBrowser,host,route,origin,browser,admit,resolve,subject,decode,judge,execute,apiEncode,logicFailureStatus}=http({Ok,Error,registry,attached,c,runtime,hosts,args,modules,phaseGates,accepted,ports,hooks,subjects,roles,browserCookie,pageviews,subjectFree,apiKeyPattern:keyPattern});\n",
    ])
  #(header <> imports <> body, notes)
}

fn quoted(text: String) -> String {
  "'" <> text <> "'"
}

fn camel(snake: String) -> String {
  case string.split(snake, "_") {
    [] -> snake
    [first, ..rest] -> first <> string.concat(list.map(rest, naming.pascal))
  }
}

fn module_alias(path: String) -> String {
  "m_" <> string.replace(path, "/", "_")
}

/// root を持たず、句が全部 `As<Entity>` で `Only([..])` の Service ── 主体の相で門を閉じる。
/// `Only` の相は allow の Entity の相なので、`As<X>` の X が allow の Entity そのものの句に限る
/// (WGy r4)。X が別の Entity の句を持つ Service は門を出さず、相は読みの SQL が allow の行で照らす。
fn phase_gate(app: App, service: Service) -> Result(String, Nil) {
  case root.root_for(app, service) {
    Some(_) -> Error(Nil)
    None -> {
      let clauses = case list.key_find(app.clauses, service.module) {
        Ok(found) -> found
        Error(_) -> []
      }
      let phases =
        list.map(clauses, fn(clause) {
          case clause {
            model.Clause(who: who, at: model.OnlyAt(items), ..) ->
              case root.who_is_allow_entity(app, service, who) {
                True -> Ok(items)
                False -> Error(Nil)
              }
            _ -> Error(Nil)
          }
        })
      case clauses != [] && list.all(phases, fn(item) { item != Error(Nil) }) {
        True -> {
          let names =
            phases
            |> list.flat_map(fn(item) {
              case item {
                Ok(items) -> items
                Error(_) -> []
              }
            })
            |> list.map(fn(name) {
              let last = case string.split(name, ".") |> list.last {
                Ok(found) -> found
                Error(_) -> name
              }
              quoted(naming.snake(last))
            })
            |> list.unique
          Ok(service.module <> ":[" <> string.join(names, ",") <> "]")
        }
        False -> Error(Nil)
      }
    }
  }
}

/// Args の欄の型 -> decode の語彙(JS の値の綴り)と、import が要る列挙の module。
fn arg_type(
  app: App,
  units: List(Unit),
  hooks: List(String),
  service: Service,
  arg: model.Arg,
) -> Result(#(String, List(String)), String) {
  let specific = "arg_" <> service.module <> "_" <> arg.name
  let general = "arg_" <> arg.name
  case list.contains(hooks, specific), list.contains(hooks, general) {
    True, _ -> Ok(#("['hook'," <> quoted(specific) <> "]", []))
    _, True -> Ok(#("['hook'," <> quoted(general) <> "]", []))
    _, _ -> shape_type(app, units, service, arg.type_)
  }
}

fn shape_type(
  app: App,
  units: List(Unit),
  service: Service,
  shape: model.TypeShape,
) -> Result(#(String, List(String)), String) {
  case shape {
    model.NamedShape(
      module: Some("gleam/option"),
      name: "Option",
      parameters: [inner],
    )
    | model.NamedShape(module: None, name: "Option", parameters: [inner]) -> {
      use #(text, modules) <- result_try(shape_type(app, units, service, inner))
      Ok(#("['option'," <> text <> "]", modules))
    }
    model.NamedShape(module: None, name: "List", parameters: [inner]) -> {
      use #(text, modules) <- result_try(shape_type(app, units, service, inner))
      Ok(#("['list'," <> text <> "]", modules))
    }
    model.NamedShape(module: None, name: "Int", ..) -> Ok(#("['integer']", []))
    model.NamedShape(module: None, name: "Float", ..) -> Ok(#("['float']", []))
    model.NamedShape(module: None, name: "Bool", ..) -> Ok(#("['bool']", []))
    model.NamedShape(module: None, name: "String", ..) -> Ok(#("['text']", []))
    model.NamedShape(module: Some("yumemi/time"), name: "Date", ..) ->
      Ok(#("['date']", []))
    model.NamedShape(module: Some("yumemi/time"), name: "Datetime", ..) ->
      Ok(#("['datetime']", []))
    model.NamedShape(module: Some("yumemi/time"), name: "Time", ..) ->
      Ok(#("['time']", []))
    model.NamedShape(module: Some("yumemi/blob"), name: "Blob", ..) ->
      Ok(#("['blob']", []))
    model.NamedShape(module: Some("yumemi/page"), name: "Cursor", ..) ->
      Ok(#("['cursor']", []))
    model.NamedShape(module: Some("yumemi/page"), name: "PageSize", ..) ->
      Ok(#("['integer']", []))
    model.NamedShape(module: Some("yumemi/er"), name: "Key", ..) ->
      Ok(#("['key']", []))
    model.NamedShape(module: Some("yumemi/front/color"), name: "Color", ..) ->
      Ok(#("['color']", []))
    model.NamedShape(module: Some(path), name: name, ..) ->
      case string.starts_with(path, "gen/types/") {
        True -> value_type(app, string.drop_start(path, 10))
        False ->
          case path, name {
            "ledger_store", "LedgerStoreId" | "ledger", "LedgerStoreId" ->
              Ok(#("['scalar','ledger_store_id']", []))
            _, _ -> enum_type(units, path, name)
          }
      }
    model.NamedShape(module: None, name: name, ..) ->
      enum_type(units, "service/" <> service.module, name)
    model.TupleShape(_) -> Error("組")
  }
}

fn result_try(
  result: Result(a, e),
  next: fn(a) -> Result(b, e),
) -> Result(b, e) {
  case result {
    Ok(value) -> next(value)
    Error(error) -> Error(error)
  }
}

fn value_type(
  app: App,
  scalar: String,
) -> Result(#(String, List(String)), String) {
  case list.find(app.value_types, fn(value) { value.name == scalar }) {
    Ok(model.ValueType(backing: model.IntValue, ..)) ->
      Ok(#("['int'," <> quoted(scalar) <> "]", []))
    _ -> Ok(#("['scalar'," <> quoted(scalar) <> "]", []))
  }
}

/// payload の無い構成子だけの sum -> `['enum', module, [snake の名…]]`。
fn enum_type(
  units: List(Unit),
  path: String,
  name: String,
) -> Result(#(String, List(String)), String) {
  case list.find(units, fn(unit) { unit.path == path }) {
    Error(_) -> Error(path <> "." <> name <> " の module が読めない")
    Ok(unit) ->
      case g.find_custom_type(unit.module, name) {
        None -> Error(path <> "." <> name <> " の型が無い")
        Some(custom) -> {
          let bare =
            list.all(custom.variants, fn(variant: glance.Variant) {
              variant.fields == []
            })
          case bare {
            False -> Error(path <> "." <> name <> " は payload を持つ構成子がある")
            True -> {
              let values =
                list.map(custom.variants, fn(variant: glance.Variant) {
                  quoted(naming.snake(variant.name))
                })
              Ok(
                #(
                  "['enum',"
                    <> quoted(path)
                    <> ",["
                    <> string.join(values, ",")
                    <> "]]",
                  [path],
                ),
              )
            }
          }
        }
      }
  }
}

/// 数える口の 1 面(`<入口の名>:{only,fields,sink}`、0.12)。
fn pageview_js(app: App, counted: model.Counted) -> String {
  let only =
    list.map(counted.only, fn(when) {
      case when {
        model.WhenDeclared(kind) ->
          "{type:'declared',kind:" <> quoted(kind) <> "}"
        model.WhenSignedIn -> "{type:'signed-in'}"
      }
    })
  let fields =
    list.map(counted.fields, fn(field) {
      case field {
        model.NavKindField -> "{type:'kind'}"
        model.ClientAtField -> "{type:'client_at'}"
        model.PathField -> "{type:'path'}"
        model.PreviousField -> "{type:'previous'}"
        model.ReferrerField -> "{type:'referrer'}"
        model.FromQueryField(name: name, max: max, ..) ->
          "{type:'query',name:"
          <> quoted(name)
          <> ",max:"
          <> int.to_string(max)
          <> "}"
      }
    })
  let sink = case counted.sink {
    model.ServiceSink(service) ->
      "{type:'service',service:"
      <> quoted(service)
      <> ",browser:"
      <> case carries_browser(app, service) {
        True -> "true"
        False -> "false"
      }
      <> "}"
    model.StoreSink(
      resolve: resolve,
      rollup_by: rollup_by,
      exclude_when: exclude,
    ) ->
      "{type:'store',resolve:"
      <> case resolve {
        Some(name) -> quoted(name)
        None -> "null"
      }
      <> ",rollupBy:["
      <> string.join(list.map(rollup_by, quoted), ",")
      <> "],excludeWhen:["
      <> string.join(list.map(exclude, quoted), ",")
      <> "]}"
  }
  quoted(counted.face)
  <> ":{only:["
  <> string.join(only, ",")
  <> "],fields:["
  <> string.join(fields, ",")
  <> "],sink:"
  <> sink
  <> "}"
}

/// Service が印(`Carried(.., "browser", ..)`)を root に運ぶか。
pub fn carries_browser(app: App, service: String) -> Bool {
  list.any(app.server.roots, fn(shape) {
    case shape {
      model.Carried(service: name, name: "browser", ..) -> name == service
      _ -> False
    }
  })
}

/// 数える口の event の欄 `field` の値から、Args の欄 `arg` の型を decode できるか(51 v6 第 36 条)。
/// event の欄の値は文字列で、`kind` は `initial` / `reload` / `spa` の 3 値。文字列から読む語彙(文字列・値型・hook)は
/// どの欄でも通し、`client_at` は日時も、`kind` は 3 値を全部持つ列挙も通す。`Option` は中身を見る。
/// 型から decode を導けない欄は Error(`decode を導けない` の検査が止める)。
pub fn decodes_from_event(
  app: App,
  units: List(Unit),
  service: Service,
  arg: model.Arg,
  field: String,
) -> Result(Bool, Nil) {
  let hook_names = list.map(app.server.hooks, fn(hook) { hook.name })
  case arg_type(app, units, hook_names, service, arg) {
    Error(_) -> Error(Nil)
    Ok(#(text, _)) -> {
      let inner = case string.starts_with(text, "['option',") {
        True -> text |> string.drop_start(10) |> string.drop_end(1)
        False -> text
      }
      Ok(
        inner == "['text']"
        || string.starts_with(inner, "['scalar',")
        || string.starts_with(inner, "['hook',")
        || { field == "client_at" && inner == "['datetime']" }
        || {
          field == "kind"
          && string.starts_with(inner, "['enum',")
          && list.all(["initial", "reload", "spa"], fn(value) {
            string.contains(inner, quoted(value))
          })
        },
      )
    }
  }
}
