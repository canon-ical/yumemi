//// 束6 ── `src/gen/root/<service>.gleam`。Service の root / actor / 手順書の器。
//// root は allow module の Entity と Args の key / path_key 型から決める。

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import yumemi_gen/emit/hash
import yumemi_gen/emit/types.{type File, File}
import yumemi_gen/model.{type App, type Entity, type Service, type Subject}
import yumemi_gen/stop

pub fn emit(app: App, hashes: hash.Hashes) -> List(File) {
  list.map(app.services, fn(service) {
    File(
      path: "src/gen/root/" <> service.module <> ".gleam",
      text: text(app, service, hash.service(hashes, service.module)),
    )
  })
}

pub fn notes(app: App) -> List(stop.Note) {
  list.filter_map(app.services, fn(service) {
    case root_for(app, service) {
      Some(root) ->
        case module_prefix(service.module) == root.module {
          True -> Error(Nil)
          False ->
            Ok(stop.Note(
              class: stop.Warning,
              text: "service."
                <> service.module
                <> ": module 名の `_` 前と root Entity が違う: "
                <> root.module,
            ))
        }
      None -> Error(Nil)
    }
  })
}

pub fn root_for(app: App, service: Service) -> Option(Entity) {
  case service.allow_module {
    None -> None
    Some(path) -> {
      let module = last_segment(path)
      case model_entity_by_module(app.entities, module) {
        None -> None
        Some(entity) ->
          case key_matches(entity, service) {
            True -> Some(entity)
            False -> None
          }
      }
    }
  }
}

fn key_matches(entity: Entity, service: Service) -> Bool {
  list.any(service.args, fn(arg) {
    case entity.key_type, entity.path_key_type {
      Some(key_type), Some(path_key_type) ->
        arg.type_ == key_type || arg.type_ == path_key_type
      Some(key_type), None -> arg.type_ == key_type
      None, Some(path_key_type) -> arg.type_ == path_key_type
      None, None -> False
    }
  })
}

fn model_entity_by_module(
  entities: List(Entity),
  module: String,
) -> Option(Entity) {
  case list.find(entities, fn(entity) { entity.module == module }) {
    Ok(entity) -> Some(entity)
    Error(_) -> None
  }
}

type ActorPlan {
  Direct(type_: String, imports: List(String))
  Sum(variants: List(String), imports: List(String))
}

fn actor_plan(subjects: List(Subject)) -> ActorPlan {
  let subjects =
    subjects
    |> list.unique
    |> list.sort(fn(left, right) {
      string.compare(actor_variant(left), actor_variant(right))
    })
  case subjects {
    [] -> Sum(variants: ["  Anonymous"], imports: [])
    [model.SubjectEntity(module: module, type_name: type_name)] ->
      Direct(type_: module <> "." <> type_name, imports: ["entity/" <> module])
    [model.SubjectParty] -> Direct(type_: "allow.PartyActor", imports: [])
    [model.SubjectSystem] -> Direct(type_: "allow.SystemActor", imports: [])
    _ ->
      Sum(
        variants: list.map(subjects, actor_variant),
        imports: list.filter_map(subjects, fn(subject) {
          case actor_import(subject) {
            Some(path) -> Ok(path)
            None -> Error(Nil)
          }
        }),
      )
  }
}

fn actor_variant(subject: Subject) -> String {
  case subject {
    model.SubjectAnonymous -> "  Anonymous"
    model.SubjectEntity(module: _, type_name: type_name) ->
      "  As" <> type_name <> "(" <> subject_type(subject) <> ")"
    model.SubjectParty -> "  AsParty(allow.PartyActor)"
    model.SubjectSystem -> "  AsSystem(allow.SystemActor)"
  }
}

fn actor_import(subject: Subject) -> Option(String) {
  case subject {
    model.SubjectEntity(module: module, ..) -> Some("entity/" <> module)
    _ -> None
  }
}

fn subject_type(subject: Subject) -> String {
  case subject {
    model.SubjectEntity(module: module, type_name: type_name) ->
      module <> "." <> type_name
    model.SubjectAnonymous -> "Anonymous"
    model.SubjectParty -> "allow.PartyActor"
    model.SubjectSystem -> "allow.SystemActor"
  }
}

fn actor_argument(plan: ActorPlan) -> String {
  case plan {
    Direct(type_: type_, ..) -> type_
    Sum(..) -> "Actor"
  }
}

fn actor_declaration(plan: ActorPlan) -> String {
  case plan {
    Direct(..) -> ""
    Sum(variants: variants, ..) ->
      "pub type Actor {\n" <> string.join(variants, "\n") <> "\n}\n\n"
  }
}

fn actor_imports(plan: ActorPlan) -> List(String) {
  case plan {
    Direct(imports: imports, ..) -> imports
    Sum(imports: imports, ..) -> imports
  }
}

fn text(app: App, service: Service, input_hash: String) -> String {
  let plan = actor_plan(service.subjects)
  let allow_path = case service.allow_module {
    Some(path) -> path
    None -> "gen/allow/" <> module_prefix(service.module)
  }
  let base_imports = [
    "framework/step",
    "framework/time.{type Datetime}",
    allow_path <> " as allow",
  ]
  let imports = case root_for(app, service) {
    Some(root) -> [
      "entity/" <> root.module,
      ..list.append(base_imports, actor_imports(plan))
    ]
    None -> list.append(base_imports, actor_imports(plan))
  }
  let imports = imports |> list.unique |> list.sort(string.compare)
  let root = root_for(app, service)
  string.concat([
    "//// GENERATED from service.",
    service.module,
    " [sha256:",
    input_hash,
    "] — 手で編集しない\n\n",
    list.map(imports, fn(path) { "import " <> path })
      |> string.join("\n"),
    "\n\n",
    actor_declaration(plan),
    root_declaration(root),
    "pub type Service(args, out, err) {\n",
    "  Service(\n",
    "    allow: List(allow.Clause),\n",
    "    logic: fn(",
    actor_argument(plan),
    ", Root, args) -> step.Step(out, err, step.Start),\n",
    "  )\n",
    "}\n",
  ])
}

fn root_declaration(root: Option(Entity)) -> String {
  case root {
    None -> "pub type Root {\n  Root(at: Datetime, seed: String)\n}\n\n"
    Some(entity) -> {
      let phase_fields = case entity.phases {
        [] -> []
        _ -> ["    phase: " <> entity.module <> ".Phase,"]
      }
      let fields = [
        "    "
          <> entity.module
          <> ": "
          <> entity.module
          <> "."
          <> entity.type_name
          <> ",",
        ..phase_fields
      ]
      string.concat([
        "pub type Root {\n",
        "  Root(\n",
        string.join(fields, "\n"),
        "\n    at: Datetime,\n",
        "    seed: String,\n",
        "  )\n",
        "}\n\n",
      ])
    }
  }
}

fn module_prefix(module: String) -> String {
  case list.first(string.split(module, "_")) {
    Ok(prefix) -> prefix
    Error(_) -> module
  }
}

fn last_segment(path: String) -> String {
  case list.last(string.split(path, "/")) {
    Ok(segment) -> segment
    Error(_) -> path
  }
}
