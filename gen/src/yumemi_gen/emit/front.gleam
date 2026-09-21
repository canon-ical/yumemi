//// 面の束 ── route / blocks / widgets / API / Service / Out の写し。
//// 面側へ back の module を再輸出せず、面 package が単独で型を持てる形にする。

import glance
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/string
import yumemi_gen/digest
import yumemi_gen/emit/entry
import yumemi_gen/emit/hash
import yumemi_gen/emit/types.{type File, File}
import yumemi_gen/face
import yumemi_gen/glance_util as g
import yumemi_gen/model
import yumemi_gen/naming
import yumemi_gen/reader/front as reader_front
import yumemi_gen/source.{type Unit}

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
      out_file(app, back_units, service, hashes, face_name)
    })
  list.append(files, out_files)
}

fn source_hash(units: List(Unit), keep: fn(Unit) -> Bool) -> String {
  units
  |> list.filter(keep)
  |> list.sort(fn(left, right) { string.compare(left.path, right.path) })
  |> list.map(fn(unit) { unit.path <> "\n" <> unit.text })
  |> string.join("\n")
  |> digest.short
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
            True -> Ok(ApiRoute(service: service, method: method, path: path))
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

// ── Out の写し ──────────────────────────────────────────────────────────────

type Scope {
  Scope(module: String, imports: List(glance.Definition(glance.Import)))
}

type CustomDecl {
  CustomDecl(scope: Scope, definition: glance.CustomType)
}

type AliasDecl {
  SourceAlias(scope: Scope, definition: glance.TypeAlias)
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
  let output = output_type(units, service_path)
  let state = case output {
    Some(type_) -> collect_gl_type(empty_state(), app, units, scope, type_)
    None -> empty_state()
  }
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
        "framework/time" ->
          case is_time_type(name) {
            True -> add_opaque(state, name)
            False -> add_import(state, path, name)
          }
        "framework/blob" ->
          case name == "Blob" {
            True -> add_opaque(state, name)
            False -> add_import(state, path, name)
          }
        _ ->
          case string.starts_with(path, "gen/types/") {
            True -> ensure_value_alias(state, app, path, name)
            False ->
              case string.starts_with(path, "entity/") {
                True ->
                  collect_entity_or_custom(state, app, units, scope, path, name)
                False ->
                  case string.starts_with(path, "service/") {
                    True -> ensure_named(state, app, units, path, name)
                    False -> {
                      let state = add_import(state, path, name)
                      list.fold(parameters, state, fn(acc, parameter) {
                        collect_gl_type(acc, app, units, scope, parameter)
                      })
                    }
                  }
              }
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
    "framework/time" ->
      case is_time_type(name) {
        True -> add_opaque(state, name)
        False -> add_import(state, path, name)
      }
    "framework/blob" ->
      case name == "Blob" {
        True -> add_opaque(state, name)
        False -> add_import(state, path, name)
      }
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
            False -> add_import(state, path, name)
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
          let state = reserve_type(state, path, name).0
          let state = State(..state, alias_work: [key, ..state.alias_work])
          let state =
            collect_gl_type(state, app, units, scope, definition.aliased)
          State(
            ..state,
            aliases: list.append(state.aliases, [SourceAlias(scope, definition)]),
            alias_work: without(state.alias_work, key),
          )
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
      ValueAlias(path: path, source_name: source_name, ..) ->
        key == path <> ":" <> source_name
    }
  })
}

fn has_entity(state: State, name: String) -> Bool {
  list.any(state.entities, fn(entity) { entity.type_name == name })
  || list.any(state.entity_work, fn(key) { string.ends_with(key, ":" <> name) })
}

fn declarations_text(state: State, app: model.App) -> String {
  let aliases = list.map(state.aliases, fn(alias) { alias_text(state, alias) })
  let opaque_decls =
    list.map(state.opaque_names, fn(name) {
      opaque_text(mapped_name(state, opaque_path(name), name))
    })
  let entities =
    list.map(state.entities, fn(entity) { entity_text(state, entity, app) })
  let phantoms =
    list.map(state.phantoms, fn(name) { "pub type " <> name <> "\n" })
  let entity_names =
    list.map(state.entities, fn(entity) {
      mapped_name(state, "entity/" <> entity.module, entity.type_name)
    })
  let custom =
    list.map(state.custom, fn(declaration) {
      custom_text(state, declaration, entity_names)
    })
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

fn custom_text(
  state: State,
  declaration: CustomDecl,
  conflicts: List(String),
) -> String {
  let CustomDecl(scope: scope, definition: definition) = declaration
  let name = mapped_name(state, scope.module, definition.name)
  case definition.variants {
    [] -> "pub type " <> name <> type_parameters(definition.parameters) <> "\n"
    variants ->
      "pub type "
      <> name
      <> type_parameters(definition.parameters)
      <> " {\n"
      <> string.join(
        list.map(variants, fn(variant) {
          variant_text(state, scope, variant, conflicts, definition.name, name)
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
  conflicts: List(String),
  type_name: String,
  emitted_type_name: String,
) -> String {
  let name = case variant.name == type_name {
    True -> emitted_type_name
    False ->
      case list.contains(conflicts, variant.name) {
        True -> variant.name <> "Row"
        False -> variant.name
      }
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
        Some(path) -> mapped_name(state, path, name)
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
    Some(path) -> mapped_name(state, path, reference.name)
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
        Some(path) -> mapped_name(state, path, name)
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

fn is_time_type(name: String) -> Bool {
  list.contains(["Date", "Datetime", "Time"], name)
}

fn type_name(type_: glance.Type) -> String {
  case type_ {
    glance.NamedType(name: name, ..) -> name
    _ -> ""
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
