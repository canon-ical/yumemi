//// 面の束 ── route / blocks / widgets / API / Service / Out の写し。
//// 面側へ back の module を再輸出せず、面 package が単独で型を持てる形にする。

import glance
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/string
import yumemi_gen/digest
import yumemi_gen/emit/draft
import yumemi_gen/emit/entry
import yumemi_gen/emit/hash
import yumemi_gen/emit/types.{type File, File}
import yumemi_gen/face
import yumemi_gen/glance_util as g
import yumemi_gen/model
import yumemi_gen/naming
import yumemi_gen/reader/front as reader_front
import yumemi_gen/source.{type Unit, Unit}

type ApiRoute {
  ApiRoute(service: String, method: String, path: String)
}

pub fn emit(
  app: model.App,
  back_units: List(Unit),
  package: face.Package,
  model_: reader_front.Front,
  hashes: hash.Hashes,
) -> List(File) {
  let face_name = package.name
  let route_hash =
    source_hash(package.units, fn(unit) {
      string.starts_with(unit.path, "pages/")
      && string.ends_with(unit.path, "/page")
    })
  let blocks_hash =
    source_hash(package.units, fn(unit) {
      string.starts_with(unit.path, "blocks/")
    })
  let widgets_hash =
    source_hash(package.units, fn(unit) {
      unit.path == "layout" || string.starts_with(unit.path, "pages/")
    })
  let service_hash =
    source_hash(back_units, fn(unit) {
      string.starts_with(unit.path, "service/")
    })
  let type_units = back_type_units(app, back_units, hashes)
  let files = [
    File(
      path: face_name <> "/src/gen/route.gleam",
      text: route_text(face_name, model_.pages, route_hash),
    ),
    File(
      path: face_name <> "/src/gen/blocks.gleam",
      text: blocks_text(face_name, model_.blocks, blocks_hash),
    ),
    File(
      path: face_name <> "/src/gen/widgets.gleam",
      text: widgets_text(face_name, model_.widget_keys, widgets_hash),
    ),
    File(
      path: face_name <> "/src/gen/service.gleam",
      text: service_text(face_name, app.services, service_hash),
    ),
    File(
      path: face_name <> "/src/gen/api.gleam",
      text: api_text(face_name, app, hashes),
    ),
  ]
  let out_files =
    app.services
    |> list.sort(fn(left, right) { string.compare(left.module, right.module) })
    |> list.map(fn(service) {
      out_file(app, type_units, service, hashes, face_name)
    })
  let live_files =
    live_targets(model_.components, app.services)
    |> list.map(fn(target) {
      let #(service, component) = target
      live_file(app, back_units, package, service, component, hashes, face_name)
    })
  let load_files =
    list.append(
      [load_layout_file(app, package, model_)],
      list.map(model_.pages, fn(page) {
        load_page_file(app, type_units, package, model_, page)
      }),
    )
  list.append(
    list.append(files, list.append(out_files, live_files)),
    load_files,
  )
}

fn source_hash(units: List(Unit), keep: fn(Unit) -> Bool) -> String {
  units
  |> list.filter(keep)
  |> list.sort(fn(left, right) { string.compare(left.path, right.path) })
  |> list.map(fn(unit) { unit.path <> "\n" <> unit.text })
  |> string.join("\n")
  |> digest.short
}

fn live_targets(
  components: List(reader_front.Component),
  services: List(model.Service),
) -> List(#(model.Service, reader_front.Component)) {
  let empty: List(#(model.Service, reader_front.Component)) = []
  components
  |> list.fold(empty, fn(targets, component) {
    component.calls
    |> list.fold(targets, fn(acc, variant) {
      case service_for(services, variant) {
        Some(service) ->
          case list.any(acc, fn(target) { target.0.module == service.module }) {
            True -> acc
            False -> list.append(acc, [#(service, component)])
          }
        None -> acc
      }
    })
  })
  |> list.sort(fn(left, right) { string.compare(left.0.module, right.0.module) })
}

fn service_for(
  services: List(model.Service),
  variant: String,
) -> Option(model.Service) {
  case
    list.find(services, fn(service) {
      naming.pascal(service.module) == variant || service.module == variant
    })
  {
    Ok(service) -> Some(service)
    Error(_) -> None
  }
}

fn live_file(
  app: model.App,
  units: List(Unit),
  package: face.Package,
  service: model.Service,
  component: reader_front.Component,
  hashes: hash.Hashes,
  face_name: String,
) -> File {
  let given_service =
    component.reloads
    |> list.first
    |> option.from_result
    |> option.then(fn(reload) { service_for(app.services, reload.1) })
  let component_hash =
    source_hash(package.units, fn(unit) { unit.path == component.module })
  let input_hash =
    digest.short(hash.service(hashes, service.module) <> component_hash)
  File(
    path: face_name <> "/src/gen/live/" <> service.module <> ".gleam",
    text: live_text(
      app,
      units,
      service,
      component,
      given_service,
      header("src/" <> component.module <> ".gleam", input_hash),
    ),
  )
}

fn live_text(
  app: model.App,
  units: List(Unit),
  service: model.Service,
  component: reader_front.Component,
  given_service: Option(model.Service),
  generated_header: String,
) -> String {
  let validations = validation_specs(app, units, service.args)
  generated_header
  <> "\n"
  <> live_imports(
    service,
    given_service,
    validations != [],
    component.after_send == Some("ReloadPage"),
  )
  <> "\n\n"
  <> args_type_text(service.args)
  <> "\n"
  <> field_type_text(service.args)
  <> "\n"
  <> "pub type Error = Nil\n\n"
  <> state_type_text(service, given_service)
  <> "\n"
  <> init_text(service, given_service)
  <> "\n"
  <> update_text(service, component)
  <> "\n"
  <> validate_text(validations)
  <> send_text(component.after_send)
}

fn live_imports(
  service: model.Service,
  given_service: Option(model.Service),
  has_validation: Bool,
  reloads_page: Bool,
) -> String {
  let validation = case has_validation {
    True -> ["framework/spec", "gleam/list"]
    False -> []
  }
  let given = case given_service {
    Some(value) -> ["gen/out/" <> value.module]
    None -> []
  }
  let reload = case reloads_page {
    True -> ["gleam/json", "lustre/event"]
    False -> []
  }
  let base = [
    "framework/front/live",
    "gen/out/" <> service.module,
    "gleam/option.{None, Some}",
    "lustre/effect.{type Effect}",
  ]
  base
  |> list.append(validation)
  |> list.append(reload)
  |> list.append(given)
  |> list.unique
  |> list.sort(string.compare)
  |> list.map(fn(path) { "import " <> path })
  |> string.join("\n")
}

fn args_type_text(args: List(model.Arg)) -> String {
  case args {
    [] -> "pub type Args {\n  Args\n}\n"
    _ ->
      "pub type Args {\n  Args(\n"
      <> string.concat(
        list.map(args, fn(arg) { "    " <> arg.name <> ": String,\n" }),
      )
      <> "  )\n}\n"
  }
}

fn field_type_text(args: List(model.Arg)) -> String {
  let variants =
    args
    |> list.map(fn(arg) { "  " <> naming.pascal(arg.name) })
    |> string.join("\n")
  case variants {
    "" -> "pub type Field\n"
    _ -> "pub type Field {\n" <> variants <> "\n}\n"
  }
}

fn state_type_text(
  service: model.Service,
  given_service: Option(model.Service),
) -> String {
  let given = given_type(given_service)
  "pub type State = live.State(Args, "
  <> given
  <> ", "
  <> service.module
  <> ".Out, Error)\n\n"
  <> "pub type Event = live.Event(Field, "
  <> given
  <> ", "
  <> service.module
  <> ".Out, Error)\n"
}

fn given_type(given_service: Option(model.Service)) -> String {
  case given_service {
    Some(service) -> service.module <> ".Out"
    None -> "Nil"
  }
}

fn init_text(
  service: model.Service,
  given_service: Option(model.Service),
) -> String {
  "pub fn init(given: "
  <> given_type(given_service)
  <> ") -> #(State, Effect(Event)) {\n"
  <> "  #(\n"
  <> "    live.State(\n"
  <> "      args: "
  <> args_constructor(service.args)
  <> ",\n"
  <> "      given: given,\n"
  <> "      last: None,\n"
  <> "      waiting: False,\n"
  <> "    ),\n"
  <> "    effect.none(),\n"
  <> "  )\n}\n"
}

fn args_constructor(args: List(model.Arg)) -> String {
  case args {
    [] -> "Args"
    _ ->
      "Args(\n"
      <> string.concat(
        list.map(args, fn(arg) { "        " <> arg.name <> ": \"\",\n" }),
      )
      <> "      )"
  }
}

fn update_text(
  service: model.Service,
  component: reader_front.Component,
) -> String {
  "pub fn update(model: State, msg: Event) -> #(State, Effect(Event)) {\n"
  <> "  case msg {\n"
  <> set_branches(service.args)
  <> "    live.Send ->\n"
  <> "      case model.waiting {\n"
  <> "        True -> #(model, effect.none())\n"
  <> "        False -> #(\n"
  <> "          live.State(..model, waiting: True),\n"
  <> "          send(model.args),\n"
  <> "        )\n"
  <> "      }\n"
  <> "    live.Given(given) -> #(\n"
  <> "      live.State(..model, given: given),\n"
  <> "      effect.none(),\n"
  <> "    )\n"
  <> "    live.Done(result) -> {\n"
  <> "      let next = live.State(..model, last: Some(result), waiting: False)\n"
  <> "      case result {\n"
  <> "        Ok(_) -> "
  <> done_success(component)
  <> "        Error(_) -> #(next, effect.none())\n"
  <> "      }\n    }\n"
  <> "  }\n}\n"
}

fn set_branches(args: List(model.Arg)) -> String {
  args
  |> list.map(fn(arg) {
    let updated = case list.length(args) {
      1 -> "Args(" <> arg.name <> ": value)"
      _ -> "Args(..model.args, " <> arg.name <> ": value)"
    }
    "    live.Set("
    <> naming.pascal(arg.name)
    <> ", value) -> #(\n"
    <> "      live.State(..model, args: "
    <> updated
    <> "),\n"
    <> "      effect.none(),\n"
    <> "    )\n"
  })
  |> string.concat
}

fn done_success(component: reader_front.Component) -> String {
  case component.after_send {
    Some("ReloadPage") -> "#(next, reload_page())\n"
    _ -> "#(next, effect.none())\n"
  }
}

fn validate_text(validations: List(#(String, String))) -> String {
  case validations {
    [] ->
      "pub fn validate(model: State) -> Result(Args, List(#(Field, String))) {\n"
      <> "  Ok(model.args)\n}\n\n"
    _ ->
      "pub fn validate(model: State) -> Result(Args, List(#(Field, String))) {\n"
      <> "  let errors = list.flatten([\n"
      <> string.concat(
        list.map(validations, fn(validation) {
          let #(field, spec) = validation
          "    validate_field("
          <> field
          <> ", model.args."
          <> field_name(field)
          <> ", "
          <> spec
          <> "),\n"
        }),
      )
      <> "  ])\n"
      <> "  case errors {\n"
      <> "    [] -> Ok(model.args)\n"
      <> "    _ -> Error(errors)\n"
      <> "  }\n}\n\n"
      <> "fn validate_field(\n"
      <> "  field: Field,\n"
      <> "  raw: String,\n"
      <> "  constraint: spec.Spec,\n"
      <> ") -> List(#(Field, String)) {\n"
      <> "  case spec.validate(raw, constraint) {\n"
      <> "    Ok(_) -> []\n"
      <> "    Error(_) -> [#(field, \"invalid\")]\n"
      <> "  }\n}\n\n"
  }
}

fn field_name(field: String) -> String {
  naming.snake(field)
}

fn send_text(after_send: Option(String)) -> String {
  let reload = case after_send {
    Some("ReloadPage") ->
      "\nfn reload_page() -> Effect(Event) {\n  event.emit(\"yumemi-done\", json.null())\n}\n"
    _ -> ""
  }
  "fn send(_args: Args) -> Effect(Event) {\n  effect.none()\n}\n\n" <> reload
}

fn validation_specs(
  app: model.App,
  units: List(Unit),
  args: List(model.Arg),
) -> List(#(String, String)) {
  args
  |> list.filter_map(fn(arg) {
    case value_type_for_arg(app.value_types, arg.type_) {
      Some(value) ->
        Ok(#(naming.pascal(arg.name), spec_expression(units, value)))
      None -> Error(Nil)
    }
  })
}

fn value_type_for_arg(
  value_types: List(model.ValueType),
  shape: model.TypeShape,
) -> Option(model.ValueType) {
  case shape {
    model.NamedShape(module: Some(path), name: name, parameters: []) ->
      case string.starts_with(path, "gen/types/") {
        True ->
          list.find(value_types, fn(value) { value.type_name == name })
          |> option.from_result
        False -> None
      }
    _ -> None
  }
}

fn spec_expression(units: List(Unit), value: model.ValueType) -> String {
  case list.find(units, fn(unit) { unit.path == "types" }) {
    Ok(unit) -> {
      let module = g.in_order(unit.module)
      case g.find_constant(module, value.name) {
        Some(constant) -> spec_constructor_text(constant.value, value)
        None -> fallback_spec(value)
      }
    }
    Error(_) -> fallback_spec(value)
  }
}

fn spec_constructor_text(
  expression: glance.Expression,
  value: model.ValueType,
) -> String {
  case g.ctor_name(expression) {
    Some("Pattern") ->
      case spec_bounds(expression), g.labelled(expression, "regex") {
        Some(#(min, max)), Some(regex) ->
          case g.string_value(regex) {
            Some(raw) ->
              "spec.Pattern(min: "
              <> min
              <> ", max: "
              <> max
              <> ", regex: "
              <> quoted(raw)
              <> ")"
            None -> fallback_spec(value)
          }
        _, _ -> fallback_spec(value)
      }
    Some("Text") -> bounded_spec("spec.Text", expression, value)
    Some("MarkdownText") -> bounded_spec("spec.MarkdownText", expression, value)
    Some("Range") -> bounded_spec("spec.Range", expression, value)
    Some("Uuid") -> "spec.Uuid"
    Some("Markdown") -> "spec.Markdown"
    Some("Url") -> "spec.Url"
    Some(_) -> fallback_spec(value)
    None -> fallback_spec(value)
  }
}

fn spec_bounds(expression: glance.Expression) -> Option(#(String, String)) {
  case
    g.labelled(expression, "min") |> option.then(g.int_value),
    g.labelled(expression, "max") |> option.then(g.int_value)
  {
    Some(min), Some(max) -> Some(#(min, max))
    _, _ -> None
  }
}

fn bounded_spec(
  name: String,
  expression: glance.Expression,
  value: model.ValueType,
) -> String {
  case spec_bounds(expression) {
    Some(#(min, max)) -> name <> "(min: " <> min <> ", max: " <> max <> ")"
    None -> fallback_spec(value)
  }
}

fn fallback_spec(value: model.ValueType) -> String {
  case value.spec, value.range {
    "Range", Some(#(min, max)) ->
      "spec.Range(min: "
      <> int.to_string(min)
      <> ", max: "
      <> int.to_string(max)
      <> ")"
    "Uuid", _ -> "spec.Uuid"
    "Markdown", _ -> "spec.Markdown"
    "Url", _ -> "spec.Url"
    _, _ -> "spec.Markdown"
  }
}

fn quoted(value: String) -> String {
  "\""
  <> value
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", "\\n")
  <> "\""
}

type LoadSource {
  LoadSource(key: String, name: String, service: String, optional: Bool)
}

fn load_layout_file(
  app: model.App,
  package: face.Package,
  front: reader_front.Front,
) -> File {
  let sources = layout_sources(front.layout, front.blocks, app.services)
  let source_hash =
    source_hash(package.units, fn(unit) { unit.path == "layout" })
  File(
    path: package.name <> "/src/gen/load/layout.gleam",
    text: load_layout_text(package.name, sources, source_hash),
  )
}

fn load_page_file(
  app: model.App,
  units: List(Unit),
  package: face.Package,
  front: reader_front.Front,
  page: reader_front.Page,
) -> File {
  let layout_sources = layout_sources(front.layout, front.blocks, app.services)
  let page_sources = page_sources(page, front.blocks, app.services)
  let source_hash =
    source_hash(package.units, fn(unit) { unit.path == page.module })
  File(
    path: package.name
      <> "/src/gen/load/"
      <> load_page_module_path(page.module)
      <> ".gleam",
    text: load_page_text(
      app,
      units,
      package.name,
      front,
      page,
      layout_sources,
      page_sources,
      source_hash,
    ),
  )
}

fn load_page_module_path(path: String) -> String {
  case string.starts_with(path, "pages/") {
    True -> string.drop_start(path, 6)
    False -> path
  }
}

fn layout_sources(
  layout: reader_front.Layout,
  blocks: List(reader_front.Block),
  services: List(model.Service),
) -> List(LoadSource) {
  case layout.sp {
    Some(frame) -> placement_sources(frame.placements, blocks, services, [])
    None -> []
  }
}

fn page_sources(
  page: reader_front.Page,
  blocks: List(reader_front.Block),
  services: List(model.Service),
) -> List(LoadSource) {
  let root = case page.of {
    Some(service) ->
      case service_module(services, service) {
        Some(module) -> [
          LoadSource(
            key: "service:" <> module,
            name: module,
            service: module,
            optional: False,
          ),
        ]
        None -> []
      }
    None -> []
  }
  let placements = case page.sp {
    Some(frame) -> frame.placements
    None -> []
  }
  placement_sources(placements, blocks, services, root)
}

fn placement_sources(
  placements: List(reader_front.Placement),
  blocks: List(reader_front.Block),
  services: List(model.Service),
  initial: List(LoadSource),
) -> List(LoadSource) {
  case placements {
    [] -> initial
    [placement, ..rest] -> {
      let next = case placement {
        reader_front.Fixed(block: block_name, ..) ->
          case block_source(blocks, block_name, services) {
            Some(module) ->
              add_load_source(
                initial,
                LoadSource(
                  key: "service:" <> module,
                  name: module,
                  service: module,
                  optional: True,
                ),
              )
            None -> initial
          }
        reader_front.Widget(name: name, service: service_name, ..) ->
          case service_module(services, service_name) {
            Some(module) ->
              add_load_source(
                initial,
                LoadSource(
                  key: "widget:" <> module <> ":" <> name,
                  name: name,
                  service: module,
                  optional: True,
                ),
              )
            None -> initial
          }
      }
      placement_sources(rest, blocks, services, next)
    }
  }
}

fn add_load_source(
  sources: List(LoadSource),
  source: LoadSource,
) -> List(LoadSource) {
  case list.find(sources, fn(item) { item.key == source.key }) {
    Error(_) -> list.append(sources, [source])
    Ok(found) ->
      case found.optional, source.optional {
        True, False ->
          list.map(sources, fn(item) {
            case item.key == source.key {
              True -> LoadSource(..source, name: found.name)
              False -> item
            }
          })
        _, _ -> sources
      }
  }
}

fn service_module(
  services: List(model.Service),
  variant: String,
) -> Option(String) {
  case
    list.find(services, fn(service) {
      naming.pascal(service.module) == variant || service.module == variant
    })
  {
    Ok(service) -> Some(service.module)
    Error(_) -> None
  }
}

fn block_source(
  blocks: List(reader_front.Block),
  block_name: String,
  services: List(model.Service),
) -> Option(String) {
  case list.find(blocks, fn(block) { block.name == block_name }) {
    Ok(block) ->
      case block.input, block.input_module {
        Some("Nil"), _ -> None
        Some(_), Some(module) -> service_module(services, last_segment(module))
        _, _ -> None
      }
    Error(_) -> None
  }
}

fn load_source_type(source: LoadSource) -> String {
  let out = source.service <> ".Out"
  case source.optional {
    True -> "Option(" <> out <> ")"
    False -> out
  }
}

fn load_data_field_text(source: LoadSource) -> String {
  "    " <> source.name <> ": " <> load_source_type(source) <> ",\n"
}

fn load_data_text(name: String, fields: List(String)) -> String {
  case fields {
    [] -> "pub type " <> name <> " {\n  Data\n}\n"
    _ ->
      "pub type "
      <> name
      <> " {\n  Data(\n"
      <> string.concat(fields)
      <> "  )\n}\n"
  }
}

fn load_constructor_text(fields: List(LoadSource)) -> String {
  case fields {
    [] -> "Data"
    _ ->
      "Data(\n"
      <> string.concat(
        list.map(fields, fn(source) {
          "    " <> source.name <> ": " <> source.name <> ",\n"
        }),
      )
      <> "  )"
  }
}

fn load_function_text(fields: List(LoadSource), constructor: String) -> String {
  case fields {
    [] -> "pub fn load() -> Data {\n  " <> constructor <> "\n}\n"
    _ ->
      "pub fn load(\n"
      <> string.concat(
        list.map(fields, fn(source) {
          "  " <> source.name <> ": " <> load_source_type(source) <> ",\n"
        }),
      )
      <> ") -> Data {\n  "
      <> constructor
      <> "\n}\n"
  }
}

fn load_layout_text(
  face_name: String,
  sources: List(LoadSource),
  input_hash: String,
) -> String {
  let imports = layout_imports(sources)
  let body =
    header(face_name <> "/src/layout.gleam", input_hash)
    <> "\n"
    <> imports
    <> import_gap(imports)
    <> load_data_text("Data", list.map(sources, load_data_field_text))
    <> "\n"
    <> load_function_text(sources, load_constructor_text(sources))
  body
}

fn load_page_text(
  app: model.App,
  units: List(Unit),
  face_name: String,
  front: reader_front.Front,
  page: reader_front.Page,
  layout_sources: List(LoadSource),
  page_sources: List(LoadSource),
  input_hash: String,
) -> String {
  let imports =
    load_imports(front, list.append(layout_sources, page_sources), True)
  let data_fields =
    ["    layout: layout.Data,\n"]
    |> list.append(list.map(page_sources, load_data_field_text))
  let page_path = face_name <> "/src/" <> page.module <> ".gleam"
  let source_body =
    header(page_path, input_hash)
    <> "\n"
    <> imports
    <> import_gap(imports)
    <> load_data_text("Data", data_fields)
    <> "\n"
    <> page_load_function_text(layout_sources, page_sources)
    <> "\n"
    <> page_view_text(app, units, front, page, layout_sources, page_sources)
  source_body
}

fn import_gap(imports: String) -> String {
  case imports {
    "" -> ""
    _ -> "\n\n"
  }
}

fn load_imports(
  front: reader_front.Front,
  sources: List(LoadSource),
  include_layout: Bool,
) -> String {
  let base = [
    "framework/front/css",
    "framework/front/sketch_css",
    "gleam/list",
    "gleam/option.{type Option, None, Some}",
    "lustre/attribute",
    "sketch/lustre/element",
    "sketch/lustre/element/html",
    "style",
  ]
  let layout = case include_layout {
    True -> ["gen/load/layout"]
    False -> []
  }
  let blocks = case include_layout {
    True -> list.map(front.blocks, fn(block) { block.module })
    False -> []
  }
  let outs = list.map(sources, fn(source) { "gen/out/" <> source.service })
  list.unique(list.append(base, list.append(layout, list.append(blocks, outs))))
  |> list.sort(string.compare)
  |> list.map(fn(path) {
    case string.starts_with(path, "gleam/option.{") {
      True -> "import " <> path
      False -> "import " <> path
    }
  })
  |> string.join("\n")
}

fn layout_imports(sources: List(LoadSource)) -> String {
  let option_import = case sources {
    [] -> []
    _ -> ["gleam/option.{type Option}"]
  }
  let out_imports =
    list.map(sources, fn(source) { "gen/out/" <> source.service })
  list.unique(list.append(option_import, out_imports))
  |> list.sort(string.compare)
  |> list.map(fn(path) { "import " <> path })
  |> string.join("\n")
}

fn page_load_function_text(
  layout_sources: List(LoadSource),
  page_sources: List(LoadSource),
) -> String {
  let fields = list.append(layout_sources, page_sources)
  case fields {
    [] -> "pub fn load() -> Data {\n  Data(layout: layout.load())\n}\n"
    _ ->
      "pub fn load(\n"
      <> string.concat(
        list.map(fields, fn(source) {
          "  " <> source.name <> ": " <> load_source_type(source) <> ",\n"
        }),
      )
      <> ") -> Data {\n  Data(\n    layout: layout.load("
      <> string.join(list.map(layout_sources, fn(source) { source.name }), ", ")
      <> "),\n"
      <> string.concat(
        list.map(page_sources, fn(source) {
          "    " <> source.name <> ": " <> source.name <> ",\n"
        }),
      )
      <> "  )\n}\n"
  }
}

fn page_view_text(
  app: model.App,
  units: List(Unit),
  front: reader_front.Front,
  page: reader_front.Page,
  layout_sources: List(LoadSource),
  page_sources: List(LoadSource),
) -> String {
  let layout_areas = case front.layout.sp {
    Some(frame) -> frame.areas
    None -> []
  }
  let layout_placements = case front.layout.sp {
    Some(frame) -> frame.placements
    None -> []
  }
  let page_areas = case page.sp {
    Some(frame) -> frame.areas
    None -> []
  }
  let page_placements = case page.sp {
    Some(frame) -> frame.placements
    None -> []
  }
  let areas =
    string.concat(
      list.map(layout_areas, fn(area) {
        layout_area_text(area, layout_placements)
      }),
    )
  let page_children = page_children_text(page_areas, page_placements)
  let page_helpers =
    placement_helpers_text(
      app,
      units,
      front,
      "layout_placement",
      layout_placements,
      layout_sources,
      "it.layout",
    )
  let page_helpers =
    page_helpers
    <> placement_helpers_text(
      app,
      units,
      front,
      "page_placement",
      page_placements,
      page_sources,
      "it",
    )
  "pub fn view(it: Data) -> element.Element(Nil) {\n"
  <> "  html.div_([attribute.attribute(\"data-yumemi-grid\", \"layout\")], [\n"
  <> areas
  <> "  ])\n}\n\n"
  <> "fn page_children(it: Data) -> List(element.Element(Nil)) {\n"
  <> page_children
  <> "}\n\n"
  <> styled_area_text()
  <> case has_plain_page_area(page_areas) {
    True -> plain_area_text()
    False -> ""
  }
  <> page_helpers
}

fn has_plain_page_area(areas: List(reader_front.Area)) -> Bool {
  list.any(areas, fn(area) { area.name != "page" && area.style == [] })
}

fn layout_area_text(
  area: reader_front.Area,
  placements: List(reader_front.Placement),
) -> String {
  let extra = case area.name == "page" {
    True -> Some("page_children(it)")
    False -> None
  }
  let children =
    area_children_expression("layout_placement", placements, area.name, extra)
  let opener = case area.style {
    [] -> "plain_area(\"" <> area.name <> "\", "
    _ ->
      "styled_area(\""
      <> area.name
      <> "\", "
      <> style_expression(area.style)
      <> ", "
  }
  let body = opener <> children <> "),\n"
  "    " <> body
}

fn page_children_text(
  areas: List(reader_front.Area),
  placements: List(reader_front.Placement),
) -> String {
  let expressions =
    list.flat_map(areas, fn(area) {
      let children =
        placement_children_expressions("page_placement", placements, area.name)
      case area.name {
        "page" -> children
        _ -> [
          "["
          <> page_area_text(area, children_expression(children, None))
          <> "]",
        ]
      }
    })
  case expressions {
    [] -> "  []\n"
    _ ->
      "  list.flatten([\n"
      <> string.concat(
        list.map(expressions, fn(expression) { "    " <> expression <> ",\n" }),
      )
      <> "  ])\n"
  }
}

fn page_area_text(area: reader_front.Area, children: String) -> String {
  let opener = case area.style {
    [] -> "plain_area(\"" <> area.name <> "\", "
    _ ->
      "styled_area(\""
      <> area.name
      <> "\", "
      <> style_expression(area.style)
      <> ", "
  }
  opener <> children <> ")"
}

fn area_children_expression(
  prefix: String,
  placements: List(reader_front.Placement),
  area: String,
  extra: Option(String),
) -> String {
  let placement_children =
    placement_children_expressions(prefix, placements, area)
  children_expression(placement_children, extra)
}

fn placement_children_expressions(
  prefix: String,
  placements: List(reader_front.Placement),
  area: String,
) -> List(String) {
  indexed_placements(placements, 0)
  |> list.filter_map(fn(item) {
    let #(index, placement) = item
    case placement_area(placement) == area {
      True -> Ok(prefix <> "_" <> int.to_string(index) <> "(it)")
      False -> Error(Nil)
    }
  })
}

fn children_expression(
  placement_children: List(String),
  extra: Option(String),
) -> String {
  let children = case extra {
    Some(value) -> list.append(placement_children, [value])
    None -> placement_children
  }
  case children {
    [] -> "[]"
    [one] -> one
    _ -> "list.flatten([" <> string.join(children, ", ") <> "])"
  }
}

fn indexed_placements(
  placements: List(reader_front.Placement),
  index: Int,
) -> List(#(Int, reader_front.Placement)) {
  case placements {
    [] -> []
    [placement, ..rest] -> [
      #(index, placement),
      ..indexed_placements(rest, index + 1)
    ]
  }
}

fn placement_area(placement: reader_front.Placement) -> String {
  case placement {
    reader_front.Fixed(area: area, ..) -> area
    reader_front.Widget(area: area, ..) -> area
  }
}

fn style_expression(styles: List(String)) -> String {
  case styles {
    [] -> "[]"
    [style] -> "style." <> style
    _ ->
      "["
      <> string.join(list.map(styles, fn(name) { "style." <> name }), ", ")
      <> "]"
  }
}

fn styled_area_text() -> String {
  "fn styled_area(\n"
  <> "  name: String,\n"
  <> "  styles: List(css.Style),\n"
  <> "  children: List(element.Element(Nil)),\n"
  <> ") -> element.Element(Nil) {\n"
  <> "  html.div(\n"
  <> "    sketch_css.class(styles),\n"
  <> "    [attribute.attribute(\"data-yumemi-area\", name)],\n"
  <> "    children,\n"
  <> "  )\n"
  <> "}\n\n"
}

fn plain_area_text() -> String {
  "fn plain_area(\n"
  <> "  name: String,\n"
  <> "  children: List(element.Element(Nil)),\n"
  <> ") -> element.Element(Nil) {\n"
  <> "  html.div_([attribute.attribute(\"data-yumemi-area\", name)], children)\n"
  <> "}\n\n"
}

fn placement_helpers_text(
  app: model.App,
  units: List(Unit),
  front: reader_front.Front,
  prefix: String,
  placements: List(reader_front.Placement),
  sources: List(LoadSource),
  access: String,
) -> String {
  indexed_placements(placements, 0)
  |> list.map(fn(item) {
    let #(index, placement) = item
    placement_helper_text(
      app,
      units,
      front,
      prefix,
      index,
      placement,
      sources,
      access,
    )
  })
  |> string.join("\n")
}

fn placement_helper_text(
  app: model.App,
  units: List(Unit),
  front: reader_front.Front,
  prefix: String,
  index: Int,
  placement: reader_front.Placement,
  sources: List(LoadSource),
  access: String,
) -> String {
  let helper = prefix <> "_" <> int.to_string(index)
  let body = case placement {
    reader_front.Fixed(block: block_name, ..) ->
      fixed_placement_body(front, block_name, app.services, sources, access)
    reader_front.Widget(name: name, service: service_name, render: render, ..) ->
      widget_placement_body(
        app,
        units,
        front,
        helper,
        name,
        service_name,
        render,
        sources,
        access,
      )
  }
  let argument = case
    placement_uses_data(front, app.services, placement, sources)
  {
    True -> "it"
    False -> "_it"
  }
  let extra = placement_extra_text(app, units, front, prefix, index, placement)
  "fn "
  <> helper
  <> "("
  <> argument
  <> ": Data) -> List(element.Element(Nil)) {\n"
  <> body
  <> "\n}\n"
  <> extra
}

fn placement_uses_data(
  front: reader_front.Front,
  services: List(model.Service),
  placement: reader_front.Placement,
  sources: List(LoadSource),
) -> Bool {
  case placement {
    reader_front.Fixed(block: block_name, ..) ->
      case block_source(front.blocks, block_name, services) {
        Some(service) -> load_source(sources, "service:" <> service) != None
        None -> False
      }
    reader_front.Widget(name: name, service: service_name, ..) ->
      case service_module(services, service_name) {
        Some(service) ->
          load_source(sources, "widget:" <> service <> ":" <> name) != None
        None -> False
      }
  }
}

fn fixed_placement_body(
  front: reader_front.Front,
  block_name: String,
  services: List(model.Service),
  sources: List(LoadSource),
  access: String,
) -> String {
  let block = block_module(front, block_name)
  let view = module_ref(block) <> ".view"
  case block_source(front.blocks, block_name, services) {
    None -> "  [" <> view <> "(Nil)]"
    Some(service) ->
      case load_source(sources, "service:" <> service) {
        Some(source) -> source_view_list(source, access, view)
        None -> "  []"
      }
  }
}

fn widget_placement_body(
  app: model.App,
  units: List(Unit),
  front: reader_front.Front,
  helper: String,
  name: String,
  service_name: String,
  render: reader_front.Render,
  sources: List(LoadSource),
  access: String,
) -> String {
  case service_module(app.services, service_name) {
    None -> "  []"
    Some(service) ->
      case load_source(sources, "widget:" <> service <> ":" <> name) {
        None -> "  []"
        Some(source) ->
          case render {
            reader_front.One(block_name) ->
              source_view_list(
                source,
                access,
                module_ref(block_module(front, block_name)) <> ".view",
              )
            reader_front.ByKind(table: _table, ..) -> {
              let rows_helper = "render_" <> helper
              let row_field = row_field_name(units, service)
              source_rows_list(source, access, rows_helper, row_field)
            }
            reader_front.UnknownRender -> "  []"
          }
      }
  }
}

fn placement_extra_text(
  app: model.App,
  units: List(Unit),
  front: reader_front.Front,
  prefix: String,
  index: Int,
  placement: reader_front.Placement,
) -> String {
  case placement {
    reader_front.Widget(
      service: service_name,
      render: reader_front.ByKind(table: table, ..),
      ..,
    ) ->
      case service_module(app.services, service_name) {
        Some(service) -> {
          let state = out_state(app, units, "service/" <> service).0
          "\n"
          <> rows_helper_text(
            front,
            service,
            table,
            state,
            "render_" <> prefix <> "_" <> int.to_string(index),
          )
        }
        None -> ""
      }
    _ -> ""
  }
}

fn load_source(sources: List(LoadSource), key: String) -> Option(LoadSource) {
  case list.find(sources, fn(source) { source.key == key }) {
    Ok(source) -> Some(source)
    Error(_) -> None
  }
}

fn source_view_list(
  source: LoadSource,
  access: String,
  view: String,
) -> String {
  let value = access <> "." <> source.name
  case source.optional {
    True ->
      "  case "
      <> value
      <> " {\n    Some(out) -> ["
      <> view
      <> "(out)]\n    None -> []\n  }"
    False -> "  [" <> view <> "(" <> value <> ")]"
  }
}

fn source_rows_list(
  source: LoadSource,
  access: String,
  helper: String,
  row_field: String,
) -> String {
  "  case "
  <> access
  <> "."
  <> source.name
  <> " {\n    Some(out) -> "
  <> helper
  <> "(out."
  <> row_field
  <> ")\n    None -> []\n  }"
}

fn rows_helper_text(
  front: reader_front.Front,
  service: String,
  table: List(#(String, String)),
  state: State,
  helper: String,
) -> String {
  let out = module_ref("gen/out/" <> service)
  let rows =
    table
    |> list.map(fn(entry) {
      let #(key, block_name) = entry
      let constructor = row_constructor_name(state, service, key)
      "        "
      <> out
      <> "."
      <> constructor
      <> "(..) -> [\n          "
      <> module_ref(block_module(front, block_name))
      <> ".view(row),\n          .."
      <> helper
      <> "(rest),\n        ]\n"
    })
    |> string.concat
  let fallback = case exhaustive_row_table(state, service, table) {
    True -> ""
    False -> "        _ -> " <> helper <> "(rest)\n"
  }
  "fn "
  <> helper
  <> "(rows: List("
  <> out
  <> ".Row)) -> List(element.Element(Nil)) {\n"
  <> "  case rows {\n    [] -> []\n    [row, ..rest] ->\n      case row {\n"
  <> rows
  <> fallback
  <> "      }\n  }\n}"
}

fn exhaustive_row_table(
  state: State,
  service: String,
  table: List(#(String, String)),
) -> Bool {
  let variants = row_variant_names(state, service)
  let covered =
    list.map(table, fn(entry) { row_constructor_name(state, service, entry.0) })
  variants != []
  && list.length(variants) == list.length(covered)
  && list.all(variants, fn(variant) { list.contains(covered, variant) })
}

fn row_variant_names(state: State, service: String) -> List(String) {
  case
    list.find(state.custom, fn(declaration) {
      let CustomDecl(scope: scope, definition: definition) = declaration
      scope.module == "service/" <> service && definition.name == "Row"
    })
  {
    Ok(CustomDecl(definition: definition, ..)) ->
      list.map(definition.variants, fn(variant) {
        row_constructor_name(state, service, variant.name)
      })
    Error(_) -> []
  }
}

fn row_constructor_name(
  state: State,
  service: String,
  variant: String,
) -> String {
  case entity_type_name(state, variant) {
    Some(_) -> variant <> "Row"
    None -> mapped_constructor(state, "service/" <> service, "Row", variant)
  }
}

fn row_field_name(units: List(Unit), service: String) -> String {
  let path = "service/" <> service
  let scope = scope_for(units, path)
  case output_type(units, path) {
    Some(type_) ->
      case resolved_path(scope, type_), type_name(type_) {
        Some(output_path), name ->
          case custom_for(units, output_path, name) {
            Some(definition) ->
              case
                list.find(definition.variants, fn(variant) {
                  variant.name == name
                })
              {
                Ok(variant) ->
                  case
                    list.first(
                      variant.fields
                      |> list.filter_map(fn(field) {
                        case list_row_field(field) {
                          Some(value) -> Ok(value)
                          None -> Error(Nil)
                        }
                      }),
                    )
                  {
                    Ok(field) -> field
                    Error(_) -> "rows"
                  }
                Error(_) -> "rows"
              }
            None -> "rows"
          }
        _, _ -> "rows"
      }
    None -> "rows"
  }
}

fn list_row_field(field: glance.VariantField) -> Option(String) {
  case g.variant_field_type(field) {
    glance.NamedType(
      name: "List",
      parameters: [glance.NamedType(name: "Row", ..)],
      ..,
    ) -> g.variant_field_label(field)
    _ -> None
  }
}

fn block_module(front: reader_front.Front, name: String) -> String {
  case list.find(front.blocks, fn(block) { block.name == name }) {
    Ok(block) -> block.module
    Error(_) -> "blocks/" <> naming.snake(name)
  }
}

fn module_ref(path: String) -> String {
  last_segment(path)
}

fn header(source: String, input_hash: String) -> String {
  "//// GENERATED from "
  <> source
  <> " [sha256:"
  <> input_hash
  <> "] — 手で編集しない\n"
}

fn route_text(
  face_name: String,
  pages: List(reader_front.Page),
  input_hash: String,
) -> String {
  let rows =
    pages
    |> list.map(fn(page) {
      "  PageRoute(path: \"" <> reader_front.route_path(page.path) <> "\"),"
    })
    |> list.sort(string.compare)
    |> string.join("\n")
  header(face_name <> "/src/pages/**/page.gleam", input_hash)
  <> "\npub type PageRoute {\n  PageRoute(path: String)\n}\n\n"
  <> "pub const routes: List(PageRoute) = [\n"
  <> rows
  <> "\n]\n"
}

fn blocks_text(
  face_name: String,
  blocks: List(reader_front.Block),
  input_hash: String,
) -> String {
  let variants =
    blocks
    |> list.map(fn(block) { block.name })
    |> list.sort(string.compare)
    |> list.map(fn(name) { "  " <> name })
    |> string.join("\n")
  header(face_name <> "/src/blocks/*.gleam", input_hash)
  <> "\n"
  <> enum_body("Block", variants)
}

fn widgets_text(
  face_name: String,
  widget_keys: List(String),
  input_hash: String,
) -> String {
  let variants =
    widget_keys
    |> list.unique
    |> list.sort(string.compare)
    |> list.map(fn(name) { "  " <> name })
    |> string.join("\n")
  header(
    face_name
      <> "/src/layout.gleam and "
      <> face_name
      <> "/src/pages/**/*.gleam",
    input_hash,
  )
  <> "\n"
  <> enum_body("WidgetKey", variants)
}

fn service_text(
  _face_name: String,
  services: List(model.Service),
  input_hash: String,
) -> String {
  let variants =
    services
    |> list.map(fn(service) { naming.pascal(service.module) })
    |> list.unique
    |> list.sort(string.compare)
    |> list.map(fn(name) { "  " <> name })
    |> string.join("\n")
  header("src/service/*.gleam", input_hash)
  <> "\n"
  <> enum_body("Service", variants)
}

fn enum_body(name: String, variants: String) -> String {
  case variants {
    "" -> "pub type " <> name <> "\n"
    _ -> "pub type " <> name <> " {\n" <> variants <> "\n}\n"
  }
}

fn api_text(face_name: String, app: model.App, hashes: hash.Hashes) -> String {
  let routes = api_routes(app, hashes, face_name)
  let methods =
    routes
    |> list.map(fn(route) { method_variant(route.method) })
    |> list.unique
    |> list.sort(string.compare)
  let method_rows =
    string.join(list.map(methods, fn(name) { "  " <> name }), "\n")
  let rows = routes |> list.map(api_route_text) |> string.join("\n")
  header("src/entry.gleam", hash.entry(hashes))
  <> "\nimport gen/service\n\n"
  <> enum_body("Method", method_rows)
  <> "\n"
  <> "pub type Route {\n"
  <> "  Route(service: service.Service, method: Method, path: String)\n"
  <> "}\n\n"
  <> "pub const routes: List(Route) = [\n"
  <> rows
  <> "\n]\n"
}

fn method_variant(method: String) -> String {
  naming.pascal(string.lowercase(method))
}

fn api_route_text(route: ApiRoute) -> String {
  "  Route(service: service."
  <> naming.pascal(route.service)
  <> ", method: "
  <> method_variant(route.method)
  <> ", path: \""
  <> route.path
  <> "\"),"
}

fn api_routes(
  app: model.App,
  hashes: hash.Hashes,
  face_name: String,
) -> List(ApiRoute) {
  let output = entry.emit(app, hashes)
  case
    list.find(output.files, fn(file) { file.path == "src/gen/entry/http.gleam" })
  {
    Ok(file) ->
      file.text
      |> string.split("\n")
      |> list.filter_map(fn(row) { api_route_from_row(row, face_name) })
    Error(_) -> []
  }
}

fn api_route_from_row(row: String, face_name: String) -> Result(ApiRoute, Nil) {
  case string.starts_with(row, "  Route(face:") {
    False -> Error(Nil)
    True ->
      case
        quoted_field(row, "face"),
        quoted_field(row, "method"),
        quoted_field(row, "path"),
        quoted_field(row, "service")
      {
        Some(face), Some(method), Some(path), Some(service) ->
          case face == face_name {
            True ->
              Ok(ApiRoute(
                service: service,
                method: method,
                path: colon_path(path),
              ))
            False -> Error(Nil)
          }
        _, _, _, _ -> Error(Nil)
      }
  }
}

fn quoted_field(row: String, label: String) -> Option(String) {
  let marker = label <> ": \""
  case string.split(row, marker) {
    [_, rest, ..] ->
      case string.split(rest, "\"") {
        [value, ..] -> Some(value)
        [] -> None
      }
    _ -> None
  }
}

fn colon_path(path: String) -> String {
  path |> string.replace("{", ":") |> string.replace("}", "")
}

fn back_type_units(
  app: model.App,
  units: List(Unit),
  hashes: hash.Hashes,
) -> List(Unit) {
  list.append(units, generated_draft_units(app, hashes))
}

fn generated_draft_units(app: model.App, hashes: hash.Hashes) -> List(Unit) {
  draft.emit(app, hashes)
  |> list.filter_map(fn(file) {
    case
      string.starts_with(file.path, "src/")
      && string.ends_with(file.path, ".gleam")
    {
      False -> Error(Nil)
      True ->
        case glance.module(file.text) {
          Ok(module) ->
            Ok(Unit(
              path: file.path |> string.drop_start(4) |> string.drop_end(6),
              text: file.text,
              module: module,
            ))
          Error(_) -> Error(Nil)
        }
    }
  })
}

// ── Out の写し ──────────────────────────────────────────────────────────────

type Scope {
  Scope(module: String, imports: List(glance.Definition(glance.Import)))
}

type CustomDecl {
  CustomDecl(scope: Scope, definition: glance.CustomType)
}

type AliasDecl {
  SourceAlias(scope: Scope, definition: glance.TypeAlias)
  AliasRedirect(path: String, source_name: String)
  ValueAlias(
    path: String,
    source_name: String,
    name: String,
    backing: model.Backing,
  )
}

type OutAlias {
  OutAlias(scope: Scope, type_: glance.Type)
}

type State {
  State(
    aliases: List(AliasDecl),
    custom: List(CustomDecl),
    entities: List(model.Entity),
    phantoms: List(String),
    opaque_names: List(String),
    names: List(#(String, String)),
    constructors: List(#(String, String)),
    enum_aliases: List(String),
    imports: List(#(String, String)),
    entity_work: List(String),
    custom_work: List(String),
    alias_work: List(String),
  )
}

fn empty_state() -> State {
  State(
    aliases: [],
    custom: [],
    entities: [],
    phantoms: [],
    opaque_names: [],
    names: [],
    constructors: [],
    enum_aliases: [],
    imports: [],
    entity_work: [],
    custom_work: [],
    alias_work: [],
  )
}

fn out_file(
  app: model.App,
  units: List(Unit),
  service: model.Service,
  hashes: hash.Hashes,
  face_name: String,
) -> File {
  let service_path = "service/" <> service.module
  let scope = scope_for(units, service_path)
  let #(state, output) = out_state(app, units, service_path)
  let out_alias = case output {
    Some(type_) ->
      case has_local_decl(units, scope, type_) {
        True -> None
        False -> Some(OutAlias(scope: scope, type_: type_))
      }
    None -> None
  }
  let declarations = case output {
    None -> "pub type Out\n"
    Some(_) -> declarations_text(state, app)
  }
  let body =
    header(
      "src/service/" <> service.module <> ".gleam",
      hash.service(hashes, service.module),
    )
    <> "\n"
    <> imports_text(state)
    <> case imports_text(state) {
      "" -> ""
      _ -> "\n\n"
    }
    <> declarations
    <> case out_alias {
      None -> ""
      Some(alias) -> "\n" <> out_alias_text(state, alias)
    }
  File(
    path: face_name <> "/src/gen/out/" <> service.module <> ".gleam",
    text: body,
  )
}

fn out_state(
  app: model.App,
  units: List(Unit),
  service_path: String,
) -> #(State, Option(glance.Type)) {
  let scope = scope_for(units, service_path)
  let output = output_type(units, service_path)
  let state = case output {
    Some(type_) -> collect_gl_type(empty_state(), app, units, scope, type_)
    None -> empty_state()
  }
  #(finalize_state(state), output)
}

fn scope_for(units: List(Unit), path: String) -> Scope {
  case unit_for(units, path) {
    Some(unit) -> {
      let module = g.in_order(unit.module)
      Scope(module: path, imports: module.imports)
    }
    None -> Scope(module: path, imports: [])
  }
}

fn unit_for(units: List(Unit), path: String) -> Option(Unit) {
  case list.find(units, fn(unit) { unit.path == path }) {
    Ok(unit) -> Some(unit)
    Error(_) -> None
  }
}

fn output_type(units: List(Unit), service_path: String) -> Option(glance.Type) {
  case unit_for(units, service_path) {
    Some(unit) -> {
      let module = g.in_order(unit.module)
      case g.find_constant(module, "service") {
        Some(constant) ->
          case constant.annotation {
            Some(glance.NamedType(parameters: [_, output, ..], ..)) ->
              Some(output)
            _ -> None
          }
        None -> None
      }
    }
    None -> None
  }
}

fn has_local_decl(units: List(Unit), scope: Scope, type_: glance.Type) -> Bool {
  case resolved_path(scope, type_) {
    Some(path) ->
      case path == scope.module {
        True ->
          case unit_for(units, path) {
            Some(unit) -> {
              let module = g.in_order(unit.module)
              g.find_custom_type(module, type_name(type_)) != None
              || g.find_type_alias(module, type_name(type_)) != None
            }
            None -> False
          }
        False -> False
      }
    _ -> False
  }
}

fn collect_gl_type(
  state: State,
  app: model.App,
  units: List(Unit),
  scope: Scope,
  type_: glance.Type,
) -> State {
  case type_ {
    glance.NamedType(name: name, parameters: parameters, ..) -> {
      let path = resolved_path(scope, type_)
      let state =
        collect_named(state, app, units, scope, path, name, parameters)
      case path {
        Some("framework/er") ->
          case is_relation_type(name) {
            True -> state
            False ->
              list.fold(parameters, state, fn(acc, parameter) {
                collect_gl_type(acc, app, units, scope, parameter)
              })
          }
        _ ->
          list.fold(parameters, state, fn(acc, parameter) {
            collect_gl_type(acc, app, units, scope, parameter)
          })
      }
    }
    glance.TupleType(elements: elements, ..) ->
      list.fold(elements, state, fn(acc, element) {
        collect_gl_type(acc, app, units, scope, element)
      })
    glance.FunctionType(parameters: parameters, return: return_type, ..) -> {
      let state =
        list.fold(parameters, state, fn(acc, parameter) {
          collect_gl_type(acc, app, units, scope, parameter)
        })
      collect_gl_type(state, app, units, scope, return_type)
    }
    glance.VariableType(..) | glance.HoleType(..) -> state
  }
}

fn collect_named(
  state: State,
  app: model.App,
  units: List(Unit),
  scope: Scope,
  path: Option(String),
  name: String,
  parameters: List(glance.Type),
) -> State {
  case path {
    None -> state
    Some(path) ->
      case path {
        "framework/er" ->
          case is_relation_type(name) {
            True -> {
              let state = relation_type(state, name)
              list.fold(parameters, state, fn(acc, parameter) {
                collect_relation_parameter(acc, app, units, scope, parameter)
              })
            }
            False -> {
              let state = add_import(state, "framework/er", name)
              list.fold(parameters, state, fn(acc, parameter) {
                collect_gl_type(acc, app, units, scope, parameter)
              })
            }
          }
        "framework/time" -> add_import(state, path, name)
        "framework/blob" -> add_import(state, path, name)
        _ -> collect_back_named(state, app, units, scope, path, name)
      }
  }
}

fn collect_back_named(
  state: State,
  app: model.App,
  units: List(Unit),
  scope: Scope,
  path: String,
  name: String,
) -> State {
  case string.starts_with(path, "gen/types/") {
    True -> ensure_value_alias(state, app, path, name)
    False ->
      case string.starts_with(path, "entity/") {
        True -> collect_entity_or_custom(state, app, units, scope, path, name)
        False ->
          case allowed_import(path) {
            True -> add_import(state, path, name)
            False -> ensure_named(state, app, units, path, name)
          }
      }
  }
}

fn collect_relation_parameter(
  state: State,
  app: model.App,
  units: List(Unit),
  scope: Scope,
  parameter: glance.Type,
) -> State {
  case parameter {
    glance.NamedType(name: name, ..) ->
      case resolved_path(scope, parameter) {
        Some(path) ->
          case string.starts_with(path, "entity/") {
            True -> ensure_phantom(state, app, path, name)
            False -> collect_gl_type(state, app, units, scope, parameter)
          }
        None -> collect_gl_type(state, app, units, scope, parameter)
      }
    _ -> collect_gl_type(state, app, units, scope, parameter)
  }
}

fn collect_entity_or_custom(
  state: State,
  app: model.App,
  units: List(Unit),
  _scope: Scope,
  path: String,
  name: String,
) -> State {
  case model.entity_by_module(app.entities, string.drop_start(path, 7)) {
    Some(entity) ->
      case entity.type_name == name {
        True -> ensure_entity(state, app, units, entity)
        False -> ensure_named(state, app, units, path, name)
      }
    None -> ensure_named(state, app, units, path, name)
  }
}

fn ensure_entity(
  state: State,
  app: model.App,
  units: List(Unit),
  entity: model.Entity,
) -> State {
  let key = "entity/" <> entity.module <> ":" <> entity.type_name
  case
    list.contains(state.entity_work, key),
    has_entity(state, entity.type_name)
  {
    True, _ | _, True -> state
    False, False -> {
      let state =
        reserve_type(state, "entity/" <> entity.module, entity.type_name).0
      let state = State(..state, entity_work: [key, ..state.entity_work])
      let state =
        list.fold(entity.props, state, fn(acc, prop) {
          collect_prop(acc, app, units, prop)
        })
      let state =
        State(
          ..state,
          entities: list.append(state.entities, [entity]),
          entity_work: without(state.entity_work, key),
          phantoms: list.filter(state.phantoms, fn(name) {
            name
            != mapped_name(state, "entity/" <> entity.module, entity.type_name)
          }),
        )
      state
    }
  }
}

fn collect_prop(
  state: State,
  app: model.App,
  units: List(Unit),
  prop: model.Prop,
) -> State {
  let state = case prop.optional {
    True -> add_import(state, "gleam/option", "Option")
    False -> state
  }
  case prop.kind {
    model.RelProp(kind: kind, target_module: module, target_type: type_name_) -> {
      let state = ensure_phantom(state, app, "entity/" <> module, type_name_)
      relation_type(state, relation_name(kind))
    }
    model.ValueProp(reference) ->
      collect_model_ref(state, app, units, reference)
    model.SumProp(reference, payloads) -> {
      let state = collect_model_ref(state, app, units, reference)
      list.fold(payloads, state, fn(acc, payload) {
        collect_model_ref(acc, app, units, payload)
      })
    }
  }
}

fn collect_model_ref(
  state: State,
  app: model.App,
  units: List(Unit),
  reference: model.TypeRef,
) -> State {
  let state = case reference.module {
    None -> state
    Some(path) ->
      collect_model_named(
        state,
        app,
        units,
        path,
        reference.name,
        reference.parameters,
      )
  }
  case reference.module, is_relation_type(reference.name) {
    Some("framework/er"), True -> state
    _, _ ->
      list.fold(reference.parameters, state, fn(acc, parameter) {
        collect_model_shape(acc, app, units, parameter)
      })
  }
}

fn collect_model_named(
  state: State,
  app: model.App,
  units: List(Unit),
  path: String,
  name: String,
  parameters: List(model.TypeShape),
) -> State {
  case path {
    "framework/er" ->
      case is_relation_type(name) {
        True -> {
          let state = relation_type(state, name)
          list.fold(parameters, state, fn(acc, parameter) {
            collect_relation_shape(acc, app, units, parameter)
          })
        }
        False -> add_import(state, path, name)
      }
    "framework/time" -> add_import(state, path, name)
    "framework/blob" -> add_import(state, path, name)
    _ ->
      case string.starts_with(path, "gen/types/") {
        True -> ensure_value_alias(state, app, path, name)
        False ->
          case string.starts_with(path, "entity/") {
            True ->
              collect_entity_or_custom(
                state,
                app,
                units,
                Scope(module: path, imports: []),
                path,
                name,
              )
            False ->
              case allowed_import(path) {
                True -> add_import(state, path, name)
                False -> ensure_named(state, app, units, path, name)
              }
          }
      }
  }
}

fn collect_relation_shape(
  state: State,
  app: model.App,
  units: List(Unit),
  shape: model.TypeShape,
) -> State {
  case shape {
    model.NamedShape(module: Some(path), name: name, ..) ->
      case string.starts_with(path, "entity/") {
        True -> ensure_phantom(state, app, path, name)
        False -> collect_model_shape(state, app, units, shape)
      }
    _ -> collect_model_shape(state, app, units, shape)
  }
}

fn collect_model_shape(
  state: State,
  app: model.App,
  units: List(Unit),
  shape: model.TypeShape,
) -> State {
  case shape {
    model.NamedShape(module: module, name: name, parameters: parameters) -> {
      let state = case module {
        None -> state
        Some(path) ->
          collect_model_named(state, app, units, path, name, parameters)
      }
      list.fold(parameters, state, fn(acc, parameter) {
        collect_model_shape(acc, app, units, parameter)
      })
    }
    model.TupleShape(items) ->
      list.fold(items, state, fn(acc, item) {
        collect_model_shape(acc, app, units, item)
      })
  }
}

fn ensure_phantom(
  state: State,
  app: model.App,
  path: String,
  name: String,
) -> State {
  let local_name = case
    model.entity_by_module(app.entities, string.drop_start(path, 7))
  {
    Some(entity) -> entity.type_name
    None -> name
  }
  let #(state, emitted_name) = reserve_type(state, path, local_name)
  case
    has_entity(state, local_name),
    list.contains(state.phantoms, emitted_name)
  {
    True, _ | _, True -> state
    False, False ->
      State(..state, phantoms: list.append(state.phantoms, [emitted_name]))
  }
}

fn ensure_custom(
  state: State,
  app: model.App,
  units: List(Unit),
  path: String,
  name: String,
) -> State {
  let key = path <> ":" <> name
  case list.contains(state.custom_work, key), has_custom(state, key) {
    True, _ | _, True -> state
    False, False ->
      case custom_for(units, path, name) {
        Some(definition) -> {
          let scope = scope_for(units, path)
          let state = reserve_type(state, path, name).0
          let state = State(..state, custom_work: [key, ..state.custom_work])
          let state =
            list.fold(definition.variants, state, fn(acc, variant) {
              list.fold(variant.fields, acc, fn(inner, field) {
                collect_gl_type(
                  inner,
                  app,
                  units,
                  scope,
                  g.variant_field_type(field),
                )
              })
            })
          State(
            ..state,
            custom: list.append(state.custom, [CustomDecl(scope, definition)]),
            custom_work: without(state.custom_work, key),
          )
        }
        None -> state
      }
  }
}

fn ensure_named(
  state: State,
  app: model.App,
  units: List(Unit),
  path: String,
  name: String,
) -> State {
  let key = path <> ":" <> name
  let state = ensure_custom(state, app, units, path, name)
  case has_custom(state, key), has_alias(state, key) {
    True, _ | _, True -> state
    False, False -> ensure_alias(state, app, units, path, name)
  }
}

fn ensure_alias(
  state: State,
  app: model.App,
  units: List(Unit),
  path: String,
  name: String,
) -> State {
  let key = path <> ":" <> name
  case list.contains(state.alias_work, key), has_alias(state, key) {
    True, _ | _, True -> state
    False, False ->
      case alias_for(units, path, name) {
        Some(definition) -> {
          let scope = scope_for(units, path)
          case direct_named_target(scope, definition.aliased) {
            Some(#(target_path, target_name)) ->
              case string.starts_with(target_path, "gen/types/") {
                True -> {
                  let state =
                    ensure_value_alias(state, app, target_path, target_name)
                  let emitted_name =
                    mapped_name(state, target_path, target_name)
                  State(
                    ..state,
                    names: list.append(state.names, [#(key, emitted_name)]),
                    aliases: list.append(state.aliases, [
                      AliasRedirect(path: path, source_name: name),
                    ]),
                  )
                }
                False -> {
                  let state = reserve_type(state, path, name).0
                  let state =
                    State(..state, alias_work: [key, ..state.alias_work])
                  let state =
                    collect_gl_type(
                      state,
                      app,
                      units,
                      scope,
                      definition.aliased,
                    )
                  State(
                    ..state,
                    aliases: list.append(state.aliases, [
                      SourceAlias(scope, definition),
                    ]),
                    alias_work: without(state.alias_work, key),
                  )
                }
              }
            _ -> {
              let state = reserve_type(state, path, name).0
              let state = State(..state, alias_work: [key, ..state.alias_work])
              let state =
                collect_gl_type(state, app, units, scope, definition.aliased)
              State(
                ..state,
                aliases: list.append(state.aliases, [
                  SourceAlias(scope, definition),
                ]),
                alias_work: without(state.alias_work, key),
              )
            }
          }
        }
        None -> state
      }
  }
}

fn ensure_value_alias(
  state: State,
  app: model.App,
  path: String,
  name: String,
) -> State {
  let key = path <> ":" <> name
  case list.contains(state.alias_work, key), has_alias(state, key) {
    True, _ | _, True -> state
    False, False ->
      case model.value_type_by_name(app.value_types, name) {
        Some(value) -> {
          let #(state, emitted_name) =
            reserve_type(state, path, value.type_name)
          State(
            ..state,
            aliases: list.append(state.aliases, [
              ValueAlias(path, name, emitted_name, value.backing),
            ]),
          )
        }
        None -> state
      }
  }
}

fn custom_for(
  units: List(Unit),
  path: String,
  name: String,
) -> Option(glance.CustomType) {
  case unit_for(units, path) {
    Some(unit) -> g.find_custom_type(g.in_order(unit.module), name)
    None -> None
  }
}

fn alias_for(
  units: List(Unit),
  path: String,
  name: String,
) -> Option(glance.TypeAlias) {
  case unit_for(units, path) {
    Some(unit) -> g.find_type_alias(g.in_order(unit.module), name)
    None -> None
  }
}

fn direct_named_target(
  scope: Scope,
  type_: glance.Type,
) -> Option(#(String, String)) {
  case type_ {
    glance.NamedType(name: name, ..) ->
      case resolved_path(scope, type_) {
        Some(path) -> Some(#(path, name))
        None -> None
      }
    _ -> None
  }
}

fn has_custom(state: State, key: String) -> Bool {
  list.any(state.custom, fn(declaration) {
    let CustomDecl(scope: scope, definition: definition) = declaration
    scope.module <> ":" <> definition.name == key
  })
}

fn has_alias(state: State, key: String) -> Bool {
  list.any(state.aliases, fn(declaration) {
    case declaration {
      SourceAlias(scope: scope, definition: definition) ->
        scope.module <> ":" <> definition.name == key
      AliasRedirect(path: path, source_name: source_name) ->
        key == path <> ":" <> source_name
      ValueAlias(path: path, source_name: source_name, ..) ->
        key == path <> ":" <> source_name
    }
  })
}

fn has_entity(state: State, name: String) -> Bool {
  list.any(state.entities, fn(entity) { entity.type_name == name })
  || list.any(state.entity_work, fn(key) { string.ends_with(key, ":" <> name) })
}

fn finalize_state(state: State) -> State {
  let enum_aliases = row_enum_aliases(state.custom)
  let state = State(..state, enum_aliases: enum_aliases)
  let constructors = constructor_names(state)
  State(..state, constructors: constructors)
}

fn row_enum_aliases(declarations: List(CustomDecl)) -> List(String) {
  let row_variants =
    declarations
    |> list.filter_map(fn(declaration) {
      let CustomDecl(definition: definition, ..) = declaration
      case definition.name {
        "Row" ->
          Ok(definition.variants |> list.map(fn(variant) { variant.name }))
        _ -> Error(Nil)
      }
    })
    |> list.flatten
  declarations
  |> list.filter_map(fn(declaration) {
    let CustomDecl(scope: scope, definition: definition) = declaration
    case definition.name == "Row" {
      True -> Error(Nil)
      False ->
        case
          list.any(definition.variants, fn(variant) {
            list.contains(row_variants, variant.name)
          })
        {
          True -> Ok(scope.module <> ":" <> definition.name)
          False -> Error(Nil)
        }
    }
  })
}

fn constructor_names(state: State) -> List(#(String, String)) {
  let entity_constructors =
    list.map(state.entities, fn(entity) {
      let path = "entity/" <> entity.module
      #(
        constructor_key(path, entity.type_name, entity.type_name),
        mapped_name(state, path, entity.type_name),
      )
    })
  list.fold(state.custom, entity_constructors, fn(acc, declaration) {
    let CustomDecl(scope: scope, definition: definition) = declaration
    case
      list.contains(state.enum_aliases, scope.module <> ":" <> definition.name)
    {
      True -> acc
      False ->
        list.fold(definition.variants, acc, fn(_inner, variant) {
          let candidate = case variant.name == definition.name {
            True -> mapped_name(state, scope.module, definition.name)
            False ->
              case definition.name {
                "Row" ->
                  case entity_type_name(state, variant.name) {
                    Some(_) ->
                      fresh_constructor_name(acc, variant.name <> "Row")
                    None -> fresh_constructor_name(acc, variant.name)
                  }
                _ -> fresh_constructor_name(acc, variant.name)
              }
          }
          list.append(acc, [
            #(
              constructor_key(scope.module, definition.name, variant.name),
              candidate,
            ),
          ])
        })
    }
  })
}

fn entity_type_name(state: State, name: String) -> Option(String) {
  case list.find(state.entities, fn(entity) { entity.type_name == name }) {
    Ok(entity) -> Some(mapped_name(state, "entity/" <> entity.module, name))
    Error(_) -> None
  }
}

fn fresh_constructor_name(
  constructors: List(#(String, String)),
  base: String,
) -> String {
  case list.any(constructors, fn(item) { item.1 == base }) {
    False -> base
    True -> fresh_constructor_suffix(constructors, base, 2)
  }
}

fn fresh_constructor_suffix(
  constructors: List(#(String, String)),
  base: String,
  number: Int,
) -> String {
  let candidate = base <> int.to_string(number)
  case list.any(constructors, fn(item) { item.1 == candidate }) {
    True -> fresh_constructor_suffix(constructors, base, number + 1)
    False -> candidate
  }
}

fn constructor_key(path: String, type_name: String, variant: String) -> String {
  path <> ":" <> type_name <> ":" <> variant
}

fn mapped_constructor(
  state: State,
  path: String,
  type_name: String,
  variant: String,
) -> String {
  case
    list.find(state.constructors, fn(item) {
      item.0 == constructor_key(path, type_name, variant)
    })
  {
    Ok(item) -> item.1
    Error(_) -> variant
  }
}

fn declarations_text(state: State, app: model.App) -> String {
  let aliases =
    state.aliases
    |> list.filter_map(fn(alias) {
      case alias_text(state, alias) {
        "" -> Error(Nil)
        text -> Ok(text)
      }
    })
  let opaque_decls =
    list.map(state.opaque_names, fn(name) {
      opaque_text(mapped_name(state, opaque_path(name), name))
    })
  let entities =
    list.map(state.entities, fn(entity) { entity_text(state, entity, app) })
  let phantoms =
    list.map(state.phantoms, fn(name) { "pub type " <> name <> "\n" })
  let custom =
    list.map(state.custom, fn(declaration) { custom_text(state, declaration) })
  string.join(
    list.append(
      aliases,
      list.append(
        opaque_decls,
        list.append(entities, list.append(phantoms, custom)),
      ),
    ),
    "\n",
  )
}

fn imports_text(state: State) -> String {
  state.imports
  |> list.sort(fn(left, right) {
    case string.compare(left.0, right.0) {
      order.Eq -> string.compare(left.1, right.1)
      other -> other
    }
  })
  |> group_imports
}

fn group_imports(imports: List(#(String, String))) -> String {
  case imports {
    [] -> ""
    [first, ..rest] -> {
      let groups = collect_import_groups(rest, [#(first.0, [first.1])])
      groups
      |> list.map(fn(group) {
        let #(path, names) = group
        "import "
        <> path
        <> ".{"
        <> string.join(
          list.map(list.unique(names), fn(name) { "type " <> name }),
          ", ",
        )
        <> "}"
      })
      |> string.join("\n")
    }
  }
}

fn collect_import_groups(
  imports: List(#(String, String)),
  groups: List(#(String, List(String))),
) -> List(#(String, List(String))) {
  case imports {
    [] -> groups
    [#(path, name), ..rest] ->
      case list.find(groups, fn(group) { group.0 == path }) {
        Ok(_) ->
          collect_import_groups(
            rest,
            list.map(groups, fn(group) {
              case group.0 == path {
                True -> #(group.0, list.append(group.1, [name]))
                False -> group
              }
            }),
          )
        Error(_) ->
          collect_import_groups(rest, list.append(groups, [#(path, [name])]))
      }
  }
}

fn alias_text(state: State, alias: AliasDecl) -> String {
  case alias {
    AliasRedirect(..) -> ""
    ValueAlias(name: name, backing: model.StringValue, ..) ->
      "pub type " <> name <> " = String\n"
    ValueAlias(name: name, backing: model.IntValue, ..) ->
      "pub type " <> name <> " = Int\n"
    SourceAlias(scope: scope, definition: definition) ->
      "pub type "
      <> mapped_name(state, scope.module, definition.name)
      <> type_parameters(definition.parameters)
      <> " = "
      <> render_gl_type(state, scope, definition.aliased)
      <> "\n"
  }
}

fn opaque_text(name: String) -> String {
  case name {
    "Has" -> "pub type Has(entity) {\n  Has(value: String)\n}\n"
    "Held" -> "pub type Held(entity) {\n  Held(value: String)\n}\n"
    "Multi" -> "pub type Multi(entity) {\n  Multi(values: List(String))\n}\n"
    "Date" -> "pub type Date {\n  Date(value: String)\n}\n"
    "Datetime" -> "pub type Datetime {\n  Datetime(value: String)\n}\n"
    "Time" -> "pub type Time {\n  Time(value: String)\n}\n"
    "Blob" -> "pub type Blob {\n  Blob(key: String)\n}\n"
    _ -> ""
  }
}

fn entity_text(state: State, entity: model.Entity, app: model.App) -> String {
  let name = mapped_name(state, "entity/" <> entity.module, entity.type_name)
  case entity.props {
    [prop] ->
      "pub type "
      <> name
      <> " {\n  "
      <> name
      <> "("
      <> prop.name
      <> ": "
      <> entity_prop_type(state, prop, app)
      <> ")\n}\n"
    props -> {
      let fields =
        props
        |> list.map(fn(prop) {
          "    "
          <> prop.name
          <> ": "
          <> entity_prop_type(state, prop, app)
          <> ",\n"
        })
        |> string.concat
      "pub type " <> name <> " {\n  " <> name <> "(\n" <> fields <> "  )\n}\n"
    }
  }
}

fn entity_prop_type(state: State, prop: model.Prop, _app: model.App) -> String {
  let base = case prop.kind {
    model.RelProp(kind: kind, target_module: module, target_type: target) ->
      relation_name(kind)
      <> "("
      <> mapped_name(state, "entity/" <> module, target)
      <> ")"
    model.ValueProp(reference) -> render_model_ref(state, reference)
    model.SumProp(reference, ..) -> render_model_ref(state, reference)
  }
  let base = case prop.kind, prop.repeated {
    model.RelProp(kind: model.Multi, ..), _ -> base
    _, True -> "List(" <> base <> ")"
    _, False -> base
  }
  case prop.optional {
    True -> "Option(" <> base <> ")"
    False -> base
  }
}

fn custom_text(state: State, declaration: CustomDecl) -> String {
  let CustomDecl(scope: scope, definition: definition) = declaration
  let name = mapped_name(state, scope.module, definition.name)
  case
    list.contains(state.enum_aliases, scope.module <> ":" <> definition.name)
  {
    True -> "pub type " <> name <> " = String\n"
    False -> custom_definition_text(state, scope, definition, name)
  }
}

fn custom_definition_text(
  state: State,
  scope: Scope,
  definition: glance.CustomType,
  name: String,
) -> String {
  case definition.variants {
    [] -> "pub type " <> name <> type_parameters(definition.parameters) <> "\n"
    variants ->
      "pub type "
      <> name
      <> type_parameters(definition.parameters)
      <> " {\n"
      <> string.join(
        list.map(variants, fn(variant) {
          variant_text(state, scope, variant, definition.name)
        }),
        "\n",
      )
      <> "\n}\n"
  }
}

fn variant_text(
  state: State,
  scope: Scope,
  variant: glance.Variant,
  type_name: String,
) -> String {
  let name = case type_name, entity_type_name(state, variant.name) {
    "Row", Some(_) -> variant.name <> "Row"
    _, _ -> mapped_constructor(state, scope.module, type_name, variant.name)
  }
  case variant.fields {
    [] -> "  " <> name
    fields ->
      case list.length(fields) <= 1 {
        True ->
          "  "
          <> name
          <> "("
          <> string.join(
            list.map(fields, fn(field) {
              render_variant_field(state, scope, field)
            }),
            ", ",
          )
          <> ")"
        False ->
          "  "
          <> name
          <> "(\n"
          <> string.concat(
            list.map(fields, fn(field) {
              "    " <> render_variant_field(state, scope, field) <> ",\n"
            }),
          )
          <> "  )"
      }
  }
}

fn render_variant_field(
  state: State,
  scope: Scope,
  field: glance.VariantField,
) -> String {
  case field {
    glance.LabelledVariantField(label: label, item: item) ->
      label <> ": " <> render_gl_type(state, scope, item)
    glance.UnlabelledVariantField(item: item) ->
      render_gl_type(state, scope, item)
  }
}

fn out_alias_text(state: State, alias: OutAlias) -> String {
  let OutAlias(scope: scope, type_: type_) = alias
  "pub type Out = " <> render_gl_type(state, scope, type_) <> "\n"
}

fn render_gl_type(state: State, scope: Scope, type_: glance.Type) -> String {
  case type_ {
    glance.NamedType(name: name, parameters: parameters, ..) ->
      case resolved_path(scope, type_) {
        Some(path) -> reference_name(state, path, name)
        None -> name
      }
      <> case parameters {
        [] -> ""
        _ ->
          "("
          <> string.join(
            list.map(parameters, fn(item) { render_gl_type(state, scope, item) }),
            ", ",
          )
          <> ")"
      }
    glance.TupleType(elements: elements, ..) ->
      "#("
      <> string.join(
        list.map(elements, fn(item) { render_gl_type(state, scope, item) }),
        ", ",
      )
      <> ")"
    glance.FunctionType(parameters: parameters, return: return_type, ..) ->
      "fn("
      <> string.join(
        list.map(parameters, fn(item) { render_gl_type(state, scope, item) }),
        ", ",
      )
      <> ") -> "
      <> render_gl_type(state, scope, return_type)
    glance.VariableType(name: name, ..) -> name
    glance.HoleType(..) -> "_"
  }
}

fn render_model_ref(state: State, reference: model.TypeRef) -> String {
  let name = case reference.module {
    Some(path) -> reference_name(state, path, reference.name)
    None -> reference.name
  }
  name
  <> case reference.parameters {
    [] -> ""
    _ ->
      "("
      <> string.join(
        list.map(reference.parameters, fn(parameter) {
          render_model_shape(state, parameter)
        }),
        ", ",
      )
      <> ")"
  }
}

fn render_model_shape(state: State, shape: model.TypeShape) -> String {
  case shape {
    model.NamedShape(module: module, name: name, parameters: parameters) ->
      case module {
        Some(path) -> reference_name(state, path, name)
        None -> name
      }
      <> case parameters {
        [] -> ""
        _ ->
          "("
          <> string.join(
            list.map(parameters, fn(parameter) {
              render_model_shape(state, parameter)
            }),
            ", ",
          )
          <> ")"
      }
    model.TupleShape(items) ->
      "#("
      <> string.join(
        list.map(items, fn(item) { render_model_shape(state, item) }),
        ", ",
      )
      <> ")"
  }
}

fn relation_type(state: State, name: String) -> State {
  case is_relation_type(name) {
    True ->
      case list.contains(["Has", "Held", "Multi"], name) {
        True -> add_opaque(state, name)
        False -> add_import(state, "framework/er", name)
      }
    False -> state
  }
}

fn relation_name(kind: model.RelKind) -> String {
  case kind {
    model.Has -> "Has"
    model.Held -> "Held"
    model.Link -> "Link"
    model.Multi -> "Multi"
  }
}

fn is_relation_type(name: String) -> Bool {
  list.contains(["Key", "Has", "Held", "Link", "Multi"], name)
}

fn type_name(type_: glance.Type) -> String {
  case type_ {
    glance.NamedType(name: name, ..) -> name
    _ -> ""
  }
}

fn reference_name(state: State, path: String, name: String) -> String {
  case list.contains(state.enum_aliases, path <> ":" <> name) {
    True -> "String"
    False -> mapped_name(state, path, name)
  }
}

fn resolved_path(scope: Scope, type_: glance.Type) -> Option(String) {
  case type_ {
    glance.NamedType(name: name, module: module, ..) ->
      case module {
        Some(local) -> import_module(scope.imports, local)
        None ->
          case unqualified_module(scope.imports, name) {
            Some(path) -> Some(path)
            None ->
              case local_type(scope, name) {
                True -> Some(scope.module)
                False -> None
              }
          }
      }
    _ -> None
  }
}

fn local_type(_scope: Scope, name: String) -> Bool {
  // An unqualified name not imported is a type declared in the current
  // service/entity module, or a built-in. Both are intentionally local.
  name == "List"
  || list.contains(["Bool", "Float", "Int", "String"], name)
  || name != ""
}

fn import_module(
  imports: List(glance.Definition(glance.Import)),
  local: String,
) -> Option(String) {
  case
    list.find(imports, fn(definition) {
      let import_ = definition.definition
      case import_.alias {
        Some(glance.Named(name)) -> name == local
        Some(glance.Discarded(name)) -> name == local
        None -> last_segment(import_.module) == local
      }
    })
  {
    Ok(definition) -> Some(definition.definition.module)
    Error(_) -> None
  }
}

fn unqualified_module(
  imports: List(glance.Definition(glance.Import)),
  name: String,
) -> Option(String) {
  case
    list.find(imports, fn(definition) {
      list.any(definition.definition.unqualified_types, fn(entry) {
        case entry.alias {
          Some(alias) -> alias == name
          None -> entry.name == name
        }
      })
    })
  {
    Ok(definition) -> Some(definition.definition.module)
    Error(_) -> None
  }
}

fn last_segment(path: String) -> String {
  case list.last(string.split(path, "/")) {
    Ok(value) -> value
    Error(_) -> path
  }
}

fn add_import(state: State, path: String, name: String) -> State {
  case list.contains(state.imports, #(path, name)) {
    True -> state
    False ->
      State(..state, imports: list.append(state.imports, [#(path, name)]))
  }
}

fn reserve_type(state: State, path: String, name: String) -> #(State, String) {
  let key = path <> ":" <> name
  case list.find(state.names, fn(item) { item.0 == key }) {
    Ok(item) -> #(state, item.1)
    Error(_) -> {
      let collision = list.find(state.names, fn(item) { item.1 == name })
      let state = case collision {
        Error(_) -> state
        Ok(existing) -> {
          let old_path = key_path(existing.0)
          let replacement = fresh_type_name(state, old_path, name)
          State(
            ..state,
            names: list.map(state.names, fn(item) {
              case item.0 == existing.0 {
                True -> #(item.0, replacement)
                False -> item
              }
            }),
          )
        }
      }
      let emitted = case collision {
        Ok(_) -> fresh_type_name(state, path, name)
        Error(_) -> name
      }
      #(
        State(..state, names: list.append(state.names, [#(key, emitted)])),
        emitted,
      )
    }
  }
}

fn fresh_type_name(state: State, path: String, name: String) -> String {
  let candidate = naming.pascal(last_segment(path)) <> name
  case list.any(state.names, fn(item) { item.1 == candidate }) {
    False -> candidate
    True -> fresh_type_suffix(state, candidate, 2)
  }
}

fn fresh_type_suffix(state: State, base: String, number: Int) -> String {
  let candidate = base <> int.to_string(number)
  case list.any(state.names, fn(item) { item.1 == candidate }) {
    True -> fresh_type_suffix(state, base, number + 1)
    False -> candidate
  }
}

fn mapped_name(state: State, path: String, name: String) -> String {
  case list.find(state.names, fn(item) { item.0 == path <> ":" <> name }) {
    Ok(item) -> item.1
    Error(_) -> name
  }
}

fn key_path(key: String) -> String {
  let parts = string.split(key, ":")
  case list.length(parts) {
    0 | 1 -> key
    length -> parts |> list.take(length - 1) |> string.join(":")
  }
}

fn opaque_path(name: String) -> String {
  case name {
    "Has" | "Held" | "Key" | "Link" | "Multi" -> "framework/er"
    "Date" | "Datetime" | "Time" -> "framework/time"
    "Blob" -> "framework/blob"
    _ -> "framework"
  }
}

fn allowed_import(path: String) -> Bool {
  string.starts_with(path, "gleam/")
  || string.starts_with(path, "framework/")
  || path == "gen/service"
}

fn add_opaque(state: State, name: String) -> State {
  case list.contains(state.opaque_names, name) {
    True -> state
    False -> {
      let path = opaque_path(name)
      let #(state, _) = reserve_type(state, path, name)
      State(..state, opaque_names: list.append(state.opaque_names, [name]))
    }
  }
}

fn type_parameters(parameters: List(String)) -> String {
  case parameters {
    [] -> ""
    _ -> "(" <> string.join(parameters, ", ") <> ")"
  }
}

fn without(values: List(String), value: String) -> List(String) {
  list.filter(values, fn(item) { item != value })
}
