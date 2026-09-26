//// 面の束 ── route / blocks / widgets / API / Service / Out の写し。
//// 面側へ back の module を再輸出せず、面 package が単独で型を持てる形にする。

import framework/front as framework_front
import framework/front/css as framework_css
import framework/front/track as framework_track
import glance
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import gleam/string
import yumemi_gen/digest
import yumemi_gen/emit/accepted
import yumemi_gen/emit/draft
import yumemi_gen/emit/entry
import yumemi_gen/emit/gate as gate_emit
import yumemi_gen/emit/hash
import yumemi_gen/emit/types.{type File, File}
import yumemi_gen/face
import yumemi_gen/glance_util as g
import yumemi_gen/model
import yumemi_gen/naming
import yumemi_gen/reader/front as reader_front
import yumemi_gen/reader/gate as reader_gate
import yumemi_gen/source.{type Unit, Unit}
import yumemi_gen/stop

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
  let service_hash =
    source_hash(back_units, fn(unit) {
      string.starts_with(unit.path, "service/")
    })
  let type_units = back_type_units(app, back_units, hashes)
  let live = live_targets(model_.components, app.services)
  let attached_service_live = attached_service_live_targets(model_, app, live)
  let blob_entries = blob_entry_targets(model_.components, app.attached)
  let live_decoder_services =
    list.append(live, attached_service_live)
    |> list.flat_map(fn(target) {
      let #(service, component) = target
      let given =
        component.reloads
        |> list.first
        |> option.from_result
        |> option.then(fn(reload) { service_for(app.services, reload.1) })
      [service.module]
      |> list.append(case given {
        Some(value) -> [value.module]
        None -> []
      })
    })
    |> list.unique
  let page_decoder_services =
    model_.pages
    |> list.flat_map(fn(page) {
      list.append(
        layout_sources(model_.layout, model_.blocks, app.services),
        page_sources(app, type_units, page, model_.blocks, app.services),
      )
      |> list.filter_map(fn(source) {
        case source.type_name == "Out" {
          True -> Ok(source.service)
          False -> Error(Nil)
        }
      })
    })
  let decoder_services =
    list.append(live_decoder_services, page_decoder_services)
    |> list.unique
  let preview_blocks = referenced_blocks(model_)
  let skeleton_files =
    list.map(preview_blocks, fn(block) {
      skeleton_file(app, type_units, package, block)
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
      path: face_name <> "/src/gen/service.gleam",
      text: service_text(face_name, app.services, service_hash),
    ),
    File(
      path: face_name <> "/src/gen/api.gleam",
      text: api_text(face_name, app, hashes, model_),
    ),
    File(
      path: face_name <> "/src/gen/shell.mjs",
      text: shell_text(app, type_units, package, model_, hashes),
    ),
    gate_file(app, back_units, package, model_, hashes),
    File(
      path: face_name <> "/src/gen/blocks_preview.gleam",
      text: blocks_preview_text(
        app,
        type_units,
        package,
        model_,
        hashes,
        preview_blocks,
      ),
    ),
    File(
      path: face_name <> "/priv/static/_yumemi/style.css",
      text: style_text(package, model_),
    ),
  ]
  let out_files =
    app.services
    |> list.sort(fn(left, right) { string.compare(left.module, right.module) })
    |> list.map(fn(service) {
      out_file(
        app,
        type_units,
        service,
        hashes,
        face_name,
        list.contains(decoder_services, service.module),
      )
    })
  let live_files =
    live
    |> list.map(fn(target) {
      let #(service, component) = target
      live_file(app, back_units, package, service, component, hashes, face_name)
    })
  let attached_service_files =
    attached_service_live
    |> list.map(fn(target) {
      let #(service, component) = target
      attached_service_live_file(
        app,
        back_units,
        package,
        service,
        component,
        hashes,
        face_name,
      )
    })
  let attached_live =
    attached_live_targets(model_, app)
    |> list.map(fn(target) {
      let #(route, component) = target
      attached_live_file(app, route, package, component, hashes, face_name)
    })
  let blob_entry_files =
    blob_entries
    |> list.map(fn(target) {
      let #(route, _component) = target
      File(
        path: face_name
          <> "/src/gen/live/"
          <> naming.snake(route.name)
          <> ".gleam",
        text: blob_entry_live_text(route, hashes),
      )
    })
  let all_live_files =
    list.append(
      live_files,
      list.append(
        attached_service_files,
        list.append(attached_live, blob_entry_files),
      ),
    )
  let island_files = case all_live_files {
    [] -> []
    _ -> [
      File(
        path: face_name <> "/src/gen/live/transport_ffi.mjs",
        text: transport_text(face_name, model_, hashes),
      ),
      File(
        path: face_name <> "/priv/static/_yumemi/client.mjs",
        text: client_text(
          face_name,
          model_,
          package.units,
          app,
          hashes,
          navigable_routes(app, back_units, package, model_),
        ),
      ),
    ]
  }
  let load_files =
    list.append(
      [load_layout_file(app, package, model_)],
      list.map(model_.pages, fn(page) {
        load_page_file(app, type_units, package, model_, page)
      }),
    )
  list.append(
    list.append(
      files,
      list.append(out_files, list.append(all_live_files, island_files)),
    ),
    load_files,
  )
  |> list.append(skeleton_files)
}

fn source_hash(units: List(Unit), keep: fn(Unit) -> Bool) -> String {
  units
  |> list.filter(keep)
  |> list.sort(fn(left, right) { string.compare(left.path, right.path) })
  |> list.map(fn(unit) { unit.path <> "\n" <> unit.text })
  |> string.join("\n")
  |> digest.short
}

fn referenced_blocks(front: reader_front.Front) -> List(reader_front.Block) {
  let layout_names =
    list.append(
      frame_block_names(front.layout.sp),
      list.append(
        frame_block_names(front.layout.pc),
        frame_block_names(front.layout.tablet),
      ),
    )
  let page_names =
    front.pages
    |> list.flat_map(fn(page) {
      list.append(
        frame_block_names(page.sp),
        list.append(frame_block_names(page.pc), frame_block_names(page.tablet)),
      )
    })
  let names =
    list.append(layout_names, page_names)
    |> list.unique
    |> list.sort(string.compare)
  front.blocks
  |> list.filter(fn(block) { list.contains(names, block.name) })
  |> list.sort(fn(left, right) { string.compare(left.name, right.name) })
}

fn frame_block_names(frame: Option(reader_front.Frame)) -> List(String) {
  case frame {
    Some(value) ->
      value.placements
      |> list.flat_map(fn(placement) {
        case placement {
          reader_front.Fixed(block: block, ..) -> [block]
          reader_front.Widget(render: render, ..) -> render_block_names(render)
        }
      })
    None -> []
  }
}

fn render_block_names(render: reader_front.Render) -> List(String) {
  case render {
    reader_front.One(block) -> [block]
    reader_front.ByKind(table: table, ..) -> list.map(table, fn(row) { row.1 })
    reader_front.UnknownRender -> []
  }
}

fn skeleton_file(
  _app: model.App,
  units: List(Unit),
  package: face.Package,
  block: reader_front.Block,
) -> File {
  let service = block_service_module(block)
  let fields = case service {
    Some(name) -> output_fields(units, name)
    None -> []
  }
  let imports =
    list.append(
      [
        "import framework/front/el",
        "import sketch/lustre/element/html",
      ],
      case service {
        Some(name) -> ["import gen/out/" <> name]
        None -> []
      },
    )
  let imports = case fields {
    [] -> imports
    _ -> list.append(imports, ["import gleam/string"])
  }
  let in_type = case service {
    Some(name) -> name <> ".Out"
    None -> "Nil"
  }
  let view_argument = case service {
    Some(_) -> "it"
    None -> "_it"
  }
  let children = case fields {
    [] ->
      case service {
        Some(_) -> [
          "el.text(\"value: \" <> string.inspect(" <> view_argument <> "))",
        ]
        None -> ["el.text(\"\")"]
      }
    _ ->
      list.map(fields, fn(field) {
        "el.text("
        <> quoted(field.0)
        <> " <> \": \" <> string.inspect("
        <> view_argument
        <> "."
        <> field.0
        <> "))"
      })
  }
  let body =
    header(
      package.name <> "/src/" <> block.module <> ".gleam",
      source_hash(package.units, fn(unit) { unit.path == block.module }),
    )
    <> "\n"
    <> string.join(list.sort(imports, string.compare), "\n")
    <> "\n\npub type In = "
    <> in_type
    <> "\n\npub fn view("
    <> view_argument
    <> ": In) -> el.Element(Nil) {\n  html.div_([], [\n"
    <> string.concat(list.map(children, fn(child) { "    " <> child <> ",\n" }))
    <> "  ])\n}\n"
  File(
    path: package.name
      <> "/src/gen/skeleton/"
      <> last_segment(block.module)
      <> ".gleam",
    text: body,
  )
}

fn block_service_module(block: reader_front.Block) -> Option(String) {
  case block.input_module {
    Some(path) ->
      case
        string.starts_with(path, "gen/out/")
        || string.starts_with(path, "service/")
      {
        True -> Some(string.drop_start(path, 8))
        False -> None
      }
    None -> None
  }
}

fn default_block_input_expression(
  app: model.App,
  units: List(Unit),
  block: reader_front.Block,
) -> String {
  let block_module =
    block_module_reference(block.module, service_module_names(app.services))
  case block.input_definition {
    Some(definition) ->
      case definition.variants {
        [variant, ..] ->
          block_module
          <> "."
          <> variant.name
          <> default_block_variant_arguments(app, units, block, variant.fields)
        [] -> default_block_input_alias_expression(app, units, block)
      }
    None -> default_block_input_alias_expression(app, units, block)
  }
}

fn default_block_input_alias_expression(
  app: model.App,
  units: List(Unit),
  block: reader_front.Block,
) -> String {
  case block.input {
    Some("Nil") -> "Nil"
    Some("String") -> quoted("value")
    Some("Int") -> "0"
    Some("Bool") -> "False"
    Some("Float") -> "0.0"
    Some("Out") ->
      case block_service_module(block) {
        Some(service) -> default_output_expression(app, units, service)
        None -> "Nil"
      }
    Some(_) ->
      case block_service_module(block) {
        Some(service) -> default_block_expression(app, units, service, block)
        None -> "Nil"
      }
    None ->
      case block_service_module(block) {
        Some(service) -> default_output_expression(app, units, service)
        None -> "Nil"
      }
  }
}

fn default_block_variant_arguments(
  app: model.App,
  units: List(Unit),
  block: reader_front.Block,
  fields: List(glance.VariantField),
) -> String {
  case fields {
    [] -> ""
    _ -> {
      let scope = Scope(module: block.module, imports: block.input_imports)
      "("
      <> string.join(
        list.map(fields, fn(field) {
          case field {
            glance.LabelledVariantField(label: label, item: item) ->
              label
              <> ": "
              <> default_block_type_expression(
                app,
                units,
                block,
                scope,
                item,
                label,
              )
            glance.UnlabelledVariantField(item) ->
              default_block_type_expression(
                app,
                units,
                block,
                scope,
                item,
                "value",
              )
          }
        }),
        ", ",
      )
      <> ")"
    }
  }
}

fn default_block_type_expression(
  app: model.App,
  units: List(Unit),
  block: reader_front.Block,
  scope: Scope,
  type_: glance.Type,
  field_name: String,
) -> String {
  let block_module =
    block_module_reference(block.module, service_module_names(app.services))
  case type_ {
    glance.NamedType(name: name, parameters: parameters, ..) ->
      case name, parameters {
        "String", [] -> quoted(field_name)
        "Int", [] -> "0"
        "Bool", [] -> "False"
        "Float", [] -> "0.0"
        "Option", [_] -> "None"
        "List", [item] ->
          "["
          <> string.join(
            list.map([1, 2, 3], fn(_) {
              default_block_type_expression(
                app,
                units,
                block,
                scope,
                item,
                field_name,
              )
            }),
            ", ",
          )
          <> "]"
        "Page", [item] ->
          "framework_page.Page(items: ["
          <> string.join(
            list.map([1, 2, 3], fn(_) {
              default_block_type_expression(
                app,
                units,
                block,
                scope,
                item,
                field_name,
              )
            }),
            ", ",
          )
          <> "], next: None)"
        _, _ ->
          case resolved_path(scope, type_) {
            Some(path) if path == block.module ->
              case g.find_custom_type(block.source, name) {
                Some(definition) ->
                  case definition.variants {
                    [variant, ..] ->
                      block_module
                      <> "."
                      <> mapped_constructor(
                        empty_state(),
                        block.module,
                        definition.name,
                        variant.name,
                      )
                      <> default_block_variant_arguments(
                        app,
                        units,
                        block,
                        variant.fields,
                      )
                    [] -> "Nil"
                  }
                None ->
                  default_type_expression(
                    app,
                    units,
                    empty_state(),
                    scope,
                    block_module,
                    type_,
                    field_name,
                  )
              }
            _ ->
              default_type_expression(
                app,
                units,
                empty_state(),
                scope,
                block_module,
                type_,
                field_name,
              )
          }
      }
    glance.TupleType(elements: elements, ..) ->
      "#("
      <> string.join(
        list.map(elements, fn(element) {
          default_block_type_expression(
            app,
            units,
            block,
            scope,
            element,
            field_name,
          )
        }),
        ", ",
      )
      <> ")"
    _ -> "Nil"
  }
}

fn preview_input_imports(blocks: List(reader_front.Block)) -> List(String) {
  blocks
  |> list.flat_map(fn(block) {
    case block.input_definition {
      Some(definition) -> {
        let scope = Scope(module: block.module, imports: block.input_imports)
        definition.variants
        |> list.flat_map(fn(variant) {
          variant.fields
          |> list.flat_map(fn(field) {
            case field {
              glance.LabelledVariantField(item: item, ..) ->
                preview_type_imports(scope, item)
              glance.UnlabelledVariantField(item) ->
                preview_type_imports(scope, item)
            }
          })
        })
      }
      None -> []
    }
  })
  |> list.unique
}

fn preview_type_imports(scope: Scope, type_: glance.Type) -> List(String) {
  case type_ {
    glance.NamedType(parameters: parameters, ..) -> {
      let imported = case resolved_path(scope, type_) {
        Some(path) ->
          case string.starts_with(path, "gen/out/") {
            True -> [path]
            False -> []
          }
        None -> []
      }
      list.append(
        imported,
        list.flat_map(parameters, fn(parameter) {
          preview_type_imports(scope, parameter)
        }),
      )
    }
    glance.TupleType(elements: elements, ..) ->
      list.flat_map(elements, fn(element) {
        preview_type_imports(scope, element)
      })
    _ -> []
  }
}

fn output_fields(
  units: List(Unit),
  service: String,
) -> List(#(String, glance.Type)) {
  let path = "service/" <> service
  let scope = scope_for(units, path)
  case output_type(units, path) {
    Some(type_) -> fields_for_type(units, scope, type_)
    None -> []
  }
}

fn fields_for_type(
  units: List(Unit),
  scope: Scope,
  type_: glance.Type,
) -> List(#(String, glance.Type)) {
  case type_ {
    glance.NamedType(..) ->
      case resolved_path(scope, type_) {
        Some(path) ->
          case unit_for(units, path) {
            Some(unit) ->
              case
                g.find_custom_type(g.in_order(unit.module), type_name(type_))
              {
                Some(definition) ->
                  case definition.variants {
                    [variant, ..] ->
                      variant.fields
                      |> list.filter_map(fn(field) {
                        case g.variant_field_label(field) {
                          Some(label) ->
                            Ok(#(label, g.variant_field_type(field)))
                          None -> Error(Nil)
                        }
                      })
                    [] -> []
                  }
                None -> []
              }
            None -> []
          }
        None -> []
      }
    _ -> []
  }
}

fn blocks_preview_text(
  app: model.App,
  units: List(Unit),
  package: face.Package,
  front: reader_front.Front,
  hashes: hash.Hashes,
  blocks: List(reader_front.Block),
) -> String {
  let frame = case front.layout.pc {
    Some(value) -> value
    None ->
      case front.layout.sp {
        Some(value) -> value
        None ->
          reader_front.Frame(
            media: "pc",
            areas: [],
            placements: [],
            cols: [],
            rows: [],
            template: [],
          )
      }
  }
  let layout_placements =
    list.append(
      frame_placements(front.layout.pc),
      list.append(
        frame_placements(front.layout.tablet),
        frame_placements(front.layout.sp),
      ),
    )
    |> list.unique
  let preview_services = service_module_names(app.services)
  let block_imports =
    list.map(blocks, fn(block) {
      "import " <> block_import_path(block.module, preview_services)
    })
  let area_children =
    frame.areas
    |> list.map(fn(area) {
      preview_area_text(area.name, layout_placements, app, units, blocks)
    })
    |> string.join(",\n    ")
  let out_imports =
    list.append(
      blocks
        |> list.filter_map(fn(block) {
          case block.has_sample, block_service_module(block) {
            False, Some(service) -> Ok("gen/out/" <> service)
            _, _ -> Error(Nil)
          }
        }),
      preview_input_imports(blocks),
    )
    |> list.unique
    |> list.map(fn(path) { "import " <> path })
  let option_imports = case string.contains(area_children, "None") {
    True -> ["import gleam/option.{None}"]
    False -> []
  }
  let time_imports =
    list.append(
      case string.contains(area_children, "default_date()") {
        True -> ["type Date", "date"]
        False -> []
      },
      list.append(
        case string.contains(area_children, "default_datetime()") {
          True -> ["type Datetime", "datetime"]
          False -> []
        },
        case string.contains(area_children, "default_time()") {
          True -> ["type Time", "time"]
          False -> []
        },
      ),
    )
    |> list.unique
  let time_import = case time_imports {
    [] -> []
    _ -> ["import framework/time.{" <> string.join(time_imports, ", ") <> "}"]
  }
  let opaque_imports =
    list.append(
      case string.contains(area_children, "default_blob()") {
        True -> ["import framework/blob.{type Blob, parse as parse_blob}"]
        False -> []
      },
      list.append(
        case string.contains(area_children, "default_party_id()") {
          True -> [
            "import framework/party.{type PartyId, parse as parse_party}",
          ]
          False -> []
        },
        list.append(
          time_import,
          case string.contains(area_children, "er.key(") {
            True -> ["import framework/er as er"]
            False -> []
          },
        ),
      ),
    )
  let page_imports = case
    string.contains(area_children, "framework_page.Page(")
  {
    True -> ["import framework/page as framework_page"]
    False -> []
  }
  let body_imports =
    list.append(
      [
        "import framework/front/el",
        "import lustre/attribute",
        "import lustre/element/html as raw_html",
        "import sketch/lustre as sketch_lustre",
        "import sketch/lustre/element",
        "import sketch/lustre/element/html",
      ],
      list.append(
        block_imports,
        list.append(
          out_imports,
          list.append(option_imports, list.append(opaque_imports, page_imports)),
        ),
      ),
    )
  let input_hash =
    digest.short(
      hash.entry(hashes)
      <> source_hash(package.units, fn(unit) {
        unit.path == "layout"
        || string.starts_with(unit.path, "pages/")
        || string.starts_with(unit.path, "blocks/")
      }),
    )
  let default_helpers =
    case string.contains(area_children, "default_blob()") {
      True ->
        "\nfn default_blob() -> Blob {\n"
        <> "  let assert Ok(value) = parse_blob(\"placeholder\")\n"
        <> "  value\n}\n"
      False -> ""
    }
    <> case string.contains(area_children, "default_time()") {
      True ->
        "\nfn default_time() -> Time {\n"
        <> "  let assert Ok(value) = time(\"00:00\")\n"
        <> "  value\n}\n"
      False -> ""
    }
    <> case string.contains(area_children, "default_date()") {
      True ->
        "\nfn default_date() -> Date {\n"
        <> "  let assert Ok(value) = date(\"2026-01-01\")\n"
        <> "  value\n}\n"
      False -> ""
    }
    <> case string.contains(area_children, "default_datetime()") {
      True ->
        "\nfn default_datetime() -> Datetime {\n"
        <> "  let assert Ok(value) = datetime(\"2026-01-01T00:00:00Z\")\n"
        <> "  value\n}\n"
      False -> ""
    }
    <> case string.contains(area_children, "default_party_id()") {
      True ->
        "\nfn default_party_id() -> PartyId {\n"
        <> "  let assert Ok(value) = parse_party(\"placeholder\")\n"
        <> "  value\n}\n"
      False -> ""
    }
  header(
    package.name <> "/src/{layout.gleam,pages/**/page.gleam,blocks/*.gleam}",
    input_hash,
  )
  <> "\n"
  <> string.join(list.sort(body_imports, string.compare), "\n")
  <> default_helpers
  <> "\npub fn view() -> element.Element(Nil) {\n"
  <> "  html.div_([attribute.attribute(\"data-yumemi-blocks-preview\", \"pc\")], [\n"
  <> "    "
  <> area_children
  <> "\n  ])\n}\n\n"
  <> "pub fn render() -> element.Element(Nil) {\n"
  <> "  let assert Ok(stylesheet) =\n"
  <> "    sketch_lustre.construct(fn(stylesheet) { stylesheet })\n"
  <> "  let output =\n"
  <> "    sketch_lustre.render(stylesheet, in: [sketch_lustre.node()], after: fn() { view() })\n"
  <> "  let assert Ok(_) = sketch_lustre.teardown(stylesheet)\n"
  <> "  raw_html.html([], [\n"
  <> "    raw_html.head([], []),\n"
  <> "    raw_html.body([], [output]),\n"
  <> "  ])\n}\n"
}

fn preview_area_text(
  name: String,
  layout_placements: List(reader_front.Placement),
  app: model.App,
  units: List(Unit),
  blocks: List(reader_front.Block),
) -> String {
  let children = case name {
    "page" ->
      list.map(blocks, fn(block) { preview_block_text(app, units, block) })
    _ -> {
      let placed =
        preview_layout_blocks(name, layout_placements, app, units, blocks)
      case placed {
        [] -> ["el.text(" <> quoted(name) <> ")"]
        _ -> placed
      }
    }
  }
  let children_text =
    "[\n"
    <> string.concat(
      list.map(children, fn(child) { "      " <> child <> ",\n" }),
    )
    <> "    ]"
  let attributes =
    "[attribute.attribute(\"data-yumemi-area\", " <> quoted(name) <> ")]"
  case name {
    "header" -> "html.header_(" <> attributes <> ", " <> children_text <> ")"
    "nav" -> "html.nav_(" <> attributes <> ", " <> children_text <> ")"
    "footer" -> "html.footer_(" <> attributes <> ", " <> children_text <> ")"
    _ -> "html.div_(" <> attributes <> ", " <> children_text <> ")"
  }
}

fn frame_placements(
  frame: Option(reader_front.Frame),
) -> List(reader_front.Placement) {
  case frame {
    Some(value) -> value.placements
    None -> []
  }
}

fn preview_layout_blocks(
  area: String,
  placements: List(reader_front.Placement),
  app: model.App,
  units: List(Unit),
  blocks: List(reader_front.Block),
) -> List(String) {
  let names =
    placements
    |> list.flat_map(fn(placement) {
      case placement {
        reader_front.Fixed(area: placement_area, block: block, ..) ->
          case placement_area == area {
            True -> [block]
            False -> []
          }
        reader_front.Widget(area: placement_area, render: render, ..) ->
          case placement_area == area {
            True -> render_block_names(render)
            False -> []
          }
      }
    })
    |> list.unique
  names
  |> list.filter_map(fn(name) {
    case list.find(blocks, fn(block) { block.name == name }) {
      Ok(block) -> Ok(preview_block_text(app, units, block))
      Error(_) -> Error(Nil)
    }
  })
}

fn preview_block_text(
  app: model.App,
  units: List(Unit),
  block: reader_front.Block,
) -> String {
  let module =
    block_module_reference(block.module, service_module_names(app.services))
  let service = block_service_module(block)
  let service_label = case service {
    Some(name) -> naming.pascal(name)
    None -> "Nil"
  }
  let out_label = case service {
    Some(name) -> name <> ".Out"
    None -> "Nil"
  }
  let value = case block.has_sample {
    True -> module <> ".sample"
    False -> default_block_input_expression(app, units, block)
  }
  let arg = preview_block_arg(module, block)
  "html.div_([], [\n"
  <> "        el.text("
  <> quoted(block.module <> " | of " <> service_label <> " | " <> out_label)
  <> "),\n"
  <> "        "
  <> module
  <> ".view("
  <> value
  <> arg
  <> "),\n"
  <> "      ])"
}

fn preview_block_arg(module: String, block: reader_front.Block) -> String {
  case block.view_arity {
    2 -> {
      let fields =
        block.args
        |> list.map(fn(arg) {
          let value = case arg.type_ {
            reader_front.StringArg -> quoted("preview")
            reader_front.OptionalStringArg -> "None"
            reader_front.OtherArg(_) -> "Nil"
          }
          arg.name <> ": " <> value
        })
      ", " <> module <> ".Arg(" <> string.join(fields, ", ") <> ")"
    }
    _ -> ""
  }
}

fn default_block_expression(
  app: model.App,
  units: List(Unit),
  service: String,
  block: reader_front.Block,
) -> String {
  let path = "service/" <> service
  let scope = scope_for(units, path)
  let state = out_state(app, units, path).0
  case block.input {
    Some("Nil") -> "Nil"
    Some(name) ->
      case unit_for(units, path) {
        Some(unit) ->
          case g.find_custom_type(g.in_order(unit.module), name) {
            Some(definition) ->
              case definition.variants {
                [variant, ..] ->
                  service
                  <> "."
                  <> mapped_constructor(state, path, name, variant.name)
                  <> default_variant_arguments(
                    app,
                    units,
                    state,
                    scope,
                    service,
                    variant.fields,
                    "value",
                  )
                [] -> "Nil"
              }
            None -> default_output_expression(app, units, service)
          }
        None -> default_output_expression(app, units, service)
      }
    None -> default_output_expression(app, units, service)
  }
}

fn default_output_expression(
  app: model.App,
  units: List(Unit),
  service: String,
) -> String {
  let path = "service/" <> service
  let scope = scope_for(units, path)
  let state = out_state(app, units, path).0
  case output_type(units, path) {
    Some(type_) ->
      default_type_expression(app, units, state, scope, service, type_, "value")
    None -> "Nil"
  }
}

fn default_type_expression(
  app: model.App,
  units: List(Unit),
  state: State,
  scope: Scope,
  output_module: String,
  type_: glance.Type,
  field_name: String,
) -> String {
  case type_ {
    glance.NamedType(name: name, parameters: parameters, ..) ->
      case name, parameters {
        "String", [] -> quoted(field_name)
        "Int", [] -> "0"
        "Bool", [] -> "False"
        "Float", [] -> "0.0"
        "Option", [_] -> "None"
        "Page", [inner] ->
          "framework_page.Page(items: ["
          <> string.join(
            list.map([1, 2, 3], fn(_) {
              default_type_expression(
                app,
                units,
                state,
                scope,
                output_module,
                inner,
                field_name,
              )
            }),
            ", ",
          )
          <> "], next: None)"
        "List", [inner] ->
          "["
          <> string.join(
            list.map([1, 2, 3], fn(_) {
              default_type_expression(
                app,
                units,
                state,
                scope,
                output_module,
                inner,
                field_name,
              )
            }),
            ", ",
          )
          <> "]"
        _, _ ->
          default_custom_expression(
            app,
            units,
            state,
            scope,
            output_module,
            type_,
            field_name,
          )
      }
    glance.TupleType(elements: elements, ..) ->
      "#("
      <> string.join(
        list.map(elements, fn(element) {
          default_type_expression(
            app,
            units,
            state,
            scope,
            output_module,
            element,
            field_name,
          )
        }),
        ", ",
      )
      <> ")"
    _ -> "Nil"
  }
}

fn default_custom_expression(
  app: model.App,
  units: List(Unit),
  state: State,
  scope: Scope,
  output_module: String,
  type_: glance.Type,
  field_name: String,
) -> String {
  case resolved_path(scope, type_) {
    Some(path) ->
      case list.contains(state.enum_aliases, path <> ":" <> type_name(type_)) {
        True -> quoted(field_name)
        False ->
          case path {
            "framework/er" ->
              relation_default(output_module, type_name(type_), field_name)
            "framework/blob" -> "default_blob()"
            "framework/party" -> "default_party_id()"
            "framework/time" ->
              case type_name(type_) {
                "Date" -> "default_date()"
                "Datetime" -> "default_datetime()"
                "Time" -> "default_time()"
                _ -> default_named_value(app, type_name(type_), field_name)
              }
            _ ->
              case string.starts_with(path, "gen/out/") {
                True ->
                  default_generated_out_expression(
                    app,
                    units,
                    path,
                    type_name(type_),
                    field_name,
                  )
                False ->
                  case unit_for(units, path) {
                    Some(unit) ->
                      case
                        g.find_custom_type(
                          g.in_order(unit.module),
                          type_name(type_),
                        )
                      {
                        Some(definition) ->
                          case definition.variants {
                            [variant, ..] ->
                              output_module
                              <> "."
                              <> mapped_constructor(
                                state,
                                path,
                                type_name(type_),
                                variant.name,
                              )
                              <> default_variant_arguments(
                                app,
                                units,
                                state,
                                scope_for(units, path),
                                output_module,
                                variant.fields,
                                field_name,
                              )
                            [] -> "Nil"
                          }
                        None ->
                          default_named_value(app, type_name(type_), field_name)
                      }
                    None ->
                      default_named_value(app, type_name(type_), field_name)
                  }
              }
          }
      }
    None -> default_named_value(app, type_name(type_), field_name)
  }
}

fn default_generated_out_expression(
  app: model.App,
  units: List(Unit),
  path: String,
  name: String,
  field_name: String,
) -> String {
  let service = string.drop_start(path, 8)
  case name {
    "Out" -> default_output_expression(app, units, service)
    _ -> {
      let service_path = "service/" <> service
      let state = out_state(app, units, service_path).0
      case
        list.find(state.custom, fn(declaration) {
          let CustomDecl(scope:, definition:) = declaration
          definition.name == name
          || mapped_name(state, scope.module, definition.name) == name
        })
      {
        Ok(CustomDecl(scope: scope, definition: definition)) ->
          case definition.variants {
            [variant, ..] ->
              service
              <> "."
              <> mapped_constructor(
                state,
                scope.module,
                definition.name,
                variant.name,
              )
              <> default_variant_arguments(
                app,
                units,
                state,
                scope,
                service,
                variant.fields,
                field_name,
              )
            [] -> default_named_value(app, name, field_name)
          }
        Error(_) -> default_named_value(app, name, field_name)
      }
    }
  }
}

fn relation_default(
  output_module: String,
  name: String,
  field_name: String,
) -> String {
  case name {
    "Key" -> "er.key(" <> quoted(field_name) <> ")"
    "Link" -> "None"
    "Has" | "Held" ->
      output_module <> "." <> name <> "(value: " <> quoted(field_name) <> ")"
    "Multi" ->
      output_module
      <> ".Multi(values: ["
      <> quoted(field_name)
      <> ", "
      <> quoted(field_name)
      <> ", "
      <> quoted(field_name)
      <> "])"
    _ -> quoted(field_name)
  }
}

fn default_variant_arguments(
  app: model.App,
  units: List(Unit),
  state: State,
  scope: Scope,
  output_module: String,
  fields: List(glance.VariantField),
  field_name: String,
) -> String {
  case fields {
    [] -> ""
    _ ->
      "("
      <> string.join(
        list.map(fields, fn(field) {
          case field {
            glance.LabelledVariantField(label: label, item: item) ->
              label
              <> ": "
              <> default_type_expression(
                app,
                units,
                state,
                scope,
                output_module,
                item,
                label,
              )
            glance.UnlabelledVariantField(item) ->
              default_type_expression(
                app,
                units,
                state,
                scope,
                output_module,
                item,
                field_name,
              )
          }
        }),
        ", ",
      )
      <> ")"
  }
}

fn default_named_value(
  app: model.App,
  name: String,
  field_name: String,
) -> String {
  case model.value_type_by_name(app.value_types, name) {
    Some(value) ->
      case value.backing {
        model.IntValue -> "0"
        model.StringValue -> quoted(field_name)
      }
    None -> quoted(field_name)
  }
}

fn live_targets(
  components: List(reader_front.Component),
  services: List(model.Service),
) -> List(#(model.Service, reader_front.Component)) {
  let empty: List(#(model.Service, reader_front.Component)) = []
  components
  |> list.fold(empty, fn(targets, component) {
    component.calls
    |> list.fold(targets, fn(acc, target) {
      case target {
        reader_front.ServiceCall(variant) ->
          case service_for(services, variant) {
            Some(service) ->
              case
                list.any(acc, fn(found) { found.0.module == service.module })
              {
                True -> acc
                False -> list.append(acc, [#(service, component)])
              }
            None -> acc
          }
        reader_front.AttachedCall(_) -> acc
      }
    })
  })
  |> list.sort(fn(left, right) { string.compare(left.0.module, right.0.module) })
}

fn attached_service_live_targets(
  front: reader_front.Front,
  app: model.App,
  live: List(#(model.Service, reader_front.Component)),
) -> List(#(model.Service, reader_front.Component)) {
  let targets =
    front.components
    |> list.flat_map(fn(component) {
      component.calls
      |> list.filter_map(fn(target) {
        case target {
          reader_front.AttachedCall(name) ->
            case service_for(app.services, name) {
              Some(service) ->
                case
                  list.any(live, fn(found) { found.0.module == service.module })
                {
                  True -> Error(Nil)
                  False -> Ok(#(service, component))
                }
              None -> Error(Nil)
            }
          reader_front.ServiceCall(_) -> Error(Nil)
        }
      })
    })
  let empty: List(#(model.Service, reader_front.Component)) = []
  list.fold(targets, empty, fn(acc, target) {
    let #(service, _) = target
    case list.any(acc, fn(found) { found.0.module == service.module }) {
      True -> acc
      False -> list.append(acc, [target])
    }
  })
  |> list.sort(fn(left, right) { string.compare(left.0.module, right.0.module) })
}

fn attached_live_targets(
  front: reader_front.Front,
  app: model.App,
) -> List(#(model.AttachedRoute, reader_front.Component)) {
  let targets =
    front.components
    |> list.flat_map(fn(component) {
      component.calls
      |> list.filter_map(fn(target) {
        case target {
          reader_front.AttachedCall(name) ->
            case service_for(app.services, name) {
              Some(_) -> Error(Nil)
              None ->
                case
                  app.attached |> list.find(fn(route) { route.name == name })
                {
                  Ok(route) ->
                    case
                      route.name == "BlobCopy"
                      && route.method == "POST"
                      && route.path == "/api/blobs"
                    {
                      True -> Error(Nil)
                      False -> Ok(#(route, component))
                    }
                  Error(_) -> Error(Nil)
                }
            }
          reader_front.ServiceCall(_) -> Error(Nil)
        }
      })
    })
  let empty: List(#(model.AttachedRoute, reader_front.Component)) = []
  list.fold(targets, empty, fn(acc, target) {
    let #(route, _) = target
    case list.any(acc, fn(found) { found.0.name == route.name }) {
      True -> acc
      False -> list.append(acc, [target])
    }
  })
  |> list.sort(fn(left, right) { string.compare(left.0.name, right.0.name) })
}

fn attached_live_file(
  app: model.App,
  route: model.AttachedRoute,
  package: face.Package,
  component: reader_front.Component,
  hashes: hash.Hashes,
  face_name: String,
) -> File {
  let component_hash =
    source_hash(package.units, fn(unit) { unit.path == component.module })
  let input_hash = digest.short(hash.entry(hashes) <> component_hash)
  let module = naming.snake(route.name)
  File(
    path: face_name <> "/src/gen/live/" <> module <> ".gleam",
    text: attached_live_text(
      route,
      component,
      attached_body_fields(app, route),
      header("src/" <> component.module <> ".gleam", input_hash),
    ),
  )
}

/// attached の口が body に載せる欄(0.11.4、H6)。framework の役が本文の形を決める口だけが持つ:
/// `SwitchSubject` は `{kind, id}`(`server/http.mjs` の switch_subject が `s.args.kind` / `s.args.id` を読む)。
/// 役の無い口・本文を読まない役の口は空(body は今までどおり null)。
fn attached_body_fields(
  app: model.App,
  route: model.AttachedRoute,
) -> List(String) {
  let roles =
    app.server.attached_roles
    |> list.filter(fn(row) { row.attached == naming.snake(route.name) })
    |> list.map(fn(row) { row.role })
  case list.contains(roles, "switch_subject") {
    True -> ["kind", "id"]
    False -> []
  }
}

fn attached_live_text(
  route: model.AttachedRoute,
  component: reader_front.Component,
  fields: List(String),
  generated_header: String,
) -> String {
  let field_type = case fields {
    [] -> "pub type Field\n\n"
    _ ->
      "pub type Field {\n"
      <> string.concat(
        list.map(fields, fn(field) { "  " <> naming.pascal(field) <> "\n" }),
      )
      <> "}\n\n"
  }
  let args_type = case fields {
    [] -> "pub type Args {\n  Args\n}\n\n"
    _ ->
      "pub type Args {\n  Args("
      <> string.join(list.map(fields, fn(field) { field <> ": String" }), ", ")
      <> ")\n}\n\n"
  }
  let args_init = case fields {
    [] -> "Args"
    _ ->
      "Args("
      <> string.join(list.map(fields, fn(field) { field <> ": \"\"" }), ", ")
      <> ")"
  }
  let set_branches = case fields {
    [] -> "    live.Set(_, _) -> #(model, effect.none())\n"
    _ ->
      string.concat(
        list.map(fields, fn(field) {
          "    live.Set("
          <> naming.pascal(field)
          <> ", value) -> #(live.State(..model, args: Args(..model.args, "
          <> field
          <> ": value)), effect.none())\n"
        }),
      )
  }
  let #(request_call, request_head, body) = case fields {
    [] -> #("request()", "fn request() -> Effect(Event) {\n", "json.null()")
    _ -> #(
      "request(model.args)",
      "fn request(args: Args) -> Effect(Event) {\n",
      "json.object(["
        <> string.join(
        list.map(fields, fn(field) {
          "#(" <> quoted(field) <> ", json.string(args." <> field <> "))"
        }),
        ", ",
      )
        <> "])",
    )
  }
  let reload = component.after_send == Some("ReloadPage")
  let reload_imports = case reload {
    True -> "import lustre/event\n"
    False -> ""
  }
  generated_header
  <> "\n"
  <> "import framework/front/live\n"
  <> "import gleam/dynamic.{type Dynamic}\n"
  <> "import gleam/dynamic/decode\n"
  <> "import gleam/json\n"
  <> "import gleam/option.{None, Some}\n"
  <> "import lustre/effect.{type Effect}\n"
  <> reload_imports
  <> "\n"
  <> field_type
  <> args_type
  <> "pub type Error\n\n"
  <> "pub type Failure {\n  Refused(Error)\n  Broke(String)\n}\n\n"
  <> "pub type State = live.State(Args, Nil, Dynamic, Failure)\n\n"
  <> "pub type Event = live.Event(Field, Nil, Dynamic, Failure)\n\n"
  <> "pub fn init(_args: Nil) -> #(State, Effect(Event)) {\n"
  <> "  #(live.State(args: "
  <> args_init
  <> ", given: Nil, last: None, waiting: False), effect.none())\n}\n\n"
  <> "pub fn update(model: State, msg: Event, after: live.After) -> #(State, Effect(Event)) {\n"
  <> "  case msg {\n"
  <> set_branches
  <> "    live.Send ->\n"
  <> "      case model.waiting {\n"
  <> "        True -> #(model, effect.none())\n"
  <> "        False -> #(live.State(..model, waiting: True), "
  <> request_call
  <> ")\n"
  <> "      }\n"
  <> "    live.Given(_) -> #(model, effect.none())\n"
  <> "    live.Done(result) -> {\n"
  <> "      let next = live.State(..model, last: Some(result), waiting: False)\n"
  <> "      case result, after {\n"
  <> "        Ok(_), live.ReloadPage -> "
  <> case reload {
    True -> "#(next, event.emit(\"yumemi-done\", json.null()))\n"
    False -> "#(next, effect.none())\n"
  }
  <> "        _, _ -> #(next, effect.none())\n"
  <> "      }\n"
  <> "    }\n"
  <> "  }\n}\n\n"
  <> "@external(javascript, \"./transport_ffi.mjs\", \"send\")\n"
  <> "fn transport_send(method: String, path: String, body: json.Json, blob_fields: List(String), on_ok: fn(Dynamic) -> Nil, on_error: fn(Dynamic) -> Nil) -> Nil\n\n"
  <> request_head
  <> "  use dispatch <- effect.from\n"
  <> "  transport_send(\n"
  <> "    "
  <> quoted(route.method)
  <> ",\n"
  <> "    "
  <> quoted(route.path)
  <> ",\n"
  <> "    "
  <> body
  <> ",\n"
  <> "    [],\n"
  <> "    fn(value) { dispatch(live.Done(Ok(value))) },\n"
  <> "    fn(value) { dispatch(live.Done(Error(Broke(error_text(value))))) },\n"
  <> "  )\n  Nil\n}\n\n"
  <> "fn error_text(value: Dynamic) -> String {\n"
  <> "  case decode.run(value, error_field_decoder(\"code\")) {\n"
  <> "    Ok(code) if code != \"\" -> code\n"
  <> "    _ ->\n"
  <> "      case decode.run(value, error_field_decoder(\"message\")) {\n"
  <> "        Ok(message) if message != \"\" -> message\n"
  <> "        _ -> \"request failed\"\n"
  <> "      }\n"
  <> "  }\n}\n\n"
  <> "fn error_field_decoder(field: String) -> decode.Decoder(String) {\n"
  <> "  decode.optional_field(field, \"\", decode.string, fn(value) {\n"
  <> "    decode.success(value)\n"
  <> "  })\n}\n"
}

fn blob_entry_targets(
  components: List(reader_front.Component),
  attached: List(model.AttachedRoute),
) -> List(#(model.AttachedRoute, reader_front.Component)) {
  let empty: List(#(model.AttachedRoute, reader_front.Component)) = []
  components
  |> list.fold(empty, fn(targets, component) {
    component.calls
    |> list.fold(targets, fn(acc, target) {
      case target {
        reader_front.ServiceCall(_) -> acc
        reader_front.AttachedCall(name) ->
          case list.find(attached, fn(route) { route.name == name }) {
            Ok(route)
              if route.name == "BlobCopy"
              && route.method == "POST"
              && route.path == "/api/blobs"
            ->
              case list.any(acc, fn(found) { found.0.name == route.name }) {
                True -> acc
                False -> list.append(acc, [#(route, component)])
              }
            _ -> acc
          }
      }
    })
  })
}

fn blob_entry_live_text(
  route: model.AttachedRoute,
  hashes: hash.Hashes,
) -> String {
  let input_hash = digest.short(hash.entry(hashes) <> string.inspect(route))
  "//// GENERATED from src/server.gleam [sha256:"
  <> input_hash
  <> "] — 手で編集しない\n\n"
  <> "import framework/front/live\n"
  <> "import gleam/dynamic.{type Dynamic}\n"
  <> "import gleam/dynamic/decode\n"
  <> "import gleam/json\n"
  <> "import gleam/option.{None, Some}\n"
  <> "import lustre/attribute\n"
  <> "import lustre/effect.{type Effect}\n"
  <> "import lustre/event\n\n"
  <> "pub type Args {\n  Args(file: String)\n}\n\n"
  <> "pub type Field {\n  File\n}\n\n"
  <> "pub type State = live.State(Args, Nil, String, String)\n\n"
  <> "pub type Event = live.Event(Field, Nil, String, String)\n\n"
  <> "pub fn init(_given: Nil) -> #(State, Effect(Event)) {\n"
  <> "  #(\n"
  <> "    live.State(args: Args(file: \"\"), given: Nil, last: None, waiting: False),\n"
  <> "    effect.none(),\n"
  <> "  )\n}\n\n"
  <> "pub fn update(model: State, msg: Event) -> #(State, Effect(Event)) {\n"
  <> "  case msg {\n"
  <> "    live.Set(File, value) -> #(\n"
  <> "      live.State(..model, args: Args(file: value)),\n"
  <> "      effect.none(),\n"
  <> "    )\n"
  <> "    live.Send ->\n"
  <> "      case model.waiting {\n"
  <> "        True -> #(model, effect.none())\n"
  <> "        False -> #(live.State(..model, waiting: True), send(model.args))\n"
  <> "      }\n"
  <> "    live.Given(_) -> #(model, effect.none())\n"
  <> "    live.Done(result) -> #(\n"
  <> "      live.State(..model, last: Some(result), waiting: False),\n"
  <> "      effect.none(),\n"
  <> "    )\n"
  <> "  }\n}\n\n"
  <> "pub fn file_input() -> List(attribute.Attribute(Event)) {\n"
  <> "  [\n"
  <> "    attribute.attribute(\"type\", \"file\"),\n"
  <> "    attribute.attribute(\"data-yumemi-file-input\", \"\"),\n"
  <> "    event.on(\"change\", file_input_event()),\n"
  <> "  ]\n}\n\n"
  <> "fn file_input_event() -> decode.Decoder(Event) {\n"
  <> "  decode.map(\n"
  <> "    decode.dynamic,\n"
  <> "    fn(event) { live.Set(File, file_token(event)) },\n"
  <> "  )\n}\n\n"
  <> "@external(javascript, \"./transport_ffi.mjs\", \"file_token\")\n"
  <> "fn file_token(event: Dynamic) -> String\n\n"
  <> "@external(javascript, \"./transport_ffi.mjs\", \"upload_file\")\n"
  <> "fn transport_upload(\n"
  <> "  method: String,\n"
  <> "  path: String,\n"
  <> "  token: String,\n"
  <> "  on_ok: fn(String) -> Nil,\n"
  <> "  on_error: fn(Nil) -> Nil,\n"
  <> ") -> Nil\n\n"
  <> "fn send(args: Args) -> Effect(Event) {\n"
  <> "  effect.from(fn(dispatch) {\n"
  <> "    transport_upload(\n"
  <> "      "
  <> quoted(route.method)
  <> ",\n"
  <> "      "
  <> quoted(route.path)
  <> ",\n"
  <> "      args.file,\n"
  <> "      fn(key) { dispatch(live.Done(Ok(key))) },\n"
  <> "      fn(_unit) { dispatch(live.Done(Error(\"file upload failed\"))) },\n"
  <> "    )\n"
  <> "    Nil\n"
  <> "  })\n}\n\n"
  // 0.11.4(H5):URL の写し。framework の blob の口は JSON の `{from: url}` を受けて写した key を返す
  <> "/// URL の写し(`{from: url}` を JSON で送る)。成功は写した key、失敗は本文の `code`(無ければ `url copy failed`)。\n"
  <> "/// `Send`(file の upload)と同じ State を使い、送りの間は `waiting`。\n"
  <> "pub fn copy_from(model: State, url: String) -> #(State, Effect(Event)) {\n"
  <> "  case model.waiting || url == \"\" {\n"
  <> "    True -> #(model, effect.none())\n"
  <> "    False -> #(live.State(..model, waiting: True), send_from(url))\n"
  <> "  }\n}\n\n"
  <> "@external(javascript, \"./transport_ffi.mjs\", \"send\")\n"
  <> "fn transport_send(\n"
  <> "  method: String,\n"
  <> "  path: String,\n"
  <> "  body: json.Json,\n"
  <> "  blob_fields: List(String),\n"
  <> "  on_ok: fn(Dynamic) -> Nil,\n"
  <> "  on_error: fn(Dynamic) -> Nil,\n"
  <> ") -> Nil\n\n"
  <> "fn send_from(url: String) -> Effect(Event) {\n"
  <> "  effect.from(fn(dispatch) {\n"
  <> "    transport_send(\n"
  <> "      "
  <> quoted(route.method)
  <> ",\n"
  <> "      "
  <> quoted(route.path)
  <> ",\n"
  <> "      json.object([#(\"from\", json.string(url))]),\n"
  <> "      [],\n"
  <> "      fn(value) {\n"
  <> "        case decode.run(value, decode.at([\"key\"], decode.string)) {\n"
  <> "          Ok(key) if key != \"\" -> dispatch(live.Done(Ok(key)))\n"
  <> "          _ -> dispatch(live.Done(Error(\"invalid response\")))\n"
  <> "        }\n"
  <> "      },\n"
  <> "      fn(value) {\n"
  <> "        case decode.run(value, decode.at([\"code\"], decode.string)) {\n"
  <> "          Ok(code) if code != \"\" -> dispatch(live.Done(Error(code)))\n"
  <> "          _ -> dispatch(live.Done(Error(\"url copy failed\")))\n"
  <> "        }\n"
  <> "      },\n"
  <> "    )\n"
  <> "  })\n}\n"
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

fn component_services(component: reader_front.Component) -> List(String) {
  component.calls
  |> list.filter_map(fn(target) {
    case target {
      reader_front.ServiceCall(service) -> Ok(service)
      reader_front.AttachedCall(attached) -> Ok(attached)
    }
  })
}

fn transport_text(
  face_name: String,
  front: reader_front.Front,
  hashes: hash.Hashes,
) -> String {
  js_header(
    face_name <> "/src/components/*.gleam and src/entry.gleam",
    digest.short(hash.entry(hashes) <> string.inspect(front.components)),
  )
  <> "\n"
  <> "const selectedFiles = new Map();\n"
  <> "const uploadedFiles = new Map();\n"
  <> "const pendingUploads = new Map();\n\n"
  <> "export function file_token(event) {\n"
  <> "  const input = event.currentTarget ?? event.target;\n"
  <> "  if (!(input instanceof HTMLInputElement)) return \"\";\n"
  <> "  const previous = input.dataset.yumemiFileToken;\n"
  <> "  if (previous) { selectedFiles.delete(previous); uploadedFiles.delete(previous); }\n"
  <> "  const file = input.files?.[0];\n"
  <> "  if (!file) { delete input.dataset.yumemiFileToken; return \"\"; }\n"
  <> "  const token = `~yumemi-file:${crypto.randomUUID()}`;\n"
  <> "  selectedFiles.set(token, file);\n"
  <> "  input.dataset.yumemiFileToken = token;\n"
  <> "  return token;\n"
  <> "}\n\n"
  <> "async function uploadToken(token, method = \"POST\", path = \"/api/blobs\") {\n"
  <> "  if (uploadedFiles.has(token)) return uploadedFiles.get(token);\n"
  <> "  const file = selectedFiles.get(token);\n"
  <> "  if (!file) throw new Error(\"unknown file token\");\n"
  <> "  if (pendingUploads.has(token)) return pendingUploads.get(token);\n"
  <> "  const upload = fetch(path, {\n"
  <> "    method,\n"
  <> "    headers: { \"content-type\": file.type || \"application/octet-stream\" },\n"
  <> "    body: file,\n"
  <> "  }).then(async (response) => {\n"
  <> "    if (!response.ok) throw new Error(\"blob upload failed\");\n"
  <> "    const result = await response.json();\n"
  <> "    if (typeof result?.key !== \"string\" || result.key === \"\") throw new Error(\"blob response has no key\");\n"
  <> "    selectedFiles.delete(token);\n"
  <> "    uploadedFiles.set(token, result.key);\n"
  <> "    return result.key;\n"
  <> "  }).catch(() => { throw new Error(\"file upload failed\"); })\n"
  <> "    .finally(() => pendingUploads.delete(token));\n"
  <> "  pendingUploads.set(token, upload);\n"
  <> "  return upload;\n"
  <> "}\n\n"
  <> "export function send(method, path, body, blobFields, onOk, onError) {\n"
  <> "  Promise.resolve().then(async () => {\n"
  <> "    const nextBody = { ...body };\n"
  <> "    for (const field of blobFields) {\n"
  <> "      const value = nextBody[field];\n"
  <> "      if (typeof value !== \"string\") continue;\n"
  <> "      if (selectedFiles.has(value) || uploadedFiles.has(value)) nextBody[field] = await uploadToken(value);\n"
  <> "    }\n"
  <> "    const response = await fetch(path, {\n"
  <> "      method,\n"
  <> "      headers: { \"content-type\": \"application/json\" },\n"
  <> "      body: method === \"GET\" ? undefined : JSON.stringify(nextBody),\n"
  <> "    });\n"
  <> "    return response;\n"
  <> "  }).then((response) => {\n"
  <> "    if (response.ok) {\n"
  <> "      response.json().then(onOk).catch(() => onError({ code: \"invalid_response\" }));\n"
  <> "    } else {\n"
  <> "      response.json().then(onError).catch(() => onError({ code: \"request_failed\" }));\n"
  <> "    }\n"
  <> "  }).catch((error) => onError({ code: error?.message ?? \"network_error\" }));\n"
  <> "  return undefined;\n"
  <> "}\n\n"
  <> "export function upload_file(method, path, token, onOk, onError) {\n"
  <> "  if (!selectedFiles.has(token) && !uploadedFiles.has(token)) { onError(undefined); return undefined; }\n"
  <> "  uploadToken(token, method, path)\n"
  <> "    .then(onOk)\n"
  <> "    .catch(() => onError(undefined));\n"
  <> "  return undefined;\n"
  <> "}\n"
}

/// client の入口に登録する島 ── `components/` のうち `pub fn app()` を持つもの全部
/// (`calls` の無い島も登録する。島の登録の源は component の `app()`)。
fn client_components(
  front: reader_front.Front,
  units: List(Unit),
) -> List(reader_front.Component) {
  let empty: List(reader_front.Component) = []
  front.components
  |> list.filter(fn(component) { component_has_app(units, component) })
  |> list.fold(empty, fn(acc, component) {
    case list.any(acc, fn(found) { found.module == component.module }) {
      True -> acc
      False -> list.append(acc, [component])
    }
  })
  |> list.sort(fn(left, right) { string.compare(left.module, right.module) })
}

fn component_has_app(
  units: List(Unit),
  component: reader_front.Component,
) -> Bool {
  case list.find(units, fn(unit) { unit.path == component.module }) {
    Ok(unit) ->
      case g.find_function(g.in_order(unit.module), "app") {
        Some(function) -> function.publicity == glance.Public
        None -> False
      }
    Error(_) -> False
  }
}

/// `calls` / `target` を持つ島(送る先がある component)に `pub fn app()` が無ければ exit 3。
/// client の入口は `app()` を登録するだけで、島の組み立て(init / update / view / 属性)は component が持つ。
pub fn client_notes(
  package: face.Package,
  front: reader_front.Front,
) -> List(stop.Note) {
  front.components
  |> list.filter(fn(component) {
    component.calls != [] && !component_has_app(package.units, component)
  })
  |> list.map(fn(component) { component.module })
  |> list.unique
  |> list.sort(string.compare)
  |> list.map(fn(module) {
    stop.Note(
      stop.Missing,
      package.name
        <> "/"
        <> module
        <> ": `pub fn app()` が無い(client の入口は島を `app()` で登録する)",
    )
  })
}

/// client で差し替えてよい Page の route(0.11.4、H9)。面の Page の route から、応答に頁の読み込みの印が付く
/// Page を外す:門の `frame_src`(CSP の header は頁の読み込みにしか効かない)と `pageview`(数える script は頁の
/// 読み込みで走る)。外した Page へ・から の遷移は頁の読み込みのまま。
fn navigable_routes(
  app: model.App,
  back_units: List(Unit),
  package: face.Package,
  front: reader_front.Front,
) -> List(String) {
  let #(gate, _) = read_gate(app, back_units, package, front)
  let csp = case gate.frame_hosts {
    [] -> []
    _ -> gate.frame_src
  }
  let counted = case gate.pageview {
    Some(pageview) -> pageview.pages
    None -> []
  }
  front_route_paths(front)
  |> list.filter(fn(path) {
    !list.any(list.append(csp, counted), fn(match) {
      reader_gate.covers(match, path)
    })
  })
}

fn client_text(
  face_name: String,
  front: reader_front.Front,
  units: List(Unit),
  app: model.App,
  hashes: hash.Hashes,
  routes: List(String),
) -> String {
  let navigation = case routes {
    [] -> #("", "")
    _ -> #(
      "import { start as startNavigation } from \"__YUMEMI_BUILD__/yumemi/framework/front/navigate.mjs\";\n",
      "startNavigation({ routes: ["
        <> string.join(list.map(routes, fn(route) { quoted(route) }), ", ")
        <> "], boot });\n",
    )
  }
  let components = client_components(front, units)
  let imports =
    string.concat([
      "import { register as lustreRegister } from \"__YUMEMI_BUILD__/lustre/lustre.mjs\";\n",
      "import { run as decodeRun } from \"__YUMEMI_BUILD__/gleam_stdlib/gleam/dynamic/decode.mjs\";\n",
      "import { Result$isOk, Result$Ok$0 } from \"__YUMEMI_BUILD__/__YUMEMI_FACE__/gleam.mjs\";\n",
      // 0.11.4(H8):島は sketch の stylesheet の下で描く(class 付きの要素が panic しない)
      "import { styled } from \"__YUMEMI_BUILD__/yumemi/framework/front/island_style.mjs\";\n",
      navigation.0,
      string.concat(list.map(components, client_component_import)),
      string.concat(
        list.filter_map(components, fn(component) {
          case component.reloads |> list.first |> option.from_result {
            Some(reload) ->
              case service_for(app.services, reload.1) {
                Some(service) ->
                  Ok(
                    "import * as "
                    <> service.module
                    <> "Out from \"__YUMEMI_BUILD__/__YUMEMI_FACE__/gen/out/"
                    <> service.module
                    <> ".mjs\";\n",
                  )
                None -> Error(Nil)
              }
            None -> Error(Nil)
          }
        }),
      ),
    ])
  let registrations =
    string.concat(
      list.map(components, fn(component) {
        client_registration(component, app.services)
      }),
    )
  let reloads =
    string.concat(
      components
      |> list.filter(fn(component) {
        component.after_send == Some("ReloadPage")
      })
      |> list.map(fn(component) {
        "listenReload(\"" <> component_tag(component) <> "\");\n"
      }),
    )
  js_header(
    face_name <> "/src/components/*.gleam and src/entry.gleam",
    digest.short(hash.entry(hashes) <> string.inspect(front.components)),
  )
  <> "\n"
  <> imports
  <> "\n"
  <> "function registerWithGiven(app, decoder, tag) {\n"
  <> "  const element = document.querySelector(tag);\n"
  <> "  const raw = element?.getAttribute(\"data-yumemi-given\");\n"
  <> "  if (raw === null) return;\n"
  <> "  let given;\n"
  <> "  try {\n"
  <> "    const decoded = decodeRun(JSON.parse(raw), decoder());\n"
  <> "    if (!Result$isOk(decoded)) return;\n"
  <> "    given = Result$Ok$0(decoded);\n"
  <> "  } catch (_error) {\n"
  <> "    return;\n"
  <> "  }\n"
  <> "  lustreRegister({ ...app, init: () => app.init(given) }, tag);\n"
  <> "}\n\n"
  <> "function defined(tag) {\n"
  <> "  return globalThis.customElements?.get(tag) !== undefined;\n"
  <> "}\n\n"
  <> "function listenReload(tag) {\n"
  <> "  document.querySelectorAll(tag).forEach((element) => {\n"
  <> "    element.addEventListener(\"yumemi-done\", () => {\n"
  <> "      globalThis.location.assign(globalThis.location.href);\n"
  <> "    });\n"
  <> "  });\n"
  <> "}\n\n"
  // 0.11.4(H9):島の登録は client 遷移で body を差し替えた後にも走らせ直す
  <> "function boot() {\n"
  <> registrations
  <> reloads
  <> "}\n\n"
  <> "boot();\n"
  <> navigation.1
}

fn client_component_import(component: reader_front.Component) -> String {
  "import * as "
  <> component_js_name(component)
  <> " from \"__YUMEMI_BUILD__/__YUMEMI_FACE__/"
  <> component.module
  <> ".mjs\";\n"
}

fn client_registration(
  component: reader_front.Component,
  services: List(model.Service),
) -> String {
  let name = component_js_name(component)
  let tag = component_tag(component)
  case component.reloads |> list.first |> option.from_result {
    Some(reload) ->
      case service_for(services, reload.1) {
        Some(service) ->
          "if (!defined(\""
          <> tag
          <> "\")) registerWithGiven(styled("
          <> name
          <> ".app()), "
          <> service.module
          <> "Out.decoder, \""
          <> tag
          <> "\");\n"
        None -> ""
      }
    None ->
      "if (!defined(\""
      <> tag
      <> "\")) lustreRegister(styled("
      <> name
      <> ".app()), \""
      <> tag
      <> "\");\n"
  }
}

fn component_js_name(component: reader_front.Component) -> String {
  naming.snake(last_segment(component.module))
}

fn component_tag(component: reader_front.Component) -> String {
  string.replace(component_js_name(component), "_", "-")
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
  live_file_with_error_mode(
    app,
    units,
    package,
    service,
    component,
    hashes,
    face_name,
    True,
  )
}

fn attached_service_live_file(
  app: model.App,
  units: List(Unit),
  package: face.Package,
  service: model.Service,
  component: reader_front.Component,
  hashes: hash.Hashes,
  face_name: String,
) -> File {
  live_file_with_error_mode(
    app,
    units,
    package,
    service,
    component,
    hashes,
    face_name,
    False,
  )
}

fn live_file_with_error_mode(
  app: model.App,
  units: List(Unit),
  package: face.Package,
  service: model.Service,
  component: reader_front.Component,
  hashes: hash.Hashes,
  face_name: String,
  structured_errors: Bool,
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
  let route = api_route_for(app, hashes, face_name, service.module)
  File(
    path: face_name <> "/src/gen/live/" <> service.module <> ".gleam",
    text: live_text(
      app,
      units,
      service,
      component,
      given_service,
      route,
      structured_errors,
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
  route: Option(ApiRoute),
  structured_errors: Bool,
  generated_header: String,
) -> String {
  let validations = validation_specs(app, units, service.args)
  let service_errors = case structured_errors {
    True -> service_error_variants(units, service)
    False -> []
  }
  let error_handling = case route {
    Some(_) -> error_failure_text(service_errors)
    None -> ""
  }
  let blob_args = blob_args(service.args)
  let wires = arg_wires(units, service)
  let accepting = accepted.accepts(app, units, service)
  generated_header
  <> "\n"
  <> live_imports(
    service,
    given_service,
    validations != [],
    component.after_send == Some("ReloadPage"),
    blob_args != [],
    list.append(
      send_imports(wires, route),
      reply_imports(accepting && option.is_some(route)),
    ),
  )
  <> "\n\n"
  <> args_type_text(service.args)
  <> "\n"
  <> field_type_text(service.args)
  <> "\n"
  <> service_error_type_text(service_errors)
  <> failure_type_text(service_errors)
  <> reply_type_text(service, accepting)
  <> state_type_text(service, given_service, accepting)
  <> "\n"
  <> init_text(service, given_service)
  <> "\n"
  <> update_text(service, component, validations != [])
  <> "\n"
  <> file_input_text(blob_args)
  <> validate_text(validations)
  <> validation_error_text(validations)
  <> error_handling
  <> send_text(service, wires, route, component.after_send, accepting)
}

fn validation_error_text(
  validations: List(#(String, String, String)),
) -> String {
  case validations {
    [] -> ""
    _ ->
      "fn validation_error_text(errors: List(#(Field, String))) -> String {\n"
      <> "  errors |> list.map(fn(error) { error.1 }) |> string.join(\"; \")\n"
      <> "}\n\n"
  }
}

fn service_error_variants(
  units: List(Unit),
  service: model.Service,
) -> List(glance.Variant) {
  case unit_for(units, "service/" <> service.module) {
    Some(unit) -> {
      let module = g.in_order(unit.module)
      case g.find_custom_type(module, "Error") {
        Some(definition) -> definition.variants
        None -> []
      }
    }
    None -> []
  }
}

fn service_error_type_text(variants: List(glance.Variant)) -> String {
  case variants {
    [] -> "pub type Error\n\n"
    _ ->
      "pub type Error {\n"
      <> string.concat(list.map(variants, error_variant_text))
      <> "}\n\n"
  }
}

fn error_variant_text(variant: glance.Variant) -> String {
  case variant.fields {
    [] -> "  " <> variant.name <> "\n"
    fields ->
      "  "
      <> variant.name
      <> "("
      <> string.join(list.map(fields, error_field_text), ", ")
      <> ")\n"
  }
}

fn error_field_text(field: glance.VariantField) -> String {
  case field {
    glance.LabelledVariantField(label:, ..) -> label <> ": String"
    glance.UnlabelledVariantField(_) -> "String"
  }
}

fn failure_type_text(variants: List(glance.Variant)) -> String {
  case variants {
    [] -> "pub type Failure {\n  Broke(String)\n}\n\n"
    _ ->
      "pub type Failure {\n"
      <> "  Refused(Error)\n"
      <> "  Broke(String)\n"
      <> "}\n\n"
  }
}

fn error_failure_text(variants: List(glance.Variant)) -> String {
  let branches =
    variants
    |> list.filter(fn(variant) { variant.fields == [] })
    |> list.map(fn(variant) {
      "    "
      <> string.inspect(naming.snake(variant.name))
      <> " -> Refused("
      <> variant.name
      <> ")\n"
    })
    |> string.concat
  "fn error_failure(value: Dynamic) -> Failure {\n"
  <> "  case error_text(value) {\n"
  <> branches
  <> "    code -> Broke(code)\n"
  <> "  }\n"
  <> "}\n\n"
  <> "fn error_text(value: Dynamic) -> String {\n"
  <> "  case decode.run(value, error_field_decoder(\"code\")) {\n"
  <> "    Ok(code) if code != \"\" -> code\n"
  <> "    _ ->\n"
  <> "      case decode.run(value, error_field_decoder(\"message\")) {\n"
  <> "        Ok(message) if message != \"\" -> message\n"
  <> "        _ -> \"invalid error payload\"\n"
  <> "      }\n"
  <> "  }\n"
  <> "}\n\n"
  <> "fn error_field_decoder(field: String) -> decode.Decoder(String) {\n"
  <> "  decode.optional_field(field, \"\", decode.string, fn(value) {\n"
  <> "    decode.success(value)\n"
  <> "  })\n"
  <> "}\n\n"
}

fn live_imports(
  service: model.Service,
  given_service: Option(model.Service),
  has_validation: Bool,
  reloads_page: Bool,
  has_blob_fields: Bool,
  send: List(String),
) -> String {
  let validation = case has_validation {
    True -> ["framework/spec", "gleam/list", "gleam/string"]
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
  let file_input = case has_blob_fields {
    True -> ["lustre/attribute", "lustre/event"]
    False -> []
  }
  let base = [
    "framework/front/live",
    "gleam/dynamic.{type Dynamic}",
    "gleam/dynamic/decode",
    "gen/out/" <> service.module,
    "gleam/json",
    "gleam/option.{None, Some}",
    "lustre/effect.{type Effect}",
  ]
  base
  |> list.append(validation)
  |> list.append(reload)
  |> list.append(file_input)
  |> list.append(given)
  |> list.append(send)
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

fn blob_args(args: List(model.Arg)) -> List(model.Arg) {
  list.filter(args, fn(arg) { blob_shape(arg.type_) })
}

fn blob_shape(shape: model.TypeShape) -> Bool {
  case shape {
    model.NamedShape(
      module: Some("framework/blob"),
      name: "Blob",
      parameters: [],
    ) -> True
    model.NamedShape(
      module: Some("gleam/option"),
      name: "Option",
      parameters: [inner],
    ) -> blob_shape(inner)
    _ -> False
  }
}

fn file_input_text(args: List(model.Arg)) -> String {
  case args {
    [] -> ""
    _ ->
      string.concat(
        list.map(args, fn(arg) {
          "pub fn "
          <> arg.name
          <> "_file_input() -> List(attribute.Attribute(Event)) {\n"
          <> "  file_input("
          <> naming.pascal(arg.name)
          <> ")\n"
          <> "}\n\n"
        }),
      )
      <> "fn file_input(field: Field) -> List(attribute.Attribute(Event)) {\n"
      <> "  [\n"
      <> "    attribute.attribute(\"type\", \"file\"),\n"
      <> "    attribute.attribute(\"data-yumemi-file-input\", \"\"),\n"
      <> "    event.on(\"change\", file_input_event(field)),\n"
      <> "  ]\n}\n\n"
      <> "fn file_input_event(field: Field) -> decode.Decoder(Event) {\n"
      <> "  decode.map(\n"
      <> "    decode.dynamic,\n"
      <> "    fn(event) { live.Set(field, file_token(event)) },\n"
      <> "  )\n}\n\n"
      <> "@external(javascript, \"./transport_ffi.mjs\", \"file_token\")\n"
      <> "fn file_token(event: Dynamic) -> String\n\n"
  }
}

fn state_type_text(
  service: model.Service,
  given_service: Option(model.Service),
  accepting: Bool,
) -> String {
  let given = given_type(given_service)
  let out = case accepting {
    True -> "Reply"
    False -> service.module <> ".Out"
  }
  "pub type State = live.State(Args, "
  <> given
  <> ", "
  <> out
  <> ", Failure)\n\n"
  <> "pub type Event = live.Event(Field, "
  <> given
  <> ", "
  <> out
  <> ", Failure)\n"
}

/// 0.11.3(H4)── commit の後に続きを持つ Service(`accepted.accepts`)の live は、Out の代わりに
/// `Reply` を持つ。HTTP は 202 Accepted と 1 欄の本文(`{<root>: id}`、欄の名は ★ `respond` が替えてよい)を
/// 返すので、send はそれを `Accepted(id)` に読み、`Done(Ok(_))` として after_send へ進む。
/// commit の前に `step.done` で終わる道の 200 は、今までどおり Out を読んで `Replied(out)`。
fn reply_type_text(service: model.Service, accepting: Bool) -> String {
  case accepting {
    False -> ""
    True ->
      "/// commit の後に続きを持つ Service。HTTP は 202 Accepted と `{<root>: id}` で応える\n"
      <> "pub type Reply {\n"
      <> "  Replied("
      <> service.module
      <> ".Out)\n"
      <> "  Accepted(id: String)\n"
      <> "}\n\n"
  }
}

fn reply_imports(accepting: Bool) -> List(String) {
  case accepting {
    True -> ["gleam/dict"]
    False -> []
  }
}

fn reply_decoder_text(service: model.Service) -> String {
  "\nfn reply_decoder() -> decode.Decoder(Reply) {\n"
  <> "  decode.one_of(decode.map("
  <> service.module
  <> ".decoder(), Replied), [\n"
  <> "    accepted_decoder(),\n"
  <> "  ])\n}\n\n"
  <> "fn accepted_decoder() -> decode.Decoder(Reply) {\n"
  <> "  use fields <- decode.then(decode.dict(decode.string, decode.string))\n"
  <> "  case dict.to_list(fields) {\n"
  <> "    [#(_, id)] -> decode.success(Accepted(id))\n"
  <> "    _ -> decode.failure(Accepted(\"\"), \"Accepted\")\n"
  <> "  }\n}\n"
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
  has_validation: Bool,
) -> String {
  let invalid_input = case has_validation {
    True -> "validation_error_text(errors)"
    False -> "\"invalid input\""
  }
  "pub fn update(model: State, msg: Event) -> #(State, Effect(Event)) {\n"
  <> "  case msg {\n"
  <> case service.args {
    [] -> "    live.Set(_, _) -> #(model, effect.none())\n"
    _ -> set_branches(service.args)
  }
  <> "    live.Send ->\n"
  <> "      case model.waiting {\n"
  <> "        True -> #(model, effect.none())\n"
  <> "        False ->\n"
  <> "          case validate(model) {\n"
  <> "            Error(errors) -> #(\n"
  <> "              live.State(..model, last: Some(Error(Broke("
  <> invalid_input
  <> ")))),\n"
  <> "              effect.none(),\n"
  <> "            )\n"
  <> "            Ok(args) -> #(live.State(..model, waiting: True), send(args))\n"
  <> "          }\n"
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

fn validate_text(validations: List(#(String, String, String))) -> String {
  case validations {
    [] ->
      "pub fn validate(model: State) -> Result(Args, List(#(Field, String))) {\n"
      <> "  Ok(model.args)\n}\n\n"
    _ ->
      "pub fn validate(model: State) -> Result(Args, List(#(Field, String))) {\n"
      <> "  let errors = list.flatten([\n"
      <> string.concat(
        list.map(validations, fn(validation) {
          let #(field, spec, message) = validation
          "    validate_field("
          <> field
          <> ", model.args."
          <> field_name(field)
          <> ", "
          <> spec
          <> ", "
          <> quoted(message)
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
      <> "  message: String,\n"
      <> ") -> List(#(Field, String)) {\n"
      <> "  case spec.validate(raw, constraint) {\n"
      <> "    Ok(_) -> []\n"
      <> "    Error(_) -> [#(field, message)]\n"
      <> "  }\n}\n\n"
  }
}

fn field_name(field: String) -> String {
  naming.snake(field)
}

fn send_text(
  service: model.Service,
  wires: List(#(model.Arg, Wire)),
  route: Option(ApiRoute),
  after_send: Option(String),
  accepting: Bool,
) -> String {
  let #(response_decoder, reply) = case accepting {
    True -> #("reply_decoder()", "reply")
    False -> #(service.module <> ".decoder()", "out")
  }
  let blob_fields =
    blob_args(service.args)
    |> list.map(fn(arg) { quoted(arg.name) })
    |> string.join(", ")
  let blob_fields = "[" <> blob_fields <> "]"
  let reload = case after_send {
    Some("ReloadPage") ->
      "\nfn reload_page() -> Effect(Event) {\n  event.emit(\"yumemi-done\", json.null())\n}\n"
    _ -> ""
  }
  let send = case route {
    None -> "fn send(_args: Args) -> Effect(Event) {\n  effect.none()\n}\n"
    Some(route) ->
      "@external(javascript, \"./transport_ffi.mjs\", \"send\")\n"
      <> "fn transport_send(\n"
      <> "  method: String,\n"
      <> "  path: String,\n"
      <> "  body: json.Json,\n"
      <> "  blob_fields: List(String),\n"
      <> "  on_ok: fn(Dynamic) -> Nil,\n"
      <> "  on_error: fn(Dynamic) -> Nil,\n"
      <> ") -> Nil\n\n"
      <> "fn send(args: Args) -> Effect(Event) {\n"
      <> "  effect.from(fn(dispatch) {\n"
      <> "    transport_send(\n"
      <> "      "
      <> quoted(route.method)
      <> ",\n"
      <> "      "
      <> case route.method {
        "GET" -> query_path_expression(route.path, service.args)
        _ -> path_expression(route.path)
      }
      <> ",\n"
      <> "      "
      <> case route.method {
        "GET" -> "json.object([])"
        _ -> body_expression(wires)
      }
      <> ",\n"
      <> "      "
      <> blob_fields
      <> ",\n"
      <> "      fn(value) {\n"
      <> "        case decode.run(value, "
      <> response_decoder
      <> ") {\n"
      <> "          Ok("
      <> reply
      <> ") -> dispatch(live.Done(Ok("
      <> reply
      <> ")))\n"
      <> "          Error(_) -> dispatch(live.Done(Error(Broke(\"invalid response\"))))\n"
      <> "        }\n"
      <> "      },\n"
      <> "      fn(value) { dispatch(live.Done(Error(error_failure(value)))) },\n"
      <> "    )\n"
      <> "  })\n}\n"
      <> case route.method, send_imports(wires, Some(route)) {
        "GET", [_, ..] ->
          "\nfn with_query(path: String, pairs: List(#(String, String))) -> String {\n"
          <> "  case pairs {\n"
          <> "    [] -> path\n"
          <> "    _ -> path <> \"?\" <> uri.query_to_string(pairs)\n"
          <> "  }\n}\n"
        "GET", _ -> ""
        _, _ -> wire_helpers_text(wires)
      }
      <> case accepting {
        True -> reply_decoder_text(service)
        False -> ""
      }
  }
  send <> reload
}

fn path_expression(path: String) -> String {
  case string.split(path, ":") {
    [] -> quoted(path)
    [first, ..rest] ->
      quoted(first)
      <> string.concat(
        list.map(rest, fn(part) {
          let #(name, suffix) = path_part(part)
          " <> args." <> name <> " <> " <> quoted(suffix)
        }),
      )
  }
}

fn path_part(part: String) -> #(String, String) {
  case string.split(part, "/") {
    [name, suffix, ..rest] -> #(name, "/" <> string.join([suffix, ..rest], "/"))
    [name] -> #(name, "")
    [] -> #("", "")
  }
}

fn body_expression(wires: List(#(model.Arg, Wire))) -> String {
  "json.object([\n"
  <> string.concat(
    list.map(wires, fn(pair) {
      let #(arg, wire) = pair
      "    #(\""
      <> arg.name
      <> "\", "
      <> wire_value_expression(wire, "args." <> arg.name)
      <> "),\n"
    }),
  )
  <> "  ])"
}

/// Args の欄の送り方(0.11.2)。live は欄を文字列で持ち、send で Args の型の JSON にする。
type Wire {
  /// Bool / Int / Float は H1 の規則で真偽・数に、それ以外(値型・Id・列挙・日付…)は文字列
  ScalarWire(ScalarKind)
  /// `Option(X)` ── `""` は null、それ以外は X
  OptionWire(Wire)
  /// `List(X)`(X がスカラ)── 欄は JSON の文字列の配列(`["a","b"]`)、要素を X の規則で送る
  ListWire(ScalarKind)
  /// record・組・Dict・スカラでない要素の List ── 欄の文字列を JSON の本文として読み、そのまま送る
  /// (形は back の decoder が決める。読めない綴りは文字列のまま送り、back が `invalid_argument` で返す)
  JsonWire
}

fn arg_wires(
  units: List(Unit),
  service: model.Service,
) -> List(#(model.Arg, Wire)) {
  list.map(service.args, fn(arg) { #(arg, arg_wire(units, service, arg.type_)) })
}

fn arg_wire(
  units: List(Unit),
  service: model.Service,
  shape: model.TypeShape,
) -> Wire {
  case shape {
    model.NamedShape(
      module: Some("gleam/option"),
      name: "Option",
      parameters: [inner],
    ) -> OptionWire(arg_wire(units, service, inner))
    model.NamedShape(module: None, name: "List", parameters: [inner]) ->
      case arg_wire(units, service, inner) {
        ScalarWire(kind) -> ListWire(kind)
        _ -> JsonWire
      }
    model.NamedShape(module: Some("gleam/dict"), name: "Dict", ..) -> JsonWire
    model.TupleShape(_) -> JsonWire
    model.NamedShape(module: module, name: name, ..) ->
      case record_type(units, service, module, name) {
        True -> JsonWire
        False -> ScalarWire(scalar_kind(shape))
      }
  }
}

/// 構成子が 1 つで、欄が全部名付きの opaque でない custom type(record)か。構成子が複数の sum
/// (`Place` など)と値型(`gen/types/*`・framework の opaque な型、`LinkId(value: String)` の形)は
/// back が文字列で読むので record としない。
fn record_type(
  units: List(Unit),
  service: model.Service,
  module: Option(String),
  name: String,
) -> Bool {
  let path = case module {
    Some(path) -> path
    None -> "service/" <> service.module
  }
  let value_type =
    string.starts_with(path, "gen/") || string.starts_with(path, "framework/")
  case value_type, unit_for(units, path) {
    True, _ | _, None -> False
    False, Some(unit) ->
      case g.find_custom_type(g.in_order(unit.module), name) {
        Some(glance.CustomType(opaque_: False, variants: [variant], ..)) ->
          variant.fields != []
          && list.all(variant.fields, fn(field) {
            case field {
              glance.LabelledVariantField(..) -> True
              glance.UnlabelledVariantField(..) -> False
            }
          })
        _ -> False
      }
  }
}

/// Args の欄の値(live は文字列で持つ)を Args の型で JSON に(0.11.2 H1・r2)。Bool は真偽、
/// Int / Float は数(読めない綴りは文字列のまま送り、back が `invalid_argument` で返す)。
fn wire_value_expression(wire: Wire, value: String) -> String {
  case wire {
    OptionWire(inner) ->
      "case "
      <> value
      <> " {\n"
      <> "  \"\" -> json.null()\n"
      <> "  value -> "
      <> wire_value_expression(inner, "value")
      <> "\n"
      <> "}"
    ScalarWire(kind) -> json_value_expression(kind, value)
    ListWire(kind) ->
      "case list_items("
      <> value
      <> ") {\n"
      <> "  Ok(items) -> json.array(items, fn(value) { "
      <> json_value_expression(kind, "value")
      <> " })\n"
      <> "  Error(_) -> json.string("
      <> value
      <> ")\n"
      <> "}"
    JsonWire -> "json_text(" <> value <> ")"
  }
}

fn wire_helpers_text(wires: List(#(model.Arg, Wire))) -> String {
  let flat = list.map(wires, fn(pair) { inner_wire(pair.1) })
  let lists = case list.any(flat, fn(wire) { is_list_wire(wire) }) {
    True ->
      "\n/// List の欄は JSON の文字列の配列(`[\"a\",\"b\"]`、空の欄は `[]`)。\n"
      <> "fn list_items(text: String) -> Result(List(String), Nil) {\n"
      <> "  case text {\n"
      <> "    \"\" -> Ok([])\n"
      <> "    _ ->\n"
      <> "      case json.parse(text, decode.list(decode.string)) {\n"
      <> "        Ok(items) -> Ok(items)\n"
      <> "        Error(_) -> Error(Nil)\n"
      <> "      }\n"
      <> "  }\n}\n"
    False -> ""
  }
  let texts = case list.contains(flat, JsonWire) {
    True ->
      "\n/// record・組・Dict の欄は JSON の本文。読めなければ文字列のまま送る。\n"
      <> "fn json_text(text: String) -> json.Json {\n"
      <> "  case json.parse(text, json_value()) {\n"
      <> "    Ok(value) -> value\n"
      <> "    Error(_) -> json.string(text)\n"
      <> "  }\n}\n\n"
      <> "fn json_value() -> decode.Decoder(json.Json) {\n"
      <> "  use <- decode.recursive\n"
      <> "  decode.one_of(decode.map(decode.string, json.string), [\n"
      <> "    decode.map(decode.bool, json.bool),\n"
      <> "    decode.map(decode.int, json.int),\n"
      <> "    decode.map(decode.float, json.float),\n"
      <> "    decode.map(decode.list(json_value()), json.preprocessed_array),\n"
      <> "    decode.map(decode.dict(decode.string, json_value()), fn(entries) {\n"
      <> "      json.object(dict.to_list(entries))\n"
      <> "    }),\n"
      <> "    decode.success(json.null()),\n"
      <> "  ])\n}\n"
    False -> ""
  }
  lists <> texts
}

fn inner_wire(wire: Wire) -> Wire {
  case wire {
    OptionWire(inner) -> inner_wire(inner)
    _ -> wire
  }
}

fn is_list_wire(wire: Wire) -> Bool {
  case wire {
    ListWire(_) -> True
    _ -> False
  }
}

fn wire_kinds(wire: Wire) -> List(ScalarKind) {
  case wire {
    OptionWire(inner) -> wire_kinds(inner)
    ScalarWire(kind) | ListWire(kind) -> [kind]
    JsonWire -> []
  }
}

fn json_value_expression(kind: ScalarKind, value: String) -> String {
  case kind {
    BoolArg ->
      "case "
      <> value
      <> " {\n"
      <> "  \"true\" | \"True\" | \"on\" -> json.bool(True)\n"
      <> "  \"false\" | \"False\" | \"\" -> json.bool(False)\n"
      <> "  other -> json.string(other)\n"
      <> "}"
    IntArg ->
      "case int.parse("
      <> value
      <> ") {\n"
      <> "  Ok(number) -> json.int(number)\n"
      <> "  Error(_) -> json.string("
      <> value
      <> ")\n"
      <> "}"
    FloatArg ->
      "case float.parse("
      <> value
      <> "), int.parse("
      <> value
      <> ") {\n"
      <> "  Ok(number), _ -> json.float(number)\n"
      <> "  _, Ok(number) -> json.float(int.to_float(number))\n"
      <> "  _, _ -> json.string("
      <> value
      <> ")\n"
      <> "}"
    TextArg -> "json.string(" <> value <> ")"
  }
}

/// GET の path(0.11.2 H2)── path の穴に入らない Args を query に載せる。Option の空は載せない、
/// Bool は `true` / `false` の綴りに揃える(back の query の読みと同じ綴り)。
fn query_path_expression(path: String, args: List(model.Arg)) -> String {
  let holes = path_holes(path)
  let pairs =
    args
    |> list.filter(fn(arg) { !list.contains(holes, arg.name) })
    |> list.map(query_pair_expression)
  case pairs {
    [] -> path_expression(path)
    _ ->
      "with_query(\n"
      <> "        "
      <> path_expression(path)
      <> ",\n"
      <> "        list.flatten([\n"
      <> string.concat(
        list.map(pairs, fn(pair) { "          " <> pair <> ",\n" }),
      )
      <> "        ]),\n"
      <> "      )"
  }
}

fn query_pair_expression(arg: model.Arg) -> String {
  case arg.type_ {
    model.NamedShape(
      module: Some("gleam/option"),
      name: "Option",
      parameters: [inner],
    ) ->
      "case args."
      <> arg.name
      <> " { \"\" -> [] value -> [#("
      <> quoted(arg.name)
      <> ", "
      <> query_value_expression(inner, "value")
      <> ")] }"
    shape ->
      "[#("
      <> quoted(arg.name)
      <> ", "
      <> query_value_expression(shape, "args." <> arg.name)
      <> ")]"
  }
}

fn query_value_expression(shape: model.TypeShape, value: String) -> String {
  case scalar_kind(shape) {
    BoolArg ->
      "case "
      <> value
      <> " { \"true\" | \"True\" | \"on\" -> \"true\" \"false\" | \"False\" | \"\" -> \"false\" other -> other }"
    _ -> value
  }
}

fn path_holes(path: String) -> List(String) {
  case string.split(path, ":") {
    [] | [_] -> []
    [_, ..rest] -> list.map(rest, fn(part) { path_part(part).0 })
  }
}

type ScalarKind {
  BoolArg
  IntArg
  FloatArg
  TextArg
}

fn scalar_kind(shape: model.TypeShape) -> ScalarKind {
  case shape {
    model.NamedShape(module: None, name: "Bool", parameters: []) -> BoolArg
    model.NamedShape(module: None, name: "Int", parameters: []) -> IntArg
    model.NamedShape(module: None, name: "Float", parameters: []) -> FloatArg
    _ -> TextArg
  }
}

/// live の send が使う import(Args の型の encode と GET の query)。
fn send_imports(
  wires: List(#(model.Arg, Wire)),
  route: Option(ApiRoute),
) -> List(String) {
  case route {
    None -> []
    Some(route) -> {
      let holes = path_holes(route.path)
      let kinds = list.flat_map(wires, fn(pair) { wire_kinds(pair.1) })
      case route.method {
        "GET" ->
          case
            list.any(wires, fn(pair) { !list.contains(holes, { pair.0 }.name) })
          {
            True -> ["gleam/list", "gleam/uri"]
            False -> []
          }
        _ ->
          list.flatten([
            case
              list.contains(kinds, IntArg) || list.contains(kinds, FloatArg)
            {
              True -> ["gleam/int"]
              False -> []
            },
            case list.contains(kinds, FloatArg) {
              True -> ["gleam/float"]
              False -> []
            },
            case list.any(wires, fn(pair) { inner_wire(pair.1) == JsonWire }) {
              True -> ["gleam/dict"]
              False -> []
            },
          ])
      }
    }
  }
}

fn validation_specs(
  app: model.App,
  units: List(Unit),
  args: List(model.Arg),
) -> List(#(String, String, String)) {
  args
  |> list.filter_map(fn(arg) {
    case value_type_for_arg(app.value_types, arg.type_) {
      Some(value) ->
        Ok(#(
          naming.pascal(arg.name),
          spec_expression(units, value),
          spec_error_message(units, value),
        ))
      None -> Error(Nil)
    }
  })
}

fn spec_error_message(units: List(Unit), value: model.ValueType) -> String {
  case list.find(units, fn(unit) { unit.path == "types" }) {
    Ok(unit) -> {
      let module = g.in_order(unit.module)
      case g.find_constant(module, value.name) {
        Some(constant) -> spec_error_message_text(constant.value, value)
        None -> fallback_validation_message(value)
      }
    }
    Error(_) -> fallback_validation_message(value)
  }
}

fn spec_error_message_text(
  expression: glance.Expression,
  value: model.ValueType,
) -> String {
  case g.ctor_name(expression) {
    Some("Pattern") ->
      case
        spec_bounds(expression),
        g.labelled(expression, "regex") |> option.then(g.string_value)
      {
        Some(#(min, max)), Some(regex) ->
          "must contain "
          <> min
          <> " to "
          <> max
          <> " characters and match /"
          <> regex
          <> "/"
        _, _ -> fallback_validation_message(value)
      }
    Some("Text") | Some("MarkdownText") ->
      case spec_bounds(expression) {
        Some(#(min, max)) ->
          "must contain " <> min <> " to " <> max <> " characters"
        None -> fallback_validation_message(value)
      }
    Some("Range") ->
      case spec_bounds(expression) {
        Some(#(min, max)) ->
          "must be an integer from " <> min <> " through " <> max
        None -> fallback_validation_message(value)
      }
    Some("Uuid") -> "must be a UUID"
    Some("Markdown") -> "must be valid Markdown"
    Some("Url") -> "must be a valid URL"
    Some(_) | None -> fallback_validation_message(value)
  }
}

fn fallback_validation_message(value: model.ValueType) -> String {
  case value.spec, value.range {
    "Pattern", _ -> "must match the configured pattern"
    "Text", _ -> "must satisfy the configured length"
    "MarkdownText", _ -> "must satisfy the configured Markdown length"
    "Range", Some(#(min, max)) ->
      "must be an integer from "
      <> int.to_string(min)
      <> " through "
      <> int.to_string(max)
    "Range", None -> "must satisfy the configured integer range"
    "Uuid", _ -> "must be a UUID"
    "Markdown", _ -> "must be valid Markdown"
    "Url", _ -> "must be a valid URL"
    _, _ -> "does not satisfy the configured constraint"
  }
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
  LoadSource(
    key: String,
    name: String,
    service: String,
    type_name: String,
    optional: Bool,
  )
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
  let page_sources = page_sources(app, units, page, front.blocks, app.services)
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
  placement_sources(layout_placements(layout), blocks, services, [])
}

fn page_sources(
  app: model.App,
  units: List(Unit),
  page: reader_front.Page,
  blocks: List(reader_front.Block),
  services: List(model.Service),
) -> List(LoadSource) {
  let root_service = page_root_service(page, services)
  let sources = placement_sources(page_placements(page), blocks, services, [])
  case page.theme, root_service {
    Some(name), Some(fallback_module) -> {
      let module = page_theme_service(app, units, sources, fallback_module)
      list.append(sources, [
        LoadSource(
          key: "theme:" <> module <> ":" <> name,
          name: name,
          service: module,
          type_name: "PageTheme",
          optional: True,
        ),
      ])
    }
    _, _ -> sources
  }
}

fn layout_placements(
  layout: reader_front.Layout,
) -> List(reader_front.Placement) {
  list.flatten([
    layout.sp
      |> option.then(fn(frame) { Some(frame.placements) })
      |> option.unwrap([]),
    layout.pc
      |> option.then(fn(frame) { Some(frame.placements) })
      |> option.unwrap([]),
    layout.tablet
      |> option.then(fn(frame) { Some(frame.placements) })
      |> option.unwrap([]),
  ])
}

fn page_placements(page: reader_front.Page) -> List(reader_front.Placement) {
  list.flatten([
    page.sp
      |> option.then(fn(frame) { Some(frame.placements) })
      |> option.unwrap([]),
    page.pc
      |> option.then(fn(frame) { Some(frame.placements) })
      |> option.unwrap([]),
    page.tablet
      |> option.then(fn(frame) { Some(frame.placements) })
      |> option.unwrap([]),
  ])
}

fn page_theme_service(
  app: model.App,
  units: List(Unit),
  sources: List(LoadSource),
  fallback: String,
) -> String {
  case
    list.find(sources, fn(source) {
      source.type_name == "Out"
      && output_has_custom_type(app, units, source.service, "PageTheme")
    })
  {
    Ok(source) -> source.service
    Error(_) -> fallback
  }
}

fn output_has_custom_type(
  app: model.App,
  units: List(Unit),
  service: String,
  name: String,
) -> Bool {
  let #(state, _) = out_state(app, units, "service/" <> service)
  list.any(state.custom, fn(declaration) {
    let CustomDecl(definition: definition, ..) = declaration
    definition.name == name
  })
}

fn unique_load_sources(sources: List(LoadSource)) -> List(LoadSource) {
  list.fold(sources, [], add_load_source)
}

fn page_root_service(
  page: reader_front.Page,
  services: List(model.Service),
) -> Option(String) {
  case page.of {
    Some(service) -> service_module(services, service)
    None -> None
  }
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
                  type_name: "Out",
                  optional: False,
                ),
              )
            None -> initial
          }
        reader_front.Widget(service: service_name, ..) ->
          case service_module(services, service_name) {
            Some(module) ->
              add_load_source(
                initial,
                LoadSource(
                  key: "service:" <> module,
                  name: module,
                  service: module,
                  type_name: "Out",
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
    Ok(reader_front.Block(input_kind: reader_front.ServiceOut(service), ..)) ->
      service_module(services, naming.pascal(service))
    Ok(_) -> None
    Error(_) -> None
  }
}

fn load_source_type(source: LoadSource) -> String {
  let out = source.service <> "." <> source.type_name
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
  let theme = theme_source(page_sources)
  let theme_background_blob = theme_background_is_blob(units, theme)
  let vars = list.append(page.vars, front.layout.vars)
  let data_fields =
    ["    layout: layout.Data,\n", "    vars: Vars,\n"]
    |> list.append(list.map(page_sources, load_data_field_text))
  let page_path = face_name <> "/src/" <> page.module <> ".gleam"
  let body =
    vars_type_text(vars, front.http_entries, front.face)
    <> "\n"
    <> load_data_text("Data", data_fields)
    <> "\n"
    <> page_load_function_text(layout_sources, page_sources)
    <> "\n"
    <> page_render_text(front, page_sources, theme_background_blob)
    <> "\n"
    <> page_view_text(app, units, front, page, layout_sources, page_sources)
  let imports =
    load_imports(
      front,
      page,
      list.append(layout_sources, page_sources),
      True,
      theme_background_blob,
      body,
    )
  let source_body =
    header(page_path, input_hash)
    <> "\n"
    <> imports
    <> import_gap(imports)
    <> body
  source_body
}

fn page_render_text(
  front: reader_front.Front,
  page_sources: List(LoadSource),
  theme_background_blob: Bool,
) -> String {
  let theme = theme_source(page_sources)
  let theme_call = case theme {
    Some(_) -> "theme_global(it.theme)"
    None -> "theme_global()"
  }
  "pub fn render(it: Data) -> element.Element(Nil) {\n"
  <> "  let assert Ok(stylesheet) =\n"
  <> "    sketch_lustre.construct(fn(stylesheet) {\n"
  <> "      sketch.global(stylesheet, "
  <> theme_call
  <> ")\n"
  <> "    })\n"
  <> "  let output = render_view(stylesheet, fn() { view(it) })\n"
  <> "  let assert Ok(_) = sketch_lustre.teardown(stylesheet)\n"
  <> "  output\n"
  <> "}\n\n"
  <> "fn render_view(\n"
  <> "  stylesheet: sketch.StyleSheet,\n"
  <> "  body: fn() -> element.Element(Nil),\n"
  <> ") -> element.Element(Nil) {\n"
  <> "  let styled_body =\n"
  <> "    sketch_lustre.render(stylesheet, in: [sketch_lustre.node()], after: body)\n"
  <> "\n"
  <> "  raw_html.html([attribute.attribute(\"lang\", "
  <> quoted(front.shell.lang)
  <> ")], [\n"
  <> "    raw_html.head([], [\n"
  <> "      raw_html.meta([attribute.attribute(\"charset\", \"utf-8\")]),\n"
  <> "      raw_html.meta([\n"
  <> "        attribute.attribute(\"name\", \"viewport\"),\n"
  <> "        attribute.attribute(\"content\", \"width=device-width, initial-scale=1, viewport-fit=cover\"),\n"
  <> "      ]),\n"
  <> "      raw_html.title([], "
  <> quoted(front.shell.title)
  <> "),\n"
  <> "    ]),\n"
  <> "    raw_html.body([], [styled_body]),\n"
  <> "  ])\n"
  <> "}\n\n"
  <> theme_global_text(front, theme, theme_background_blob)
}

fn theme_source(sources: List(LoadSource)) -> Option(LoadSource) {
  list.find(sources, fn(source) { source.type_name == "PageTheme" })
  |> option.from_result
}

fn theme_background_is_blob(
  units: List(Unit),
  theme: Option(LoadSource),
) -> Bool {
  case theme {
    Some(source) -> {
      let service_path = "service/" <> source.service
      let service_scope = scope_for(units, service_path)
      let theme_path = case
        unqualified_module(service_scope.imports, source.type_name)
      {
        Some(path) -> path
        None -> service_path
      }
      case unit_for(units, theme_path) {
        Some(unit) -> {
          let module = g.in_order(unit.module)
          case g.find_custom_type(module, source.type_name) {
            Some(definition) -> theme_definition_background_is_blob(definition)
            None -> theme_background_from_any_unit(units, source.type_name)
          }
        }
        None -> False
      }
    }
    None -> False
  }
}

fn theme_background_from_any_unit(
  units: List(Unit),
  type_name: String,
) -> Bool {
  case
    list.find_map(units, fn(unit) {
      let module = g.in_order(unit.module)
      case g.find_custom_type(module, type_name) {
        Some(definition) -> Ok(definition)
        None -> Error(Nil)
      }
    })
  {
    Ok(definition) -> theme_definition_background_is_blob(definition)
    Error(_) -> False
  }
}

fn theme_definition_background_is_blob(definition: glance.CustomType) -> Bool {
  case definition.variants {
    [variant, ..] ->
      case
        list.find_map(variant.fields, fn(field) {
          case g.variant_field_label(field) {
            Some("background_image") -> Ok(g.variant_field_type(field))
            _ -> Error(Nil)
          }
        })
      {
        Ok(type_) -> theme_field_is_blob(type_)
        Error(_) -> False
      }
    [] -> False
  }
}

fn theme_field_is_blob(type_: glance.Type) -> Bool {
  case type_ {
    glance.NamedType(name: "Option", parameters: [inner], ..) ->
      theme_field_is_blob(inner)
    glance.NamedType(name: "Blob", ..) -> True
    _ -> False
  }
}

fn theme_global_text(
  front: reader_front.Front,
  theme: Option(LoadSource),
  theme_background_blob: Bool,
) -> String {
  let defaults =
    quoted(front.shell.background)
    <> ", "
    <> quoted(front.shell.background_image)
    <> ", "
    <> quoted(front.shell.text)
    <> ", "
    <> quoted(front.shell.accent)
  case theme {
    Some(source) ->
      "fn theme_global(value: Option("
      <> source.service
      <> "."
      <> source.type_name
      <> ")) -> raw_css.Global {\n"
      <> "  let #(background, background_image, text, accent) = case value {\n"
      <> "    Some("
      <> source.service
      <> "."
      <> source.type_name
      <> "(background:, background_image:, text:, accent:)) -> #(\n"
      <> "      option_string(background, "
      <> quoted(front.shell.background)
      <> "),\n"
      <> "      option_background(background_image),\n"
      <> "      option_string(text, "
      <> quoted(front.shell.text)
      <> "),\n"
      <> "      option_string(accent, "
      <> quoted(front.shell.accent)
      <> "),\n"
      <> "    )\n"
      <> "    None -> #("
      <> defaults
      <> ")\n"
      <> "  }\n\n"
      <> theme_global_body()
      <> "}\n\n"
      <> option_string_text()
      <> "\n"
      <> option_background_text(theme_background_blob)
    None ->
      "fn theme_global() -> raw_css.Global {\n"
      <> "  let #(background, background_image, text, accent) = #("
      <> defaults
      <> ")\n\n"
      <> theme_global_body()
      <> "}\n"
  }
}

fn theme_global_body() -> String {
  "  raw_css.global(\"body\", [\n"
  <> "    raw_css.property(\"--bg\", background),\n"
  <> "    raw_css.property(\"--bg-image\", background_image),\n"
  <> "    raw_css.property(\"--text\", text),\n"
  <> "    raw_css.property(\"--accent\", accent),\n"
  <> "  ])\n"
}

fn option_string_text() -> String {
  "fn option_string(value: Option(String), default: String) -> String {\n"
  <> "  case value {\n"
  <> "    Some(value) -> value\n"
  <> "    None -> default\n"
  <> "  }\n}\n"
}

fn option_background_text(blob: Bool) -> String {
  case blob {
    True ->
      "fn option_background(value: Option(Blob)) -> String {\n"
      <> "  case value {\n"
      <> "    Some(value) -> "
      <> quoted("url(\"")
      <> " <> media.url(value, media.W1600) <> "
      <> quoted("\")")
      <> "\n"
      <> "    None -> \"none\"\n"
      <> "  }\n}\n"
    False ->
      "fn option_background(value: Option(String)) -> String {\n"
      <> "  case value {\n"
      <> "    Some(value) -> value\n"
      <> "    None -> \"none\"\n"
      <> "  }\n}\n"
  }
}

fn import_gap(imports: String) -> String {
  case imports {
    "" -> ""
    _ -> "\n\n"
  }
}

fn load_imports(
  front: reader_front.Front,
  page: reader_front.Page,
  sources: List(LoadSource),
  include_layout: Bool,
  theme_background_blob: Bool,
  body: String,
) -> String {
  let html_body = string.replace(body, "raw_html.", "")
  let base =
    [
      #("css", "framework/front/css"),
      #("el", "framework/front/el as el"),
      #("sketch_css", "framework/front/sketch_css"),
      #("list", "gleam/list"),
      #("attribute", "lustre/attribute"),
      #("raw_html", "lustre/element/html as raw_html"),
      #("sketch", "sketch"),
      #("raw_css", "sketch/css as raw_css"),
      #("sketch_lustre", "sketch/lustre as sketch_lustre"),
      #("element", "sketch/lustre/element"),
      #("html", "sketch/lustre/element/html"),
      #("style", "style"),
    ]
    |> list.filter_map(fn(item) {
      let #(reference, path) = item
      let rendered = case path == "sketch/lustre/element/html" {
        True -> html_body
        False -> body
      }
      case module_alias_used(rendered, reference) {
        True -> Ok(path)
        False -> Error(Nil)
      }
    })
  let option_items =
    [
      #("type Option", "Option("),
      #("None", "None"),
      #("Some", "Some"),
    ]
    |> list.filter_map(fn(item) {
      let #(name, reference) = item
      case string.contains(body, reference) {
        True -> Ok(name)
        False -> Error(Nil)
      }
    })
  let option = case option_items {
    [] -> []
    _ -> ["gleam/option.{" <> string.join(option_items, ", ") <> "}"]
  }
  let base = list.append(base, option)
  let blob = case theme_background_blob {
    True -> ["framework/blob.{type Blob}", "media"]
    False -> []
  }
  let layout = case include_layout {
    True -> ["gen/load/layout"]
    False -> []
  }
  let blocks = case include_layout {
    True -> {
      let layout_placements = case front.layout.sp {
        Some(frame) -> frame.placements
        None -> []
      }
      let page_placements = case page.sp {
        Some(frame) -> frame.placements
        None -> []
      }
      placement_block_modules(
        front,
        list.append(layout_placements, page_placements),
      )
      |> list.map(fn(path) {
        block_import_path(path, load_source_service_names(sources))
      })
    }
    False -> []
  }
  let outs = list.map(sources, fn(source) { "gen/out/" <> source.service })
  list.unique(list.append(
    base,
    list.append(blob, list.append(layout, list.append(blocks, outs))),
  ))
  |> list.sort(string.compare)
  |> list.map(fn(path) {
    case string.starts_with(path, "gleam/option.{") {
      True -> "import " <> path
      False -> "import " <> path
    }
  })
  |> string.join("\n")
}

fn module_alias_used(body: String, alias: String) -> Bool {
  [" ", "\n", "(", "[", "{", ",", "=", ":", "->", "=>"]
  |> list.any(fn(prefix) { string.contains(body, prefix <> alias <> ".") })
}

fn placement_block_modules(
  front: reader_front.Front,
  placements: List(reader_front.Placement),
) -> List(String) {
  placements
  |> list.flat_map(fn(placement) {
    case placement {
      reader_front.Fixed(block: name, ..) -> [block_module(front, name)]
      reader_front.Widget(render: render, ..) ->
        case render {
          reader_front.One(name) -> [block_module(front, name)]
          reader_front.ByKind(table: table, ..) ->
            list.map(table, fn(row) { block_module(front, row.1) })
          reader_front.UnknownRender -> []
        }
    }
  })
  |> list.unique
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
  let fields = unique_load_sources(list.append(layout_sources, page_sources))
  "pub fn load(\n  vars: Vars,\n"
  <> string.concat(
    list.map(fields, fn(source) {
      "  " <> source.name <> ": " <> load_source_type(source) <> ",\n"
    }),
  )
  <> ") -> Data {\n  Data(\n    layout: layout.load("
  <> string.join(
    list.map(layout_sources, fn(source) {
      page_load_source_argument(source, fields)
    }),
    ", ",
  )
  <> "),\n    vars: vars,\n"
  <> string.concat(
    list.map(page_sources, fn(source) {
      "    "
      <> source.name
      <> ": "
      <> page_load_source_argument(source, fields)
      <> ",\n"
    }),
  )
  <> "  )\n}\n"
}

fn vars_type_text(
  vars: List(reader_front.Var),
  entries: List(reader_front.HttpEntry),
  face: String,
) -> String {
  let authenticated =
    list.any(entries, fn(entry) { entry.name == face && entry.authenticated })
  let fields =
    vars
    |> list.map(fn(var) {
      "    " <> var.name <> ": " <> vars_field_type(var, authenticated) <> ",\n"
    })
  case fields {
    [] -> "pub type Vars {\n  Vars\n}\n"
    _ -> "pub type Vars {\n  Vars(\n" <> string.concat(fields) <> "  )\n}\n"
  }
}

fn vars_field_type(var: reader_front.Var, authenticated: Bool) -> String {
  case var.from {
    reader_front.Query(_) -> "Option(String)"
    reader_front.Session(_) if !authenticated -> "Option(String)"
    _ -> "String"
  }
}

fn page_load_source_argument(
  source: LoadSource,
  parameters: List(LoadSource),
) -> String {
  case source.optional, load_source(parameters, source.key) {
    True, Some(parameter) if !parameter.optional -> "Some(" <> source.name <> ")"
    _, _ -> source.name
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
  let page_children = page_children_text(page, page_areas, page_placements)
  let page_helpers =
    placement_helpers_text(
      app,
      units,
      front,
      "layout_placement",
      layout_placements,
      layout_sources,
      "it.layout",
      "it.vars",
      front.layout.vars,
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
      "it.vars",
      list.append(page.vars, front.layout.vars),
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
  <> case has_overlay_area(list.append(layout_areas, page_areas)) {
    True -> overlay_area_text()
    False -> ""
  }
  <> page_helpers
}

fn has_plain_page_area(areas: List(reader_front.Area)) -> Bool {
  list.any(areas, fn(area) { area.name != "page" && area.style == [] })
}

fn has_overlay_area(areas: List(reader_front.Area)) -> Bool {
  list.any(areas, fn(area) { area.pin == "Overlay" })
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
  let body = area_element_text(area, children) <> ",\n"
  "    " <> body
}

fn page_children_text(
  page: reader_front.Page,
  areas: List(reader_front.Area),
  placements: List(reader_front.Placement),
) -> String {
  let expressions =
    list.flat_map(areas, fn(area) {
      let children =
        placement_children_expressions("page_placement", placements, area.name)
      case page_has_explicit_grid(page) {
        True -> [
          "["
          <> page_area_text(area, children_expression(children, None))
          <> "]",
        ]
        False ->
          case area.name {
            "page" -> children
            _ -> [
              "["
              <> page_area_text(area, children_expression(children, None))
              <> "]",
            ]
          }
      }
    })
  let children = case expressions {
    [] -> "[]"
    _ ->
      "list.flatten([\n"
      <> string.concat(
        list.map(expressions, fn(expression) { "    " <> expression <> ",\n" }),
      )
      <> "  ])"
  }
  case page_has_explicit_grid(page) {
    True ->
      "  [html.div_([attribute.attribute(\"data-yumemi-grid\", \""
      <> page_grid_name(page)
      <> "\")], "
      <> children
      <> ")]\n"
    False -> "  " <> children <> "\n"
  }
}

fn page_area_text(area: reader_front.Area, children: String) -> String {
  area_element_text(area, children)
}

fn area_element_text(area: reader_front.Area, children: String) -> String {
  case area.pin {
    "Overlay" ->
      "overlay_area(\""
      <> area.name
      <> "\", "
      <> style_expression(area.style)
      <> ", "
      <> children
      <> ")"
    _ ->
      case area.style {
        [] -> "plain_area(\"" <> area.name <> "\", " <> children <> ")"
        _ ->
          "styled_area(\""
          <> area.name
          <> "\", "
          <> style_expression(area.style)
          <> ", "
          <> children
          <> ")"
      }
  }
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

fn overlay_area_text() -> String {
  "fn overlay_area(\n"
  <> "  name: String,\n"
  <> "  styles: List(css.Style),\n"
  <> "  children: List(element.Element(Nil)),\n"
  <> ") -> element.Element(Nil) {\n"
  <> "  let attributes = [\n"
  <> "    attribute.attribute(\"id\", el.overlay_id_prefix <> name),\n"
  <> "    attribute.attribute(\"popover\", \"\"),\n"
  <> "    attribute.attribute(\"data-yumemi-area\", name),\n"
  <> "    attribute.attribute(\"data-yumemi-overlay\", \"\"),\n"
  <> "  ]\n"
  <> "  case styles {\n"
  <> "    [] -> html.div_(attributes, children)\n"
  <> "    _ -> html.div(sketch_css.class(styles), attributes, children)\n"
  <> "  }\n"
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
  vars_access: String,
  vars: List(reader_front.Var),
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
      vars_access,
      vars,
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
  vars_access: String,
  vars: List(reader_front.Var),
) -> String {
  let helper = prefix <> "_" <> int.to_string(index)
  let body = case placement {
    reader_front.Fixed(block: block_name, cell: cell, ..) ->
      fixed_placement_body(
        front,
        block_name,
        cell,
        sources,
        access,
        vars_access,
        vars,
      )
    reader_front.Widget(service: service_name, render: render, ..) ->
      widget_placement_body(
        app,
        units,
        front,
        helper,
        service_name,
        render,
        sources,
        access,
        vars_access,
        vars,
      )
  }
  let argument = case
    placement_uses_data(front, app.services, placement, sources)
  {
    True -> "it"
    False -> "_it"
  }
  let extra =
    placement_extra_text(app, units, front, prefix, index, placement, vars)
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
      case list.find(front.blocks, fn(block) { block.name == block_name }) {
        Ok(block) ->
          block.view_arity == 2
          || case block_source(front.blocks, block_name, services) {
            Some(service) -> load_source(sources, "service:" <> service) != None
            None -> False
          }
        Error(_) -> False
      }
    reader_front.Widget(service: service_name, ..) ->
      case service_module(services, service_name) {
        Some(service) -> load_source(sources, "service:" <> service) != None
        None -> False
      }
  }
}

fn fixed_placement_body(
  front: reader_front.Front,
  block_name: String,
  cell: reader_front.Cell,
  sources: List(LoadSource),
  access: String,
  vars_access: String,
  vars: List(reader_front.Var),
) -> String {
  let block_path = block_module(front, block_name)
  let service_names = load_source_service_names(sources)
  let view = block_module_reference(block_path, service_names) <> ".view"
  let children = case
    list.find(front.blocks, fn(block) { block.name == block_name })
  {
    Ok(block) -> {
      let arg = block_arg_suffix(front, block, vars, vars_access, service_names)
      case block.input_kind {
        reader_front.ServiceOut(service) ->
          case load_source(sources, "service:" <> service) {
            Some(source) -> source_view_list_with_arg(source, access, view, arg)
            None -> "[]"
          }
        reader_front.NilInput -> "[" <> view <> "(Nil" <> arg <> ")]"
        reader_front.OtherInput(_) -> "[" <> view <> "(Nil" <> arg <> ")]"
      }
    }
    Error(_) -> "[" <> view <> "(Nil)]"
  }
  case cell {
    reader_front.Flow -> "  " <> children
    reader_front.Span(cols:, rows:) ->
      fixed_cell_wrapper(
        children,
        "grid-column: span "
          <> int.to_string(cols)
          <> "; grid-row: span "
          <> int.to_string(rows)
          <> ";",
      )
    reader_front.At(col:, row:, span: reader_front.CellSpan(cols:, rows:)) ->
      fixed_cell_wrapper(
        children,
        "grid-column: "
          <> int.to_string(col)
          <> " / "
          <> int.to_string(col + cols)
          <> "; grid-row: "
          <> int.to_string(row)
          <> " / "
          <> int.to_string(row + rows)
          <> ";",
      )
  }
}

fn fixed_cell_wrapper(children: String, style: String) -> String {
  "  list.map(\n"
  <> indent_expression(children, "    ")
  <> ",\n"
  <> "    fn(child) {\n"
  <> "      html.div_([attribute.attribute(\"style\", "
  <> quoted(style)
  <> ")], [child])\n"
  <> "    },\n"
  <> "  )"
}

fn block_arg_suffix(
  front: reader_front.Front,
  block: reader_front.Block,
  vars: List(reader_front.Var),
  vars_access: String,
  service_names: List(String),
) -> String {
  case block.view_arity {
    2 ->
      ", "
      <> block_arg_expression(front, block, vars, vars_access, service_names)
    _ -> ""
  }
}

fn block_arg_expression(
  front: reader_front.Front,
  block: reader_front.Block,
  vars: List(reader_front.Var),
  vars_access: String,
  service_names: List(String),
) -> String {
  let fields =
    block.args
    |> list.map(fn(arg) {
      let value = case list.find(vars, fn(var) { var.name == arg.name }) {
        Ok(var) -> {
          let source = vars_access <> "." <> var.name
          case arg.type_, var_is_optional(var, front) {
            reader_front.OptionalStringArg, True -> source
            reader_front.OptionalStringArg, False -> "Some(" <> source <> ")"
            _, _ -> source
          }
        }
        Error(_) -> "Nil"
      }
      arg.name <> ": " <> value
    })
  block_module_reference(block.module, service_names)
  <> ".Arg("
  <> string.join(fields, ", ")
  <> ")"
}

fn var_is_optional(var: reader_front.Var, front: reader_front.Front) -> Bool {
  let authenticated =
    list.any(front.http_entries, fn(entry) {
      entry.name == front.face && entry.authenticated
    })
  case var.from {
    reader_front.Query(_) -> True
    reader_front.Session(_) if !authenticated -> True
    _ -> False
  }
}

fn indent_expression(expression: String, indent: String) -> String {
  indent <> string.replace(expression, "\n", "\n" <> indent)
}

fn widget_placement_body(
  app: model.App,
  units: List(Unit),
  front: reader_front.Front,
  helper: String,
  service_name: String,
  render: reader_front.Render,
  sources: List(LoadSource),
  access: String,
  vars_access: String,
  vars: List(reader_front.Var),
) -> String {
  case service_module(app.services, service_name) {
    None -> "  []"
    Some(service) ->
      case load_source(sources, "service:" <> service) {
        None -> "  []"
        Some(source) ->
          case render {
            reader_front.One(block_name) -> {
              let service_names =
                list.unique(
                  [service]
                  |> list.append(load_source_service_names(sources))
                  |> list.append(front.services),
                )
              let view =
                block_module_reference(
                  block_module(front, block_name),
                  service_names,
                )
                <> ".view"
              let arg = case
                list.find(front.blocks, fn(block) { block.name == block_name })
              {
                Ok(block) ->
                  block_arg_suffix(
                    front,
                    block,
                    vars,
                    vars_access,
                    service_names,
                  )
                Error(_) -> ""
              }
              source_view_list_with_arg(source, access, view, arg)
            }
            reader_front.ByKind(table: table, ..) -> {
              let rows_helper = "render_" <> helper
              let row_field = row_field_name(units, service)
              let vars_access = case block_rows_use_vars(front, table) {
                True -> vars_access
                False -> ""
              }
              source_rows_list(
                source,
                access,
                rows_helper,
                row_field,
                vars_access,
              )
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
  vars: List(reader_front.Var),
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
            vars,
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

fn source_view_list_with_arg(
  source: LoadSource,
  access: String,
  view: String,
  arg: String,
) -> String {
  let value = access <> "." <> source.name
  case source.optional {
    True ->
      "case "
      <> value
      <> " {\n    Some(out) -> ["
      <> view
      <> "(out"
      <> arg
      <> ")]\n    None -> []\n  }"
    False -> "[" <> view <> "(" <> value <> arg <> ")]"
  }
}

fn source_rows_list(
  source: LoadSource,
  access: String,
  helper: String,
  row_field: String,
  vars_access: String,
) -> String {
  let vars_argument = case vars_access {
    "" -> ""
    _ -> ", " <> vars_access
  }
  "  case "
  <> access
  <> "."
  <> source.name
  <> " {\n    Some(out) -> "
  <> helper
  <> "(out."
  <> row_field
  <> vars_argument
  <> ")\n    None -> []\n  }"
}

fn rows_helper_text(
  front: reader_front.Front,
  service: String,
  table: List(#(String, String)),
  state: State,
  helper: String,
  vars: List(reader_front.Var),
) -> String {
  let uses_vars = block_rows_use_vars(front, table)
  let vars_parameter = case uses_vars {
    True -> ", vars: Vars"
    False -> ""
  }
  let recursive_vars = case uses_vars {
    True -> ", vars"
    False -> ""
  }
  let out = module_ref("gen/out/" <> service)
  let rows =
    table
    |> list.map(fn(entry) {
      let #(key, block_name) = entry
      let constructor = row_constructor_name(state, service, key)
      let service_names = list.unique([service] |> list.append(front.services))
      let arg = case
        list.find(front.blocks, fn(block) { block.name == block_name })
      {
        Ok(block) -> block_arg_suffix(front, block, vars, "vars", service_names)
        Error(_) -> ""
      }
      "        "
      <> out
      <> "."
      <> constructor
      <> "(..) -> [\n          "
      <> block_module_reference(block_module(front, block_name), service_names)
      <> ".view(row"
      <> arg
      <> "),\n          .."
      <> helper
      <> "(rest"
      <> recursive_vars
      <> "),\n        ]\n"
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
  <> ".Row)"
  <> vars_parameter
  <> ") -> List(element.Element(Nil)) {\n"
  <> "  case rows {\n    [] -> []\n    [row, ..rest] ->\n      case row {\n"
  <> rows
  <> fallback
  <> "      }\n  }\n}"
}

fn block_rows_use_vars(
  front: reader_front.Front,
  table: List(#(String, String)),
) -> Bool {
  list.any(table, fn(row) {
    case list.find(front.blocks, fn(block) { block.name == row.1 }) {
      Ok(block) -> block.view_arity == 2
      Error(_) -> False
    }
  })
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

fn service_module_names(services: List(model.Service)) -> List(String) {
  list.map(services, fn(service) { service.module })
}

fn load_source_service_names(sources: List(LoadSource)) -> List(String) {
  list.map(sources, fn(source) { source.service }) |> list.unique
}

fn block_module_reference(path: String, service_names: List(String)) -> String {
  let name = last_segment(path)
  case list.contains(service_names, name) {
    True -> "block_" <> name
    False -> name
  }
}

fn block_import_path(path: String, service_names: List(String)) -> String {
  let name = last_segment(path)
  let reference = block_module_reference(path, service_names)
  case name == reference {
    True -> path
    False -> path <> " as " <> reference
  }
}

fn header(source: String, input_hash: String) -> String {
  "//// GENERATED from "
  <> source
  <> " [sha256:"
  <> input_hash
  <> "] — 手で編集しない\n"
}

fn js_header(source: String, input_hash: String) -> String {
  "// GENERATED from " <> source <> " [sha256:" <> input_hash <> "] — 手で編集しない"
}

fn route_text(
  face_name: String,
  pages: List(reader_front.Page),
  input_hash: String,
) -> String {
  let rows =
    pages
    |> list.map(fn(page) { reader_front.route_path(page.path) })
    |> list.sort(route_order)
    |> list.map(fn(path) { "  PageRoute(path: \"" <> path <> "\")," })
    |> string.join("\n")
  header(face_name <> "/src/pages/**/page.gleam", input_hash)
  <> "\npub type PageRoute {\n  PageRoute(path: String)\n}\n\n"
  <> "pub const routes: List(PageRoute) = [\n"
  <> rows
  <> "\n]\n"
}

/// route 表の順 ── 段ごとに比べ、同じ位置で literal の段を param の段より先に置く
/// (`/articles/new` は `/articles/:id` より先)。shell も門もこの順で最初に当たった Page を採る。
pub fn route_order(left: String, right: String) -> order.Order {
  route_segments_order(route_segments(left), route_segments(right))
}

fn route_segments(path: String) -> List(String) {
  string.split(path, "/") |> list.filter(fn(segment) { segment != "" })
}

fn route_segments_order(
  left: List(String),
  right: List(String),
) -> order.Order {
  case left, right {
    [], [] -> order.Eq
    [], _ -> order.Lt
    _, [] -> order.Gt
    [a, ..left_rest], [b, ..right_rest] -> {
      let a_param = string.starts_with(a, ":")
      let b_param = string.starts_with(b, ":")
      case a_param, b_param {
        False, True -> order.Lt
        True, False -> order.Gt
        _, _ ->
          case string.compare(a, b) {
            order.Eq -> route_segments_order(left_rest, right_rest)
            other -> other
          }
      }
    }
  }
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

fn api_text(
  face_name: String,
  app: model.App,
  hashes: hash.Hashes,
  front: reader_front.Front,
) -> String {
  let used = face_service_names(front)
  let routes =
    api_routes(app, hashes, face_name)
    |> list.filter(fn(route) { list.contains(used, route.service) })
  let attached_names = attached_names(front, app.attached)
  let attached_methods =
    app.attached
    |> list.map(fn(route) { method_variant(route.method) })
  let methods =
    list.append(
      routes |> list.map(fn(route) { method_variant(route.method) }),
      attached_methods,
    )
    |> list.unique
    |> list.sort(string.compare)
  let method_rows =
    string.join(list.map(methods, fn(name) { "  " <> name }), "\n")
  let rows = routes |> list.map(api_route_text) |> string.join("\n")
  let attached_rows =
    app.attached |> list.map(attached_route_text) |> string.join("\n")
  let api_hash = case app.attached {
    [] -> hash.entry(hashes)
    _ -> digest.short(hash.entry(hashes) <> string.inspect(app.attached))
  }
  header("src/entry.gleam", api_hash)
  <> "\nimport framework/front as front\nimport gen/service\n\n"
  <> enum_body("Method", method_rows)
  <> "\n"
  <> attached_type_text(attached_names)
  <> "pub type AttachedRoute {\n"
  <> "  AttachedRoute(entry: Attached, method: Method, path: String)\n"
  <> "}\n\n"
  <> "pub const attached: List(AttachedRoute) = [\n"
  <> attached_rows
  <> "\n]\n\n"
  <> "pub type Target = front.Target(service.Service, Attached)\n\n"
  <> "pub type Route {\n"
  <> "  Route(service: service.Service, method: Method, path: String)\n"
  <> "}\n\n"
  <> "pub const routes: List(Route) = [\n"
  <> rows
  <> "\n]\n"
}

/// 面の `api.gleam` に載せる Service ── 面が参照する(page の置き場・block・component の calls と
/// reload)ものだけ。面が呼ばない Service の route を載せない(www に `Put` が出ない)。
fn face_service_names(front: reader_front.Front) -> List(String) {
  list.append(
    front.services,
    list.flat_map(front.components, fn(component) {
      list.append(
        component_services(component),
        list.map(component.reloads, fn(reload) { reload.1 }),
      )
    }),
  )
  |> list.flat_map(fn(name) { [name, naming.snake(name)] })
  |> list.unique
}

fn attached_names(
  front: reader_front.Front,
  attached: List(model.AttachedRoute),
) -> List(String) {
  list.append(
    list.map(attached, fn(route) { route.name }),
    front.components
      |> list.flat_map(fn(component) {
        component.calls
        |> list.filter_map(fn(target) {
          case target {
            reader_front.AttachedCall(name) -> Ok(name)
            reader_front.ServiceCall(_) -> Error(Nil)
          }
        })
      }),
  )
  |> list.unique
  |> list.sort(string.compare)
}

fn attached_route_text(route: model.AttachedRoute) -> String {
  "  AttachedRoute(entry: "
  <> route.name
  <> ", method: "
  <> method_variant(route.method)
  <> ", path: "
  <> quoted(route.path)
  <> "),"
}

fn attached_type_text(names: List(String)) -> String {
  case names {
    [] -> "pub type Attached = Nil\n\n"
    _ ->
      "pub type Attached {\n"
      <> string.concat(list.map(names, fn(name) { "  " <> name <> "\n" }))
      <> "}\n\n"
  }
}

fn shell_text(
  app: model.App,
  units: List(Unit),
  package: face.Package,
  front: reader_front.Front,
  hashes: hash.Hashes,
) -> String {
  let decoder_services = shell_services(app, units, front)
  let source_hash =
    source_hash(package.units, fn(unit) {
      unit.path == "layout"
      || unit.path == "shell"
      || string.starts_with(unit.path, "pages/")
    })
  js_header(
    package.name
      <> "/src/{gen/route.gleam,gen/load/**,pages/**,layout.gleam,shell.gleam}",
    digest.short(hash.entry(hashes) <> source_hash),
  )
  <> "\n\n"
  <> shell_imports(decoder_services, front)
  <> "\n\n"
  <> shell_page_tables(app, units, front)
  <> "\n"
  <> shell_decoder_text(decoder_services)
  <> "\n"
  <> shell_runtime_text(
    front.components != [],
    static_grid_css(front.layout)
      <> static_pages_grid_css(front.pages)
      <> generated_front_css(front),
  )
}

fn gate_file(
  app: model.App,
  back_units: List(Unit),
  package: face.Package,
  front: reader_front.Front,
  hashes: hash.Hashes,
) -> File {
  let #(gate, _) = read_gate(app, back_units, package, front)
  let input_hash =
    digest.short(
      hash.entry(hashes)
      <> source_hash(package.units, fn(unit) {
        unit.path == "gate"
        || string.starts_with(unit.path, "pages/")
        && string.ends_with(unit.path, "/page")
      })
      <> string.inspect(gate.session_path),
    )
  File(
    path: package.name <> "/src/gen/gate.mjs",
    text: gate_emit.text(
      js_header(
        package.name
          <> "/src/{gate.gleam,pages/**} and src/{entry,server}.gleam",
        input_hash,
      ),
      gate,
      front_route_paths(front),
    ),
  )
}

fn read_gate(
  app: model.App,
  back_units: List(Unit),
  package: face.Package,
  front: reader_front.Front,
) -> #(reader_gate.Gate, List(stop.Note)) {
  reader_gate.read(
    package.name,
    package.units,
    back_units,
    app.entries,
    front_route_paths(front),
    session_path(app),
  )
}

/// 門が session を読む口 ── `attached_roles` の `ReadSession` が指す attached の path。
fn session_path(app: model.App) -> Option(String) {
  app.server.attached_roles
  |> list.find(fn(row) { row.role == "read_session" })
  |> result.try(fn(row) {
    list.find(app.attached, fn(route) {
      route.name == naming.pascal(row.attached)
    })
  })
  |> result.map(fn(route) { route.path })
  |> option.from_result
}

fn front_route_paths(front: reader_front.Front) -> List(String) {
  front.pages
  |> list.map(fn(page) { reader_front.route_path(page.path) })
  |> list.sort(route_order)
}

/// 門の宣言(`src/gate.gleam`)の診断。
pub fn gate_notes(
  app: model.App,
  back_units: List(Unit),
  package: face.Package,
  front: reader_front.Front,
) -> List(stop.Note) {
  read_gate(app, back_units, package, front).1
}

fn shell_imports(
  services: List(model.Service),
  front: reader_front.Front,
) -> String {
  let base = [
    "import {Some, Option$None$const} from \"../../gleam_stdlib/gleam/option.mjs\";",
    "import {Ok} from \"../gleam.mjs\";",
    "import {run as decodeRun} from \"../../gleam_stdlib/gleam/dynamic/decode.mjs\";",
    "import {to_document_string} from \"../../lustre/lustre/element.mjs\";",
    "import * as frontCss from \"../../yumemi/framework/front/css.mjs\";",
    "import * as api from \"./api.mjs\";",
    "import * as blocksPreview from \"./blocks_preview.mjs\";",
    "import * as gate from \"./gate.mjs\";",
    "import * as layoutDefinition from \"../layout.mjs\";",
    "import * as route from \"./route.mjs\";",
    "import * as service from \"./service.mjs\";",
  ]
  let outs =
    services
    |> list.map(fn(service) {
      "import * as out_"
      <> service.module
      <> " from \"./out/"
      <> service.module
      <> ".mjs\";"
    })
  let pages =
    front.pages
    |> list.index_map(fn(page, index) {
      [
        "import * as pageDefinition"
          <> int.to_string(index)
          <> " from \"../"
          <> page.module
          <> ".mjs\";",
        "import * as pageLoader"
          <> int.to_string(index)
          <> " from \"./load/"
          <> load_page_module_path(page.module)
          <> ".mjs\";",
      ]
    })
    |> list.flatten
  list.append(base, list.append(outs, pages))
  |> list.unique
  |> list.sort(string.compare)
  |> string.join("\n")
}

fn shell_services(
  app: model.App,
  units: List(Unit),
  front: reader_front.Front,
) -> List(model.Service) {
  let from_pages =
    front.pages
    |> list.flat_map(fn(page) {
      list.append(
        layout_sources(front.layout, front.blocks, app.services),
        page_sources(app, units, page, front.blocks, app.services),
      )
      |> list.map(fn(source) { source.service })
    })
  let from_components =
    front.components
    |> list.flat_map(fn(component) {
      list.append(
        component_services(component),
        list.map(component.reloads, fn(reload) { reload.1 }),
      )
      |> list.filter_map(fn(variant) {
        case service_for(app.services, variant) {
          Some(service) -> Ok(service.module)
          None -> Error(Nil)
        }
      })
    })
  let names = list.unique(list.append(from_pages, from_components))
  app.services
  |> list.filter(fn(service) { list.contains(names, service.module) })
}

fn shell_page_tables(
  app: model.App,
  units: List(Unit),
  front: reader_front.Front,
) -> String {
  let page_rows =
    front.pages
    |> list.index_map(fn(page, index) {
      "  ["
      <> quoted(reader_front.route_path(page.path))
      <> ", pageDefinition"
      <> int.to_string(index)
      <> ".page],"
    })
    |> string.join("\n")
  let spec_rows =
    front.pages
    |> list.index_map(fn(page, index) {
      let sources =
        unique_load_sources(list.append(
          layout_sources(front.layout, front.blocks, app.services),
          page_sources(app, units, page, front.blocks, app.services),
        ))
      "  ["
      <> quoted(reader_front.route_path(page.path))
      <> ", {\n"
      <> "    loader: pageLoader"
      <> int.to_string(index)
      <> ",\n"
      <> "    layout: layoutDefinition."
      <> js_export_name(front.layout.name)
      <> ",\n"
      <> "    vars: [\n"
      <> shell_var_rows(front, page)
      <> "    ],\n"
      <> "    givens: [\n"
      <> shell_given_rows(app, front, page)
      <> "    ],\n"
      <> "    sources: [\n"
      <> shell_source_rows(app, front, page, sources)
      <> "    ],\n"
      <> "  }],"
    })
    |> string.join("\n")
  "const pageRoutes = [...route.routes];\n"
  <> "const pages = new Map([\n"
  <> page_rows
  <> "\n]);\n"
  <> "const pageSpecs = new Map([\n"
  <> spec_rows
  <> "\n]);\n"
}

fn shell_given_rows(
  app: model.App,
  front: reader_front.Front,
  page: reader_front.Page,
) -> String {
  front.components
  |> list.filter_map(fn(component) {
    case component.reloads |> list.first |> option.from_result {
      Some(reload) ->
        case service_for(app.services, reload.1) {
          Some(service) ->
            Ok(
              "      { tag: "
              <> quoted(component_tag(component))
              <> ", service: service.Service$"
              <> naming.pascal(service.module)
              <> "$const, "
              <> shell_service_args(app, front, page, service.module)
              <> ", decoder: decode"
              <> naming.pascal(service.module)
              <> " },\n",
            )
          None -> Error(Nil)
        }
      None -> Error(Nil)
    }
  })
  |> string.concat
}

fn shell_var_rows(
  front: reader_front.Front,
  page: reader_front.Page,
) -> String {
  let vars = list.append(page.vars, front.layout.vars)
  let authenticated =
    list.any(front.http_entries, fn(entry) {
      entry.name == front.face && entry.authenticated
    })
  vars
  |> list.map(fn(var) {
    let optional = case var.from {
      reader_front.Query(_) -> True
      reader_front.Session(_) if !authenticated -> True
      _ -> False
    }
    "      { name: "
    <> quoted(var.name)
    <> ", optional: "
    <> bool_text(optional)
    <> ", from: "
    <> shell_var_source(var.from)
    <> " },\n"
  })
  |> string.concat
}

fn shell_var_source(source: reader_front.From) -> String {
  case source {
    reader_front.Path(name) ->
      "{ type: \"path\", name: " <> quoted(name) <> " }"
    reader_front.Query(name) ->
      "{ type: \"query\", name: " <> quoted(name) <> " }"
    reader_front.Session(name) ->
      "{ type: \"session\", name: " <> quoted(name) <> " }"
    reader_front.Origin(face) ->
      "{ type: \"origin\", name: " <> quoted(face) <> " }"
    reader_front.AuthOrigin -> "{ type: \"auth-origin\" }"
    reader_front.InvalidFrom(_) -> "{ type: \"invalid\" }"
  }
}

fn js_export_name(name: String) -> String {
  case name {
    "public" -> "public$"
    "private" -> "private$"
    "default" -> "default$"
    _ -> name
  }
}

fn shell_source_rows(
  app: model.App,
  front: reader_front.Front,
  page: reader_front.Page,
  sources: List(LoadSource),
) -> String {
  sources
  |> list.map(fn(source) {
    case source.type_name == "PageTheme" {
      True -> "      { theme: true },\n"
      False -> {
        "      { service: service.Service$"
        <> naming.pascal(source.service)
        <> "$const, "
        <> shell_service_args(app, front, page, source.service)
        <> ", decoder: decode"
        <> naming.pascal(source.service)
        <> ", optional: "
        <> bool_text(source.optional)
        <> ", root: "
        <> bool_text(!source.optional)
        <> " },\n"
      }
    }
  })
  |> string.concat
}

fn shell_service_args(
  app: model.App,
  front: reader_front.Front,
  page: reader_front.Page,
  service_name: String,
) -> String {
  let args = case
    list.find(front.page_service_args, fn(item) { item.page == page.module })
  {
    Ok(reader_front.PageServiceArgs(services: services, ..)) ->
      case list.find(services, fn(item) { item.service == service_name }) {
        Ok(reader_front.ServiceArgs(args: args, ..)) -> args
        Error(_) -> []
      }
    Error(_) -> []
  }
  "args: ["
  <> string.join(
    list.map(args, fn(arg) {
      case arg.source {
        reader_front.VariableSource(name: var_name, ..) ->
          "["
          <> quoted(arg.name)
          <> ", "
          <> quoted(var_name)
          <> ", "
          <> bool_text(service_arg_optional(app, service_name, arg.name))
          <> "]"
      }
    }),
    ", ",
  )
  <> "]"
}

fn service_arg_optional(
  app: model.App,
  service_name: String,
  arg_name: String,
) -> Bool {
  case list.find(app.services, fn(service) { service.module == service_name }) {
    Ok(service) ->
      case list.find(service.args, fn(arg) { arg.name == arg_name }) {
        Ok(model.Arg(type_: model.NamedShape(name: "Option", ..), ..)) -> True
        _ -> False
      }
    Error(_) -> False
  }
}

fn bool_text(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

fn style_text(package: face.Package, front: reader_front.Front) -> String {
  let input_hash =
    source_hash(package.units, fn(unit) {
      unit.path == "layout" || string.starts_with(unit.path, "pages/")
    })
  "/* GENERATED from "
  <> package.name
  <> "/src/layout.gleam [sha256:"
  <> input_hash
  <> "] — 手で編集しない */\n"
  <> static_grid_css(front.layout)
  <> static_pages_grid_css(front.pages)
  <> generated_front_css(front)
}

fn generated_front_css(front: reader_front.Front) -> String {
  badge_css()
  <> case front_has_overlay(front) {
    True -> "[popover]::backdrop { background: rgba(0, 0, 0, 0.45); }\n"
    False -> ""
  }
}

fn badge_css() -> String {
  "[data-yumemi-badge] {\n"
  <> "  position: absolute;\n"
  <> "  inset-block-start: 0;\n"
  <> "  inset-inline-end: 0;\n"
  <> "  display: inline-flex;\n"
  <> "  align-items: center;\n"
  <> "  justify-content: center;\n"
  <> "  min-width: 1.25rem;\n"
  <> "  height: 1.25rem;\n"
  <> "  padding-inline: 0.25rem;\n"
  <> "  border-radius: 999px;\n"
  <> "  color: var(--bg);\n"
  <> "  background: var(--accent);\n"
  <> "  font: 600 0.75rem/1 system-ui, sans-serif;\n"
  <> "}\n"
  <> "[data-yumemi-badge][data-count=\"\"],\n"
  <> "[data-yumemi-badge][data-count=\"0\"] { display: none; }\n"
}

fn front_has_overlay(front: reader_front.Front) -> Bool {
  let layout_frames =
    option_frame_list(front.layout.sp)
    |> list.append(option_frame_list(front.layout.pc))
    |> list.append(option_frame_list(front.layout.tablet))
  let page_frames =
    front.pages
    |> list.flat_map(fn(page) {
      option_frame_list(page.sp)
      |> list.append(option_frame_list(page.pc))
      |> list.append(option_frame_list(page.tablet))
    })
  list.any(list.append(layout_frames, page_frames), fn(frame) {
    list.any(frame.areas, fn(area) { area.pin == "Overlay" })
  })
}

fn static_grid_css(layout: reader_front.Layout) -> String {
  static_frames_grid_css(
    "[data-yumemi-grid=\"layout\"]",
    layout.sp,
    layout.pc,
    layout.tablet,
  )
}

fn static_pages_grid_css(pages: List(reader_front.Page)) -> String {
  pages
  |> list.filter(page_has_explicit_grid)
  |> list.map(fn(page) {
    static_frames_grid_css(
      "[data-yumemi-grid=\"" <> page_grid_name(page) <> "\"]",
      page.sp,
      page.pc,
      page.tablet,
    )
  })
  |> string.concat
}

fn static_frames_grid_css(
  selector: String,
  sp: Option(reader_front.Frame),
  pc: Option(reader_front.Frame),
  tablet: Option(reader_front.Frame),
) -> String {
  let sp_frame = option.unwrap(sp, empty_frame("sp"))
  let sp_areas = without_overlay_areas(sp_frame.areas)
  let pc_areas = frame_areas(pc, sp_areas)
  let tablet_areas = frame_areas(tablet, sp_areas)
  let extras =
    list.append(
      list.map(pc_areas, fn(area) { area.name }),
      list.map(tablet_areas, fn(area) { area.name }),
    )
    |> list.unique
    |> list.filter(fn(name) {
      !list.any(sp_areas, fn(area) { area.name == name })
    })
  let base_rules =
    list.append(
      list.map(sp_areas, fn(area) { static_area_rule(selector, area, "normal") }),
      list.filter_map(extras, fn(name) {
        case list.find(pc_areas, fn(area) { area.name == name }) {
          Ok(area) -> Ok(static_area_rule(selector, area, "hidden"))
          Error(_) ->
            case list.find(tablet_areas, fn(area) { area.name == name }) {
              Ok(area) -> Ok(static_area_rule(selector, area, "hidden"))
              Error(_) -> Error(Nil)
            }
        }
      }),
    )
    |> string.join("\n")
  let base =
    "\n"
    <> selector
    <> " {\n"
    <> "  display: grid;\n"
    <> "  grid-template-columns: "
    <> frame_columns_css(sp_frame, framework_css.SP)
    <> ";\n"
    <> frame_rows_css(sp_frame, "  ")
    <> "  grid-template-areas: "
    <> frame_template_css(sp_frame, sp_frame, framework_css.SP)
    <> ";\n"
    <> "  gap: 0;\n}\n"
    <> base_rules
    <> "\n"
  let tablet = case tablet {
    Some(frame) ->
      static_media_block(
        "tablet",
        static_frame_body(
          selector,
          frame,
          tablet_areas,
          sp_areas,
          frame_template_css(sp_frame, frame, framework_css.Tablet),
          framework_css.Tablet,
        ),
      )
    None -> ""
  }
  let pc = case pc {
    Some(frame) ->
      static_media_block(
        "pc",
        static_frame_body(
          selector,
          frame,
          pc_areas,
          sp_areas,
          frame_template_css(sp_frame, frame, framework_css.PC),
          framework_css.PC,
        ),
      )
    None -> ""
  }
  base <> tablet <> pc
}

fn empty_frame(media: String) -> reader_front.Frame {
  reader_front.Frame(
    media: media,
    areas: [],
    placements: [],
    cols: [],
    rows: [],
    template: [],
  )
}

fn frame_columns_css(
  frame: reader_front.Frame,
  at: framework_css.Breakpoint,
) -> String {
  let resolved = framework_front.resolved_cols(framework_frame(frame), at)
  case frame.cols {
    [] ->
      case at {
        framework_css.SP -> "minmax(0, 1fr)"
        _ ->
          case resolved {
            [_, ..rest] -> {
              let rest_css =
                rest |> list.map(framework_track_css) |> string.join(" ")
              "minmax(0, 1fr) " <> rest_css
            }
            [] -> "minmax(0, 1fr)"
          }
      }
    _ -> resolved |> list.map(framework_track_css) |> string.join(" ")
  }
}

fn frame_rows_css(frame: reader_front.Frame, indent: String) -> String {
  case frame.rows {
    [] -> ""
    rows -> {
      let row_css = rows |> list.map(track_css) |> string.join(" ")
      indent <> "grid-template-rows: " <> row_css <> ";\n"
    }
  }
}

fn frame_template_css(
  sp: reader_front.Frame,
  frame: reader_front.Frame,
  at: framework_css.Breakpoint,
) -> String {
  framework_front.resolved_template(
    framework_frame(frame_without_overlay(sp)),
    framework_frame(frame_without_overlay(frame)),
    at,
  )
  |> list.map(fn(row) { "\"" <> string.join(row, " ") <> "\"" })
  |> string.join(" ")
}

fn frame_without_overlay(frame: reader_front.Frame) -> reader_front.Frame {
  reader_front.Frame(..frame, areas: without_overlay_areas(frame.areas))
}

fn without_overlay_areas(
  areas: List(reader_front.Area),
) -> List(reader_front.Area) {
  list.filter(areas, fn(area) { area.pin != "Overlay" })
}

fn framework_frame(
  frame: reader_front.Frame,
) -> framework_front.Frame(Nil, Nil) {
  framework_front.Frame(
    areas: list.map(frame.areas, fn(area) {
      framework_front.Area(
        name: area.name,
        flow: framework_css.Stack(gap: framework_css.Px(0.0)),
        pin: framework_css.NoPin,
        style: [],
      )
    }),
    placements: [],
    cols: list.map(frame.cols, framework_track_of),
    rows: list.map(frame.rows, framework_track_of),
    template: frame.template,
  )
}

fn framework_track_of(track: reader_front.Track) -> framework_track.Track {
  case track {
    reader_front.Auto -> framework_track.Auto
    reader_front.Fr(value) -> framework_track.Fr(value)
    reader_front.Rem(value) -> framework_track.Rem(value)
    reader_front.Px(value) -> framework_track.Px(value)
    reader_front.Minmax(min:, max:) ->
      framework_track.Minmax(
        min: framework_track_size_of(min),
        max: framework_track_size_of(max),
      )
  }
}

fn framework_track_size_of(
  size: reader_front.TrackSize,
) -> framework_track.TrackSize {
  case size {
    reader_front.AutoSize -> framework_track.AutoSize
    reader_front.FrSize(value) -> framework_track.FrSize(value)
    reader_front.RemSize(value) -> framework_track.RemSize(value)
    reader_front.PxSize(value) -> framework_track.PxSize(value)
  }
}

fn track_css(track: reader_front.Track) -> String {
  framework_track_css(framework_track_of(track))
}

fn framework_track_css(track: framework_track.Track) -> String {
  framework_track.to_css(track)
  |> string.replace(".0rem", "rem")
  |> string.replace(".0px", "px")
}

fn length_css(length: reader_front.Length) -> String {
  case length {
    reader_front.RemLength(value) -> float.to_string(value) <> "rem"
    reader_front.PxLength(value) -> float.to_string(value) <> "px"
  }
}

fn page_grid_name(page: reader_front.Page) -> String {
  "page:" <> page.module
}

fn page_has_explicit_grid(page: reader_front.Page) -> Bool {
  list.any(
    list.append(
      option_frame_list(page.sp),
      list.append(option_frame_list(page.pc), option_frame_list(page.tablet)),
    ),
    fn(frame) {
      frame.cols != []
      || frame.rows != []
      || frame.template != []
      || list.any(frame.areas, fn(area) {
        area.pin != "Overlay" && area.grid_tracks != None
      })
      || list.any(frame.placements, fn(placement) {
        case placement {
          reader_front.Fixed(area:, cell: reader_front.Flow, ..) ->
            !area_is_overlay(frame, area)
          reader_front.Fixed(area:, ..) -> !area_is_overlay(frame, area)
          reader_front.Widget(area:, ..) -> !area_is_overlay(frame, area)
        }
      })
    },
  )
}

fn option_frame_list(
  value: Option(reader_front.Frame),
) -> List(reader_front.Frame) {
  case value {
    Some(frame) -> [frame]
    None -> []
  }
}

fn frame_areas(
  frame: Option(reader_front.Frame),
  fallback: List(reader_front.Area),
) -> List(reader_front.Area) {
  case frame {
    Some(value) -> without_overlay_areas(value.areas)
    None -> without_overlay_areas(fallback)
  }
}

fn area_is_overlay(frame: reader_front.Frame, name: String) -> Bool {
  list.any(frame.areas, fn(area) { area.name == name && area.pin == "Overlay" })
}

fn static_frame_body(
  selector: String,
  frame: reader_front.Frame,
  areas: List(reader_front.Area),
  base_areas: List(reader_front.Area),
  template: String,
  at: framework_css.Breakpoint,
) -> String {
  let rules =
    areas
    |> list.map(fn(area) {
      let visibility = case
        list.any(base_areas, fn(candidate) { candidate.name == area.name })
      {
        True -> "normal"
        False -> "visible"
      }
      static_area_rule(selector, area, visibility)
    })
    |> string.join("\n")
  "  "
  <> selector
  <> " {\n"
  <> "    grid-template-columns: "
  <> frame_columns_css(frame, at)
  <> ";\n"
  <> frame_rows_css(frame, "    ")
  <> "    grid-template-areas: "
  <> template
  <> ";\n"
  <> "  }\n"
  <> rules
}

fn static_media_block(media: String, body: String) -> String {
  let query = case media {
    "tablet" -> "@media (min-width: 768px) and (max-width: 1023px)"
    _ -> "@media (min-width: 1024px)"
  }
  query <> " {\n" <> body <> "\n}\n"
}

fn static_area_rule(
  selector: String,
  area: reader_front.Area,
  visibility: String,
) -> String {
  let base = [selector <> " > [data-yumemi-area=\"" <> area.name <> "\"] {"]
  let grid_area = case area.pin {
    "Overlay" -> []
    _ -> ["  grid-area: " <> area.name <> ";"]
  }
  let grid_tracks = case area.grid_tracks {
    Some(reader_front.GridTracks(cols:, gap: gap)) -> [
      "  display: grid;",
      "  grid-template-columns: "
        <> string.join(list.map(cols, track_css), " ")
        <> ";",
      "  gap: " <> length_css(gap) <> ";",
    ]
    None -> []
  }
  let visible = case visibility {
    "hidden" -> ["  display: none;"]
    "visible" -> ["  display: block;"]
    _ -> []
  }
  let pin = case area.pin {
    "Top" -> [
      "  position: sticky;",
      "  top: env(safe-area-inset-top);",
      "  z-index: 3;",
    ]
    "Bottom" -> [
      "  position: sticky;",
      "  bottom: env(safe-area-inset-bottom);",
      "  z-index: 3;",
    ]
    _ -> []
  }
  string.join(
    list.append(
      base,
      list.append(
        grid_area,
        list.append(grid_tracks, list.append(visible, list.append(pin, ["}"]))),
      ),
    ),
    "\n",
  )
}

fn shell_decoder_text(services: List(model.Service)) -> String {
  services
  |> list.sort(fn(left, right) { string.compare(left.module, right.module) })
  |> list.map(fn(service) {
    "function decode"
    <> naming.pascal(service.module)
    <> "(raw) {\n"
    <> "  const decoded = decodeRun(raw, out_"
    <> service.module
    <> ".decoder());\n"
    <> "  if (!(decoded instanceof Ok)) throw new Error(\"invalid "
    <> service.module
    <> " response\");\n"
    <> "  return decoded[0];\n"
    <> "}\n"
  })
  |> string.concat
}

fn shell_runtime_text(include_client: Bool, grid_css: String) -> String {
  "function areaNames(areas) {\n"
  <> "  return areas.map((area) => area.name);\n"
  <> "}\n\n"
  <> "function gridTemplateAreas(areas) {\n"
  <> "  return areas.map((area) => '\"' + area.name + '\"').join(\" \");\n"
  <> "}\n\n"
  <> "function pcGridTemplateAreas(spAreas, pcAreas) {\n"
  <> "  const spNames = new Set(areaNames(spAreas));\n"
  <> "  const pcOnlyNames = new Set(pcAreas.filter((area) => !spNames.has(area.name)).map((area) => area.name));\n"
  <> "  const columns = pcOnlyNames.size + 1;\n"
  <> "  return spAreas.map((area) => {\n"
  <> "    const row = [area.name];\n"
  <> "    const pcIndex = pcAreas.findIndex((candidate) => candidate.name === area.name);\n"
  <> "    let next = pcIndex + 1;\n"
  <> "    while (next < pcAreas.length && pcOnlyNames.has(pcAreas[next].name)) {\n"
  <> "      row.push(pcAreas[next].name);\n"
  <> "      next += 1;\n"
  <> "    }\n"
  <> "    while (row.length < columns) row.push(area.name);\n"
  <> "    return '\"' + row.join(\" \") + '\"';\n"
  <> "  }).join(\" \");\n"
  <> "}\n\n"
  <> "function areaRule(area, visibility) {\n"
  <> "  const rules = [\n"
  <> "    '[data-yumemi-grid=\"layout\"] > [data-yumemi-area=\"' + area.name + '\"] {',\n"
  <> "    '  grid-area: ' + area.name + ';',\n"
  <> "  ];\n"
  <> "  if (visibility === \"hidden\") rules.push(\"  display: none;\");\n"
  <> "  if (visibility === \"visible\") rules.push(\"  display: block;\");\n"
  <> "  if (frontCss.Pin$isTop(area.pin)) {\n"
  <> "    rules.push(\"  position: sticky;\", \"  top: env(safe-area-inset-top);\", \"  z-index: 3;\");\n"
  <> "  }\n"
  <> "  if (frontCss.Pin$isBottom(area.pin)) {\n"
  <> "    rules.push(\"  position: sticky;\", \"  bottom: env(safe-area-inset-bottom);\", \"  z-index: 3;\");\n"
  <> "  }\n"
  <> "  rules.push(\"}\");\n"
  <> "  return rules.join(\"\\n\");\n"
  <> "}\n\n"
  <> "function frameValue(value, fallback) {\n"
  <> "  return value instanceof Some ? value[0] : fallback;\n"
  <> "}\n\n"
  <> "function mediaBlock(media, body) {\n"
  <> "  const query = media === \"tablet\"\n"
  <> "    ? \"@media (min-width: 768px) and (max-width: 1023px)\"\n"
  <> "    : \"@media (min-width: 1024px)\";\n"
  <> "  return query + \" {\\n\" + body + \"\\n}\\n\";\n"
  <> "}\n\n"
  <> "function gridCssFromLayout(_layout) {\n"
  <> "  return "
  <> quoted(grid_css)
  <> ";\n"
  <> "}\n\n"
  <> "function matchPage(pathname) {\n"
  <> "  for (const pageRoute of pageRoutes) {\n"
  <> "    const expected = pageRoute.path.split(\"/\");\n"
  <> "    const actual = pathname.split(\"/\");\n"
  <> "    if (expected.length !== actual.length) continue;\n"
  <> "    const params = {};\n"
  <> "    let matches = true;\n"
  <> "    for (let index = 0; index < expected.length; index += 1) {\n"
  <> "      const segment = expected[index];\n"
  <> "      const value = actual[index];\n"
  <> "      if (segment.startsWith(\":\")) params[segment.slice(1)] = decodeURIComponent(value);\n"
  <> "      else if (segment !== value) matches = false;\n"
  <> "    }\n"
  <> "    if (matches && pages.has(pageRoute.path)) {\n"
  <> "      return {path: pageRoute.path, definition: pages.get(pageRoute.path), spec: pageSpecs.get(pageRoute.path), params};\n"
  <> "    }\n"
  <> "  }\n"
  <> "  return null;\n"
  <> "}\n\n"
  <> "function apiPathFor(serviceValue) {\n"
  <> "  const entry = [...api.routes].find((item) => item.service === serviceValue);\n"
  <> "  if (!entry) throw new Error(\"missing front API route\");\n"
  <> "  return entry.path;\n"
  <> "}\n\n"
  <> "function argsFor(vars, mapping) {\n"
  <> "  return Object.fromEntries(mapping.map(([name, field, optional]) => {\n"
  <> "    const value = vars[field];\n"
  <> "    return [name, optional && typeof value === \"string\" ? new Some(value) : value];\n"
  <> "  }));\n"
  <> "}\n\n"
  <> "async function readFromApp(app, request, serviceValue, args) {\n"
  <> "  const used = new Set();\n"
  <> "  const path = apiPathFor(serviceValue).replace(/:([A-Za-z0-9_]+)/g, (_, name) => {\n"
  <> "    used.add(name);\n"
  <> "    const arg = args[name];\n"
  <> "    const value = arg instanceof Some ? arg[0] : arg;\n"
  <> "    if (typeof value !== \"string\") throw new Error(\"missing service path arg: \" + name);\n"
  <> "    return encodeURIComponent(value);\n"
  <> "  });\n"
  <> "  const target = new URL(path, request.url);\n"
  <> "  for (const [name, arg] of Object.entries(args)) {\n"
  <> "    if (used.has(name)) continue;\n"
  <> "    const value = arg instanceof Some ? arg[0] : arg;\n"
  <> "    if (typeof value === \"string\") target.searchParams.set(name, value);\n"
  <> "  }\n"
  <> "  return app.fetch(new Request(target, request));\n"
  <> "}\n\n"
  <> "function pageTheme(definition, root) {\n"
  <> "  if (!(definition.theme instanceof Some)) return Option$None$const;\n"
  <> "  return root[definition.theme[0]] ?? Option$None$const;\n"
  <> "}\n\n"
  <> "function failure(status, body) {\n"
  <> "  return new Response(body, {status, headers: {\"content-type\": \"text/plain; charset=utf-8\"}});\n"
  <> "}\n\n"
  <> "async function renderPage(request, env, matched, gateSession) {\n"
  <> "  const vars = {};\n"
  <> "  const query = new URL(request.url).searchParams;\n"
  <> "  let sessionLoaded = gateSession !== undefined;\n"
  <> "  let session = gateSession ?? null;\n"
  <> "  for (const field of matched.spec.vars) {\n"
  <> "    const source = field.from;\n"
  <> "    let value;\n"
  <> "    if (source.type === \"path\") {\n"
  <> "      value = matched.params[source.name];\n"
  <> "    } else if (source.type === \"query\") {\n"
  <> "      const found = query.get(source.name);\n"
  <> "      value = found === null || found.trim() === \"\" ? Option$None$const : new Some(found);\n"
  <> "    } else if (source.type === \"origin\") {\n"
  <> "      const envName = \"PUBLIC_\" + source.name.toUpperCase() + \"_ORIGIN\";\n"
  <> "      const origin = env[envName];\n"
  <> "      if (typeof origin !== \"string\" || origin.length === 0) return failure(500, envName);\n"
  <> "      value = origin;\n"
  <> "    } else if (source.type === \"auth-origin\") {\n"
  <> "      const envName = \"PUBLIC_IDP_ORIGIN\";\n"
  <> "      const origin = env[envName];\n"
  <> "      if (typeof origin !== \"string\" || origin.length === 0) return failure(500, envName);\n"
  <> "      value = origin;\n"
  <> "    } else if (source.type === \"session\") {\n"
  <> "      if (!sessionLoaded) {\n"
  <> "        sessionLoaded = true;\n"
  <> "        try {\n"
  <> "          const target = new URL(\"/api/session\", request.url);\n"
  <> "          const response = await env.APP.fetch(new Request(target, request));\n"
  <> "          if (response.ok) session = await response.json();\n"
  <> "        } catch (_) {\n"
  <> "          session = null;\n"
  <> "        }\n"
  <> "      }\n"
  <> "      const subject = session?.anonymous === true ? undefined : session?.subject;\n"
  <> "      const found = source.name === \"SubjectHandle\" ? subject?.handle : subject?.id;\n"
  <> "      if (typeof found === \"string\") value = field.optional ? new Some(found) : found;\n"
  <> "      else if (field.optional) value = Option$None$const;\n"
  <> "      else return failure(401, \"unauthorized\");\n"
  <> "    } else {\n"
  <> "      return failure(500, \"invalid variable source\");\n"
  <> "    }\n"
  <> "    vars[field.name] = value;\n"
  <> "  }\n"
  <> "  const values = [vars];\n"
  <> "  let root = null;\n"
  <> "  for (const source of matched.spec.sources) {\n"
  <> "    if (source.theme) {\n"
  <> "      values.push(pageTheme(matched.definition, root));\n"
  <> "      continue;\n"
  <> "    }\n"
  <> "    const response = await readFromApp(env.APP, request, source.service, argsFor(vars, source.args));\n"
  <> "    if (!response.ok) {\n"
  <> "      if (response.status === 403) return failure(403, \"adult declaration required\");\n"
  <> "      if (response.status === 404 && !source.root) { values.push(Option$None$const); continue; }\n"
  <> "      if (response.status === 404) return failure(404, \"muse not found\");\n"
  <> "      return failure(response.status, source.root ? \"root read failed\" : \"widget read failed\");\n"
  <> "    }\n"
  <> "    const decoded = source.decoder(await response.json());\n"
  <> "    if (source.root) root = decoded;\n"
  <> "    values.push(source.optional ? new Some(decoded) : decoded);\n"
  <> "  }\n"
  <> "  const givens = [];\n"
  <> "  for (const given of matched.spec.givens) {\n"
  <> "    const response = await readFromApp(env.APP, request, given.service, argsFor(vars, given.args));\n"
  <> "    if (!response.ok) continue;\n"
  <> "    const raw = await response.json();\n"
  <> "    given.decoder(raw);\n"
  <> "    givens.push({tag: given.tag, raw});\n"
  <> "  }\n"
  <> "  const html = to_document_string(matched.spec.loader.render(matched.spec.loader.load(...values)));\n"
  <> "  const withGivens = addGivenAttributes(html, givens);\n"
  <> "  return new Response(htmlWithGridCss(withGivens, matched.spec.layout), {status: 200, headers: {\"content-type\": \"text/html; charset=utf-8\"}});\n"
  <> "}\n\n"
  <> "function addGivenAttributes(html, givens) {\n"
  <> "  let output = html;\n"
  <> "  for (const given of givens) {\n"
  <> "    let searchFrom = 0;\n"
  <> "    const marker = `<${given.tag} `;\n"
  <> "    let markerOffset = output.indexOf(marker, searchFrom);\n"
  <> "    while (markerOffset >= 0) {\n"
  <> "      const tagEnd = output.indexOf(\">\", markerOffset + marker.length);\n"
  <> "      if (tagEnd < 0) break;\n"
  <> "      const tagText = output.slice(markerOffset, tagEnd);\n"
  <> "      searchFrom = tagEnd + 1;\n"
  <> "      if (tagText.includes(\"data-yumemi-given\")) {\n"
  <> "        markerOffset = output.indexOf(marker, searchFrom);\n"
  <> "        continue;\n"
  <> "      }\n"
  <> "      const encoded = JSON.stringify(given.raw).replaceAll(\"&\", \"&amp;\").replaceAll(\"\\\"\", \"&quot;\").replaceAll(\"<\", \"&lt;\");\n"
  <> "      const before = output.slice(0, markerOffset);\n"
  <> "      const fromMarker = output.slice(markerOffset);\n"
  <> "      output = before + fromMarker.replace(marker, () => `<${given.tag} data-yumemi-given=\"${encoded}\" `);\n"
  <> "      searchFrom = markerOffset + `<${given.tag} data-yumemi-given=\"${encoded}\" `.length;\n"
  <> "      break;\n"
  <> "    }\n"
  <> "  }\n"
  <> "  return output;\n"
  <> "}\n\n"
  <> "function htmlWithGridCss(html, layout) {\n"
  <> "  const marker = \"<style>\";\n"
  <> "  const offset = html.indexOf(marker);\n"
  <> "  if (offset < 0) throw new Error(\"SSR stylesheet is missing\");\n"
  <> "  const insertion = offset + marker.length;\n"
  <> "  const rendered = html.slice(0, insertion) + gridCssFromLayout(layout) + html.slice(insertion);\n"
  <> case include_client {
    True ->
      "  return rendered.replace(\"</head>\", '<script type=\"module\" src=\"/_yumemi/client.mjs\"></script></head>');\n"
    False -> "  return rendered;\n"
  }
  <> "}\n\n"
  <> "\n\nfunction renderBlocksPreview() {\n"
  <> "  const html = to_document_string(blocksPreview.render());\n"
  <> "  const withStyle = html.includes(\"<style>\")\n"
  <> "    ? html\n"
  <> "    : html.replace(\"<head>\", \"<head><style></style>\");\n"
  <> "  return new Response(withStyle.replace(\"</head>\", '<script type=\"module\" src=\"/_yumemi/client.mjs\"></script></head>'), {status: 200, headers: {\"content-type\": \"text/html; charset=utf-8\"}});\n"
  <> "}\n\n"
  <> "export default gate.serve(async (request, env, before) => {\n"
  <> "  if (new URL(request.url).pathname === \"/_blocks\" && env.YUMEMI_DEV === \"1\") return renderBlocksPreview();\n"
  <> "  const matched = matchPage(new URL(request.url).pathname);\n"
  <> "  if (!matched) {\n"
  <> "    if (env.SVELTE) return env.SVELTE.fetch(request);\n"
  <> "    return failure(404, \"page not found\");\n"
  <> "  }\n"
  <> "  return renderPage(request, env, matched, before.session);\n"
  <> "});\n"
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
  _hashes: hash.Hashes,
  face_name: String,
) -> List(ApiRoute) {
  entry.routes(app)
  |> list.filter(fn(route) { route.face == face_name })
  |> list.map(fn(route) {
    ApiRoute(
      service: route.service,
      method: route.method,
      path: colon_path(route.path),
    )
  })
}

pub fn route_notes(
  app: model.App,
  package_name: String,
  front: reader_front.Front,
  hashes: hash.Hashes,
) -> List(stop.Note) {
  let routes = api_routes(app, hashes, package_name)
  front.components
  |> list.flat_map(fn(component) {
    list.append(
      component_services(component),
      list.map(component.reloads, fn(reload) { reload.1 }),
    )
    |> list.unique
    |> list.filter_map(fn(variant) {
      case service_for(app.services, variant) {
        Some(service) ->
          case
            list.find(routes, fn(route) { route.service == service.module })
          {
            Ok(_) -> Error(Nil)
            Error(_) ->
              Ok(stop.Note(
                class: stop.Conflict,
                text: package_name
                  <> "/"
                  <> component.module
                  <> ": calls の Service "
                  <> service.module
                  <> " に api.gleam の route が無い",
              ))
          }
        None -> Error(Nil)
      }
    })
  })
}

fn api_route_for(
  app: model.App,
  hashes: hash.Hashes,
  face_name: String,
  service: String,
) -> Option(ApiRoute) {
  api_routes(app, hashes, face_name)
  |> list.find(fn(route) { route.service == service })
  |> option.from_result
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
    functions: List(#(String, String)),
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
    functions: [],
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
  with_decoder: Bool,
) -> File {
  let service_path = "service/" <> service.module
  let scope = scope_for(units, service_path)
  let #(state, output) = out_state(app, units, service_path)
  let out_alias = case output {
    Some(type_) -> {
      let already_out =
        type_name(type_) == "Out" && has_local_decl(units, scope, type_)
      case already_out {
        True -> None
        False -> Some(OutAlias(scope: scope, type_: type_))
      }
    }
    None -> None
  }
  let decoder = case with_decoder, output {
    True, Some(type_) -> "\n" <> decoder_text(app, units, state, scope, type_)
    _, _ -> ""
  }
  let state = case string.contains(decoder, "classify(value)") {
    True -> add_function_import(state, "gleam/dynamic", "classify")
    False -> state
  }
  let declarations = case output {
    None -> "pub type Out\n"
    Some(_) -> declarations_text(state, app)
  }
  let imports = case with_decoder {
    False -> imports_text(state, with_decoder)
    True -> {
      let rendered = imports_text(state, with_decoder)
      case string.contains(decoder, "Page(items:") {
        True ->
          rendered
          |> string.replace("type Page}", "type Page, Page, cursor}")
        False ->
          case string.contains(decoder, "cursor(raw)") {
            True ->
              rendered
              |> string.replace("type Cursor}", "type Cursor, cursor}")
            False -> rendered
          }
      }
    }
  }
  let decoder_imports = case with_decoder {
    True -> "import gleam/dynamic/decode"
    False -> ""
  }
  let all_imports =
    [imports, decoder_imports]
    |> list.filter(fn(value) { value != "" })
    |> string.join("\n")
  let body =
    header(
      "src/service/" <> service.module <> ".gleam",
      hash.service(hashes, service.module),
    )
    <> "\n"
    <> all_imports
    <> case all_imports {
      "" -> ""
      _ -> "\n\n"
    }
    <> declarations
    <> case out_alias {
      None -> ""
      Some(alias) -> "\n" <> out_alias_text(state, alias)
    }
    <> decoder
  File(
    path: face_name <> "/src/gen/out/" <> service.module <> ".gleam",
    text: body,
  )
}

fn decoder_text(
  app: model.App,
  units: List(Unit),
  state: State,
  scope: Scope,
  output: glance.Type,
) -> String {
  "pub fn decoder() -> decode.Decoder(Out) {\n"
  <> "  "
  <> decoder_for_type(app, units, state, scope, output)
  <> "\n}\n"
}

fn decoder_for_type(
  app: model.App,
  units: List(Unit),
  state: State,
  scope: Scope,
  type_: glance.Type,
) -> String {
  case type_ {
    glance.NamedType(name: name, parameters: parameters, ..) -> {
      case name {
        "String" | "Int" | "Bool" | "Float" | "List" | "Option" | "Nil" ->
          builtin_decoder(name, parameters, app, units, state, scope)
        _ -> {
          let path = resolved_path(scope, type_)
          case path, name {
            Some("framework/page"), _ ->
              page_decoder(app, units, state, scope, name, parameters)
            Some("framework/er"), _ -> relation_decoder(name)
            Some(path), _ ->
              named_decoder(app, units, state, scope, path, name, parameters)
            None, _ ->
              builtin_decoder(name, parameters, app, units, state, scope)
          }
        }
      }
    }
    glance.TupleType(elements: elements, ..) ->
      tuple_decoder(
        list.map(elements, fn(item) {
          decoder_for_type(app, units, state, scope, item)
        }),
      )
    _ -> "decode.dynamic"
  }
}

fn builtin_decoder(
  name: String,
  parameters: List(glance.Type),
  app: model.App,
  units: List(Unit),
  state: State,
  scope: Scope,
) -> String {
  case name, parameters {
    "String", [] -> "decode.string"
    "Int", [] -> "decode.int"
    "Bool", [] -> "decode.bool"
    "Float", [] -> "decode.float"
    "List", [inner] ->
      "decode.list(of: "
      <> decoder_for_type(app, units, state, scope, inner)
      <> ")"
    "Option", [inner] ->
      "decode.optional("
      <> decoder_for_type(app, units, state, scope, inner)
      <> ")"
    "Nil", [] -> nil_decoder()
    _, _ -> "decode.dynamic"
  }
}

fn named_decoder(
  app: model.App,
  units: List(Unit),
  state: State,
  scope: Scope,
  path: String,
  name: String,
  _parameters: List(glance.Type),
) -> String {
  case string.starts_with(path, "gen/types/") {
    True -> value_decoder(app, name)
    False ->
      case path {
        "framework/time" -> opaque_model_decoder(name)
        "framework/blob" -> opaque_model_decoder("Blob")
        "framework/party" -> opaque_model_decoder(name)
        _ ->
          case string.starts_with(path, "entity/") {
            True ->
              case
                model.entity_by_module(app.entities, string.drop_start(path, 7))
              {
                Some(entity) ->
                  case entity.type_name == name {
                    True -> entity_decoder(app, units, state, scope, entity)
                    False ->
                      custom_or_alias_decoder(
                        app,
                        units,
                        state,
                        scope,
                        path,
                        name,
                      )
                  }
                None ->
                  custom_or_alias_decoder(app, units, state, scope, path, name)
              }
            False ->
              custom_or_alias_decoder(app, units, state, scope, path, name)
          }
      }
  }
}

fn value_decoder(app: model.App, name: String) -> String {
  case model.value_type_by_name(app.value_types, name) {
    Some(value) ->
      case value.backing {
        model.IntValue -> "decode.int"
        model.StringValue -> "decode.string"
      }
    None -> "decode.string"
  }
}

fn custom_or_alias_decoder(
  app: model.App,
  units: List(Unit),
  state: State,
  _scope: Scope,
  path: String,
  name: String,
) -> String {
  case
    list.find(state.custom, fn(declaration) {
      let CustomDecl(scope: declaration_scope, definition: definition) =
        declaration
      declaration_scope.module == path && definition.name == name
    })
  {
    Ok(CustomDecl(scope: declaration_scope, definition: definition)) ->
      custom_decoder(app, units, state, declaration_scope, definition)
    Error(_) ->
      case
        list.find(state.aliases, fn(alias) {
          case alias {
            SourceAlias(scope: alias_scope, definition: definition) ->
              alias_scope.module == path && definition.name == name
            AliasRedirect(path: alias_path, source_name: source_name) ->
              alias_path == path && source_name == name
            ValueAlias(path: alias_path, source_name: source_name, ..) ->
              alias_path == path && source_name == name
          }
        })
      {
        Ok(SourceAlias(scope: alias_scope, definition: definition)) ->
          decoder_for_type(app, units, state, alias_scope, definition.aliased)
        Ok(AliasRedirect(path: alias_path, source_name: source_name)) ->
          case alias_for(units, alias_path, source_name) {
            Some(definition) ->
              decoder_for_type(
                app,
                units,
                state,
                scope_for(units, alias_path),
                definition.aliased,
              )
            None -> "decode.dynamic"
          }
        Ok(ValueAlias(backing: model.IntValue, ..)) -> "decode.int"
        Ok(ValueAlias(backing: model.StringValue, ..)) -> "decode.string"
        Error(_) -> "decode.dynamic"
      }
  }
}

fn custom_decoder(
  app: model.App,
  units: List(Unit),
  state: State,
  scope: Scope,
  definition: glance.CustomType,
) -> String {
  case
    list.contains(state.enum_aliases, scope.module <> ":" <> definition.name)
  {
    True -> "decode.string"
    False ->
      case definition.variants {
        [] -> "decode.dynamic"
        [variant] ->
          variant_decoder(app, units, state, scope, definition.name, variant)
        variants ->
          case list.all(variants, fn(variant) { variant.fields == [] }) {
            True -> enum_decoder(state, scope, definition)
            False ->
              case discriminator_field(state, scope, variants) {
                Some("kind") ->
                  tagged_union_decoder(
                    app,
                    units,
                    state,
                    scope,
                    definition,
                    variants,
                    "kind",
                  )
                _ ->
                  untagged_union_decoder(
                    app,
                    units,
                    state,
                    scope,
                    definition,
                    variants,
                  )
              }
          }
      }
  }
}

fn untagged_union_decoder(
  app: model.App,
  units: List(Unit),
  state: State,
  scope: Scope,
  definition: glance.CustomType,
  variants: List(glance.Variant),
) -> String {
  // A decoder for fewer fields also accepts an object with more fields.
  let decoders =
    variants
    |> list.sort(fn(left, right) {
      int.compare(list.length(right.fields), list.length(left.fields))
    })
    |> list.map(fn(variant) {
      let constructor =
        variant_constructor(state, scope, definition.name, variant.name)
      case variant.fields {
        [] ->
          untagged_nullary_variant_decoder(
            definition.name,
            variant.name,
            constructor,
          )
        _ -> variant_decoder(app, units, state, scope, definition.name, variant)
      }
    })
  case decoders {
    [first, ..rest] ->
      "decode.one_of(\n  "
      <> first
      <> ",\n  or: ["
      <> string.join(rest, ", ")
      <> "],\n)"
    [] -> "decode.dynamic"
  }
}

fn untagged_nullary_variant_decoder(
  type_name: String,
  variant: String,
  constructor: String,
) -> String {
  "decode.then(decode.string, fn(value) {\n"
  <> "  case value {\n"
  <> "    "
  <> string.inspect(codec_tag(variant))
  <> " -> decode.success("
  <> constructor
  <> ")\n"
  <> "    _ -> decode.failure("
  <> constructor
  <> ", expected: "
  <> string.inspect(type_name)
  <> ")\n"
  <> "  }\n"
  <> "})"
}

fn tagged_union_decoder(
  app: model.App,
  units: List(Unit),
  state: State,
  scope: Scope,
  definition: glance.CustomType,
  variants: List(glance.Variant),
  discriminator: String,
) -> String {
  let branches =
    variants
    |> list.map(fn(variant) {
      "      "
      <> string.inspect(tagged_variant_tag(
        state,
        scope,
        variants,
        discriminator,
        variant.name,
      ))
      <> " ->\n        "
      <> tagged_variant_decoder(
        app,
        units,
        state,
        scope,
        definition.name,
        variant,
        discriminator,
      )
      <> "\n"
    })
    |> string.concat
  let fallback = case variants {
    [first, ..] ->
      "      _ ->\n        decode.then(\n          "
      <> variant_decoder(app, units, state, scope, definition.name, first)
      <> ", fn(value) {\n            decode.failure(\n              value,\n              expected: \""
      <> definition.name
      <> "."
      <> discriminator
      <> "\",\n            )\n          })\n"
    [] -> ""
  }
  "decode.then(\n"
  <> "    decode.field(\""
  <> discriminator
  <> "\", decode.string, fn(value) { decode.success(value) }),\n"
  <> "    fn("
  <> discriminator
  <> ") {\n"
  <> "      case "
  <> discriminator
  <> " {\n"
  <> branches
  <> fallback
  <> "      }\n"
  <> "    },\n"
  <> "  )"
}

fn tagged_variant_decoder(
  app: model.App,
  units: List(Unit),
  state: State,
  scope: Scope,
  type_name: String,
  variant: glance.Variant,
  discriminator: String,
) -> String {
  let constructor = variant_constructor(state, scope, type_name, variant.name)
  case variant.fields {
    [] -> "decode.success(" <> constructor <> ")"
    fields -> {
      let all =
        list.map(fields, fn(field) {
          case field {
            glance.LabelledVariantField(label: label, item: item) -> #(
              label,
              label,
              decoder_for_type(app, units, state, scope, item),
            )
            glance.UnlabelledVariantField(item) -> #(
              "value",
              "value",
              decoder_for_type(app, units, state, scope, item),
            )
          }
        })
        |> list.map(fn(field) {
          case field.0 == discriminator {
            True -> #(field.0, field.0, field.2)
            False -> field
          }
        })
      let remaining = list.filter(all, fn(field) { field.0 != discriminator })
      field_decoder_chain_from(remaining, all, constructor)
    }
  }
}

fn tagged_variant_tag(
  state: State,
  scope: Scope,
  variants: List(glance.Variant),
  discriminator: String,
  variant: String,
) -> String {
  case discriminator_enum(state, scope, variants, discriminator) {
    True -> codec_tag(variant)
    False -> variant
  }
}

fn discriminator_enum(
  state: State,
  scope: Scope,
  variants: List(glance.Variant),
  discriminator: String,
) -> Bool {
  case discriminator_type(variants, discriminator) {
    Some(type_) ->
      case type_ {
        glance.NamedType(name: name, parameters: [], ..) ->
          case resolved_path(scope, type_) {
            Some(path) -> list.contains(state.enum_aliases, path <> ":" <> name)
            None -> False
          }
        _ -> False
      }
    None -> False
  }
}

fn discriminator_type(
  variants: List(glance.Variant),
  discriminator: String,
) -> Option(glance.Type) {
  case variants {
    [first, ..] ->
      case
        list.find(first.fields, fn(field) {
          case field {
            glance.LabelledVariantField(label: label, ..) ->
              label == discriminator
            glance.UnlabelledVariantField(_) -> False
          }
        })
      {
        Ok(glance.LabelledVariantField(item: item, ..)) -> Some(item)
        _ -> None
      }
    [] -> None
  }
}

fn discriminator_field(
  state: State,
  scope: Scope,
  variants: List(glance.Variant),
) -> Option(String) {
  case variants {
    [first, ..] -> {
      let candidates =
        first.fields
        |> list.filter_map(fn(field) {
          case field {
            glance.LabelledVariantField(label: label, item: item) ->
              case string_field_type(state, scope, item) {
                True -> Ok(label)
                False -> Error(Nil)
              }
            glance.UnlabelledVariantField(_) -> Error(Nil)
          }
        })
        |> list.filter(fn(label) {
          list.all(variants, fn(variant) {
            case
              list.find(variant.fields, fn(field) {
                case field {
                  glance.LabelledVariantField(label: found, ..) ->
                    found == label
                  glance.UnlabelledVariantField(_) -> False
                }
              })
            {
              Ok(glance.LabelledVariantField(item: item, ..)) ->
                string_field_type(state, scope, item)
              _ -> False
            }
          })
        })
      case list.contains(candidates, "kind") {
        True -> Some("kind")
        False ->
          case candidates {
            [only] -> Some(only)
            _ -> None
          }
      }
    }
    [] -> None
  }
}

fn string_field_type(state: State, scope: Scope, type_: glance.Type) -> Bool {
  string_field_type_seen(state, scope, type_, [])
}

fn string_field_type_seen(
  state: State,
  scope: Scope,
  type_: glance.Type,
  seen: List(String),
) -> Bool {
  case type_ {
    glance.NamedType(name: "String", parameters: [], ..) -> True
    glance.NamedType(name: name, parameters: [], ..) ->
      case resolved_path(scope, type_) {
        Some(path) -> {
          let key = path <> ":" <> name
          case list.contains(seen, key) {
            True -> False
            False ->
              case list.contains(state.enum_aliases, key) {
                True -> True
                False ->
                  case
                    list.find(state.aliases, fn(alias) {
                      case alias {
                        SourceAlias(alias_scope, definition) ->
                          alias_scope.module == path && definition.name == name
                        ValueAlias(alias_path, source_name, ..) ->
                          alias_path == path && source_name == name
                        AliasRedirect(alias_path, source_name) ->
                          alias_path == path && source_name == name
                      }
                    })
                  {
                    Ok(SourceAlias(alias_scope, definition)) ->
                      string_field_type_seen(
                        state,
                        alias_scope,
                        definition.aliased,
                        [key, ..seen],
                      )
                    Ok(ValueAlias(backing: model.StringValue, ..)) -> True
                    Ok(_) | Error(_) -> False
                  }
              }
          }
        }
        None -> False
      }
    _ -> False
  }
}

fn variant_constructor(
  state: State,
  scope: Scope,
  type_name: String,
  variant: String,
) -> String {
  case type_name {
    "Row" -> row_constructor_name(state, last_segment(scope.module), variant)
    _ -> mapped_constructor(state, scope.module, type_name, variant)
  }
}

fn variant_decoder(
  app: model.App,
  units: List(Unit),
  state: State,
  scope: Scope,
  type_name: String,
  variant: glance.Variant,
) -> String {
  let constructor = variant_constructor(state, scope, type_name, variant.name)
  case variant.fields {
    [] -> untagged_nullary_variant_decoder(type_name, variant.name, constructor)
    [glance.LabelledVariantField(label: "value", item: item)] ->
      "decode.map("
      <> decoder_for_type(app, units, state, scope, item)
      <> ", fn(value) { "
      <> constructor
      <> "(value: value) })"
    [glance.LabelledVariantField(label: "key", item: item)] ->
      "decode.map("
      <> decoder_for_type(app, units, state, scope, item)
      <> ", fn(key) { "
      <> constructor
      <> "(key: key) })"
    fields -> {
      let wire_fields =
        list.index_map(fields, fn(field, index) {
          case field {
            glance.LabelledVariantField(label: label, item: item) -> #(
              label,
              label,
              decoder_for_type(app, units, state, scope, item),
              label <> ": " <> label,
            )
            glance.UnlabelledVariantField(item) -> #(
              int.to_string(index),
              "arg_" <> int.to_string(index),
              decoder_for_type(app, units, state, scope, item),
              "arg_" <> int.to_string(index),
            )
          }
        })
      codec_field_decoder_chain(wire_fields, wire_fields, constructor)
    }
  }
}

fn codec_field_decoder_chain(
  remaining: List(#(String, String, String, String)),
  all: List(#(String, String, String, String)),
  constructor: String,
) -> String {
  case remaining {
    [] ->
      "decode.success("
      <> constructor
      <> "("
      <> string.join(list.map(all, fn(field) { field.3 }), ", ")
      <> "))"
    [#(key, variable, decoder, _), ..rest] ->
      "decode.field("
      <> string.inspect(key)
      <> ", "
      <> decoder
      <> ", fn("
      <> variable
      <> ") {\n    "
      <> codec_field_decoder_chain(rest, all, constructor)
      <> "\n  })"
  }
}

fn field_decoder_chain(
  fields: List(#(String, String, String)),
  constructor: String,
) -> String {
  field_decoder_chain_from(fields, fields, constructor)
}

fn field_decoder_chain_from(
  remaining: List(#(String, String, String)),
  all: List(#(String, String, String)),
  constructor: String,
) -> String {
  case remaining {
    [] -> "decode.success(" <> constructor_with_fields(constructor, all) <> ")"
    [#(label, variable, decoder), ..rest] ->
      "decode.field(\""
      <> label
      <> "\", "
      <> decoder
      <> ", fn("
      <> variable
      <> ") {\n"
      <> "    "
      <> field_decoder_chain_from(rest, all, constructor)
      <> "\n  })"
  }
}

fn constructor_with_fields(
  constructor: String,
  fields: List(#(String, String, String)),
) -> String {
  constructor
  <> "("
  <> string.join(
    list.map(fields, fn(field) { field.0 <> ": " <> field.1 }),
    ", ",
  )
  <> ")"
}

fn enum_decoder(
  state: State,
  scope: Scope,
  definition: glance.CustomType,
) -> String {
  let clauses =
    string.concat(
      list.map(definition.variants, fn(variant) {
        "      \""
        <> codec_tag(variant.name)
        <> "\" -> decode.success("
        <> mapped_constructor(
          state,
          scope.module,
          definition.name,
          variant.name,
        )
        <> ")\n"
      }),
    )
  case definition.variants {
    [first, ..] ->
      "decode.then(decode.string, fn(value) {\n"
      <> "  case value {\n"
      <> clauses
      <> "    _ -> decode.failure("
      <> mapped_constructor(state, scope.module, definition.name, first.name)
      <> ", expected: \""
      <> definition.name
      <> "\")\n"
      <> "  }\n"
      <> "})"
    [] -> "decode.dynamic"
  }
}

fn tuple_decoder(decoders: List(String)) -> String {
  case decoders {
    [] -> "decode.success(#())"
    [first, second] ->
      "decode.then(decode.at([0], "
      <> first
      <> "), fn(first) {\n"
      <> "    decode.map(decode.at([1], "
      <> second
      <> "), fn(second) { #(first, second) })\n"
      <> "  })"
    _ -> "decode.dynamic"
  }
}

fn page_decoder(
  app: model.App,
  units: List(Unit),
  state: State,
  scope: Scope,
  name: String,
  parameters: List(glance.Type),
) -> String {
  case name, parameters {
    "Page", [inner, ..] ->
      "decode.field(\"items\", decode.list(of: "
      <> decoder_for_type(app, units, state, scope, inner)
      <> "), fn(items) {\n"
      <> "    decode.field(\"next\", decode.optional(decode.map(decode.string, fn(raw) {\n"
      <> "      let assert Ok(value) = cursor(raw)\n"
      <> "      value\n"
      <> "    })), fn(next) {\n"
      <> "      decode.success(Page(items: items, next: next))\n"
      <> "    })\n"
      <> "  })"
    "Cursor", _ ->
      "decode.map(decode.string, fn(raw) {\n"
      <> "      let assert Ok(value) = cursor(raw)\n"
      <> "      value\n"
      <> "    })"
    _, _ -> "decode.dynamic"
  }
}

fn relation_decoder(name: String) -> String {
  case name {
    "Key" -> key_decoder()
    "Has" -> has_decoder()
    "Held" -> held_decoder()
    "Link" -> "decode.optional(" <> key_decoder() <> ")"
    "Multi" -> multi_decoder()
    _ -> "decode.dynamic"
  }
}

// api/src/gen/codec.mjs:135,144 uses /([a-z0-9])([A-Z])/g then toLowerCase().
// Unlike naming.snake, consecutive capitals do not introduce an underscore.
fn codec_tag(name: String) -> String {
  let #(result, _) =
    name
    |> string.to_graphemes
    |> list.fold(#("", ""), fn(acc, char) {
      let #(result, previous) = acc
      let boundary =
        previous != ""
        && string.contains("abcdefghijklmnopqrstuvwxyz0123456789", previous)
        && string.contains("ABCDEFGHIJKLMNOPQRSTUVWXYZ", char)
      let separator = case boundary {
        True -> "_"
        False -> ""
      }
      #(result <> separator <> string.lowercase(char), char)
    })
  result
}

fn entity_decoder(
  app: model.App,
  units: List(Unit),
  state: State,
  scope: Scope,
  entity: model.Entity,
) -> String {
  let fields =
    list.map(entity.props, fn(prop) {
      #(prop.name, prop.name, prop_decoder(app, units, state, scope, prop))
    })
  field_decoder_chain(
    fields,
    mapped_name(state, "entity/" <> entity.module, entity.type_name),
  )
}

fn prop_decoder(
  app: model.App,
  units: List(Unit),
  state: State,
  scope: Scope,
  prop: model.Prop,
) -> String {
  let base = case prop.kind {
    model.RelProp(kind: kind, ..) -> relation_property_decoder(kind)
    model.ValueProp(reference) ->
      model_ref_decoder(app, units, state, scope, reference)
    model.SumProp(reference, ..) ->
      model_ref_decoder(app, units, state, scope, reference)
  }
  let repeated = case prop.kind, prop.repeated {
    model.RelProp(kind: model.Multi, ..), _ -> base
    _, True -> "decode.list(of: " <> base <> ")"
    _, False -> base
  }
  case prop.optional {
    True -> "decode.optional(" <> repeated <> ")"
    False -> repeated
  }
}

fn relation_property_decoder(kind: model.RelKind) -> String {
  case kind {
    model.Has -> has_decoder()
    model.Held -> held_decoder()
    model.Multi -> multi_decoder()
    model.Link -> "decode.optional(" <> key_decoder() <> ")"
  }
}

fn model_ref_decoder(
  app: model.App,
  units: List(Unit),
  state: State,
  scope: Scope,
  reference: model.TypeRef,
) -> String {
  case reference.module, reference.name {
    None, "String" -> "decode.string"
    None, "Int" -> "decode.int"
    None, "Bool" -> "decode.bool"
    None, "Float" -> "decode.float"
    None, "Nil" -> nil_decoder()
    None, name -> unqualified_model_ref_decoder(app, units, state, name)
    Some(path), name ->
      case string.starts_with(path, "gen/types/") {
        True -> value_decoder(app, name)
        False ->
          case path {
            "framework/time" -> opaque_model_decoder(name)
            "framework/blob" -> opaque_model_decoder("Blob")
            "framework/party" -> opaque_model_decoder(name)
            "framework/er" -> relation_decoder(name)
            _ ->
              case string.starts_with(path, "entity/") {
                True ->
                  case
                    model.entity_by_module(
                      app.entities,
                      string.drop_start(path, 7),
                    )
                  {
                    Some(entity) ->
                      case entity.type_name == name {
                        True -> entity_decoder(app, units, state, scope, entity)
                        False ->
                          custom_or_alias_decoder(
                            app,
                            units,
                            state,
                            Scope(module: path, imports: []),
                            path,
                            name,
                          )
                      }
                    None ->
                      custom_or_alias_decoder(
                        app,
                        units,
                        state,
                        Scope(module: path, imports: []),
                        path,
                        name,
                      )
                  }
                False ->
                  custom_or_alias_decoder(
                    app,
                    units,
                    state,
                    Scope(module: path, imports: []),
                    path,
                    name,
                  )
              }
          }
      }
  }
}

fn unqualified_model_ref_decoder(
  app: model.App,
  units: List(Unit),
  state: State,
  name: String,
) -> String {
  case
    list.find(state.custom, fn(declaration) {
      let CustomDecl(definition: definition, ..) = declaration
      definition.name == name
    })
  {
    Ok(CustomDecl(scope: declaration_scope, definition: definition)) ->
      custom_decoder(app, units, state, declaration_scope, definition)
    Error(_) ->
      case
        list.find(state.aliases, fn(alias) {
          case alias {
            SourceAlias(_, definition) -> definition.name == name
            AliasRedirect(_, source_name) | ValueAlias(_, source_name, ..) ->
              source_name == name
          }
        })
      {
        Ok(SourceAlias(alias_scope, definition)) ->
          decoder_for_type(app, units, state, alias_scope, definition.aliased)
        Ok(AliasRedirect(path, source_name)) ->
          custom_or_alias_decoder(
            app,
            units,
            state,
            Scope(module: path, imports: []),
            path,
            source_name,
          )
        Ok(ValueAlias(backing: model.IntValue, ..)) -> "decode.int"
        Ok(ValueAlias(backing: model.StringValue, ..)) -> "decode.string"
        Error(_) -> value_decoder(app, name)
      }
  }
}

fn key_decoder() -> String {
  "decode.then(decode.string, fn(raw) { decode.success(key(raw)) })"
}

fn nil_decoder() -> String {
  "decode.new_primitive_decoder(\"Nil\", fn(value) {\n"
  <> "    case classify(value) {\n"
  <> "      \"Nil\" -> Ok(Nil)\n"
  <> "      _ -> Error(Nil)\n"
  <> "    }\n"
  <> "  })"
}

fn opaque_model_decoder(name: String) -> String {
  case name {
    "Blob" -> opaque_parser_decoder("parse", "placeholder", "Blob")
    "Date" -> opaque_parser_decoder("date", "2000-01-01", "Date")
    "Datetime" ->
      opaque_parser_decoder("datetime", "2000-01-01T00:00:00Z", "Datetime")
    "Time" -> opaque_parser_decoder("time", "00:00", "Time")
    "PartyId" -> opaque_parser_decoder("party.parse", "placeholder", "PartyId")
    _ -> "decode.dynamic"
  }
}

fn opaque_parser_decoder(
  parser: String,
  default_raw: String,
  expected: String,
) -> String {
  "decode.new_primitive_decoder(\""
  <> expected
  <> "\", fn(value) {\n"
  <> "    let parsed = case decode.run(value, decode.string) {\n"
  <> "      Ok(raw) -> "
  <> parser
  <> "(raw)\n"
  <> "      Error(_) -> Error(Nil)\n"
  <> "    }\n"
  <> "    case parsed {\n"
  <> "      Ok(value) -> Ok(value)\n"
  <> "      Error(_) -> Error(\n"
  <> "        case "
  <> parser
  <> "(\""
  <> default_raw
  <> "\") {\n"
  <> "          Ok(default_value) -> default_value\n"
  <> "          Error(_) -> panic as \"valid built-in "
  <> expected
  <> " decoder placeholder\"\n"
  <> "        },\n"
  <> "      )\n"
  <> "    }\n"
  <> "  })"
}

fn has_decoder() -> String {
  "decode.map(decode.string, fn(value) { Has(value: value) })"
}

fn held_decoder() -> String {
  "decode.map(decode.string, fn(value) { Held(value: value) })"
}

fn multi_decoder() -> String {
  "decode.field(\"keys\", decode.list(of: decode.string), fn(keys) { decode.success(Multi(values: keys)) })"
}

fn out_state(
  app: model.App,
  units: List(Unit),
  service_path: String,
) -> #(State, Option(glance.Type)) {
  let scope = scope_for(units, service_path)
  let output = output_type(units, service_path)
  let empty = case service_path {
    "service/roster_read" ->
      State(..empty_state(), names: [
        #("entity/muse:Public", "MusePublic"),
        #("entity/store:Public", "StorePublic"),
        #("entity/roster:Public", "RosterPublic"),
      ])
    _ -> empty_state()
  }
  let state = case output {
    Some(type_) -> collect_gl_type(empty, app, units, scope, type_)
    None -> empty
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
        "framework/time" -> add_time_decoder_import(state, path, name)
        "framework/blob" ->
          add_function_import(add_import(state, path, name), path, "parse")
        "framework/party" -> add_import(state, path, name)
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
    "framework/time" -> add_time_decoder_import(state, path, name)
    "framework/blob" ->
      add_function_import(add_import(state, path, name), path, "parse")
    "framework/party" -> add_import(state, path, name)
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

/// Stop before writing a decoder for variants with the same encoded shape.
pub fn decoder_notes(app: model.App, units: List(Unit)) -> List(stop.Note) {
  units
  |> list.filter(fn(unit) { string.starts_with(unit.path, "service/") })
  |> list.flat_map(fn(unit) {
    let #(state, output) = out_state(app, units, unit.path)
    case output {
      None -> []
      Some(_) ->
        state.custom
        |> list.flat_map(fn(declaration) {
          let CustomDecl(scope: scope, definition: definition) = declaration
          case missing_row_enum_tag(state, scope, definition) {
            Some(constructor) -> [
              stop.Note(
                class: stop.Conflict,
                text: unit.path
                  <> ": "
                  <> definition.name
                  <> " の構成子 "
                  <> constructor
                  <> " に対応する discriminator enum 構成子が無い",
              ),
            ]
            None ->
              case
                list.length(definition.variants) > 1
                && !decodable_variant_shapes(state, scope, definition.variants)
              {
                True -> [
                  stop.Note(
                    class: stop.NotImplemented,
                    text: unit.path
                      <> ": "
                      <> scope.module
                      <> "."
                      <> definition.name
                      <> " の複数 variant を判別できない。汎用 encode の欄名または tag が重なる",
                  ),
                ]
                False -> []
              }
          }
        })
    }
  })
}

fn missing_row_enum_tag(
  state: State,
  scope: Scope,
  definition: glance.CustomType,
) -> Option(String) {
  case discriminator_field(state, scope, definition.variants) {
    Some(discriminator) ->
      case
        discriminator_enum(state, scope, definition.variants, discriminator)
      {
        False -> None
        True ->
          case discriminator_type(definition.variants, discriminator) {
            Some(type_) ->
              case type_ {
                glance.NamedType(name: name, parameters: [], ..) ->
                  case resolved_path(scope, type_) {
                    Some(path) ->
                      case
                        list.find(state.custom, fn(declaration) {
                          let CustomDecl(scope: enum_scope, definition: enum) =
                            declaration
                          enum_scope.module == path && enum.name == name
                        })
                      {
                        Ok(CustomDecl(definition: enum, ..)) ->
                          case
                            list.find(definition.variants, fn(row_variant) {
                              !list.any(enum.variants, fn(enum_variant) {
                                enum_variant.name == row_variant.name
                              })
                            })
                          {
                            Ok(row_variant) -> Some(row_variant.name)
                            Error(_) -> None
                          }
                        Error(_) -> None
                      }
                    None -> None
                  }
                _ -> None
              }
            None -> None
          }
      }
    None -> None
  }
}

fn decodable_variant_shapes(
  state: State,
  scope: Scope,
  variants: List(glance.Variant),
) -> Bool {
  let nullary = list.filter(variants, fn(variant) { variant.fields == [] })
  let tags = list.map(nullary, fn(variant) { codec_tag(variant.name) })
  let unique_tags = list.length(tags) == list.length(list.unique(tags))
  let fielded = list.filter(variants, fn(variant) { variant.fields != [] })
  case fielded {
    [] -> unique_tags
    _ ->
      case discriminator_field(state, scope, variants) {
        Some("kind") -> unique_tags
        _ -> {
          let flattened =
            list.any(fielded, fn(variant) {
              case variant.fields {
                [glance.LabelledVariantField(label: "value", ..)]
                | [glance.LabelledVariantField(label: "key", ..)] -> True
                _ -> False
              }
            })
          let shapes = list.map(fielded, variant_wire_keys)
          unique_tags
          && !flattened
          && list.length(shapes) == list.length(list.unique(shapes))
        }
      }
  }
}

fn variant_wire_keys(variant: glance.Variant) -> List(String) {
  variant.fields
  |> list.index_map(fn(field, index) {
    case field {
      glance.LabelledVariantField(label: label, ..) -> label
      glance.UnlabelledVariantField(..) -> int.to_string(index)
    }
  })
  |> list.sort(string.compare)
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

fn imports_text(state: State, with_functions: Bool) -> String {
  let types = list.map(state.imports, fn(item) { #(item.0, item.1, True) })
  let functions = case with_functions {
    True -> list.map(state.functions, fn(item) { #(item.0, item.1, False) })
    False -> []
  }
  list.append(types, functions)
  |> list.sort(fn(left, right) {
    case string.compare(left.0, right.0) {
      order.Eq ->
        case string.compare(left.1, right.1) {
          order.Eq ->
            case left.2, right.2 {
              True, False -> order.Lt
              False, True -> order.Gt
              _, _ -> order.Eq
            }
          other -> other
        }
      other -> other
    }
  })
  |> group_imports
}

fn group_imports(imports: List(#(String, String, Bool))) -> String {
  case imports {
    [] -> ""
    [first, ..rest] -> {
      let groups =
        collect_import_groups(rest, [#(first.0, [#(first.1, first.2)])])
      groups
      |> list.map(fn(group) {
        let #(path, names) = group
        "import "
        <> path
        <> ".{"
        <> string.join(
          list.map(list.unique(names), fn(name) {
            case name.1 {
              True -> "type " <> name.0
              False -> name.0
            }
          }),
          ", ",
        )
        <> "}"
      })
      |> string.join("\n")
    }
  }
}

fn collect_import_groups(
  imports: List(#(String, String, Bool)),
  groups: List(#(String, List(#(String, Bool)))),
) -> List(#(String, List(#(String, Bool)))) {
  case imports {
    [] -> groups
    [#(path, name, is_type), ..rest] ->
      case list.find(groups, fn(group) { group.0 == path }) {
        Ok(_) ->
          collect_import_groups(
            rest,
            list.map(groups, fn(group) {
              case group.0 == path {
                True -> #(group.0, list.append(group.1, [#(name, is_type)]))
                False -> group
              }
            }),
          )
        Error(_) ->
          collect_import_groups(
            rest,
            list.append(groups, [#(path, [#(name, is_type)])]),
          )
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
        False -> {
          let state = add_import(state, "framework/er", name)
          case name {
            "Key" | "Link" -> add_function_import(state, "framework/er", "key")
            _ -> state
          }
        }
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

fn add_function_import(state: State, path: String, name: String) -> State {
  case list.contains(state.functions, #(path, name)) {
    True -> state
    False ->
      State(..state, functions: list.append(state.functions, [#(path, name)]))
  }
}

fn add_time_decoder_import(state: State, path: String, name: String) -> State {
  let state = add_import(state, path, name)
  case name {
    "Date" -> add_function_import(state, path, "date")
    "Datetime" -> add_function_import(state, path, "datetime")
    "Time" -> add_function_import(state, path, "time")
    _ -> state
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
