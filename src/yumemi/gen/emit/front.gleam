//// 面の束 ── route / blocks / widgets / API / Service / Out の写し。
//// 面側へ back の module を再輸出せず、面 package が単独で型を持てる形にする。

import glance
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import gleam/string
import simplifile
import yumemi/front as framework_front
import yumemi/front/css as framework_css
import yumemi/front/sketch_css as framework_sketch_css
import yumemi/front/track as framework_track
import yumemi/gen/digest
import yumemi/gen/emit/accepted
import yumemi/gen/emit/draft
import yumemi/gen/emit/entry
import yumemi/gen/emit/gate as gate_emit
import yumemi/gen/emit/hash
import yumemi/gen/emit/media as media_emit
import yumemi/gen/emit/root
import yumemi/gen/emit/types.{type File, File}
import yumemi/gen/face
import yumemi/gen/glance_util as g
import yumemi/gen/model
import yumemi/gen/naming
import yumemi/gen/raw_css
import yumemi/gen/reader/cms
import yumemi/gen/reader/front as reader_front
import yumemi/gen/reader/gate as reader_gate
import yumemi/gen/source.{type Unit, Unit}
import yumemi/gen/stop

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
  let live = live_targets(app, back_units, package, model_, hashes)
  let live_decoder_services = []
  let page_decoder_services =
    reader_front.with_failure(model_).pages
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
  let preview_blocks = referenced_blocks(reader_front.with_failure(model_))
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
      text: shell_text(
        app,
        type_units,
        package,
        model_,
        hashes,
        interactive_state_css(model_, live),
        escape_names(package) != [],
      ),
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
      text: style_text(package, model_) <> interactive_state_css(model_, live),
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
    list.map(live, fn(target) {
      File(
        path: face_name <> "/src/gen/live/" <> target.name <> ".gleam",
        text: live_module_text(target),
      )
    })
  let interactive_files = case placeable_components(model_, live) {
    [] -> []
    _ -> [
      File(
        path: face_name <> "/src/gen/interactive.gleam",
        text: interactive_text(package, model_, live),
      ),
    ]
  }
  let all_live_files = list.append(live_files, interactive_files)
  // 0.12:数える口の送り手。門が `pageview` を宣言した面は、Component が無くても client.mjs を出す
  let pageview_client = pageview_client_text(app, back_units, package, model_)
  let escapes = escape_names(package)
  let live_client = live_client_text(app, package, model_)
  let island_files = case
    placeable_components(model_, live),
    escapes,
    model_.shell.head.service_worker,
    pageview_client <> live_client
  {
    [], [], None, "" -> []
    _, _, _, _ -> [
      File(
        path: face_name <> "/priv/static/_yumemi/client.mjs",
        text: client_text(
          face_name,
          model_,
          live,
          escapes,
          hashes,
          navigation(app, back_units, package, model_),
        )
          <> pageview_client
          <> live_client,
      ),
    ]
  }
  let escape_files = case escapes {
    [] -> []
    _ -> [
      File(
        path: face_name <> "/src/gen/escapes.gleam",
        text: escapes_text(package, escapes),
      ),
    ]
  }
  let media_files = media_emit.emit(app, face_name, hashes)
  let load_files =
    list.append(
      [load_layout_file(app, package, model_)],
      list.map(model_.pages, fn(page) {
        load_page_file(app, type_units, package, model_, page)
      })
        // 0.14.3:失敗の頁の loader(`gen/load/failure.gleam`)。断片の口は持たない
        |> list.append(case model_.failure {
          Some(page) -> [
            load_page_file(app, type_units, package, model_, page),
          ]
          None -> []
        }),
    )
  list.append(
    list.append(
      files,
      list.append(
        out_files,
        list.append(all_live_files, list.append(island_files, escape_files)),
      ),
    ),
    list.append(load_files, media_files),
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
        "import yumemi/front/el",
        "import yumemi/front/html",
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
    <> ": In) -> el.Element {\n  html.div_([], [\n"
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
            style: reader_front.NoFrameStyle,
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
  let option_imports = case
    string.contains(area_children, "None")
    || string.contains(area_children, "default_page_theme()")
  {
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
    _ -> ["import yumemi/time.{" <> string.join(time_imports, ", ") <> "}"]
  }
  let opaque_imports =
    list.append(
      list.flatten([
        case string.contains(area_children, "default_blob()") {
          True -> ["import yumemi/blob.{type Blob, parse as parse_blob}"]
          False -> []
        },
        case string.contains(area_children, "default_color()") {
          True -> [
            "import yumemi/front/color.{type Color, parse as parse_color}",
          ]
          False -> []
        },
        case string.contains(area_children, "default_page_theme()") {
          True -> ["import yumemi/front/theme"]
          False -> []
        },
      ]),
      list.append(
        case string.contains(area_children, "default_party_id()") {
          True -> [
            "import yumemi/party.{type PartyId, parse as parse_party}",
          ]
          False -> []
        },
        list.append(
          time_import,
          case string.contains(area_children, "er.key(") {
            True -> ["import yumemi/er as er"]
            False -> []
          },
        ),
      ),
    )
  let page_imports = case
    string.contains(area_children, "framework_page.Page(")
  {
    True -> ["import yumemi/page as framework_page"]
    False -> []
  }
  let body_imports =
    list.append(
      [
        "import yumemi/front/el",
        "import yumemi/front/html",
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
    <> case string.contains(area_children, "default_color()") {
      True ->
        "\nfn default_color() -> Color {\n"
        <> "  let assert Ok(value) = parse_color(\"#000000\")\n"
        <> "  value\n}\n"
      False -> ""
    }
    <> case string.contains(area_children, "default_page_theme()") {
      True ->
        "\nfn default_page_theme() -> theme.PageTheme {\n"
        <> "  theme.PageTheme(background: None, background_image: None, text: None, accent: None)\n"
        <> "}\n"
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
  <> "\npub fn view() -> el.Element {\n"
  <> "  html.div_([el.attribute(\"data-yumemi-blocks-preview\", \"pc\")], [\n"
  <> "    "
  <> area_children
  <> "\n  ])\n}\n\n"
  <> "pub fn render() -> el.Element {\n"
  <> "  html.html([], [\n"
  <> "    html.head([], []),\n"
  <> "    html.body_([], [el.styled(fn() { view() }, \"\")]),\n"
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
    "[el.attribute(\"data-yumemi-area\", " <> quoted(name) <> ")]"
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
            "yumemi/er" ->
              relation_default(output_module, type_name(type_), field_name)
            "yumemi/blob" -> "default_blob()"
            "yumemi/front/color" -> "default_color()"
            "yumemi/front/theme" -> "default_page_theme()"
            "yumemi/party" -> "default_party_id()"
            "yumemi/time" ->
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

/// client で差し替えてよい Page の route(0.11.4、H9)。面の Page の route を全部出し、門の `csp` の当たる Page は
/// 応答に持つ CSP の header の値を `csp` に route ごとに出す(0.11.15、0.12 で門の `csp` から)。
/// client は今の document を読み込んだ Page と CSP が同じ行き先だけを取り、違えば頁の読み込み(CSP の header は
/// 頁の読み込みにしか効かない)。CSP を持つ Page の無い面は 0.11.14 と同じ字。
/// pageview の Page も入る ── 門が client 遷移の fetch に数える印を差し、navigate は差し替えで印を来た頁のものに
/// 替えるだけ(0.12。送るのは client 側の送り手)。
fn navigation(
  app: model.App,
  back_units: List(Unit),
  package: face.Package,
  front: reader_front.Front,
) -> #(List(String), String) {
  let #(gate, _) = read_gate(app, back_units, package, front)
  let routes = front_route_paths(front)
  let csp = case gate_emit.csp_routes(gate, routes) {
    [] -> ""
    framed ->
      ", csp: { "
      <> string.join(
        list.map(framed, fn(pair) { quoted(pair.0) <> ": " <> quoted(pair.1) }),
        ", ",
      )
      <> " }"
  }
  #(routes, csp)
}

fn client_text(
  face_name: String,
  front: reader_front.Front,
  targets: List(LiveTarget),
  escapes: List(String),
  hashes: hash.Hashes,
  navigation: #(List(String), String),
) -> String {
  let #(routes, options) = navigation
  // 書いた後の読み直しと GoTo・reloads の一覧:route 表があれば navigate の `reload` / `go`(client 遷移)
  let #(navigate_import, navigate_start, hooks) = case routes {
    [] -> #("", "", "go: null, reload: null")
    _ -> #(
      "import { go as navigateGo, reload as reloadPage, start as startNavigation } from \"__YUMEMI_BUILD__/yumemi/yumemi/front/navigate.mjs\";\n",
      "startNavigation({ routes: ["
        <> string.join(list.map(routes, fn(route) { quoted(route) }), ", ")
        <> "]"
        <> options
        <> " });\n",
      "go: navigateGo, reload: reloadPage",
    )
  }
  js_header(
    face_name
      <> "/src/components/*.gleam, src/escapes/*.mjs and src/entry.gleam",
    digest.short(
      hash.entry(hashes)
      <> string.inspect(front.components)
      <> string.join(escapes, ",")
      <> string.inspect(targets),
    ),
  )
  <> "\n"
  <> "import { start as startInteractive } from \"__YUMEMI_BUILD__/yumemi/yumemi/front/interactive.mjs\";\n"
  <> case front_has_live(front), escapes {
    True, _ ->
      "import { block as liveBlock, start as startLive } from \"__YUMEMI_BUILD__/yumemi/yumemi/front/live_block.mjs\";\n"
    // 0.14.1:`Live` の無い面も逃げ道に `yumemi.block` を渡す。札・socket の runtime は読まない(`block.mjs` だけ)
    False, [_, ..] ->
      "import { block as yumemiBlock, start as startBlock } from \"__YUMEMI_BUILD__/yumemi/yumemi/front/block.mjs\";\n"
    False, [] -> ""
  }
  <> navigate_import
  <> string.concat(
    list.map(escapes, fn(name) {
      "import { mount as escape_"
      <> name
      <> " } from \"__YUMEMI_BUILD__/__YUMEMI_FACE__/escapes/"
      <> name
      <> ".mjs\";\n"
    }),
  )
  <> "\n"
  <> "startInteractive({\n"
  <> "  components: "
  <> interactive_table(front, targets)
  <> ",\n"
  <> "  escapes: { "
  <> string.join(
    list.map(escapes, fn(name) { name <> ": escape_" <> name }),
    ", ",
  )
  <> " },\n"
  <> case front_has_live(front), escapes {
    True, _ -> "  yumemi: { block: liveBlock },\n"
    False, [_, ..] -> "  yumemi: { block: yumemiBlock },\n"
    False, [] -> ""
  }
  <> "  "
  <> hooks
  <> ",\n"
  <> "});\n"
  <> case front_has_live(front), escapes {
    False, [_, ..] -> "startBlock();\n"
    _, _ -> ""
  }
  <> navigate_start
  <> service_worker_text(front.shell.head.service_worker)
}

/// 0.11.12:shell の service_worker を読み込み時に 1 回登録する。client 遷移では client.mjs を
/// 読み直さないので 1 回のまま。`serviceWorker` が無い環境では何もせず、失敗は握る。
fn service_worker_text(service_worker: Option(String)) -> String {
  case service_worker {
    None -> ""
    Some(path) ->
      "\nif (globalThis.navigator?.serviceWorker) {\n"
      <> "  try {\n"
      <> "    globalThis.navigator.serviceWorker.register("
      <> quoted(path)
      <> ").catch(() => {});\n"
      <> "  } catch (_error) {\n"
      <> "    // 登録できなくても画面は壊さない\n"
      <> "  }\n"
      <> "}\n"
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

/// 要件(`requires`)が断るときの構成子(0.12.1)。`Declared` は `DeclarationMissing`、`Consented` /
/// `ConsentedFor` は `ConsentMissing` ── 403 の `code`(`declaration_missing` / `consent_missing`)を
/// live module の `Error` に載せ、Component が `when(Refused(ConsentMissing), ..)` で同意の欠けだけの枝を書ける。
fn requirement_codes(units: List(Unit), service: String) -> List(String) {
  cms.requirements(units)
  |> list.filter(fn(requirement) { requirement.service == service })
  |> list.filter_map(fn(requirement) {
    case requirement.constructor {
      "Declared" -> Ok("DeclarationMissing")
      "Consented" | "ConsentedFor" -> Ok("ConsentMissing")
      _ -> Error(Nil)
    }
  })
  |> list.unique
}

/// attached の口の役 `NeedsDeclared` が断るときの構成子(`declaration_missing`)。口の名は model では
/// `BlobCopy`、役の表では `blob_copy` の綴りなので snake で突き合わせる。
fn attached_requirement_codes(app: model.App, name: String) -> List(String) {
  case
    list.any(app.server.attached_roles, fn(role) {
      naming.snake(role.attached) == naming.snake(name)
      && role.role == "needs_declared"
    })
  {
    True -> ["DeclarationMissing"]
    False -> []
  }
}

/// 要件の構成子のうち、★ が Service の `Error` に同じ名で書いていないもの(書いていればそれを使う)。
fn without_star_errors(
  variants: List(glance.Variant),
  codes: List(String),
) -> List(String) {
  list.filter(codes, fn(code) {
    !list.any(variants, fn(variant) { variant.name == code })
  })
}

/// live module の `Error` の構成子:Service の `Error` の後ろに要件の構成子。
fn live_errors(target: LiveTarget) -> List(glance.Variant) {
  list.append(
    target.errors,
    list.map(target.requires, fn(name) {
      glance.Variant(name: name, fields: [], attributes: [])
    }),
  )
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

fn service_error_type_text(variants: List(glance.Variant)) -> String {
  case variants {
    [] -> "pub type Error\n\n"
    _ ->
      "pub type Error {\n"
      <> string.concat(list.map(variants, error_variant_text))
      <> "}\n\n"
  }
}

fn blob_shape(shape: model.TypeShape) -> Bool {
  case shape {
    model.NamedShape(module: Some("yumemi/blob"), name: "Blob", parameters: []) ->
      True
    model.NamedShape(
      module: Some("gleam/option"),
      name: "Option",
      parameters: [inner],
    ) -> blob_shape(inner)
    _ -> False
  }
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
    string.starts_with(path, "gen/") || string.starts_with(path, "yumemi/")
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

fn path_holes(path: String) -> List(String) {
  case string.split(path, ":") {
    [] | [_] -> []
    [_, ..rest] ->
      list.map(rest, fn(part) {
        case string.split_once(part, "/") {
          Ok(#(name, _)) -> name
          Error(_) -> part
        }
      })
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

fn spec_bounds(expression: glance.Expression) -> Option(#(String, String)) {
  case
    g.labelled(expression, "min") |> option.then(g.int_value),
    g.labelled(expression, "max") |> option.then(g.int_value)
  {
    Some(min), Some(max) -> Some(#(min, max))
    _, _ -> None
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
  _app: model.App,
  units: List(Unit),
  sources: List(LoadSource),
  fallback: String,
) -> String {
  case
    list.find(sources, fn(source) {
      source.type_name == "Out"
      && option.is_some(page_theme_path(units, source.service, ""))
    })
  {
    Ok(source) -> source.service
    Error(_) -> fallback
  }
}

/// 面のどこかの Page が theme を取るか。取らない面の shell には theme の path を
/// たどる実行時を出さない(theme を書かない面の生成を変えないため)。
fn uses_page_theme(
  app: model.App,
  units: List(Unit),
  front: reader_front.Front,
) -> Bool {
  list.any(front.pages, fn(page) {
    page_sources(app, units, page, front.blocks, app.services)
    |> list.any(fn(source) { source.type_name == "PageTheme" })
  })
}

/// theme を取る Service の Out の中で、PageTheme の値に着くまでの欄の path。
/// 各段は #(欄名, その欄が Option か)で、型が PageTheme か Option(PageTheme) の
/// 欄で終わる。Page の `theme: Some(name)` の `name` はその最後の欄の名で、名の
/// 合う path を取る。合う path が無ければ一番浅い path を取る。着けなければ None。
fn page_theme_path(
  units: List(Unit),
  service: String,
  name: String,
) -> Option(List(#(String, Bool))) {
  let service_path = "service/" <> service
  case output_type(units, service_path) {
    Some(type_) -> {
      let paths =
        theme_paths(units, scope_for(units, service_path), type_, [], [])
        |> list.sort(fn(left, right) {
          int.compare(list.length(left), list.length(right))
        })
      let named =
        list.find(paths, fn(path) {
          case list.last(path) {
            Ok(step) -> step.0 == name
            Error(_) -> False
          }
        })
      case named, paths {
        Ok(path), _ -> Some(path)
        Error(_), [path, ..] -> Some(path)
        Error(_), [] -> None
      }
    }
    None -> None
  }
}

fn theme_paths(
  units: List(Unit),
  scope: Scope,
  type_: glance.Type,
  prefix: List(#(String, Bool)),
  seen: List(String),
) -> List(List(#(String, Bool))) {
  case record_fields(units, scope, type_, 0) {
    Some(#(key, record_scope, fields)) ->
      case list.contains(seen, key) {
        True -> []
        False ->
          list.flat_map(fields, fn(field) {
            case field {
              glance.LabelledVariantField(label: label, item: item) -> {
                let #(inner, optional) = option_inner(item)
                let steps = [#(label, optional), ..prefix]
                case is_page_theme(record_scope, inner) {
                  True -> [list.reverse(steps)]
                  False ->
                    theme_paths(units, record_scope, inner, steps, [key, ..seen])
                }
              }
              glance.UnlabelledVariantField(..) -> []
            }
          })
      }
    None -> []
  }
}

/// 型が `yumemi/front/theme.PageTheme` か(型名の字の一致では拾わない、0.12)。
fn is_page_theme(scope: Scope, type_: glance.Type) -> Bool {
  type_name(type_) == "PageTheme"
  && resolved_path(scope, type_) == Some("yumemi/front/theme")
}

fn option_inner(type_: glance.Type) -> #(glance.Type, Bool) {
  case type_ {
    glance.NamedType(name: "Option", parameters: [inner], ..) -> #(inner, True)
    _ -> #(type_, False)
  }
}

/// 型が 1 つの variant の record なら、その欄と、欄の型を読む scope。alias はたどる。
fn record_fields(
  units: List(Unit),
  scope: Scope,
  type_: glance.Type,
  depth: Int,
) -> Option(#(String, Scope, List(glance.VariantField))) {
  case type_, resolved_path(scope, type_) {
    glance.NamedType(name: name, ..), Some(path) if depth < 8 ->
      case unit_for(units, path) {
        Some(unit) -> {
          let module = g.in_order(unit.module)
          let record_scope = scope_for(units, path)
          case
            g.find_custom_type(module, name),
            g.find_type_alias(module, name)
          {
            Some(glance.CustomType(variants: [variant], ..)), _ ->
              Some(#(path <> ":" <> name, record_scope, variant.fields))
            None, Some(alias) ->
              record_fields(units, record_scope, alias.aliased, depth + 1)
            _, _ -> None
          }
        }
        None -> None
      }
    _, _ -> None
  }
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
  let out = case source.type_name {
    "PageTheme" -> "theme.PageTheme"
    _ -> source.service <> "." <> source.type_name
  }
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
  let theme_background_blob = theme_background_is_blob(app, theme)
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
    <> case page_lives(page), page_fixed_blocks(page), page.module {
      _, _, "failure" -> ""
      [], [], _ -> ""
      _, _, _ -> "\n" <> page_live_text(app, front, page, page_sources)
    }
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
  let theme_value = case theme_source(page_sources) {
    Some(_) -> "it.theme"
    None -> "None"
  }
  "pub fn render(it: Data) -> el.Element {\n"
  <> "  let page_theme = "
  <> theme_value
  <> "\n"
  <> "  html.html([el.attribute(\"lang\", "
  <> quoted(front.shell.lang)
  <> ")], [\n"
  <> "    html.head([], [\n"
  <> "      html.meta([el.attribute(\"charset\", \"utf-8\")]),\n"
  <> "      html.meta([\n"
  <> "        el.attribute(\"name\", \"viewport\"),\n"
  <> "        el.attribute(\"content\", \"width=device-width, initial-scale=1, viewport-fit=cover\"),\n"
  <> "      ]),\n"
  <> "      html.title([], "
  <> quoted(front.shell.title)
  <> "),\n"
  <> shell_head_text(front.shell.head)
  <> "    ]),\n"
  <> "    html.body_([theme_image_attribute(page_theme)], [\n"
  <> "      el.styled(\n"
  <> "        fn() { view(it) },\n"
  <> "        theme.body_rule(page_theme, theme_defaults(), theme_image_url),\n"
  <> "      ),\n"
  <> "    ]),\n"
  <> "  ])\n"
  <> "}\n\n"
  <> theme_global_text(front, theme_background_blob)
}

/// shell の任意の const(0.11.12)を title の後ろに出す。無い const の要素は出さない。`stylesheets`(0.11.15)は
/// その後ろに並びの順で `<link rel="stylesheet">` を出す(client 遷移の head の差し替えで残る)。
fn shell_head_text(head: reader_front.ShellHead) -> String {
  let stylesheets =
    list.map(head.stylesheets, fn(href) {
      #(Some(href), "link", "rel", "stylesheet", "href")
    })
  [
    #(head.manifest, "link", "rel", "manifest", "href"),
    #(head.theme_color, "meta", "name", "theme-color", "content"),
    #(head.icon, "link", "rel", "icon", "href"),
    #(head.apple_touch_icon, "link", "rel", "apple-touch-icon", "href"),
    ..stylesheets
  ]
  |> list.filter_map(fn(row) {
    let #(value, tag, key, kind, value_key) = row
    case value {
      Some(value) ->
        Ok(
          "      el.element("
          <> quoted(tag)
          <> ", [\n"
          <> "        el.attribute("
          <> quoted(key)
          <> ", "
          <> quoted(kind)
          <> "),\n"
          <> "        el.attribute("
          <> quoted(value_key)
          <> ", "
          <> quoted(value)
          <> "),\n"
          <> "      ], []),\n",
        )
      None -> Error(Nil)
    }
  })
  |> string.concat
}

fn theme_source(sources: List(LoadSource)) -> Option(LoadSource) {
  list.find(sources, fn(source) { source.type_name == "PageTheme" })
  |> option.from_result
}

/// 頁の色の地の画像は `theme.PageTheme` の `Option(Blob)`。theme を取る頁は生成物 `gen/media` の
/// `theme_background` の variant で URL を組む(0.12 段 C、app の module の名を生成器が焼かない)。back に media の
/// 宣言が無い app は key のまま(地の画像の URL を組めない)。
fn theme_background_is_blob(app: model.App, theme: Option(LoadSource)) -> Bool {
  option.is_some(theme) && option.is_some(app.server.media)
}

fn theme_global_text(
  front: reader_front.Front,
  theme_background_blob: Bool,
) -> String {
  let image = case front.shell.background_image {
    "" -> "None"
    path -> "Some(" <> quoted(path) <> ")"
  }
  "fn theme_defaults() -> theme.Defaults {\n"
  <> "  theme.Defaults(\n"
  <> "    background: "
  <> quoted(front.shell.background)
  <> ",\n"
  <> "    text: "
  <> quoted(front.shell.text)
  <> ",\n"
  <> "    accent: "
  <> quoted(front.shell.accent)
  <> ",\n"
  <> "    background_image: "
  <> image
  <> ",\n"
  <> "  )\n"
  <> "}\n\n"
  <> "fn theme_image_attribute(value: Option(theme.PageTheme)) -> el.Attribute {\n"
  <> "  case theme.has_image(value, theme_defaults()) {\n"
  <> "    True -> el.attribute(\"data-yumemi-theme-image\", \"\")\n"
  <> "    False -> el.no_attribute()\n"
  <> "  }\n"
  <> "}\n\n"
  <> case theme_background_blob {
    True ->
      "fn theme_image_url(value: Blob) -> String {\n"
      <> "  media.url(value, media.theme_background)\n"
      <> "}\n"
    False ->
      "fn theme_image_url(value: Blob) -> String {\n"
      <> "  blob.to_string(value)\n"
      <> "}\n"
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
  let base =
    [
      #("css", "yumemi/front/css"),
      #("el", "yumemi/front/el"),
      #("html", "yumemi/front/html"),
      #("theme", "yumemi/front/theme"),
      #("list", "gleam/list"),
      #("style", "style"),
    ]
    |> list.filter_map(fn(item) {
      let #(reference, path) = item
      case module_alias_used(body, reference) {
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
  let blob = case
    theme_background_blob,
    string.contains(body, "fn theme_image_url")
  {
    True, _ -> ["yumemi/blob.{type Blob}", "gen/media"]
    False, True -> ["yumemi/blob.{type Blob}"]
    False, False -> []
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
  "pub fn view(it: Data) -> el.Element {\n"
  <> "  "
  <> grid_element_open(
    "\"layout\"",
    grid_style_expression(front.layout.sp, front.layout.pc, front.layout.tablet),
  )
  <> "[\n"
  <> areas
  <> "  ])\n}\n\n"
  <> "fn page_children(it: Data) -> List(el.Element) {\n"
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
      "  ["
      <> grid_element_open(
        "\"" <> page_grid_name(page) <> "\"",
        grid_style_expression(page.sp, page.pc, page.tablet),
      )
      <> children
      <> ")]\n"
    False -> "  " <> children <> "\n"
  }
}

/// 格子の要素を開く式(子の list の手前まで)。style が無ければ今の `html.div_`。
fn grid_element_open(name: String, style: Option(String)) -> String {
  let attributes = "[el.attribute(\"data-yumemi-grid\", " <> name <> ")], "
  case style {
    None -> "html.div_(" <> attributes
    Some(style) -> "html.div(css.class(" <> style <> "), " <> attributes
  }
}

/// 格子の要素に掛ける Style の式(`List(css.Style)`)。sp の style は全幅に、pc・
/// tablet の style は `css.Responsive` でその幅の media の中に(生成の格子の CSS の
/// media と同じ幅)。どの断点の Frame も style を持たなければ None。
fn grid_style_expression(
  sp: Option(reader_front.Frame),
  pc: Option(reader_front.Frame),
  tablet: Option(reader_front.Frame),
) -> Option(String) {
  let responsive =
    [
      #("css.Tablet", frame_style_expression(tablet)),
      #("css.PC", frame_style_expression(pc)),
    ]
    |> list.filter_map(fn(item) {
      case item.1 {
        Some(style) -> Ok("css.Responsive(" <> item.0 <> ", " <> style <> ")")
        None -> Error(Nil)
      }
    })
  case responsive, frame_style_expression(sp) {
    [], None -> None
    [], Some(style) -> Some(style)
    items, None -> Some("[" <> string.join(items, ", ") <> "]")
    items, Some(style) ->
      Some("[" <> string.join(items, ", ") <> ", .." <> style <> "]")
  }
}

fn frame_style_expression(frame: Option(reader_front.Frame)) -> Option(String) {
  case frame {
    Some(reader_front.Frame(style: reader_front.FrameStyleList(names), ..)) ->
      Some(
        "["
        <> string.join(list.map(names, fn(name) { "style." <> name }), ", ")
        <> "]",
      )
    Some(reader_front.Frame(style: reader_front.FrameStyleConstant(name), ..)) ->
      Some("style." <> name)
    _ -> None
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
  <> "  children: List(el.Element),\n"
  <> ") -> el.Element {\n"
  <> "  html.div(\n"
  <> "    css.class(styles),\n"
  <> "    [el.attribute(\"data-yumemi-area\", name)],\n"
  <> "    children,\n"
  <> "  )\n"
  <> "}\n\n"
}

fn plain_area_text() -> String {
  "fn plain_area(\n"
  <> "  name: String,\n"
  <> "  children: List(el.Element),\n"
  <> ") -> el.Element {\n"
  <> "  html.div_([el.attribute(\"data-yumemi-area\", name)], children)\n"
  <> "}\n\n"
}

fn overlay_area_text() -> String {
  "fn overlay_area(\n"
  <> "  name: String,\n"
  <> "  styles: List(css.Style),\n"
  <> "  children: List(el.Element),\n"
  <> ") -> el.Element {\n"
  <> "  let attributes = [\n"
  <> "    el.attribute(\"id\", el.overlay_id_prefix <> name),\n"
  <> "    el.attribute(\"popover\", \"\"),\n"
  <> "    el.attribute(\"data-yumemi-area\", name),\n"
  <> "    el.attribute(\"data-yumemi-overlay\", \"\"),\n"
  <> "  ]\n"
  <> "  case styles {\n"
  <> "    [] -> html.div_(attributes, children)\n"
  <> "    _ -> html.div(css.class(styles), attributes, children)\n"
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
    reader_front.Fixed(block: block_name, cell: cell, live: live, ..) ->
      fixed_placement_body(
        front,
        block_name,
        cell,
        sources,
        access,
        vars_access,
        vars,
      )
      |> live_wrap(block_name, live)
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
  <> ": Data) -> List(el.Element) {\n"
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

// ── Live(0.14)────────────────────────────────────────────────────────────

/// Page の sp の placements のうち `Live` のもの(Block の名と端)。
fn page_lives(page: reader_front.Page) -> List(#(String, String)) {
  case page.sp {
    Some(frame) ->
      list.filter_map(frame.placements, fn(placement) {
        case placement {
          reader_front.Fixed(block: block, live: Some(edge), ..) ->
            Ok(#(block, edge))
          _ -> Error(Nil)
        }
      })
    None -> []
  }
}

/// `Live` の Block の置き場の cell(断片も頁と同じ包みで描く)。
fn page_live_cell(page: reader_front.Page, block: String) -> reader_front.Cell {
  let cells = case page.sp {
    Some(frame) ->
      list.filter_map(frame.placements, fn(placement) {
        case placement {
          reader_front.Fixed(block: name, cell: cell, live: Some(_), ..)
            if name == block
          -> Ok(cell)
          _ -> Error(Nil)
        }
      })
    None -> []
  }
  case cells {
    [cell, ..] -> cell
    [] -> reader_front.Flow
  }
}

fn front_has_live(front: reader_front.Front) -> Bool {
  list.any(front.pages, fn(page) { page_lives(page) != [] })
}

/// Page の sp の `Fixed`(`Live` でない)の Block と置き場の cell(0.14.1、断片の口)。同じ Block が 2 か所にあれば
/// 先の 1 つ。同じ名の `Live` があれば `Live` が答える(ここには出さない)。Layout と `Widget` の Block は出さない。
fn page_fixed_blocks(
  page: reader_front.Page,
) -> List(#(String, reader_front.Cell)) {
  let lives = list.map(page_lives(page), fn(row) { live_name(row.0) })
  let placements = case page.sp {
    Some(frame) -> frame.placements
    None -> []
  }
  placements
  |> list.filter_map(fn(placement) {
    case placement {
      reader_front.Fixed(block: block, cell: cell, live: None, ..) ->
        Ok(#(block, cell))
      _ -> Error(Nil)
    }
  })
  |> list.fold([], fn(acc: List(#(String, reader_front.Cell)), row) {
    let name = live_name(row.0)
    case
      list.contains(lives, name)
      || list.any(acc, fn(seen) { live_name(seen.0) == name })
    {
      True -> acc
      False -> [row, ..acc]
    }
  })
  |> list.reverse
}

/// 面に断片の口があるか(0.14.1):どこかの Page の sp に `Live` か `Fixed` の Block がある。
fn front_has_door(front: reader_front.Front) -> Bool {
  list.any(front.pages, fn(page) {
    page_lives(page) != [] || page_fixed_blocks(page) != []
  })
}

/// `<yumemi-live name edge>` の name(Block の名の snake)。断片の口の `x-yumemi-block` の値。
fn live_name(block: String) -> String {
  naming.snake(block)
}

fn live_edge(edge: String) -> String {
  case edge {
    "Top" -> "top"
    "Anywhere" -> "anywhere"
    _ -> "bottom"
  }
}

/// `Live` の placement の要素を `<yumemi-live name edge>`(`display: contents`)で包む。札(`token`)は shell が
/// 読みの応答の header から差す。
fn live_wrap(body: String, block: String, live: Option(String)) -> String {
  case live {
    None -> body
    Some(edge) ->
      "  let live_children = {\n"
      <> body
      <> "\n  }\n  [\n    el.element(\n      \"yumemi-live\",\n      [el.attribute(\"name\", "
      <> quoted(live_name(block))
      <> "), el.attribute(\"edge\", "
      <> quoted(live_edge(edge))
      <> ")],\n      live_children,\n    ),\n  ]"
  }
}

/// `Fixed` の Block の断片(0.14.1)を `<yumemi-block name>`(`display: contents`、札を持たない)で包む。頁の
/// HTML は包まない(断片だけ)。
fn block_wrap(body: String, block: String) -> String {
  "  let block_children = {\n"
  <> body
  <> "\n  }\n  [\n    el.element(\n      \"yumemi-block\",\n      [el.attribute(\"name\", "
  <> quoted(live_name(block))
  <> ")],\n      block_children,\n    ),\n  ]"
}

/// loader の断片の関数(0.14):`live_<name>(vars, <Block の読み>)` が `<style>` と `<yumemi-live>` を返す。
/// 頁の Data の代わりに Block の読みと Vars だけの record を置き、置き場の本文は頁と同じ字を使う。
fn page_live_text(
  app: model.App,
  front: reader_front.Front,
  page: reader_front.Page,
  page_sources: List(LoadSource),
) -> String {
  let lives =
    page_lives(page)
    |> list.map(fn(row) {
      let #(block, edge) = row
      fragment_function_text(
        app,
        front,
        page,
        page_sources,
        block,
        page_live_cell(page, block),
        fn(body) { live_wrap(body, block, Some(edge)) },
        "Live",
        "live_",
        "`Live` の Block ",
      )
    })
  let fixed =
    page_fixed_blocks(page)
    |> list.map(fn(row) {
      let #(block, cell) = row
      fragment_function_text(
        app,
        front,
        page,
        page_sources,
        block,
        cell,
        fn(body) { block_wrap(body, block) },
        "Block",
        "block_",
        "`Fixed` の Block ",
      )
    })
  list.append(lives, fixed)
  |> string.join("\n")
}

/// 断片の関数 1 つ:`<prefix><name>(vars, <Block の読み>)` が `<style>` と包んだ Block を返す。
fn fragment_function_text(
  app: model.App,
  front: reader_front.Front,
  page: reader_front.Page,
  page_sources: List(LoadSource),
  block: String,
  cell: reader_front.Cell,
  wrap: fn(String) -> String,
  type_prefix: String,
  function_prefix: String,
  doc: String,
) -> String {
  let vars = list.append(page.vars, front.layout.vars)
  let name = live_name(block)
  let type_name = type_prefix <> naming.pascal(name)
  let source = case block_source(front.blocks, block, app.services) {
    Some(service) -> load_source(page_sources, "service:" <> service)
    None -> None
  }
  let #(params, fields, values) = case source {
    Some(source) -> #(
      ", " <> source.name <> ": " <> load_source_type(source),
      ", " <> source.name <> ": " <> load_source_type(source),
      ", " <> source.name <> ": " <> source.name,
    )
    None -> #("", "", "")
  }
  let body =
    fixed_placement_body(
      front,
      block,
      cell,
      page_sources,
      "it",
      "it.vars",
      vars,
    )
    |> wrap
  "pub type "
  <> type_name
  <> " {\n  "
  <> type_name
  <> "(vars: Vars"
  <> fields
  <> ")\n}\n\n"
  <> "/// "
  <> doc
  <> block
  <> " の断片(shell の `x-yumemi-block: "
  <> name
  <> "` の口)。\n"
  <> "pub fn "
  <> function_prefix
  <> name
  <> "(vars: Vars"
  <> params
  <> ") -> el.Element {\n"
  <> "  el.styled(\n    fn() { el.fragment("
  <> function_prefix
  <> name
  <> "_view("
  <> type_name
  <> "(vars: vars"
  <> values
  <> "))) },\n    \"\",\n  )\n}\n\n"
  <> "fn "
  <> function_prefix
  <> name
  <> "_view(it: "
  <> type_name
  <> ") -> List(el.Element) {\n"
  <> body
  <> "\n}\n"
}

/// `Live`(0.14)の検査。止めるもの(停止コード 4、宣言の矛盾):Layout の placements の `Live`(v0 は Page だけ)、
/// 同じ Page に同じ Block の `Live` が 2 つ、端の名が読めない、Block が Service の Out を受けない・その Service が書き
/// (`effect: Write`)・その Service に root の Entity が無い(合図の宛先が導けない)。警告(停止コード 0):Block の中の
/// 鍵の無い並び(`el.each`・`list.map`)の要素が interactive Component か `details` を持つ(鍵が無いと書きかけや開閉が別の行に化ける)、`edge: Bottom` の Block に
/// `el.fresh` が無い。
pub fn live_notes(
  app: model.App,
  package: face.Package,
  front: reader_front.Front,
) -> List(stop.Note) {
  let layout_frames =
    option_frame_list(front.layout.sp)
    |> list.append(option_frame_list(front.layout.pc))
    |> list.append(option_frame_list(front.layout.tablet))
  let layout_notes =
    layout_frames
    |> list.flat_map(fn(frame) { frame.placements })
    |> list.filter_map(fn(placement) {
      case placement {
        reader_front.Fixed(block: block, live: Some(_), ..) ->
          Ok(stop.Note(
            class: stop.Conflict,
            text: front.face
              <> " layout: Live(block: "
              <> block
              <> ") は Layout に置けない(v0 の Live は Page の placements だけ。Layout の Block は Fixed で置く)",
          ))
        _ -> Error(Nil)
      }
    })
  let page_notes =
    list.flat_map(front.pages, fn(page) {
      let wide =
        option_frame_list(page.pc)
        |> list.append(option_frame_list(page.tablet))
        |> list.flat_map(fn(frame) { frame.placements })
        |> list.filter_map(fn(placement) {
          case placement {
            reader_front.Fixed(block: block, live: Some(_), ..) ->
              Ok(stop.Note(
                class: stop.Conflict,
                text: front.face
                  <> " "
                  <> page.module
                  <> ": Live(block: "
                  <> block
                  <> ") は sp の Frame の placements に置く(pc・tablet の Frame の placements は描かれない)",
              ))
            _ -> Error(Nil)
          }
        })
      let lives = page_lives(page)
      let names = list.map(lives, fn(row) { row.0 })
      let duplicate =
        list.filter(list.unique(names), fn(name) {
          list.length(list.filter(names, fn(other) { other == name })) > 1
        })
        |> list.map(fn(name) {
          stop.Note(
            class: stop.Conflict,
            text: front.face
              <> " "
              <> page.module
              <> ": 同じ Block "
              <> name
              <> " の Live が 2 つある(断片の口の名が重なる)",
          )
        })
      list.flatten([
        wide,
        duplicate,
        list.flat_map(lives, fn(row) {
          live_block_notes(app, package, front, page, row.0, row.1)
        }),
      ])
    })
  list.append(layout_notes, page_notes)
}

/// 札を出す読みの Service の名(0.14.1、registry の `live` の読みの行)。Page の sp の Frame で `Live` に置かれた
/// Block の読みのうち、root の Entity を持ち、allow が root の当事者に絞るもの(そうでない `Live` は `live_notes` が
/// exit 4 で止める ── `live_reach`)。
pub fn live_reads(app: model.App, front: reader_front.Front) -> List(String) {
  list.flat_map(front.pages, page_lives)
  |> list.filter_map(fn(row) {
    case live_service(app, front, row.0) {
      Some(service) ->
        case
          service.effect,
          root.root_for(app, service),
          stops_live(live_reach(app, service))
        {
          model.ReadEffect, Some(_), False -> Ok(service.module)
          _, _, _ -> Error(Nil)
        }
      None -> Error(Nil)
    }
  })
  |> list.unique
}

/// `Live` の Block の Out を返す読みの Service。
fn live_service(
  app: model.App,
  front: reader_front.Front,
  block: String,
) -> Option(model.Service) {
  block_source(front.blocks, block, app.services)
  |> option.then(fn(module) {
    list.find(app.services, fn(service) { service.module == module })
    |> option.from_result
  })
}

/// `Live` の Block の読みの allow が、root の誰まで通すか(0.14.1)。札を持つ人はその root の書きの時刻を聞けるので、
/// root の当事者(`owner` が `Self`・`Via<Entity>Party`)に絞らない句を名指しする。`Warned` の他は exit 4。
type Reach {
  /// `Anyone` の句(公開の読み)。
  Public
  /// `Party` × `NoOwner`(session があれば誰でも root のどの行も通る)。
  AnyParty
  /// 中身を読めない句(定数の参照・spread など)。絞るかが分からない。
  Unread(text: String)
  /// Entity の主体 × `NoOwner`。その役が誰でも登録できる役かは生成器には分からないので警告。
  Warned(who: String)
}

fn live_reach(app: model.App, service: model.Service) -> List(Reach) {
  let public = case list.contains(service.subjects, model.SubjectAnonymous) {
    True -> [Some(Public)]
    False -> []
  }
  let clauses = case list.key_find(app.clauses, service.module) {
    Ok(clauses) -> list.map(clauses, clause_reach)
    Error(_) -> [Some(Unread("allow"))]
  }
  list.append(public, clauses)
  |> list.filter_map(option.to_result(_, Nil))
  |> list.unique
}

/// 句 1 つ。略記の `allow.staff`(`gen/allow` の句、いつも `NoOwner`)は who が小文字で来るので頭を大文字に揃える。
fn clause_reach(clause: model.Clause) -> Option(Reach) {
  case clause {
    model.UnreadClause(text) -> Some(Unread(text))
    model.Clause(owner: "NoOwner", who: who, ..) ->
      case naming.capitalise(who) {
        "Anyone" -> Some(Public)
        "Party" -> Some(AnyParty)
        "System" -> None
        who -> Some(Warned(who))
      }
    model.Clause(..) -> None
  }
}

fn stops_live(reach: List(Reach)) -> Bool {
  list.any(reach, fn(item) {
    case item {
      Warned(_) -> False
      _ -> True
    }
  })
}

fn reach_note(at: String, service: String, reach: Reach) -> stop.Note {
  let at = at <> " の Block の Service " <> service <> " の allow"
  case reach {
    Public ->
      stop.Note(
        class: stop.Conflict,
        text: at
          <> " に Anyone がある(公開の読みの札では、ログインしていない人も同じ root の非公開の書きの時刻を聞ける。Live の Block は root の当事者だけが通る読みにする)",
      )
    AnyParty ->
      stop.Note(
        class: stop.Conflict,
        text: at
          <> " の句 Party(owner: NoOwner)は session があれば誰でも root のどの行も通す(ログインした第三者が同じ root の書きの時刻を聞ける。owner を Self か Via<Entity>Party にする)",
      )
    Unread(text) ->
      stop.Note(
        class: stop.Conflict,
        text: at
          <> " の句が読めない: "
          <> text
          <> "(root の当事者だけが通る読みか判定できない。Live の Block の読みの allow は句を literal で書く)",
      )
    Warned(who) ->
      stop.Note(
        class: stop.Warning,
        text: at
          <> " の句 "
          <> who
          <> "(owner: NoOwner)は "
          <> who
          <> " なら誰でも root のどの行も通す("
          <> who
          <> " が誰でも登録できる役なら、同じ root の書きの時刻を聞ける。当事者に絞るなら owner を Self か Via<Entity>Party にする)",
      )
  }
}

fn live_block_notes(
  app: model.App,
  package: face.Package,
  front: reader_front.Front,
  page: reader_front.Page,
  block: String,
  edge: String,
) -> List(stop.Note) {
  let at = front.face <> " " <> page.module <> ": Live(block: " <> block <> ")"
  let edge_notes = case edge {
    "Bottom" | "Top" | "Anywhere" -> []
    _ -> [
      stop.Note(
        class: stop.Conflict,
        text: at <> " の edge は Bottom・Top・Anywhere のどれか",
      ),
    ]
  }
  let service = live_service(app, front, block)
  let service_notes = case service {
    None -> [
      stop.Note(
        class: stop.Conflict,
        text: at
          <> " の Block が読みの Service の Out を受けない(合図の宛先は Block の読みの root の Entity から導く)",
      ),
    ]
    Some(service) ->
      case service.effect, root.root_for(app, service) {
        model.WriteEffect, _ -> [
          stop.Note(
            class: stop.Conflict,
            text: at
              <> " の Block の Service "
              <> service.module
              <> " が書き(Live の Block は読みの Service で取り直す)",
          ),
        ]
        _, None -> [
          stop.Note(
            class: stop.Conflict,
            text: at
              <> " の Block の Service "
              <> service.module
              <> " の allow に Entity が無い(root の Entity が無く、合図の宛先が導けない)",
          ),
        ]
        _, Some(_) ->
          list.map(live_reach(app, service), reach_note(at, service.module, _))
      }
  }
  let text =
    list.find(package.units, fn(unit) {
      unit.path == block_module(front, block)
    })
    |> result.map(fn(unit) { unit.text })
    |> result.unwrap("")
  let fresh_notes = case
    edge == "Bottom" && !string.contains(text, "el.fresh(")
  {
    True -> [
      stop.Note(
        class: stop.Warning,
        text: at
          <> " は edge: Bottom で、Block に el.fresh が無い(上を読んでいる間に新着が来ても印が出ない)",
      ),
    ]
    False -> []
  }
  let each_notes = case unkeyed_list_with_state(text) {
    True -> [
      stop.Note(
        class: stop.Warning,
        text: at
          <> " の Block の鍵の無い並び(el.each・list.map)の要素が interactive Component か details を持つ(鍵が無いと、前に行が入ったとき書きかけや開閉が別の行に化ける。el.each_keyed で鍵を付ける)",
      ),
    ]
    False -> []
  }
  list.flatten([edge_notes, service_notes, fresh_notes, each_notes])
}

/// Block の字で、鍵の無い並び(`el.each(`・`list.map(`・`list.index_map(`・`list.flat_map(`)の呼び出しの中(引数の
/// 字)か、そこから名で呼ぶ同じ module の関数(推移的に)が、`interactive.` の Component か素の `details`
/// (`html.details`・`el.element("details"`)を描くか。字で見る近似(Block は view の関数を並べるだけの module)。
fn unkeyed_list_with_state(text: String) -> Bool {
  let functions = module_functions(text)
  let with_state =
    component_functions(
      functions,
      list.filter_map(functions, fn(row) {
        case holds_user_state(row.1) {
          True -> Ok(row.0)
          False -> Error(Nil)
        }
      }),
    )
  unkeyed_list_texts(text)
  |> list.any(fn(call) {
    holds_user_state(call)
    || list.any(with_state, fn(name) { mentions(call, name) })
  })
}

/// 字が利用者の持ち物(書きかけ・開閉)を持つ要素を描くか。
fn holds_user_state(text: String) -> Bool {
  string.contains(text, "interactive.")
  || string.contains(text, "html.details")
  || string.contains(text, "el.element(\"details\"")
}

fn component_functions(
  functions: List(#(String, String)),
  found: List(String),
) -> List(String) {
  let more =
    list.filter_map(functions, fn(row) {
      case
        !list.contains(found, row.0)
        && list.any(found, fn(name) { mentions(row.1, name) })
      {
        True -> Ok(row.0)
        False -> Error(Nil)
      }
    })
  case more {
    [] -> found
    _ -> component_functions(functions, list.append(found, more))
  }
}

/// 字の中に名が語として現れるか(前後が名の字でない)。
fn mentions(text: String, name: String) -> Bool {
  string.split(text, name)
  |> list.window_by_2
  |> list.any(fn(pair) {
    !ends_with_name_char(pair.0) && !starts_with_name_char(pair.1)
  })
}

fn ends_with_name_char(text: String) -> Bool {
  case string.last(text) {
    Ok(char) -> is_name_char(char)
    Error(_) -> False
  }
}

fn starts_with_name_char(text: String) -> Bool {
  case string.first(text) {
    Ok(char) -> is_name_char(char)
    Error(_) -> False
  }
}

fn is_name_char(char: String) -> Bool {
  string.contains(
    "abcdefghijklmnopqrstuvwxyz0123456789_.",
    string.lowercase(char),
  )
}

/// module の `fn <name>(` から次の `fn ` の手前までを、その関数の字とする(名と字の組)。
fn module_functions(text: String) -> List(#(String, String)) {
  string.split(text, "fn ")
  |> list.drop(1)
  |> list.filter_map(fn(chunk) {
    case string.split_once(chunk, "(") {
      Ok(#(name, rest)) ->
        case is_identifier(name) {
          True -> Ok(#(name, rest))
          False -> Error(Nil)
        }
      Error(_) -> Error(Nil)
    }
  })
}

fn is_identifier(name: String) -> Bool {
  name != ""
  && list.all(string.to_graphemes(name), fn(char) {
    string.contains("abcdefghijklmnopqrstuvwxyz0123456789_", char)
  })
}

/// 鍵の無い並びの呼び出しの引数の字(括弧の釣り合いで切る)。`el.each_keyed(` は入らない。
fn unkeyed_list_texts(text: String) -> List(String) {
  ["el.each(", "list.map(", "list.index_map(", "list.flat_map("]
  |> list.flat_map(fn(call) {
    string.split(text, call)
    |> list.drop(1)
    |> list.map(fn(rest) { balanced(string.to_graphemes(rest), 1, []) })
  })
}

fn balanced(chars: List(String), depth: Int, acc: List(String)) -> String {
  case chars {
    [] -> string.concat(list.reverse(acc))
    [char, ..rest] ->
      case char {
        "(" -> balanced(rest, depth + 1, [char, ..acc])
        ")" ->
          case depth - 1 {
            0 -> string.concat(list.reverse(acc))
            next -> balanced(rest, next, [char, ..acc])
          }
        _ -> balanced(rest, depth, [char, ..acc])
      }
  }
}

/// shell の Page の表の `lives`(Block の名 → 端・読みの Service・loader の断片の関数)と、0.14.1 の `blocks`
/// (`Fixed` の Block の名 → 読みの Service か null・loader の断片の関数)。
fn shell_live_rows(
  app: model.App,
  front: reader_front.Front,
  page: reader_front.Page,
  index: Int,
) -> String {
  let service_of = fn(block) {
    case block_source(front.blocks, block, app.services) {
      Some(service) -> "service.Service$" <> naming.pascal(service) <> "$const"
      None -> "null"
    }
  }
  let lives = case page_lives(page) {
    [] -> ""
    lives ->
      "    lives: {\n"
      <> string.concat(
        list.map(lives, fn(row) {
          let #(block, edge) = row
          let name = live_name(block)
          "      "
          <> quoted(name)
          <> ": { edge: "
          <> quoted(live_edge(edge))
          <> ", service: "
          <> service_of(block)
          <> ", render: pageLoader"
          <> int.to_string(index)
          <> ".live_"
          <> name
          <> " },\n"
        }),
      )
      <> "    },\n"
  }
  let blocks = case page_fixed_blocks(page) {
    [] -> ""
    rows ->
      "    blocks: {\n"
      <> string.concat(
        list.map(rows, fn(row) {
          let name = live_name(row.0)
          "      "
          <> quoted(name)
          <> ": { service: "
          <> service_of(row.0)
          <> ", render: pageLoader"
          <> int.to_string(index)
          <> ".block_"
          <> name
          <> " },\n"
        }),
      )
      <> "    },\n"
  }
  lives <> blocks
}

fn fixed_cell_wrapper(children: String, style: String) -> String {
  "  list.map(\n"
  <> indent_expression(children, "    ")
  <> ",\n"
  <> "    fn(child) {\n"
  <> "      html.div_([el.attribute(\"style\", "
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
  <> ") -> List(el.Element) {\n"
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
  let sorted =
    pages
    |> list.map(fn(page) {
      #(route_variant(page), reader_front.route_path(page.path))
    })
    |> list.sort(fn(left, right) { route_order(left.1, right.1) })
  let variants =
    sorted
    |> list.map(fn(pair) { pair.0 })
    |> list.unique
  let rows =
    sorted
    |> list.map(fn(pair) {
      "  PageRoute(route: " <> pair.0 <> ", path: \"" <> pair.1 <> "\"),"
    })
    |> string.join("\n")
  header(face_name <> "/src/pages/**/page.gleam", input_hash)
  <> "\n/// 面の Page の閉じた enum(interactive Component の `live.GoTo` の行き先)。\n"
  <> case variants {
    [] -> "pub type Route\n"
    _ ->
      "pub type Route {\n"
      <> string.concat(
        list.map(variants, fn(variant) { "  " <> variant <> "\n" }),
      )
      <> "}\n"
  }
  <> "\npub type PageRoute {\n  PageRoute(route: Route, path: String)\n}\n\n"
  <> "pub const routes: List(PageRoute) = [\n"
  <> rows
  <> "\n]\n"
}

/// 第 18 条:2 つの Page の `Route` の variant 名が重なる。
fn route_variant_notes(
  package: face.Package,
  front: reader_front.Front,
) -> List(stop.Note) {
  let names = list.map(front.pages, route_variant)
  names
  |> list.filter(fn(name) { list.count(names, fn(other) { other == name }) > 1 })
  |> list.unique
  |> list.map(fn(name) {
    stop.Note(
      class: stop.Conflict,
      text: package.name
        <> ": 2 つの Page の生成名が重なる(第 18 条、gen/route の Route): "
        <> name,
    )
  })
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
  <> "\nimport yumemi/front as front\nimport gen/service\n\n"
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
        list.map(component.calls, reader_front.call_target_name),
        case component.reloads {
          Some(reloads) -> [reloads.read]
          None -> []
        },
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
  state_css: String,
  has_escapes: Bool,
) -> String {
  let decoder_services = shell_services(app, units, front)
  let source_hash =
    source_hash(package.units, fn(unit) {
      unit.path == "layout"
      || unit.path == "shell"
      || string.starts_with(unit.path, "pages/")
      || unit.path == "failure"
    })
  let failure_source = case front.failure {
    Some(_) -> ",failure.gleam"
    None -> ""
  }
  js_header(
    package.name
      <> "/src/{gen/route.gleam,gen/load/**,pages/**,layout.gleam,shell.gleam"
      <> failure_source
      <> "}",
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
    // 0.12 段 C:逃げ道だけの面も client を読む(`yumemi-escape` の mount)
    front.components != []
      || option.is_some(front.shell.head.service_worker)
      || has_escapes
      || front_has_live(front),
    front_has_live(front),
    front_has_door(front),
    option.is_some(front.failure),
    uses_current_route(front),
    uses_page_theme(app, units, front),
    static_grid_css(front.layout)
      <> static_pages_grid_css(reader_front.with_failure(front).pages)
      <> generated_front_css(reader_front.with_failure(front))
      // 0.12 段 C:interactive Component の `when` の枝を隠す規則(SSR の頁の `<style>` にも出す)
      <> state_css,
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
      <> string.inspect(gate.session_path)
      <> case front.failure {
        Some(_) -> "failure"
        None -> ""
      },
    )
  File(
    path: package.name <> "/src/gen/gate.mjs",
    text: gate_emit.text_failure(
      js_header(
        package.name
          <> "/src/{gate.gleam,pages/**} and src/{entry,server}.gleam",
        input_hash,
      ),
      gate,
      front_route_paths(front),
      front_has_door(front),
      option.is_some(front.failure),
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

/// `Live` の Block の runtime を起こす client.mjs の行(0.14)。面に `Live` が無ければ ""。socket の口は面の入口の
/// prefix + `/_yumemi/live`(api の口、yumemi-live-1)。頁ごと取り直すのは navigate の `reload`(route 表が無ければ
/// 頁の読み込み)。
fn live_client_text(
  app: model.App,
  package: face.Package,
  front: reader_front.Front,
) -> String {
  case front_has_live(front) {
    False -> ""
    True -> {
      let prefix =
        list.find(app.entries, fn(entry) { entry.name == package.name })
        |> result.map(fn(entry) { entry.prefix })
        |> result.unwrap("")
      let reload = case front_route_paths(front) {
        [] -> "null"
        _ -> "reloadPage"
      }
      "startLive({ socket: "
      <> quoted(prefix <> "/_yumemi/live")
      <> ", reload: "
      <> reload
      <> " });\n"
    }
  }
}

/// 数える口の送り手を起こす client.mjs の行(0.12)。門が `pageview` を宣言していなければ "".
/// 宛先は面の入口の prefix + `/_yumemi/pageviews`、前の event の鎖の鍵は `yumemi:pageview:<面の名>`。
fn pageview_client_text(
  app: model.App,
  back_units: List(Unit),
  package: face.Package,
  front: reader_front.Front,
) -> String {
  case read_gate(app, back_units, package, front).0.pageview {
    None -> ""
    Some(pageview) -> {
      let prefix =
        list.find(app.entries, fn(entry) { entry.name == package.name })
        |> result.map(fn(entry) { entry.prefix })
        |> result.unwrap("")
      let fields =
        list.map(pageview.fields, fn(field) {
          case field {
            model.NavKindField -> "{ type: \"kind\" }"
            model.ClientAtField -> "{ type: \"client_at\" }"
            model.PathField -> "{ type: \"path\" }"
            model.PreviousField -> "{ type: \"previous\" }"
            model.ReferrerField -> "{ type: \"referrer\" }"
            model.FromQueryField(name: name, param: param, max: max) ->
              "{ type: \"query\", name: "
              <> quoted(name)
              <> ", param: "
              <> quoted(param)
              <> ", max: "
              <> int.to_string(max)
              <> " }"
          }
        })
      "import { start as startPageview } from \"__YUMEMI_BUILD__/yumemi/yumemi/front/pageview.mjs\";\n"
      <> "startPageview({ endpoint: "
      <> quoted(prefix <> "/_yumemi/pageviews")
      <> ", key: "
      <> quoted("yumemi:pageview:" <> package.name)
      <> ", fields: ["
      <> string.join(fields, ", ")
      <> "] });\n"
    }
  }
}

/// 面の門(数える口を back の入口へ渡すのに生成器の入口が読む、0.12)。
pub fn gate(
  app: model.App,
  back_units: List(Unit),
  package: face.Package,
  front: reader_front.Front,
) -> reader_gate.Gate {
  read_gate(app, back_units, package, front).0
}

/// 門の宣言(`src/gate.gleam`)の診断。
pub fn gate_notes(
  app: model.App,
  back_units: List(Unit),
  package: face.Package,
  front: reader_front.Front,
) -> List(stop.Note) {
  let #(gate, notes) = read_gate(app, back_units, package, front)
  list.append(notes, cms.gate_notes(app, package.name, gate))
}

fn shell_imports(
  services: List(model.Service),
  front: reader_front.Front,
) -> String {
  let base = [
    "import {Some, Option$None$const} from \"../../gleam_stdlib/gleam/option.mjs\";",
    "import {Ok} from \"../gleam.mjs\";",
    "import {run as decodeRun} from \"../../gleam_stdlib/gleam/dynamic/decode.mjs\";",
    case front_has_door(front) {
      True ->
        "import {to_document_string, to_string as to_fragment_string} from \"../../yumemi/yumemi/front/el.mjs\";"
      False ->
        "import {to_document_string} from \"../../yumemi/yumemi/front/el.mjs\";"
    },
    "import * as frontCss from \"../../yumemi/yumemi/front/css.mjs\";",
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
  let failure = case front.failure {
    Some(_) -> [
      "import * as failureDefinition from \"../failure.mjs\";",
      "import * as failureLoader from \"./load/failure.mjs\";",
    ]
    None -> []
  }
  list.append(base, list.append(outs, list.append(pages, failure)))
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
        list.map(component.calls, reader_front.call_target_name),
        case component.reloads {
          Some(reloads) -> [reloads.read]
          None -> []
        },
      )
      |> list.filter_map(fn(variant) {
        case service_for(app.services, variant) {
          Some(service) -> Ok(service.module)
          None -> Error(Nil)
        }
      })
    })
  let from_failure = case front.failure {
    Some(_) ->
      layout_sources(front.layout, front.blocks, app.services)
      |> list.map(fn(source) { source.service })
    None -> []
  }
  let names =
    list.unique(list.append(
      from_pages,
      list.append(from_components, from_failure),
    ))
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
      <> shell_var_rows(front, page, reader_front.route_path(page.path))
      <> "    ],\n"
      <> "    givens: [\n"
      <> shell_given_rows(app, front, page)
      <> "    ],\n"
      <> "    sources: [\n"
      <> shell_source_rows(app, units, front, page, sources)
      <> "    ],\n"
      <> shell_live_rows(app, front, page, index)
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
  <> case front.failure {
    Some(page) -> failure_spec_text(app, units, front, page)
    None -> ""
  }
}

/// 失敗の頁(0.14.3)の表。Vars は `Failure`・`CurrentRoute`(空の字)と Layout の `Origin`・`AuthOrigin`、読みは
/// Layout の Widget だけ(どれも optional。読めなければその Widget を描かない)。`failureDefinition` は宣言の module。
fn failure_spec_text(
  app: model.App,
  units: List(Unit),
  front: reader_front.Front,
  page: reader_front.Page,
) -> String {
  let sources = layout_sources(front.layout, front.blocks, app.services)
  "// 0.14.3:失敗の頁(`src/failure.gleam` の `page`)\n"
  <> "const failureSpec = {\n"
  <> "  definition: failureDefinition.page,\n"
  <> "  loader: failureLoader,\n"
  <> "  layout: layoutDefinition."
  <> js_export_name(front.layout.name)
  <> ",\n"
  <> "  vars: [\n"
  <> string.replace(shell_var_rows(front, page, ""), "      {", "    {")
  <> "  ],\n"
  <> "  sources: [\n"
  <> string.replace(
    shell_source_rows(app, units, front, page, sources),
    "      {",
    "    {",
  )
  <> "  ],\n"
  <> "};\n"
}

/// 0.12 段 C:given は無くなった(`reloads` の戻りは out の span か頁の取り直し)。殻の runtime の givens の
/// 表は空のまま(`shell_runtime_text` は Y6 の持ち場なので、空の表を読む形を残す)。
fn shell_given_rows(
  _app: model.App,
  _front: reader_front.Front,
  _page: reader_front.Page,
) -> String {
  ""
}

fn shell_var_rows(
  front: reader_front.Front,
  page: reader_front.Page,
  route: String,
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
    <> shell_var_source(var.from, route)
    <> " },\n"
  })
  |> string.concat
}

fn shell_var_source(source: reader_front.From, route: String) -> String {
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
    reader_front.CurrentRoute ->
      "{ type: \"route\", value: " <> quoted(route) <> " }"
    reader_front.Failure -> "{ type: \"failure\" }"
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
  units: List(Unit),
  front: reader_front.Front,
  page: reader_front.Page,
  sources: List(LoadSource),
) -> String {
  sources
  |> list.map(fn(source) {
    case source.type_name == "PageTheme" {
      True ->
        case page_theme_path(units, source.service, source.name) {
          Some(path) ->
            "      { theme: true, from: service.Service$"
            <> naming.pascal(source.service)
            <> "$const, path: ["
            <> string.join(
              list.map(path, fn(step) {
                "[" <> quoted(step.0) <> ", " <> bool_text(step.1) <> "]"
              }),
              ", ",
            )
            <> "] },\n"
          None -> "      { theme: true },\n"
        }
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
      unit.path == "layout"
      || string.starts_with(unit.path, "pages/")
      || unit.path == "failure"
    })
  let front = reader_front.with_failure(front)
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
  case front_has_live(front) {
    True -> "yumemi-live { display: contents; }\n"
    False -> ""
  }
  <> badge_css()
  <> closed_dialog_css()
  <> hidden_css()
  <> case front_has_overlay(front) {
    True -> "[popover]::backdrop { background: rgba(0, 0, 0, 0.45); }\n"
    False -> ""
  }
  <> anchored_overlay_css(front)
}

/// `pin: css.AnchoredOverlay(..)` の Area を、開いた `el.opener` の下か上へ寄せる。
/// CSS anchor positioning を支える browser だけに効く(`@supports`)── 支えない
/// browser では今の Overlay と同じく UA の既定で中央に開き、backdrop も暗くなる。
/// 寄せた Overlay は backdrop を暗くしない。同じ名の opener が複数あれば、anchor は
/// 文書順で最後の 1 つ(CSS anchor positioning の規則)。
fn anchored_overlay_css(front: reader_front.Front) -> String {
  let frames =
    list.append(
      option_frame_list(front.layout.sp)
        |> list.append(option_frame_list(front.layout.pc))
        |> list.append(option_frame_list(front.layout.tablet)),
      list.flat_map(front.pages, fn(page) {
        option_frame_list(page.sp)
        |> list.append(option_frame_list(page.pc))
        |> list.append(option_frame_list(page.tablet))
      }),
    )
  let anchored =
    frames
    |> list.flat_map(fn(frame) { frame.areas })
    |> list.filter_map(fn(area) {
      case area.pin, area.anchor {
        "Overlay", Some(anchor) -> Ok(#(area.name, anchor))
        _, _ -> Error(Nil)
      }
    })
    |> unique_by_name
  case anchored {
    [] -> ""
    _ ->
      "@supports (anchor-name: --yumemi) {\n"
      <> string.concat(list.map(anchored, anchored_overlay_rule))
      <> "}\n"
  }
}

fn unique_by_name(
  items: List(#(String, reader_front.OverlayAnchor)),
) -> List(#(String, reader_front.OverlayAnchor)) {
  list.fold(items, [], fn(found, item) {
    case list.key_find(found, item.0) {
      Ok(_) -> found
      Error(_) -> list.append(found, [item])
    }
  })
}

fn anchored_overlay_rule(
  item: #(String, reader_front.OverlayAnchor),
) -> String {
  let #(name, anchor) = item
  let anchor_name = "--yumemi-overlay-" <> css_ident(name)
  let area = "[data-yumemi-overlay][data-yumemi-area=\"" <> name <> "\"]"
  let block = case anchor.side {
    "Above" -> "block-start"
    _ -> "block-end"
  }
  // 始端をそろえる = ボタンの始端から終端の向きへ伸ばす
  let inline = case anchor.align {
    "AlignEnd" -> "span-inline-start"
    _ -> "span-inline-end"
  }
  "  [data-yumemi-overlay-opener][popovertarget=\"yumemi-overlay-"
  <> name
  <> "\"] { anchor-name: "
  <> anchor_name
  <> "; }\n"
  <> "  "
  <> area
  <> " {\n"
  <> "    position-anchor: "
  <> anchor_name
  <> ";\n"
  <> "    position-area: "
  <> block
  <> " "
  <> inline
  <> ";\n"
  <> "    position-try-fallbacks: flip-block;\n"
  <> "    inset: auto;\n"
  <> "    margin: 0;\n"
  <> "  }\n"
  <> "  "
  <> area
  <> "::backdrop { background: transparent; }\n"
}

/// dashed-ident に書けない字を `_` にする。
fn css_ident(name: String) -> String {
  name
  |> string.to_graphemes
  |> list.map(fn(char) {
    case is_ident_char(char) {
      True -> char
      False -> "_"
    }
  })
  |> string.concat
}

fn is_ident_char(char: String) -> Bool {
  case string.to_utf_codepoints(char) {
    [codepoint] -> {
      let code = string.utf_codepoint_to_int(codepoint)
      { code >= 97 && code <= 122 }
      || { code >= 65 && code <= 90 }
      || { code >= 48 && code <= 57 }
      || code == 45
      || code == 95
    }
    _ -> False
  }
}

/// 閉じた `<dialog>` を出さない(0.12.1)。UA の `dialog:not([open]) { display: none }` は作り手の Style の
/// `display`(`Flow` ほか)に負けるので、`!important` で、`@layer` の中にも置く ── 層の中の `!important` は層の
/// 外の `!important` より強い(`@layer` の無い browser は層の外の 1 行が効く)。
fn closed_dialog_css() -> String {
  "dialog:not([open]) { display: none !important; }\n"
  <> "@layer yumemi-closed-dialog { dialog:not([open]) { display: none !important; } }\n"
}

/// `hidden` の付いた要素を出さない(0.14.2)。UA の `[hidden] { display: none }` は作り手の Style の `display`
/// (`Flow` ほか)に負けるので、閉じた dialog と同じ形で `!important` を、`@layer` の中にも置く。`el.fresh` の
/// `[data-yumemi-fresh][hidden]` もこの規則に含まれる。`hidden="until-found"` だけは除く ── その値の UA の規則は
/// `display` でなく `content-visibility: hidden` で、`display: none` にすると browser 内検索と URL の fragment が
/// 中身を見つけて開けなくなる。
fn hidden_css() -> String {
  let rule =
    "[hidden]:not([hidden=until-found i]) { display: none !important; }"
  rule <> "\n" <> "@layer yumemi-hidden { " <> rule <> " }\n"
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
  <> "  color: var(--yumemi-theme-bg);\n"
  <> "  background: var(--yumemi-theme-accent);\n"
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
    style: reader_front.NoFrameStyle,
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

fn framework_area_flow(flow: reader_front.AreaFlow) -> framework_css.Flow {
  case flow {
    reader_front.StackFlow(gap:) ->
      framework_css.Stack(gap: framework_length(gap))
    reader_front.RowFlow(gap:, wrap:) ->
      framework_css.Row(gap: framework_length(gap), wrap: wrap)
    reader_front.GridFlow(cols:, gap:) ->
      framework_css.Grid(cols: cols, gap: framework_length(gap))
    reader_front.ScrollerFlow -> framework_css.Scroller
  }
}

fn framework_length(length: reader_front.Length) -> framework_css.Length {
  case length {
    reader_front.RemLength(value) -> framework_css.Rem(value)
    reader_front.PxLength(value) -> framework_css.Px(value)
    reader_front.VarLength(name) -> framework_css.Var(name)
    reader_front.EnvLength(edge) -> framework_css.Env(safe_area_of(edge))
    reader_front.DvhLength(value) -> framework_css.Dvh(value)
  }
}

fn safe_area_of(edge: String) -> framework_css.SafeArea {
  case edge {
    "top" -> framework_css.SafeTop
    "right" -> framework_css.SafeRight
    "left" -> framework_css.SafeLeft
    _ -> framework_css.SafeBottom
  }
}

fn length_css(length: reader_front.Length) -> String {
  framework_sketch_css.length_to_string(framework_length(length))
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
      || frame_style_expression(Some(frame)) != None
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
  // Area の flow(GridTracks 以外)── その Area を flex / grid にする。表示に戻す
  // media の規則では display を flow の側が書くので `display: block` を足さない。
  let flow = case area.pin, area.flow_layout {
    "Overlay", _ -> []
    _, Some(flow) ->
      framework_front.area_flow_css(framework_area_flow(flow))
      |> list.map(fn(line) { "  " <> line })
    _, None -> []
  }
  let visible = case visibility, flow {
    "hidden", _ -> ["  display: none;"]
    "visible", [] -> ["  display: block;"]
    _, _ -> []
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
    // 下端に着く棒:画面の下端(0)に留め、safe area の分は棒の内側の下の余白で持つ。
    "BottomFlush" -> [
      "  position: sticky;",
      "  bottom: 0;",
      "  padding-bottom: env(safe-area-inset-bottom, 0px);",
      "  z-index: 3;",
    ]
    _ -> []
  }
  string.join(
    list.append(
      base,
      list.append(
        grid_area,
        list.append(
          grid_tracks,
          list.append(flow, list.append(visible, list.append(pin, ["}"]))),
        ),
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

/// 面のどこかの Var が `CurrentRoute` を持つか。持たない面の shell には route の
/// 分岐を出さない(足した語彙を使わない面の生成を変えないため)。
fn uses_current_route(front: reader_front.Front) -> Bool {
  front.layout.vars
  |> list.append(list.flat_map(front.pages, fn(page) { page.vars }))
  |> list.any(fn(var) { var.from == reader_front.CurrentRoute })
}

fn shell_runtime_text(
  include_client: Bool,
  include_live: Bool,
  include_door: Bool,
  include_failure: Bool,
  include_route: Bool,
  include_theme: Bool,
  grid_css: String,
) -> String {
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
  <> case include_theme {
    True ->
      "function pageTheme(path, value) {\n"
      <> "  if (value === undefined || value === null) return Option$None$const;\n"
      <> "  for (const [field, optional] of path) {\n"
      <> "    value = value[field];\n"
      <> "    if (value instanceof Some) value = value[0];\n"
      <> "    else if (optional || value === undefined || value === null) return Option$None$const;\n"
      <> "  }\n"
      <> "  return new Some(value);\n"
      <> "}\n\n"
    False ->
      "function pageTheme(definition, root) {\n"
      <> "  if (!(definition.theme instanceof Some)) return Option$None$const;\n"
      <> "  return root[definition.theme[0]] ?? Option$None$const;\n"
      <> "}\n\n"
  }
  <> case include_failure {
    // 0.14.3:平文は門の `plain`(頁を求める要求なら失敗の頁に替わる印を門と共に持つ)
    True ->
      "function failure(status, body) {\n"
      <> "  return gate.plain(status, body);\n"
      <> "}\n\n"
    False ->
      "function failure(status, body) {\n"
      <> "  return new Response(body, {status, headers: {\"content-type\": \"text/plain; charset=utf-8\"}});\n"
      <> "}\n\n"
  }
  <> "async function renderPage(request, env, matched, gateSession) {\n"
  <> shell_vars_text(include_route)
  <> "  const values = [vars];\n"
  <> case include_live {
    True -> "  const tokens = new Map();\n"
    False -> ""
  }
  <> case include_theme {
    True ->
      "  const read = new Map();\n"
      <> "  for (const source of matched.spec.sources) {\n"
      <> "    if (source.theme) {\n"
      <> "      values.push(pageTheme(source.path ?? [], read.get(source.from)));\n"
      <> "      continue;\n"
      <> "    }\n"
    False ->
      "  let root = null;\n"
      <> "  for (const source of matched.spec.sources) {\n"
      <> "    if (source.theme) {\n"
      <> "      values.push(pageTheme(matched.definition, root));\n"
      <> "      continue;\n"
      <> "    }\n"
  }
  <> "    let response;\n"
  <> "    try {\n"
  <> "      response = await readFromApp(env.APP, request, source.service, argsFor(vars, source.args));\n"
  <> "    } catch (error) {\n"
  <> "      console.error(source.root ? \"yumemi shell: root read error\" : \"yumemi shell: widget read error\", 502, error);\n"
  <> "      return failure(503, \"unavailable\");\n"
  <> "    }\n"
  <> "    if (!response.ok) {\n"
  <> "      if (response.status === 403) return failure(403, \"forbidden\");\n"
  <> "      if (response.status === 404 && !source.root) { values.push(Option$None$const); continue; }\n"
  <> "      if (response.status === 404) return failure(404, \"not found\");\n"
  <> "      // 読みの 5xx は門と同じ 503 の unavailable、元の status と原因は log へ(0.12)\n"
  <> "      if (response.status >= 500) {\n"
  <> "        console.error(source.root ? \"yumemi shell: root read error\" : \"yumemi shell: widget read error\", response.status, await response.text().catch(() => \"\"));\n"
  <> "        return failure(503, \"unavailable\");\n"
  <> "      }\n"
  <> "      return failure(response.status, source.root ? \"root read failed\" : \"widget read failed\");\n"
  <> "    }\n"
  <> case include_live {
    True ->
      "    // 0.14:読みの札(`x-yumemi-live`)。`Live` の Block の読みのものを `<yumemi-live>` に差す\n"
      <> "    const token = response.headers.get(\"x-yumemi-live\");\n"
      <> "    if (token) tokens.set(source.service, token);\n"
    False -> ""
  }
  <> "    const decoded = source.decoder(await response.json());\n"
  <> case include_theme {
    True -> "    read.set(source.service, decoded);\n"
    False -> "    if (source.root) root = decoded;\n"
  }
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
  <> case include_live {
    True ->
      "  let withGivens = addGivenAttributes(html, givens);\n"
      <> "  for (const [name, live] of Object.entries(matched.spec.lives ?? {})) withGivens = withLiveToken(withGivens, name, tokens.get(live.service));\n"
    False -> "  const withGivens = addGivenAttributes(html, givens);\n"
  }
  <> "  return new Response(htmlWithGridCss(withGivens, matched.spec.layout), {status: 200, headers: {\"content-type\": \"text/html; charset=utf-8\"}});\n"
  <> "}\n\n"
  <> case include_door {
    True -> shell_block_text(include_route, include_live)
    False -> ""
  }
  <> case include_failure {
    True -> shell_failure_text()
    False -> ""
  }
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
  <> case include_failure {
    True ->
      "    return failurePage(request, env, failure(404, \"not found\"));\n"
    False -> "    return failure(404, \"not found\");\n"
  }
  <> "  }\n"
  <> case include_door, include_failure {
    True, False ->
      "  // 0.14:Block の断片の口(0.14.1 から `Fixed` の Block も)。門は頁と同じ道を通った後(数える印は差さない)\n"
      <> "  const block = request.headers.get(\"x-yumemi-block\");\n"
      <> "  if (block !== null) return renderBlock(request, env, matched, before.session, block);\n"
    True, True ->
      "  // 0.14:Block の断片の口(0.14.1 から `Fixed` の Block も)。門は頁と同じ道を通った後(数える印は差さない)\n"
      <> "  // 断片の口は頁を求める要求でないので、失敗は平文のまま(0.14.3)\n"
      <> "  const block = request.headers.get(\"x-yumemi-block\");\n"
      <> "  if (block !== null) return guarded(() => renderBlock(request, env, matched, before.session, block));\n"
    False, _ -> ""
  }
  <> case include_failure {
    True ->
      "  return failurePage(request, env, await guarded(() => renderPage(request, env, matched, before.session)));\n"
      <> "}, failurePage);\n\n"
      <> "// 0.14.3:面の入口が自分の平文の代わりに呼ぶ口(`failure(request, env, status)`)\n"
      <> "export {failureFor as failure};\n"
    False ->
      "  return renderPage(request, env, matched, before.session);\n" <> "});\n"
  }
}

/// 失敗の頁(0.14.3)の runtime。平文の失敗(`gate.plain`)を、頁を求める要求(`gate.wantsPage`)なら面の失敗の頁で
/// 返す(状態は元の値、印 `x-yumemi-failure: <status>`)。失敗の頁が描けない(Origin の env が無い・描画の例外)とき
/// は平文のまま ── 失敗の頁から失敗の頁へ回さない。描画の例外は log に出して 500 の unavailable。
fn shell_failure_text() -> String {
  "// 0.14.3:失敗の種類(`Failure` の値)。401・403 は forbidden、5xx は unavailable、それ以外の 4xx は not_found\n"
  <> "function failureKind(status) {\n"
  <> "  if (status === 401 || status === 403) return \"forbidden\";\n"
  <> "  if (status >= 500) return \"unavailable\";\n"
  <> "  return \"not_found\";\n"
  <> "}\n\n"
  <> "// 失敗の頁の Vars。置けるのは Failure・CurrentRoute(空の字)と Layout の Origin・AuthOrigin(第 45 条)。\n"
  <> "// Origin の env が無ければ null(平文に落とす。env の名を頁に出さない)\n"
  <> "function failureVars(env, status) {\n"
  <> "  const vars = {};\n"
  <> "  for (const field of failureSpec.vars) {\n"
  <> "    const source = field.from;\n"
  <> "    let value;\n"
  <> "    if (source.type === \"failure\") value = failureKind(status);\n"
  <> "    else if (source.type === \"route\") value = source.value;\n"
  <> "    else if (source.type === \"origin\" || source.type === \"auth-origin\") {\n"
  <> "      value = env[source.type === \"origin\" ? \"PUBLIC_\" + source.name.toUpperCase() + \"_ORIGIN\" : \"PUBLIC_IDP_ORIGIN\"];\n"
  <> "      if (typeof value !== \"string\" || value.length === 0) return null;\n"
  <> "    } else return null;\n"
  <> "    vars[field.name] = value;\n"
  <> "  }\n"
  <> "  return vars;\n"
  <> "}\n\n"
  <> "// 失敗の頁を描く。Layout の Widget は読み、読めない(4xx・5xx・例外・decode の失敗)ならその Widget を描かない\n"
  <> "async function renderFailure(request, env, status) {\n"
  <> "  const vars = failureVars(env, status);\n"
  <> "  if (vars === null) return null;\n"
  <> "  const values = [vars];\n"
  <> "  for (const source of failureSpec.sources) {\n"
  <> "    let value = Option$None$const;\n"
  <> "    try {\n"
  <> "      const response = await readFromApp(env.APP, request, source.service, argsFor(vars, source.args));\n"
  <> "      if (response.ok) value = new Some(source.decoder(await response.json()));\n"
  <> "      else {\n"
  <> "        console.error(\"yumemi shell: failure widget read error\", response.status);\n"
  <> "        await response.body?.cancel();\n"
  <> "      }\n"
  <> "    } catch (error) {\n"
  <> "      console.error(\"yumemi shell: failure widget read error\", error);\n"
  <> "    }\n"
  <> "    values.push(value);\n"
  <> "  }\n"
  <> "  const html = to_document_string(failureSpec.loader.render(failureSpec.loader.load(...values)));\n"
  <> "  return htmlWithGridCss(html, failureSpec.layout);\n"
  <> "}\n\n"
  <> "// 平文の失敗を、頁を求める要求なら失敗の頁に替える。門で止めた失敗も `gate.serve` の 2 つ目の引数としてここを通る\n"
  <> "async function failurePage(request, env, response) {\n"
  <> "  if (!gate.isPlain(response) || !gate.wantsPage(request)) return response;\n"
  <> "  let html;\n"
  <> "  try {\n"
  <> "    html = await renderFailure(request, env, response.status);\n"
  <> "  } catch (error) {\n"
  <> "    console.error(\"yumemi shell: failure page error\", error);\n"
  <> "    html = null;\n"
  <> "  }\n"
  <> "  if (html === null) return response;\n"
  <> "  await response.body?.cancel();\n"
  <> "  return new Response(html, {status: response.status, headers: {\"content-type\": \"text/html; charset=utf-8\", \"cache-control\": \"no-store\", \"x-yumemi-failure\": String(response.status)}});\n"
  <> "}\n\n"
  <> "async function failureFor(request, env, status) {\n"
  <> "  const kind = failureKind(status);\n"
  <> "  return failurePage(request, env, failure(status, kind === \"not_found\" ? \"not found\" : kind));\n"
  <> "}\n\n"
  <> "// 描画の例外(読みの decode・givens・render)は log に出して 500 の unavailable(Cloudflare の例外の頁を出さない)\n"
  <> "async function guarded(render) {\n"
  <> "  try {\n"
  <> "    return await render();\n"
  <> "  } catch (error) {\n"
  <> "    console.error(\"yumemi shell: render error\", error);\n"
  <> "    return failure(500, \"unavailable\");\n"
  <> "  }\n"
  <> "}\n\n"
}

/// 頁の Vars を組む字(renderPage と、0.14 の断片の口 renderBlock が同じ字を使う)。
fn shell_vars_text(include_route: Bool) -> String {
  ""
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
  <> case include_route {
    True ->
      "    } else if (source.type === \"route\") {\n"
      <> "      value = source.value;\n"
    False -> ""
  }
  <> "    } else if (source.type === \"session\") {\n"
  <> "      if (!sessionLoaded) {\n"
  <> "        sessionLoaded = true;\n"
  <> "        // 読みの 5xx と例外は匿名に畳まず 503 の unavailable、元の status と原因は log へ(0.12)\n"
  <> "        let response;\n"
  <> "        try {\n"
  <> "          const target = new URL(\"/api/session\", request.url);\n"
  <> "          response = await env.APP.fetch(new Request(target, request));\n"
  <> "          if (response.ok) session = await response.json();\n"
  <> "        } catch (error) {\n"
  <> "          console.error(\"yumemi shell: session read error\", 502, error);\n"
  <> "          return failure(503, \"unavailable\");\n"
  <> "        }\n"
  <> "        if (response.status >= 500) {\n"
  <> "          console.error(\"yumemi shell: session read error\", response.status, await response.text().catch(() => \"\"));\n"
  <> "          return failure(503, \"unavailable\");\n"
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
}

/// 断片の口(0.14)。`x-yumemi-block: <name>` の要求で、その頁の `Live` か `Fixed`(0.14.1)の Block の読み(と 404・
/// 403 の意味を保つ頁と Layout の `!optional` の読み)だけを叩き、`<style>` と包んだ Block(`Live` は
/// `<yumemi-live>`、`Fixed` は `<yumemi-block>`)だけを返す。Layout の `optional` の読みと givens は叩かない。
/// 頁の Block でない名(Layout・`Widget` の Block を含む)・読めない(403・404)は頁と同じ status ── client は頁ごと
/// 取り直す(`Live`)か null を返す(`yumemi.block`)。Service を読まない Block(`In = Nil`)は Vars だけで描く。
fn shell_block_text(include_route: Bool, include_live: Bool) -> String {
  case include_live {
    True ->
      "// `<yumemi-live>` の開きの tag のうち name の当たる 1 つに札を差す(属性の順は SSR が名の順に並べる)\n"
      <> "function withLiveToken(html, name, token) {\n"
      <> "  if (!token) return html;\n"
      <> "  const encoded = token.replaceAll(\"&\", \"&amp;\").replaceAll(\"\\\"\", \"&quot;\").replaceAll(\"<\", \"&lt;\");\n"
      <> "  const named = ' name=\"' + name + '\"';\n"
      <> "  let done = false;\n"
      <> "  return html.replace(/<yumemi-live\\b[^>]*>/g, (tag) => {\n"
      <> "    if (done || !tag.includes(named) || tag.includes(' token=\"')) return tag;\n"
      <> "    done = true;\n"
      <> "    return '<yumemi-live token=\"' + encoded + '\"' + tag.slice('<yumemi-live'.length);\n"
      <> "  });\n"
      <> "}\n\n"
    False -> ""
  }
  <> "async function renderBlock(request, env, matched, gateSession, name) {\n"
  <> case include_live {
    True ->
      "  const lives = matched.spec.lives ?? {};\n"
      <> "  const blocks = matched.spec.blocks ?? {};\n"
      <> "  const live = Object.hasOwn(lives, name) ? lives[name] : Object.hasOwn(blocks, name) ? blocks[name] : null;\n"
    False ->
      "  const blocks = matched.spec.blocks ?? {};\n"
      <> "  const live = Object.hasOwn(blocks, name) ? blocks[name] : null;\n"
  }
  <> "  if (live === null) return failure(404, \"not found\");\n"
  <> shell_vars_text(include_route)
  <> "  let value;\n"
  <> case include_live {
    True -> "  let token = null;\n"
    False -> ""
  }
  <> "  for (const source of matched.spec.sources) {\n"
  <> "    if (source.theme || !(source.service === live.service || source.root)) continue;\n"
  <> "    let response;\n"
  <> "    try {\n"
  <> "      response = await readFromApp(env.APP, request, source.service, argsFor(vars, source.args));\n"
  <> "    } catch (error) {\n"
  <> "      console.error(\"yumemi shell: block read error\", 502, error);\n"
  <> "      return failure(503, \"unavailable\");\n"
  <> "    }\n"
  <> "    if (!response.ok) {\n"
  <> "      if (response.status === 403) return failure(403, \"forbidden\");\n"
  <> "      if (response.status === 404 && !source.root) { value = Option$None$const; continue; }\n"
  <> "      if (response.status === 404) return failure(404, \"not found\");\n"
  <> "      if (response.status >= 500) {\n"
  <> "        console.error(\"yumemi shell: block read error\", response.status, await response.text().catch(() => \"\"));\n"
  <> "        return failure(503, \"unavailable\");\n"
  <> "      }\n"
  <> "      return failure(response.status, \"block read failed\");\n"
  <> "    }\n"
  <> "    if (source.service !== live.service) {\n"
  <> "      await response.body?.cancel();\n"
  <> "      continue;\n"
  <> "    }\n"
  <> case include_live {
    True -> "    token = response.headers.get(\"x-yumemi-live\");\n"
    False -> ""
  }
  <> "    const decoded = source.decoder(await response.json());\n"
  <> "    value = source.optional ? new Some(decoded) : decoded;\n"
  <> "  }\n"
  <> "  if (live.service !== null && value === undefined) return failure(500, \"block source is missing\");\n"
  <> "  const body = to_fragment_string(live.service === null ? live.render(vars) : live.render(vars, value));\n"
  <> case include_live {
    True -> "  const html = withLiveToken(body, name, token);\n"
    False -> "  const html = body;\n"
  }
  <> "  return new Response(html, {status: 200, headers: {\"content-type\": \"text/html; charset=utf-8\", \"cache-control\": \"no-store\", \"vary\": \"x-yumemi-block\"}});\n"
  <> "}\n\n"
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
      list.map(component.calls, reader_front.call_target_name),
      case component.reloads {
        Some(reloads) -> [reloads.read]
        None -> []
      },
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
            Some("yumemi/page"), _ ->
              page_decoder(app, units, state, scope, name, parameters)
            Some("yumemi/er"), _ -> relation_decoder(name)
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
        "yumemi/time" -> opaque_model_decoder(name)
        "yumemi/blob" -> opaque_model_decoder("Blob")
        "yumemi/front/theme" -> "page_theme_decoder()"
        "yumemi/front/color" -> "color_decoder()"
        "yumemi/party" -> opaque_model_decoder(name)
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
            "yumemi/time" -> opaque_model_decoder(name)
            "yumemi/blob" -> opaque_model_decoder("Blob")
            "yumemi/front/theme" -> "page_theme_decoder()"
            "yumemi/front/color" -> "color_decoder()"
            "yumemi/party" -> opaque_model_decoder(name)
            "yumemi/er" -> relation_decoder(name)
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
        Some("yumemi/er") ->
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
        "yumemi/er" ->
          case is_relation_type(name) {
            True -> {
              let state = relation_type(state, name)
              list.fold(parameters, state, fn(acc, parameter) {
                collect_relation_parameter(acc, app, units, scope, parameter)
              })
            }
            False -> {
              let state = add_import(state, "yumemi/er", name)
              list.fold(parameters, state, fn(acc, parameter) {
                collect_gl_type(acc, app, units, scope, parameter)
              })
            }
          }
        "yumemi/time" -> add_time_decoder_import(state, path, name)
        "yumemi/blob" ->
          add_function_import(add_import(state, path, name), path, "parse")
        "yumemi/front/theme" ->
          add_function_import(
            add_import(state, path, name),
            path,
            "decoder as page_theme_decoder",
          )
        "yumemi/front/color" ->
          add_function_import(
            add_import(state, path, name),
            path,
            "decoder as color_decoder",
          )
        "yumemi/party" -> add_import(state, path, name)
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
    Some("yumemi/er"), True -> state
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
    "yumemi/er" ->
      case is_relation_type(name) {
        True -> {
          let state = relation_type(state, name)
          list.fold(parameters, state, fn(acc, parameter) {
            collect_relation_shape(acc, app, units, parameter)
          })
        }
        False -> add_import(state, path, name)
      }
    "yumemi/time" -> add_time_decoder_import(state, path, name)
    "yumemi/blob" ->
      add_function_import(add_import(state, path, name), path, "parse")
    "yumemi/front/theme" ->
      add_function_import(
        add_import(state, path, name),
        path,
        "decoder as page_theme_decoder",
      )
    "yumemi/front/color" ->
      add_function_import(
        add_import(state, path, name),
        path,
        "decoder as color_decoder",
      )
    "yumemi/party" -> add_import(state, path, name)
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
          let state = add_import(state, "yumemi/er", name)
          case name {
            "Key" | "Link" -> add_function_import(state, "yumemi/er", "key")
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
    "Has" | "Held" | "Key" | "Link" | "Multi" -> "yumemi/er"
    "Date" | "Datetime" | "Time" -> "yumemi/time"
    "Blob" -> "yumemi/blob"
    _ -> "yumemi"
  }
}

fn allowed_import(path: String) -> Bool {
  string.starts_with(path, "gleam/")
  || string.starts_with(path, "yumemi/")
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

// ── 記述面・頁の色・生の CSS の条文(0.12 段 B)── 面の file を見る検査 ──────────

/// 第 2・26〜30 条と、生の CSS の規則の数え(exit 0 の警告、面ごとに 1 行)。
pub fn surface_notes(
  app: model.App,
  units: List(Unit),
  package: face.Package,
  front: reader_front.Front,
) -> List(stop.Note) {
  let #(raw_notes, raw_files, raw_rules) = raw_css_notes(package, front)
  let #(escape_notes, escapes) = escape_notes(package)
  let all_calls =
    list.fold(package.units, 0, fn(total, unit) {
      total
      + list.count(unit_references(unit), fn(found) { found == "gen/escapes" })
    })
  let component_calls =
    list.fold(front.components, 0, fn(total, component) {
      total + component.escape_calls
    })
  let to_service =
    list.count(app.server.counted, fn(counted) {
      counted.face == package.name
      && case counted.sink {
        model.ServiceSink(_) -> True
        _ -> False
      }
    })
  let line = case escapes, raw_files, to_service, all_calls {
    [], 0, 0, 0 -> []
    _, _, _, _ -> [
      stop.Note(
        class: stop.Warning,
        text: package.name
          <> ": 逃げ道 ── escape "
          <> int.to_string(list.length(escapes))
          <> " 種 "
          <> int.to_string(all_calls)
          <> " か所(うち interactive Component の中 "
          <> int.to_string(component_calls)
          <> ")、生の CSS "
          <> int.to_string(raw_files)
          <> " file "
          <> int.to_string(raw_rules)
          <> " 規則、数える口の送り先 ToService "
          <> int.to_string(to_service),
      ),
    ]
  }
  list.flatten([
    lustre_dependency_notes(package, front),
    shell_theme_notes(package, front),
    page_theme_notes(app, units, front),
    raw_notes,
    escape_notes,
    static_src_notes(package),
    line,
  ])
}

/// unit の中の `gen/escapes` ほかの関数の参照(module の道)。
fn unit_references(unit: Unit) -> List(String) {
  reader_front.module_references(unit)
}

/// 面の `src/escapes/*.mjs` の名(並べた順)。
fn escape_names(package: face.Package) -> List(String) {
  case simplifile.read_directory(package.path <> "/src/escapes") {
    Ok(entries) ->
      entries
      |> list.filter(fn(entry) { string.ends_with(entry, ".mjs") })
      |> list.map(fn(entry) { string.drop_end(entry, 4) })
      |> list.filter(valid_escape_name)
      |> list.sort(string.compare)
    Error(_) -> []
  }
}

fn valid_escape_name(name: String) -> Bool {
  case string.to_graphemes(name) {
    [first, ..rest] ->
      string.contains("abcdefghijklmnopqrstuvwxyz", first)
      && list.all(rest, fn(char) {
        string.contains("abcdefghijklmnopqrstuvwxyz0123456789_", char)
      })
    [] -> False
  }
}

/// 第 5・6 条:`src/escapes/` の外の `.mjs`、逃げ道の名の形、`mount` の export。
fn escape_notes(package: face.Package) -> #(List(stop.Note), List(String)) {
  let outside =
    mjs_files(package.path <> "/src", "")
    |> list.filter(fn(path) {
      !string.starts_with(path, "escapes/") && !string.starts_with(path, "gen/")
    })
    |> list.map(fn(path) {
      stop.Note(
        class: stop.Conflict,
        text: package.name
          <> "/src/"
          <> path
          <> ": src/escapes/ の外に .mjs がある(第 5 条、JS は名前付きの逃げ道 src/escapes/<name>.mjs に置く)",
      )
    })
  let entries = case simplifile.read_directory(package.path <> "/src/escapes") {
    Ok(entries) ->
      list.filter(entries, fn(entry) { string.ends_with(entry, ".mjs") })
    Error(_) -> []
  }
  let names =
    list.flat_map(entries, fn(entry) {
      let name = string.drop_end(entry, 4)
      let where = package.name <> "/src/escapes/" <> entry
      case valid_escape_name(name) {
        False -> [
          stop.Note(
            class: stop.Conflict,
            text: where <> ": 逃げ道の名が [a-z][a-z0-9_]* でない(第 6 条)",
          ),
        ]
        True ->
          case simplifile.read(package.path <> "/src/escapes/" <> entry) {
            Ok(text) ->
              case exports_mount(text) {
                True -> []
                False -> [
                  stop.Note(
                    class: stop.Missing,
                    text: where <> ": mount を export していない(第 6 条)",
                  ),
                ]
              }
            Error(_) -> []
          }
      }
    })
  #(list.append(outside, names), escape_names(package))
}

fn exports_mount(text: String) -> Bool {
  string.contains(text, "export function mount")
  || string.contains(text, "export async function mount")
  || string.contains(text, "export const mount")
  || string.contains(text, "export { mount")
  || string.contains(text, "mount }")
}

fn mjs_files(root: String, prefix: String) -> List(String) {
  case simplifile.read_directory(root <> "/" <> prefix) {
    Ok(entries) ->
      list.flat_map(entries, fn(entry) {
        let path = case prefix {
          "" -> entry
          _ -> prefix <> "/" <> entry
        }
        case simplifile.is_directory(root <> "/" <> path) {
          Ok(True) -> mjs_files(root, path)
          _ ->
            case string.ends_with(entry, ".mjs") {
              True -> [path]
              False -> []
            }
        }
      })
    Error(_) -> []
  }
}

/// 第 43 条:`el.static_src` の path が `priv/static` に無い(literal でないのは reader が止める)。
fn static_src_notes(package: face.Package) -> List(stop.Note) {
  package.units
  |> list.flat_map(reader_front.static_src_paths)
  |> list.filter(fn(pair) { !static_file_exists(package, pair.1) })
  |> list.map(fn(pair) {
    stop.Note(
      class: stop.Missing,
      text: package.name
        <> "/src/"
        <> pair.0
        <> ".gleam el.static_src "
        <> pair.1
        <> ": file が priv/static に無い(第 43 条)",
    )
  })
}

/// `src/gen/escapes.gleam`:逃げ道ごとに `<yumemi-escape name>` を出す関数。
fn escapes_text(package: face.Package, names: List(String)) -> String {
  header(
    package.name <> "/src/escapes/*.mjs",
    digest.short(string.join(names, ",")),
  )
  <> "
import yumemi/front/el
"
  <> string.concat(list.map(names, fn(name) { "
/// 逃げ道 src/escapes/" <> name <> ".mjs。子は JS が無いときに見える代わりの中身。
" <> "pub fn " <> name <> "(attributes: List(el.Attribute), fallback: List(el.Element)) -> el.Element {
" <> "  el.escape_point(" <> quoted(name) <> ", attributes, fallback)
}
" }))
}

/// 第 2 条:面の `gleam.toml` の直接の依存に lustre / sketch_lustre が無い(0.12 段 C で例外は無くなった)。
fn lustre_dependency_notes(
  package: face.Package,
  front: reader_front.Front,
) -> List(stop.Note) {
  case simplifile.read(package.path <> "/gleam.toml") {
    Ok(toml) -> {
      let found =
        direct_dependencies(toml)
        |> list.filter(fn(name) { name == "lustre" || name == "sketch_lustre" })
      let _ = front
      case found {
        [] -> []
        names -> [
          stop.Note(
            class: stop.Conflict,
            text: package.name
              <> "/gleam.toml: 直接の依存に "
              <> string.join(names, "・")
              <> " がある(第 2 条、0.12 の ★ は yumemi の el・html・attr で書く)",
          ),
        ]
      }
    }
    Error(_) -> []
  }
}

fn direct_dependencies(toml: String) -> List(String) {
  toml
  |> string.split("\n")
  |> list.fold(#(False, []), fn(acc, line) {
    let #(inside, names) = acc
    let line = string.trim(line)
    case string.starts_with(line, "[") {
      True -> #(line == "[dependencies]", names)
      False ->
        case inside, string.split_once(line, "=") {
          True, Ok(#(name, _)) -> #(inside, [string.trim(name), ..names])
          _, _ -> #(inside, names)
        }
    }
  })
  |> fn(acc) { list.reverse(acc.1) }
}

/// 第 26 条:Shell の `theme` の 3 色は `#rrggbb` の literal、地の画像は `priv/static` に在る。
fn shell_theme_notes(
  package: face.Package,
  front: reader_front.Front,
) -> List(stop.Note) {
  case front.shell.present {
    False -> []
    True -> {
      let colors =
        [
          #("background", front.shell.background),
          #("text", front.shell.text),
          #("accent", front.shell.accent),
        ]
        |> list.filter_map(fn(pair) {
          case reader_front.is_hex_color(pair.1) || pair.1 == "" {
            True -> Error(Nil)
            False ->
              Ok(stop.Note(
                class: stop.Conflict,
                text: package.name
                  <> "/src/shell.gleam: theme."
                  <> pair.0
                  <> " \""
                  <> pair.1
                  <> "\" が #rrggbb の literal でない(第 26 条)",
              ))
          }
        })
      let image = case front.shell.background_image {
        "" -> []
        path ->
          case static_file_exists(package, path) {
            True -> []
            False -> [
              stop.Note(
                class: stop.Missing,
                text: package.name
                  <> "/src/shell.gleam: theme.background_image の "
                  <> path
                  <> " が priv/static に無い(第 26 条)",
              ),
            ]
          }
      }
      list.append(colors, image)
    }
  }
}

/// 第 27 条:`theme: Some(name)` の Page の source のどれかの Out に `theme.PageTheme` がある。
fn page_theme_notes(
  app: model.App,
  units: List(Unit),
  front: reader_front.Front,
) -> List(stop.Note) {
  front.pages
  |> list.filter_map(fn(page) {
    case page.theme {
      None -> Error(Nil)
      Some(name) -> {
        let found =
          page_sources(app, units, page, front.blocks, app.services)
          |> list.any(fn(source) {
            source.type_name == "PageTheme"
            && option.is_some(page_theme_path(
              units,
              source.service,
              source.name,
            ))
          })
        case found {
          True -> Error(Nil)
          False ->
            Ok(stop.Note(
              class: stop.Conflict,
              text: front.face
                <> "/"
                <> page.module
                <> ": theme: Some(\""
                <> name
                <> "\") の source のどの Out にも yumemi/front/theme.PageTheme が無い(第 27 条)",
            ))
        }
      }
    }
  })
}

/// 第 28〜30 条と規則の数え。同じ file を 2 か所で読んでも 1 回と数え、検査も 1 回(0.12 段 C、Y2 柏木 P1-4)。
/// 戻りは #(停止の Note, file の数, 規則の数)。数えは面ごとの逃げ道の 1 行に入る。
fn raw_css_notes(
  package: face.Package,
  front: reader_front.Front,
) -> #(List(stop.Note), Int, Int) {
  let shell_sheets =
    list.map(front.shell.head.stylesheets, fn(href) {
      #("src/shell.gleam stylesheets", href)
    })
  let block_sheets =
    list.map(front.static_sheets, fn(pair) {
      #("src/" <> pair.0 <> ".gleam el.static_sheet", pair.1)
    })
  let sheets =
    list.append(shell_sheets, block_sheets)
    |> list.fold([], fn(acc: List(#(String, String)), sheet) {
      case
        list.any(acc, fn(found) {
          normal_static(found.1) == normal_static(sheet.1)
        })
      {
        True -> acc
        False -> list.append(acc, [sheet])
      }
    })
  let checked =
    list.map(sheets, fn(sheet) {
      let #(where, path) = sheet
      let label = package.name <> "/" <> where <> " " <> path
      case simplifile.read(static_path(package, path)) {
        Error(_) -> #(0, [
          stop.Note(
            class: stop.Missing,
            text: label <> ": file が priv/static に無い(第 28 条)",
          ),
        ])
        Ok(css) -> {
          let scan = raw_css.scan(css)
          let generated =
            list.map(scan.generated, fn(selector) {
              stop.Note(
                class: stop.Conflict,
                text: label <> ": 生成物を名指す選択子(第 29 条): " <> selector,
              )
            })
          let imports = case scan.imports {
            True -> [
              stop.Note(
                class: stop.Conflict,
                text: label <> ": @import がある(第 30 条)",
              ),
            ]
            False -> []
          }
          #(scan.rules, list.append(generated, imports))
        }
      }
    })
  let rules = list.fold(checked, 0, fn(total, item) { total + item.0 })
  #(list.flat_map(checked, fn(item) { item.1 }), list.length(sheets), rules)
}

fn normal_static(path: String) -> String {
  case string.starts_with(path, "/") {
    True -> path
    False -> "/" <> path
  }
}

fn static_path(package: face.Package, path: String) -> String {
  case string.starts_with(path, "/") {
    True -> package.path <> "/priv/static" <> path
    False -> package.path <> "/priv/static/" <> path
  }
}

fn static_file_exists(package: face.Package, path: String) -> Bool {
  case simplifile.is_file(static_path(package, path)) {
    Ok(True) -> True
    _ -> False
  }
}

// ── interactive Component の生成物(0.12 段 C、51 v6「interactive Component の生成物」)────────────
//
// Service ごとの live module(`src/gen/live/<name>.gleam`)は `Args`・`Field`・`Error`・`When`・`Slot` と
// `bind`・`bind_check`・`bind_choice`・`bind_file`・`when`・`out`・`send` を出す。State・Event・update は無い。
// `src/gen/interactive.gleam` は Component ごとに SSR の関数を出し、client.mjs は Component の表を runtime
// (`yumemi/front/interactive.mjs`)に渡す。

/// live module 1 つ(Component の `calls` の 1 要素)。
type LiveTarget {
  LiveTarget(
    /// live module の名(snake)。送りの印 `data-yumemi-send` と control の name の前置きも同じ
    name: String,
    /// GENERATED の source
    source: String,
    input_hash: String,
    method: String,
    /// `:name` の穴を持つ path
    path: String,
    args: List(LiveArg),
    errors: List(glance.Variant),
    /// 要件(`requires`・attached の `NeedsDeclared`)が断るときの構成子の名で、`errors` に無いもの(0.12.1)。
    /// live module の `Error` には足し、client の表では `refused`(Service の `Error`)と分けて `requires` に置く
    requires: List(String),
    /// Slot の構成子の名 → Out の欄の道
    slots: List(#(String, String)),
    read: Bool,
    /// Out の木に List がある(読みの戻りは頁の取り直し)
    list_out: Bool,
    /// file の上げ口そのもの(本文が file、戻りは `{key}`)
    upload: Bool,
    /// Out の欄の名(GoTo の穴の検査、第 15 条)。202 の Reply を返す Service は穴を検査しない
    out_fields: List(String),
    accepting: Bool,
    /// attached の口(`Entry`)。Service でないので after_send の組を持てない(戻りの後は Stay)
    entry: Bool,
  )
}

type LiveArg {
  LiveArg(name: String, wire: Wire, blob: Bool, constraints: List(String))
}

fn live_targets(
  app: model.App,
  units: List(Unit),
  package: face.Package,
  front: reader_front.Front,
  hashes: hash.Hashes,
) -> List(LiveTarget) {
  let face_name = package.name
  front.components
  |> list.flat_map(fn(component) {
    let component_hash =
      source_hash(package.units, fn(unit) { unit.path == component.module })
    list.filter_map(component.calls, fn(target) {
      live_target(
        app,
        units,
        face_name,
        hashes,
        component,
        component_hash,
        target,
      )
    })
  })
  |> list.fold([], fn(acc: List(LiveTarget), target) {
    case list.any(acc, fn(found) { found.name == target.name }) {
      True -> acc
      False -> list.append(acc, [target])
    }
  })
  |> list.sort(fn(left, right) { string.compare(left.name, right.name) })
}

fn live_target(
  app: model.App,
  units: List(Unit),
  face_name: String,
  hashes: hash.Hashes,
  component: reader_front.Component,
  component_hash: String,
  target: reader_front.CallTarget,
) -> Result(LiveTarget, Nil) {
  let name = reader_front.live_module(target)
  let source = "src/" <> component.module <> ".gleam"
  case service_for(app.services, reader_front.call_target_name(target)) {
    Some(service) ->
      case api_route_for(app, hashes, face_name, service.module) {
        Some(route) -> {
          let fields = output_fields(units, service.module)
          Ok(LiveTarget(
            name: service.module,
            source: source,
            input_hash: digest.short(
              hash.service(hashes, service.module) <> component_hash,
            ),
            method: route.method,
            path: route.path,
            args: list.map(service.args, fn(arg) {
              LiveArg(
                name: arg.name,
                wire: arg_wire(units, service, arg.type_),
                blob: blob_shape(arg.type_),
                constraints: arg_constraints(app, units, arg),
              )
            }),
            errors: service_error_variants(units, service),
            requires: without_star_errors(
              service_error_variants(units, service),
              requirement_codes(units, service.module),
            ),
            slots: fields
              |> list.filter(fn(field) { !gl_type_has_list(field.1) })
              |> list.map(fn(field) {
                #("Out" <> naming.pascal(field.0), field.0)
              }),
            read: service.effect == model.ReadEffect,
            list_out: list.any(fields, fn(field) { gl_type_has_list(field.1) }),
            upload: False,
            out_fields: list.map(fields, fn(field) { field.0 }),
            accepting: accepted.accepts(app, units, service),
            entry: False,
          ))
        }
        None -> Error(Nil)
      }
    None ->
      case
        list.find(app.attached, fn(route) {
          route.name == reader_front.call_target_name(target)
        })
      {
        Ok(route) -> {
          let upload =
            route.name == "BlobCopy"
            && route.method == "POST"
            && route.path == "/api/blobs"
          let input_hash =
            digest.short(
              hash.entry(hashes) <> string.inspect(route) <> component_hash,
            )
          Ok(LiveTarget(
            name: name,
            source: source,
            input_hash: input_hash,
            method: route.method,
            path: colon_path(route.path),
            args: case upload {
              // file を上げるか、file が無ければ `from` の URL を写す(0.11.4 H5 の copy_from)
              True -> [
                LiveArg(
                  name: "file",
                  wire: ScalarWire(TextArg),
                  blob: True,
                  constraints: [],
                ),
                LiveArg(
                  name: "from",
                  wire: ScalarWire(TextArg),
                  blob: False,
                  constraints: [],
                ),
              ]
              False ->
                list.map(attached_body_fields(app, route), fn(field) {
                  LiveArg(
                    name: field,
                    wire: ScalarWire(TextArg),
                    blob: False,
                    constraints: [],
                  )
                })
            },
            errors: [],
            requires: attached_requirement_codes(app, route.name),
            slots: case upload {
              True -> [#("OutKey", "key")]
              False -> []
            },
            read: route.method == "GET",
            list_out: False,
            upload: upload,
            out_fields: case upload {
              True -> ["key"]
              False -> []
            },
            accepting: False,
            entry: True,
          ))
        }
        Error(_) -> Error(Nil)
      }
  }
}

fn gl_type_has_list(type_: glance.Type) -> Bool {
  case type_ {
    glance.NamedType(name: "List", ..) -> True
    glance.NamedType(parameters: parameters, ..) ->
      list.any(parameters, gl_type_has_list)
    glance.TupleType(elements: elements, ..) ->
      list.any(elements, gl_type_has_list)
    _ -> False
  }
}

/// Spec から写せる制約検証(`live.Constraint` の構成子の字)。属性に写らない Spec は server に任せる。
fn arg_constraints(
  app: model.App,
  units: List(Unit),
  arg: model.Arg,
) -> List(String) {
  let optional = case arg.type_ {
    model.NamedShape(module: Some("gleam/option"), name: "Option", ..) -> True
    _ -> False
  }
  let inner = case arg.type_ {
    model.NamedShape(
      module: Some("gleam/option"),
      name: "Option",
      parameters: [inner],
    ) -> inner
    shape -> shape
  }
  case value_type_for_arg(app.value_types, inner) {
    None -> []
    Some(value) -> {
      let expression =
        list.find(units, fn(unit) { unit.path == "types" })
        |> result.map(fn(unit) {
          g.find_constant(g.in_order(unit.module), value.name)
        })
        |> result.unwrap(None)
        |> option.map(fn(constant) { constant.value })
      case expression {
        None -> []
        Some(expression) -> {
          let bounds = case g.ctor_name(expression) {
            Some("Pattern") | Some("Text") | Some("MarkdownText") ->
              spec_bounds(expression)
            _ -> None
          }
          let lengths = case bounds {
            Some(#(min, max)) ->
              list.flatten([
                case int.parse(min) {
                  Ok(number) if number > 0 && !optional -> [
                    "live.MinLength(" <> min <> ")",
                    "live.Required",
                  ]
                  Ok(number) if number > 0 -> ["live.MinLength(" <> min <> ")"]
                  _ -> []
                },
                ["live.MaxLength(" <> max <> ")"],
              ])
            None -> []
          }
          let pattern = case g.ctor_name(expression) {
            Some("Pattern") ->
              case
                g.labelled(expression, "regex") |> option.then(g.string_value)
              {
                // glance の String は書いた escape のまま(`"\\d"` は `\` 2 つ)なので、quoted で escape を
                // 重ねずにそのまま literal に戻す ── 重ねると `\d` が `\\d`(backslash と d)になり、正しい値を
                // browser の制約検証が拒む
                Some(regex) -> [
                  "live.Pattern(\""
                  <> string.replace(html_pattern(regex), "\n", "\\n")
                  <> "\")",
                ]
                None -> []
              }
            _ -> []
          }
          list.append(lengths, pattern)
        }
      }
    }
  }
}

/// HTML の `pattern` は全体に暗に掛かるので、正規表現の頭と尾の `^` / `$` を落とす。
fn html_pattern(regex: String) -> String {
  let regex = case string.starts_with(regex, "^") {
    True -> string.drop_start(regex, 1)
    False -> regex
  }
  case string.ends_with(regex, "$") {
    True -> string.drop_end(regex, 1)
    False -> regex
  }
}

fn kebab(name: String) -> String {
  string.replace(naming.snake(name), "_", "-")
}

fn live_module_text(target: LiveTarget) -> String {
  let svc = quoted(target.name)
  let args_type = case target.args {
    [] -> "pub type Args {\n  Args\n}\n"
    args ->
      "pub type Args {\n  Args("
      <> string.join(
        list.map(args, fn(arg) { arg.name <> ": " <> wire_gleam_type(arg.wire) }),
        ", ",
      )
      <> ")\n}\n"
  }
  let uses_option =
    list.any(target.args, fn(arg) {
      string.contains(wire_gleam_type(arg.wire), "Option(")
    })
  let field_type = case target.args {
    [] -> "pub type Field\n"
    args ->
      "pub type Field {\n"
      <> string.concat(
        list.map(args, fn(arg) { "  " <> naming.pascal(arg.name) <> "\n" }),
      )
      <> "}\n"
  }
  let slot_type = case target.slots {
    [] -> "pub type Slot\n"
    slots ->
      "pub type Slot {\n"
      <> string.concat(list.map(slots, fn(slot) { "  " <> slot.0 <> "\n" }))
      <> "}\n"
  }
  let field_case = fn(body: fn(LiveArg) -> String) {
    case target.args {
      [] ->
        "  case field {\n    _ -> "
        <> body(LiveArg("", ScalarWire(TextArg), False, []))
        <> "\n  }\n"
      args ->
        "  case field {\n"
        <> string.concat(
          list.map(args, fn(arg) {
            "    " <> naming.pascal(arg.name) <> " -> " <> body(arg) <> "\n"
          }),
        )
        <> "  }\n"
    }
  }
  let error_codes =
    list.map(live_errors(target), fn(variant) {
      #(
        case variant.fields {
          [] -> variant.name
          _ -> variant.name <> "(..)"
        },
        kebab(variant.name),
      )
    })
  header(target.source, target.input_hash)
  <> "\n"
  <> case uses_option {
    True -> "import gleam/option.{type Option}\n"
    False -> ""
  }
  <> "import yumemi/front/css\n"
  <> "import yumemi/front/el\n"
  <> "import yumemi/front/live\n\n"
  <> args_type
  <> "\n"
  <> field_type
  <> "\n"
  <> service_error_type_text(live_errors(target))
  <> "pub type When {\n  Idle\n  Waiting\n  Succeeded\n  Failed\n  Refused(Error)\n}\n\n"
  <> slot_type
  <> "\n"
  <> "/// name=\""
  <> target.name
  <> ".<field>\" と、Spec から写せる制約検証の属性と value。\n"
  <> "pub fn bind(field: Field, value: String) -> el.Attribute {\n"
  <> field_case(fn(arg) {
    case arg.name {
      "" -> "live.bind(" <> svc <> ", \"\", value, [])"
      _ ->
        "live.bind("
        <> svc
        <> ", "
        <> quoted(arg.name)
        <> ", value, ["
        <> string.join(arg.constraints, ", ")
        <> "])"
    }
  })
  <> "}\n\n"
  <> "/// checkbox。\n"
  <> "pub fn bind_check(field: Field, checked: Bool) -> el.Attribute {\n"
  <> "  live.bind_check("
  <> svc
  <> ", field_name(field), checked)\n}\n\n"
  <> "/// select と radio の name(選択肢は attr.value / attr.selected)。\n"
  <> "pub fn bind_choice(field: Field) -> el.Attribute {\n"
  <> "  live.bind_choice("
  <> svc
  <> ", field_name(field))\n}\n\n"
  <> "/// file の control(Blob の欄)。送る前に runtime が上げ、key を Args に入れる。\n"
  <> "pub fn bind_file(field: Field) -> el.Attribute {\n"
  <> "  live.bind_file("
  <> svc
  <> ", field_name(field))\n}\n\n"
  <> "/// data-yumemi-when=\""
  <> target.name
  <> ".<state>\" の枝。\n"
  <> "pub fn when(state: When, children: List(el.Element)) -> el.Element {\n"
  <> "  live.when("
  <> svc
  <> ", state_name(state), children)\n}\n\n"
  <> "/// data-yumemi-out=\""
  <> target.name
  <> ".<slot>\" の空の span。\n"
  <> "pub fn out(slot: Slot) -> el.Element {\n"
  <> "  live.out("
  <> svc
  <> ", slot_name(slot))\n}\n\n"
  <> "/// 送りのボタン。叩くのはこの Service 1 本。\n"
  <> "pub fn send(class: css.Class, children: List(el.Element)) -> el.Element {\n"
  <> "  live.send("
  <> svc
  <> ", class, children)\n}\n\n"
  <> "/// `data-yumemi-args` の JSON(生成物の `gen/interactive` が使う)。\n"
  <> "@internal\n"
  <> "pub fn args_json(args: Args) -> String {\n"
  <> case target.args {
    [] -> "  let _ = args\n  live.json_object([])\n"
    args ->
      "  live.json_object([\n"
      <> string.concat(
        list.map(args, fn(arg) {
          "    #("
          <> quoted(arg.name)
          <> ", "
          <> wire_encode(arg.wire, "args." <> arg.name)
          <> "),\n"
        }),
      )
      <> "  ])\n"
  }
  <> "}\n\n"
  <> "fn field_name(field: Field) -> String {\n"
  <> field_case(fn(arg) { quoted(arg.name) })
  <> "}\n\n"
  <> "fn state_name(state: When) -> String {\n"
  <> "  case state {\n"
  <> "    Idle -> \"idle\"\n    Waiting -> \"waiting\"\n    Succeeded -> \"succeeded\"\n    Failed -> \"failed\"\n"
  <> "    Refused(error) -> \"refused-\" <> error_code(error)\n"
  <> "  }\n}\n\n"
  <> "fn error_code(error: Error) -> String {\n"
  <> case error_codes {
    [] -> "  case error {\n    _ -> \"\"\n  }\n"
    codes ->
      "  case error {\n"
      <> string.concat(
        list.map(codes, fn(code) {
          "    " <> code.0 <> " -> " <> quoted(code.1) <> "\n"
        }),
      )
      <> "  }\n"
  }
  <> "}\n\n"
  <> "fn slot_name(slot: Slot) -> String {\n"
  <> case target.slots {
    [] -> "  case slot {\n    _ -> \"\"\n  }\n"
    slots ->
      "  case slot {\n"
      <> string.concat(
        list.map(slots, fn(slot) {
          "    " <> slot.0 <> " -> " <> quoted(slot.1) <> "\n"
        }),
      )
      <> "  }\n"
  }
  <> "}\n"
}

/// `src/gen/interactive.gleam`:Component ごとに、calls の順の Args(と view が受けるなら With)を受けて
/// タグの中に form と view を描く関数。
fn interactive_text(
  package: face.Package,
  front: reader_front.Front,
  targets: List(LiveTarget),
) -> String {
  let components = placeable_components(front, targets)
  let input_hash =
    source_hash(package.units, fn(unit) {
      string.starts_with(unit.path, "components/")
    })
  let lives =
    components
    |> list.flat_map(fn(component) {
      list.map(component.calls, reader_front.live_module)
    })
    |> list.unique
    |> list.sort(string.compare)
  header(package.name <> "/src/components/*.gleam", input_hash)
  <> "\n"
  <> string.concat(
    list.map(components, fn(component) {
      "import "
      <> component.module
      <> " as "
      <> naming.snake(last_segment(component.module))
      <> "_component\n"
    }),
  )
  <> string.concat(
    list.map(lives, fn(live) {
      "import gen/live/" <> live <> " as " <> live <> "_live\n"
    }),
  )
  <> "import yumemi/front/el\n"
  <> "import yumemi/front/live\n"
  <> string.concat(
    list.map(components, fn(component) {
      let module = naming.snake(last_segment(component.module))
      let lives = list.map(component.calls, reader_front.live_module)
      let params =
        list.map(lives, fn(live) { live <> ": " <> live <> "_live.Args" })
        |> list.append(case component.with_fields {
          Some(_) -> ["with: " <> module <> "_component.With"]
          None -> []
        })
      let arguments =
        lives
        |> list.append(case component.with_fields {
          Some(_) -> ["with"]
          None -> []
        })
      "\npub fn "
      <> module
      <> "("
      <> string.join(params, ", ")
      <> ") -> el.Element {\n"
      <> "  live.component(\n"
      <> "    "
      <> quoted(reader_front.component_tag(component))
      <> ",\n"
      <> "    live.json_object([\n"
      <> string.concat(
        list.map(lives, fn(live) {
          "      #("
          <> quoted(live)
          <> ", "
          <> live
          <> "_live.args_json("
          <> live
          <> ")),\n"
        }),
      )
      <> "    ]),\n"
      <> "    "
      <> module
      <> "_component.view("
      <> string.join(arguments, ", ")
      <> "),\n"
      <> "  )\n}\n"
    }),
  )
}

/// `gen/interactive` に関数を出す Component(view があり、calls の Service が全部 live を持つ)。
fn placeable_components(
  front: reader_front.Front,
  targets: List(LiveTarget),
) -> List(reader_front.Component) {
  front.components
  |> list.filter(fn(component) {
    reader_front.view_ok(component)
    && list.all(component.calls, fn(call) {
      list.any(targets, fn(target) {
        target.name == reader_front.live_module(call)
      })
    })
  })
  |> list.sort(fn(left, right) { string.compare(left.module, right.module) })
}

fn then_json(then: reader_front.Then, front: reader_front.Front) -> String {
  let notice = fn(notice: Option(String)) {
    case notice {
      Some(text) -> ", \"notice\": " <> json_quoted(text)
      None -> ""
    }
  }
  case then {
    reader_front.ThenStay -> "{ \"then\": \"stay\" }"
    reader_front.ThenReload(notice: value) ->
      "{ \"then\": \"reload\"" <> notice(value) <> " }"
    reader_front.ThenGoTo(route: route, notice: value) ->
      "{ \"then\": \"goto\", \"path\": "
      <> json_quoted(route_path_for(front, route) |> option.unwrap("/"))
      <> notice(value)
      <> " }"
  }
}

/// `Route` の variant 名(`gen/route.gleam`)→ Page の route の綴り。
fn route_path_for(
  front: reader_front.Front,
  variant: String,
) -> Option(String) {
  front.pages
  |> list.find(fn(page) { route_variant(page) == variant })
  |> result.map(fn(page) { reader_front.route_path(page.path) })
  |> option.from_result
}

/// Page の閉じた enum `Route` の variant 名(フォルダの道の各段を PascalCase にしてつなぐ、根は `Root`)。
pub fn route_variant(page: reader_front.Page) -> String {
  case page.path {
    [] -> "Root"
    parts -> string.concat(list.map(parts, naming.pascal))
  }
}

fn json_quoted(value: String) -> String {
  quoted(value)
}

/// live module の Args の欄の型(Block が初期値を型で書く、51 v6「interactive Component の生成物」)。
/// 値型・Id・列挙・日付ほか、Bool / Int / Float でないスカラは back が文字列で読むので String。record・組・
/// Dict は第 11 条で止める(型で書く形が無い)。
fn wire_gleam_type(wire: Wire) -> String {
  case wire {
    ScalarWire(kind) -> kind_gleam_type(kind)
    OptionWire(inner) -> "Option(" <> wire_gleam_type(inner) <> ")"
    ListWire(kind) -> "List(" <> kind_gleam_type(kind) <> ")"
    JsonWire -> "String"
  }
}

fn kind_gleam_type(kind: ScalarKind) -> String {
  case kind {
    BoolArg -> "Bool"
    IntArg -> "Int"
    FloatArg -> "Float"
    TextArg -> "String"
  }
}

/// Args の欄の値 `value`(Gleam の式)を `data-yumemi-args` の JSON の字に写す式(`live.json_*`)。
fn wire_encode(wire: Wire, value: String) -> String {
  case wire {
    ScalarWire(kind) -> kind_encoder(kind) <> "(" <> value <> ")"
    OptionWire(ScalarWire(kind)) ->
      "live.json_option(" <> value <> ", " <> kind_encoder(kind) <> ")"
    OptionWire(inner) ->
      "live.json_option("
      <> value
      <> ", fn(item) { "
      <> wire_encode(inner, "item")
      <> " })"
    ListWire(kind) ->
      "live.json_list(" <> value <> ", " <> kind_encoder(kind) <> ")"
    JsonWire -> "live.json_string(" <> value <> ")"
  }
}

fn wire_has_json(wire: Wire) -> Bool {
  case wire {
    JsonWire -> True
    OptionWire(inner) -> wire_has_json(inner)
    _ -> False
  }
}

fn kind_encoder(kind: ScalarKind) -> String {
  case kind {
    BoolArg -> "live.json_bool"
    IntArg -> "live.json_int"
    FloatArg -> "live.json_float"
    TextArg -> "live.json_string"
  }
}

fn wire_json(wire: Wire) -> String {
  case wire {
    OptionWire(inner) -> "{ \"option\": " <> wire_json(inner) <> " }"
    ListWire(kind) -> "{ \"list\": " <> quoted(kind_name(kind)) <> " }"
    ScalarWire(kind) -> quoted(kind_name(kind))
    JsonWire -> "\"json\""
  }
}

fn kind_name(kind: ScalarKind) -> String {
  case kind {
    BoolArg -> "bool"
    IntArg -> "int"
    FloatArg -> "float"
    TextArg -> "text"
  }
}

/// client.mjs に焼く Component の表(タグ → Service ごとの method・path・Args の型・After、reloads)。
fn interactive_table(
  front: reader_front.Front,
  targets: List(LiveTarget),
) -> String {
  let components = placeable_components(front, targets)
  "{\n"
  <> string.concat(
    list.map(components, fn(component) {
      let services =
        list.filter_map(component.calls, fn(call) {
          list.find(targets, fn(target) {
            target.name == reader_front.live_module(call)
          })
          |> result.map(fn(target) {
            let after =
              list.find(component.after_send, fn(row) {
                naming.snake(row.service) == target.name
              })
            let #(ok, error) = case after {
              Ok(row) -> #(
                then_json(row.ok, front),
                then_json(row.error, front),
              )
              Error(_) -> #("{ \"then\": \"stay\" }", "{ \"then\": \"stay\" }")
            }
            "      "
            <> quoted(target.name)
            <> ": { \"method\": "
            <> quoted(target.method)
            <> ", \"path\": "
            <> quoted(target.path)
            <> ", \"read\": "
            <> bool_text(target.read)
            <> ", \"upload\": "
            <> bool_text(target.upload)
            <> ", \"accepted\": "
            <> bool_text(target.accepting)
            <> ", \"entry\": "
            <> bool_text(target.entry)
            <> ", \"args\": ["
            <> string.join(
              list.map(target.args, fn(arg) {
                "{ \"name\": "
                <> quoted(arg.name)
                <> ", \"wire\": "
                <> wire_json(arg.wire)
                <> ", \"blob\": "
                <> bool_text(arg.blob)
                <> " }"
              }),
              ", ",
            )
            <> "], \"refused\": ["
            <> string.join(
              list.map(target.errors, fn(variant) {
                quoted(naming.snake(variant.name))
              }),
              ", ",
            )
            <> "], \"requires\": ["
            <> string.join(
              list.map(target.requires, fn(name) { quoted(naming.snake(name)) }),
              ", ",
            )
            <> "], \"slots\": { "
            <> string.join(
              list.map(target.slots, fn(slot) {
                quoted(slot.1) <> ": " <> quoted(slot.1)
              }),
              ", ",
            )
            <> " }, \"ok\": "
            <> ok
            <> ", \"error\": "
            <> error
            <> " },\n"
          })
        })
      let reloads = case component.reloads {
        Some(reloads) ->
          case
            list.find(targets, fn(target) {
              target.name == naming.snake(reloads.read)
            })
          {
            Ok(target) ->
              "{ \"read\": "
              <> quoted(target.name)
              <> ", \"on\": ["
              <> string.join(
                list.map(reloads.on, fn(field) { quoted(naming.snake(field)) }),
                ", ",
              )
              <> "], \"list\": "
              <> bool_text(target.list_out)
              <> " }"
            Error(_) -> "null"
          }
        None -> "null"
      }
      "  "
      <> quoted(reader_front.component_tag(component))
      <> ": {\n    \"services\": {\n"
      <> string.concat(services)
      <> "    },\n    \"reloads\": "
      <> reloads
      <> ",\n  },\n"
    }),
  )
  <> "}"
}

/// `when` の枝を隠す規則(51 v6「状態の写し」)。隠す側で書き、`:state()` の有る browser と無い browser の
/// 2 通り(`@supports selector(:state(x))` の中と外の属性)。
fn interactive_state_css(
  front: reader_front.Front,
  targets: List(LiveTarget),
) -> String {
  let components = placeable_components(front, targets)
  case components {
    [] -> ""
    _ -> {
      let rules =
        list.flat_map(components, fn(component) {
          let tag = reader_front.component_tag(component)
          list.filter_map(component.calls, fn(call) {
            list.find(targets, fn(target) {
              target.name == reader_front.live_module(call)
            })
          })
          |> list.flat_map(fn(target) {
            let svc = target.name
            let sent = "sent-" <> svc
            [
              #(svc <> ".idle", [sent], True),
              #(svc <> ".waiting", ["waiting", sent], False),
              #(svc <> ".succeeded", ["ok", sent], False),
              // Failed は断り(Refused の符号)でない失敗だけ(0.12.1)── runtime が `failed` を立てる
              #(svc <> ".failed", ["failed", sent], False),
              ..list.map(live_errors(target), fn(variant) {
                let code = "refused-" <> kebab(variant.name)
                #(svc <> "." <> code, [code, sent], False)
              })
            ]
            |> list.map(fn(row) { #(tag, row.0, row.1, row.2) })
          })
        })
      let state = fn(names: List(String)) {
        string.concat(list.map(names, fn(name) { ":state(" <> name <> ")" }))
      }
      let attribute = fn(names: List(String)) {
        string.concat(
          list.map(names, fn(name) { "[data-yumemi-state~=\"" <> name <> "\"]" }),
        )
      }
      let rule = fn(
        row: #(String, String, List(String), Bool),
        on: fn(List(String)) -> String,
      ) {
        let #(tag, when, names, shown_unless) = row
        let selector = case shown_unless {
          // Idle:その送りの sent が立てば隠す
          True -> tag <> on(names)
          False -> tag <> ":not(" <> on(names) <> ")"
        }
        "  "
        <> selector
        <> " [data-yumemi-when~=\""
        <> when
        <> "\"] { display: none; }\n"
      }
      "[data-yumemi-island] > form > fieldset { border: 0; margin: 0; padding: 0; min-inline-size: 0; }\n"
      <> "[data-yumemi-when] { display: contents; }\n"
      <> "@supports selector(:state(x)) {\n"
      <> string.concat(list.map(rules, rule(_, state)))
      <> "}\n"
      <> "@supports not selector(:state(x)) {\n"
      <> string.concat(list.map(rules, rule(_, attribute)))
      <> "}\n"
    }
  }
}

/// emit の側で見る interactive Component の条文(Service の model と route の要るもの)。
pub fn interactive_notes(
  app: model.App,
  back_units: List(Unit),
  package: face.Package,
  front: reader_front.Front,
  hashes: hash.Hashes,
) -> List(stop.Note) {
  let targets = live_targets(app, back_units, package, front, hashes)
  use <- with_notes(route_variant_notes(package, front))
  list.flat_map(front.components, fn(component) {
    let where = package.name <> "/" <> component.module <> ": "
    let conflict = fn(text) {
      stop.Note(class: stop.Conflict, text: where <> text)
    }
    let missing = fn(text) {
      stop.Note(class: stop.Missing, text: where <> text)
    }
    let mine =
      list.filter_map(component.calls, fn(call) {
        list.find(targets, fn(target) {
          target.name == reader_front.live_module(call)
        })
      })
    let writes = list.filter(mine, fn(target) { !target.read && !target.entry })
    let row_names =
      list.map(component.after_send, fn(row) { naming.snake(row.service) })
    // 第 12 条
    let after_missing =
      writes
      |> list.filter(fn(target) { !list.contains(row_names, target.name) })
      |> list.map(fn(target) {
        missing("after_send に書きの Service " <> target.name <> " の組が無い(第 12 条)")
      })
    let after_extra =
      row_names
      |> list.filter(fn(name) {
        !list.any(writes, fn(target) { target.name == name })
      })
      |> list.map(fn(name) {
        conflict(
          "after_send の "
          <> name
          <> " が calls の書きの Service でない(calls に無いか読みの Service、第 12 条)",
        )
      })
    let after_twice =
      row_names
      |> list.filter(fn(name) {
        list.count(row_names, fn(other) { other == name }) > 1
      })
      |> list.unique
      |> list.map(fn(name) {
        conflict("after_send に " <> name <> " の組が 2 つある(第 12 条)")
      })
    // 第 11 条:Args の欄の初期値は型で書く。record・組・Dict・スカラでない要素の List の欄は型で書く形が
    // 無いので止める(JSON の字を Block に書かせない)
    let json_args =
      list.flat_map(mine, fn(target) {
        target.args
        |> list.filter(fn(arg) { wire_has_json(arg.wire) })
        |> list.map(fn(arg) {
          conflict(
            target.name
            <> " の Args の欄 "
            <> arg.name
            <> " が record・組・Dict(JSON で送る形)で、interactive Component の初期値を型で書けない(第 11 条)",
          )
        })
      })
    // 第 15 条:GoTo の path の穴は Out の同じ名の欄
    let goto =
      list.flat_map(component.after_send, fn(row) {
        let target =
          list.find(mine, fn(target) {
            target.name == naming.snake(row.service)
          })
        [#(row.ok, False), #(row.error, True)]
        |> list.filter_map(fn(pair) {
          let #(then, failed) = pair
          case then, target {
            reader_front.ThenGoTo(route: route, ..), Ok(target) ->
              case route_path_for(front, route) {
                None ->
                  Ok(conflict(
                    "GoTo の行き先 route." <> route <> " がこの面の Page に無い(第 15 条)",
                  ))
                // 失敗の本文(`{code, ..}`)は Out でないので、error 側の穴は埋められない
                Some(path) if failed ->
                  case path_holes(path) {
                    [] -> Error(Nil)
                    _ ->
                      Ok(conflict(
                        "after_send の error 側の GoTo(route."
                        <> route
                        <> ") の path "
                        <> path
                        <> " に穴がある(第 15 条、error 側の GoTo は穴の無い route に限る)",
                      ))
                  }
                Some(path) -> {
                  let holes = path_holes(path)
                  case
                    target.accepting
                    || list.all(holes, list.contains(target.out_fields, _))
                  {
                    True -> Error(Nil)
                    False ->
                      Ok(conflict(
                        "GoTo(route."
                        <> route
                        <> ") の path "
                        <> path
                        <> " の穴が "
                        <> target.name
                        <> " の Out の欄に無い(第 15 条、穴は送りの Out の同じ名の欄で埋める)",
                      ))
                  }
                }
              }
            _, _ -> Error(Nil)
          }
        })
      })
    // 第 14 条:List でない Field の 2 回目の bind
    let twice =
      component.live_calls
      |> list.filter(fn(call) {
        list.contains(["bind", "bind_check", "bind_choice"], call.function)
      })
      |> list.filter_map(fn(call) {
        case call.field {
          Some(field) -> Ok(#(call.live, field))
          None -> Error(Nil)
        }
      })
      |> fn(pairs) {
        pairs
        |> list.filter(fn(pair) {
          list.count(pairs, fn(other) { other == pair }) > 1
        })
        |> list.unique
      }
      |> list.filter(fn(pair) {
        case list.find(mine, fn(target) { target.name == pair.0 }) {
          Ok(target) ->
            case
              list.find(target.args, fn(arg) {
                naming.pascal(arg.name) == pair.1
              })
            {
              Ok(LiveArg(wire: ListWire(_), ..)) -> False
              Ok(LiveArg(wire: OptionWire(ListWire(_)), ..)) -> False
              _ -> True
            }
          Error(_) -> False
        }
      })
      |> list.map(fn(pair) {
        conflict(
          pair.0
          <> " の Field "
          <> pair.1
          <> "(List でない)を 2 回以上 bind している(第 14 条)",
        )
      })
    // 第 20 条:書きに send が無い、読みに send も reloads も無い、一覧の読みに send がある
    let sends =
      component.live_calls
      |> list.filter(fn(call) { call.function == "send" })
      |> list.map(fn(call) { call.live })
    let reload_read = case component.reloads {
      Some(reloads) -> Some(naming.snake(reloads.read))
      None -> None
    }
    let unsent =
      mine
      |> list.filter(fn(target) {
        !list.contains(sends, target.name)
        && { !target.read || reload_read != Some(target.name) }
      })
      |> list.map(fn(target) {
        missing(
          target.name
          <> " を calls に書いたのに送れない(書きは view の send、読みは send か reloads が要る、第 20 条)",
        )
      })
    let list_send =
      mine
      |> list.filter(fn(target) {
        target.read && target.list_out && list.contains(sends, target.name)
      })
      |> list.map(fn(target) {
        conflict(
          target.name
          <> " は Out が一覧の読みなのに send がある(第 20 条、一覧は reloads の頁の取り直しで描く)",
        )
      })
    // 第 17 条
    let reloads = case component.reloads {
      None -> []
      Some(reloads) ->
        case
          list.find(mine, fn(target) {
            target.name == naming.snake(reloads.read)
          })
        {
          Error(_) -> [
            conflict(
              "reloads の read " <> reloads.read <> " が calls に無い(第 17 条)",
            ),
          ]
          Ok(target) ->
            case target.read {
              False -> [
                conflict(
                  "reloads の read "
                  <> reloads.read
                  <> " が読みの Service でない(第 17 条)",
                ),
              ]
              True ->
                reloads.on
                |> list.filter(fn(field) {
                  !list.any(target.args, fn(arg) {
                    naming.pascal(arg.name) == field
                  })
                })
                |> list.map(fn(field) {
                  conflict(
                    "reloads の on の "
                    <> field
                    <> " が "
                    <> target.name
                    <> " の Field でない(第 17 条)",
                  )
                })
                |> list.append(case target.list_out {
                  True ->
                    list_reload_notes(
                      front,
                      component,
                      target,
                      reloads,
                      conflict,
                    )
                  False -> []
                })
            }
        }
    }
    list.flatten([
      after_missing,
      after_extra,
      after_twice,
      json_args,
      goto,
      twice,
      unsent,
      list_send,
      reloads,
    ])
  })
}

fn with_notes(
  first: List(stop.Note),
  rest: fn() -> List(stop.Note),
) -> List(stop.Note) {
  list.append(first, rest())
}

/// 第 17 条の一覧の形:Component を置いた Block の Service(`In`)が `read` で、Block の載る Page に
/// `Var(<field>, Query(<field>))` がある(行は頁の loader が読み、Block が SSR で描く)。
fn list_reload_notes(
  front: reader_front.Front,
  component: reader_front.Component,
  target: LiveTarget,
  reloads: reader_front.Reloads,
  conflict: fn(String) -> stop.Note,
) -> List(stop.Note) {
  reader_front.placing_blocks(front, component)
  |> list.flat_map(fn(block) {
    let input = case block.input_kind {
      reader_front.ServiceOut(service) -> service == target.name
      _ -> False
    }
    let service = case input {
      True -> []
      False -> [
        conflict(
          "reloads の一覧の読み "
          <> target.name
          <> " を、別の Service の Block "
          <> block.module
          <> " に置いている(第 17 条、行は置いた Block が read の Out から描く)",
        ),
      ]
    }
    let vars =
      reader_front.block_pages(front, block)
      |> list.flat_map(fn(pair) {
        let #(page, vars) = pair
        reloads.on
        |> list.map(naming.snake)
        |> list.filter(fn(field) {
          !list.any(vars, fn(var) {
            var.name == field && var.from == reader_front.Query(field)
          })
        })
        |> list.map(fn(field) {
          conflict(
            "reloads の一覧の読み "
            <> target.name
            <> " の Component を載せる "
            <> page.module
            <> " に Var(\""
            <> field
            <> "\", Query(\""
            <> field
            <> "\")) が無い(第 17 条)",
          )
        })
      })
    list.append(service, vars)
  })
}
