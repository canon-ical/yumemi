//// 束6 ── `src/gen/root/<service>.gleam`。Service の root / actor / 手順書の器。
//// root は allow module の Entity と Args の key / path_key 型から決める。
//// Actor は主体が1つなら その型、複数か `Anyone` だけなら `pub type Actor = allow.Actor`
//// (variant は `gen/allow/<m>` が持つ ── `emit/allow`)。

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
  let shapes =
    list.append(
      option_shapes(entity.key_type),
      option_shapes(entity.path_key_type),
    )
  list.any(service.args, fn(arg) {
    list.any(shapes, fn(shape) { arg.type_ == shape })
  })
}

fn option_shapes(shape: Option(model.TypeShape)) -> List(model.TypeShape) {
  case shape {
    None -> []
    Some(value) -> flatten_shape(value)
  }
}

fn flatten_shape(shape: model.TypeShape) -> List(model.TypeShape) {
  case shape {
    model.TupleShape(items) -> list.flat_map(items, flatten_shape)
    _ -> [shape]
  }
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
  /// 複数の主体か、`Anyone` だけの形。root 独自の variant は出さず、allow の `Actor` を使う。
  Sum
}

fn actor_plan(subjects: List(Subject)) -> ActorPlan {
  case list.unique(subjects) {
    [model.SubjectEntity(module: module, type_name: type_name)] ->
      Direct(type_: module <> "." <> type_name, imports: ["entity/" <> module])
    [model.SubjectParty] -> Direct(type_: "allow.PartyActor", imports: [])
    [model.SubjectSystem] -> Direct(type_: "allow.SystemActor", imports: [])
    _ -> Sum
  }
}

/// root の Actor が allow の `Actor` の別名になる形か。`emit/allow` が Actor の variant を集めるのに使う。
pub fn actor_is_sum(subjects: List(Subject)) -> Bool {
  actor_plan(subjects) == Sum
}

/// root が import する allow module の道。allow を import しない Service は module 名の `_` 前。
pub fn allow_path(service: Service) -> String {
  case service.allow_module {
    Some(path) -> path
    None -> "gen/allow/" <> module_prefix(service.module)
  }
}

fn actor_argument(plan: ActorPlan) -> String {
  case plan {
    Direct(type_: type_, ..) -> type_
    Sum -> "Actor"
  }
}

fn actor_declaration(plan: ActorPlan) -> String {
  case plan {
    Direct(..) -> ""
    Sum -> "pub type Actor =\n  allow.Actor\n\n"
  }
}

fn actor_imports(plan: ActorPlan) -> List(String) {
  case plan {
    Direct(imports: imports, ..) -> imports
    Sum -> []
  }
}

fn text(app: App, service: Service, input_hash: String) -> String {
  let plan = actor_plan(service.subjects)
  let allow_path = allow_path(service)
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
