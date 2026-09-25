//// `src/server.gleam` の宣言を読む(`framework/server` の構成子)。WGy で、手書きの
//// `api/src/gen/http_runtime.mjs` を入力として読むのをやめ、attached と HTTP の上書きをここから取る。
//// 読めない形は `Error(<名指し>)` で返し、reader が exit 4 にする ── 黙って落とすと口が消える。

import glance
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import yumemi_gen/glance_util as g
import yumemi_gen/model
import yumemi_gen/naming
import yumemi_gen/source.{type Unit}
import yumemi_gen/stop

pub type Read {
  Read(server: model.Server, attached: List(model.AttachedRoute))
}

pub fn read(units: List(Unit)) -> Result(Read, String) {
  case list.find(units, fn(unit) { unit.path == "server" }) {
    Error(_) -> Ok(Read(server: model.empty_server(), attached: []))
    Ok(unit) -> {
      let module = g.in_order(unit.module)
      use routes <- result.try(items(module, "routes", route_of))
      use aliases <- result.try(items(module, "aliases", alias_of))
      use attached <- result.try(items(module, "attached", attached_of))
      use cron <- result.try(items(module, "cron", cron_of))
      use objects <- result.try(items(module, "durable_objects", object_of))
      use hooks <- result.try(items(module, "hooks", hook_of))
      use connectors <- result.try(items(module, "connectors", connector_of))
      Ok(Read(
        server: model.Server(
          declared: True,
          routes: routes,
          aliases: aliases,
          cron: cron,
          durable_objects: objects,
          hooks: hooks,
          connectors: connectors,
        ),
        attached: attached,
      ))
    }
  }
}

fn items(
  module: glance.Module,
  name: String,
  each: fn(glance.Expression) -> Result(a, String),
) -> Result(List(a), String) {
  case g.find_constant(module, name) {
    None -> Ok([])
    Some(constant) ->
      case constant.publicity, constant.value {
        glance.Public, glance.List(elements: elements, rest: None, ..) ->
          list.try_map(elements, fn(item) {
            each(item)
            |> result.map_error(fn(detail) { name <> ": " <> detail })
          })
        glance.Public, _ -> Error(name <> " が List の literal でない")
        glance.Private, _ -> Error(name <> " が pub でない")
      }
  }
}

fn route_of(
  expression: glance.Expression,
) -> Result(model.ServerRoute, String) {
  case g.ctor_name(expression) {
    Some("Route") -> {
      use service <- result.try(text(expression, "service"))
      use method <- result.try(method(expression))
      use path <- result.try(text(expression, "path"))
      Ok(model.OverrideRoute(
        service: service,
        method: method,
        path: path,
        credential: None,
      ))
    }
    Some("RouteVia") -> {
      use service <- result.try(text(expression, "service"))
      use method <- result.try(method(expression))
      use path <- result.try(text(expression, "path"))
      use credential <- result.try(credential(expression))
      Ok(model.OverrideRoute(
        service: service,
        method: method,
        path: path,
        credential: Some(credential),
      ))
    }
    Some("Internal") -> {
      use service <- result.try(text(expression, "service"))
      Ok(model.InternalRoute(service: service))
    }
    _ -> Error("Route / RouteVia / Internal でない項")
  }
}

fn alias_of(
  expression: glance.Expression,
) -> Result(model.ServerAlias, String) {
  case g.ctor_name(expression) {
    Some("Alias") -> {
      use name <- result.try(text(expression, "name"))
      use service <- result.try(text(expression, "service"))
      use method <- result.try(method(expression))
      use path <- result.try(text(expression, "path"))
      use credential <- result.try(credential(expression))
      use external_id <- result.try(boolean(expression, "external_id"))
      Ok(model.ServiceAlias(
        name: name,
        service: service,
        method: method,
        path: path,
        credential: credential,
        external_id: external_id,
      ))
    }
    Some("AttachedAlias") -> {
      use name <- result.try(text(expression, "name"))
      use attached <- result.try(text(expression, "attached"))
      use method <- result.try(method(expression))
      use path <- result.try(text(expression, "path"))
      use credential <- result.try(credential(expression))
      use who <- result.try(who(expression))
      Ok(model.AttachedAlias(
        name: name,
        attached: attached,
        method: method,
        path: path,
        credential: credential,
        who: who,
      ))
    }
    _ -> Error("Alias / AttachedAlias でない項")
  }
}

fn attached_of(
  expression: glance.Expression,
) -> Result(model.AttachedRoute, String) {
  case g.ctor_name(expression) {
    Some("Attached") -> {
      use name <- result.try(text(expression, "name"))
      use method <- result.try(method(expression))
      use path <- result.try(text(expression, "path"))
      use who <- result.try(who(expression))
      Ok(model.AttachedRoute(
        name: naming.pascal(name),
        method: method,
        path: path,
        who: who,
      ))
    }
    _ -> Error("Attached でない項")
  }
}

fn cron_of(expression: glance.Expression) -> Result(model.Cron, String) {
  case g.ctor_name(expression) {
    Some("Cron") -> {
      use schedule <- result.try(text(expression, "schedule"))
      use jobs <- result.try(case g.labelled(expression, "jobs") {
        Some(glance.List(elements: elements, rest: None, ..)) ->
          list.try_map(elements, job_of)
        _ -> Error("Cron.jobs が List の literal でない")
      })
      Ok(model.Cron(schedule: schedule, jobs: jobs))
    }
    _ -> Error("Cron でない項")
  }
}

fn job_of(expression: glance.Expression) -> Result(model.CronJob, String) {
  case g.ctor_name(expression) {
    Some("EachDue") -> {
      use service <- result.try(text(expression, "service"))
      use query <- result.try(text(expression, "query"))
      Ok(model.EachDue(service: service, query: query))
    }
    Some("Hooked") -> {
      use service <- result.try(text(expression, "service"))
      use hook <- result.try(text(expression, "hook"))
      Ok(model.HookedJob(service: service, hook: hook))
    }
    _ -> Error("EachDue / Hooked でない項")
  }
}

fn object_of(
  expression: glance.Expression,
) -> Result(model.DurableObject, String) {
  case g.ctor_name(expression) {
    Some("DurableObject") -> {
      use class <- result.try(text(expression, "class"))
      use module <- result.try(text(expression, "module"))
      use adapter <- result.try(text(expression, "adapter"))
      use methods <- result.try(texts(expression, "methods"))
      Ok(model.DurableObject(
        class: class,
        module: module,
        adapter: adapter,
        methods: methods,
      ))
    }
    _ -> Error("DurableObject でない項")
  }
}

fn hook_of(expression: glance.Expression) -> Result(model.Hook, String) {
  case g.ctor_name(expression) {
    Some("Hook") -> {
      use name <- result.try(text(expression, "name"))
      use module <- result.try(text(expression, "module"))
      Ok(model.Hook(name: name, module: module))
    }
    _ -> Error("Hook でない項")
  }
}

fn connector_of(
  expression: glance.Expression,
) -> Result(model.Connector, String) {
  case g.ctor_name(expression) {
    Some("Connector") -> {
      use name <- result.try(text(expression, "name"))
      use ports <- result.try(case g.labelled(expression, "ports") {
        Some(glance.List(elements: elements, rest: None, ..)) ->
          list.try_map(elements, port_of)
        _ -> Error("ports が List の literal でない")
      })
      Ok(model.Connector(name: name, ports: ports))
    }
    _ -> Error("Connector でない項")
  }
}

fn port_of(
  expression: glance.Expression,
) -> Result(model.ConnectorPort, String) {
  case g.ctor_name(expression) {
    Some("Call") -> {
      use name <- result.try(text(expression, "name"))
      use op <- result.try(text(expression, "op"))
      Ok(model.CallPort(name: name, op: op))
    }
    Some("Send") -> {
      use name <- result.try(text(expression, "name"))
      use op <- result.try(text(expression, "op"))
      Ok(model.SendPort(name: name, op: op))
    }
    Some("Enqueue") -> {
      use name <- result.try(text(expression, "name"))
      use kind <- result.try(text(expression, "kind"))
      Ok(model.EnqueuePort(name: name, kind: kind))
    }
    Some("Fetch") -> {
      use name <- result.try(text(expression, "name"))
      use module <- result.try(text(expression, "module"))
      use js <- result.try(text(expression, "js"))
      use arity <- result.try(integer(expression, "arity"))
      Ok(model.FetchPort(name: name, module: module, js: js, arity: arity))
    }
    Some("Pure") -> {
      use name <- result.try(text(expression, "name"))
      use module <- result.try(text(expression, "module"))
      use js <- result.try(text(expression, "js"))
      use arity <- result.try(integer(expression, "arity"))
      Ok(model.PurePort(name: name, module: module, js: js, arity: arity))
    }
    _ -> Error("Call / Send / Enqueue / Fetch / Pure でない口")
  }
}

fn integer(
  expression: glance.Expression,
  label: String,
) -> Result(Int, String) {
  case g.labelled(expression, label) {
    Some(value) ->
      g.int_value(value)
      |> option.then(fn(found) { option.from_result(int.parse(found)) })
      |> option.to_result(label <> " が Int の literal でない")
    None -> Error(label <> " が無い")
  }
}

fn text(
  expression: glance.Expression,
  label: String,
) -> Result(String, String) {
  case g.labelled(expression, label) {
    Some(value) ->
      g.string_value(value)
      |> option.to_result(label <> " が String の literal でない")
    None -> Error(label <> " が無い")
  }
}

fn texts(
  expression: glance.Expression,
  label: String,
) -> Result(List(String), String) {
  case g.labelled(expression, label) {
    Some(glance.List(elements: elements, rest: None, ..)) ->
      list.try_map(elements, fn(item) {
        g.string_value(item)
        |> option.to_result(label <> " の項が String の literal でない")
      })
    _ -> Error(label <> " が List の literal でない")
  }
}

fn constructor(
  expression: glance.Expression,
  label: String,
) -> Result(String, String) {
  case g.labelled(expression, label) {
    Some(value) -> g.ctor_name(value) |> option.to_result(label <> " の構成子が読めない")
    None -> Error(label <> " が無い")
  }
}

fn method(expression: glance.Expression) -> Result(String, String) {
  use name <- result.try(constructor(expression, "method"))
  case name {
    "Get" | "Post" | "Put" | "Delete" -> Ok(string.uppercase(name))
    _ -> Error("method が Get / Post / Put / Delete でない: " <> name)
  }
}

fn credential(expression: glance.Expression) -> Result(String, String) {
  use name <- result.try(constructor(expression, "credential"))
  case name {
    "Session" -> Ok("session")
    "ApiKey" -> Ok("api_key")
    _ -> Error("credential が Session / ApiKey でない: " <> name)
  }
}

fn who(expression: glance.Expression) -> Result(String, String) {
  use name <- result.try(constructor(expression, "who"))
  case name {
    "Anyone" -> Ok("anyone")
    "Party" -> Ok("party")
    _ -> Error("who が Anyone / Party でない: " <> name)
  }
}

fn boolean(
  expression: glance.Expression,
  label: String,
) -> Result(Bool, String) {
  use name <- result.try(constructor(expression, label))
  case name {
    "True" -> Ok(True)
    "False" -> Ok(False)
    _ -> Error(label <> " が True / False でない")
  }
}

/// 名が Service / attached に無い行、同じ Service の上書きが 2 行ある、を exit 4 で名指しする。
pub fn notes(app: model.App) -> List(stop.Note) {
  let services = list.map(app.services, fn(service) { service.module })
  let attached = list.map(app.attached, fn(route) { naming.snake(route.name) })
  let route_names =
    list.map(app.server.routes, fn(route) {
      case route {
        model.OverrideRoute(service: name, ..) -> name
        model.InternalRoute(service: name) -> name
      }
    })
  let unknown_routes =
    route_names
    |> list.filter(fn(name) { !list.contains(services, name) })
    |> list.map(fn(name) { "routes に Service が無い: " <> name })
  let duplicate_routes =
    route_names
    |> list.filter(fn(name) {
      list.length(list.filter(route_names, fn(other) { other == name })) > 1
    })
    |> list.unique
    |> list.map(fn(name) { "routes に同じ Service が 2 行: " <> name })
  let unknown_aliases =
    list.filter_map(app.server.aliases, fn(alias) {
      case alias {
        model.ServiceAlias(name: name, service: service, ..) ->
          case list.contains(services, service) {
            True -> Error(Nil)
            False -> Ok("aliases " <> name <> " の Service が無い: " <> service)
          }
        model.AttachedAlias(name: name, attached: target, ..) ->
          case list.contains(attached, target) {
            True -> Error(Nil)
            False -> Ok("aliases " <> name <> " の attached が無い: " <> target)
          }
      }
    })
  let hook_names = list.map(app.server.hooks, fn(hook) { hook.name })
  let unknown_jobs =
    list.flat_map(app.server.cron, fn(cron) {
      list.filter_map(cron.jobs, fn(job) {
        let #(service, hook) = case job {
          model.EachDue(service: service, ..) -> #(service, None)
          model.HookedJob(service: service, hook: hook) -> #(
            service,
            Some(hook),
          )
        }
        case list.contains(services, service), hook {
          False, _ ->
            Ok("cron " <> cron.schedule <> " の Service が無い: " <> service)
          True, Some(name) ->
            case list.contains(hook_names, name) {
              True -> Error(Nil)
              False ->
                Ok("cron " <> cron.schedule <> " の hook が hooks に無い: " <> name)
            }
          True, None -> Error(Nil)
        }
      })
    })
  list.flatten([unknown_routes, duplicate_routes, unknown_aliases, unknown_jobs])
  |> list.map(fn(text) {
    stop.Note(class: stop.Conflict, text: "server.gleam: " <> text)
  })
}
