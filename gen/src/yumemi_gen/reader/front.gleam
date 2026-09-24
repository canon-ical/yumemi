//// 面 package の front model。
////
//// back の `reader.gleam` と出入口を分ける。ここでは面の const / type / function
//// から、次段の emit が使う構造だけを拾う。まだ file は出さない。

import glance
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import yumemi_gen/glance_util as g
import yumemi_gen/model
import yumemi_gen/naming
import yumemi_gen/source.{type Unit}
import yumemi_gen/stop

pub type Error {
  Unsupported(where: String, detail: String)
}

pub type Front {
  Front(
    face: String,
    package_name: String,
    layout: Layout,
    shell: Shell,
    pages: List(Page),
    blocks: List(Block),
    components: List(Component),
    style: Style,
    widget_keys: List(String),
    services: List(String),
    violations: List(Violation),
  )
}

pub type Shell {
  Shell(
    lang: String,
    title: String,
    background: String,
    background_image: String,
    text: String,
    accent: String,
    present: Bool,
    missing: List(String),
  )
}

pub type Layout {
  Layout(
    name: String,
    sp: Option(Frame),
    pc: Option(Frame),
    tablet: Option(Frame),
    reads: List(String),
    nested: Bool,
  )
}

pub type Page {
  Page(
    module: String,
    path: List(String),
    url: String,
    of: Option(String),
    layout: Option(String),
    theme: Option(String),
    sp: Option(Frame),
    pc: Option(Frame),
    tablet: Option(Frame),
    reads: List(String),
  )
}

pub type Frame {
  Frame(
    media: String,
    areas: List(Area),
    placements: List(Placement),
    cols: List(Track),
    rows: List(Track),
    template: List(List(String)),
  )
}

pub type Track {
  Fr(Int)
  Rem(Float)
  Px(Float)
  Minmax(min: TrackSize, max: TrackSize)
}

pub type TrackSize {
  FrSize(Int)
  RemSize(Float)
  PxSize(Float)
}

pub type Cell {
  Flow
  Span(cols: Int, rows: Int)
  At(col: Int, row: Int, span: CellSpan)
}

pub type CellSpan {
  CellSpan(cols: Int, rows: Int)
}

pub type GridTracks {
  GridTracks(cols: List(Track), gap: Length)
}

pub type Length {
  RemLength(Float)
  PxLength(Float)
}

pub type Area {
  Area(
    name: String,
    flow: String,
    grid_tracks: Option(GridTracks),
    pin: String,
    style: List(String),
  )
}

pub type Placement {
  Fixed(area: String, block: String, cell: Cell)
  Widget(area: String, name: String, service: String, render: Render)
}

pub type Render {
  One(block: String)
  ByKind(by: String, table: List(#(String, String)))
  UnknownRender
}

pub type Block {
  Block(
    name: String,
    module: String,
    input: Option(String),
    input_module: Option(String),
    has_view: Bool,
    has_sample: Bool,
  )
}

pub type Component {
  Component(
    name: String,
    module: String,
    calls: List(CallTarget),
    reloads: List(#(String, String)),
    has_view: Bool,
    after_send: Option(String),
    nested_island: Bool,
  )
}

pub type CallTarget {
  ServiceCall(String)
  AttachedCall(String)
}

pub type Style {
  Style(tokens: List(String), media_variants: List(#(String, List(String))))
}

pub type Violation {
  DirectCall(module: String, target: String)
  InternalImport(module: String, imported: String)
  NestedIsland(module: String)
}

/// 面の source units を model にする。Service の variant と Args は back reader の
/// model を受け取るが、back の読み方そのものは呼ばない。
pub fn read(
  face: String,
  units: List(Unit),
  services: List(model.Service),
) -> Result(Front, Error) {
  read_with_package_and_warning(face, face, units, services)
}

pub fn read_with_package(
  face: String,
  package_name: String,
  units: List(Unit),
  services: List(model.Service),
) -> Result(Front, Error) {
  read_with_package_and_warning(face, package_name, units, services)
}

fn read_with_package_and_warning(
  face: String,
  package_name: String,
  units: List(Unit),
  _services: List(model.Service),
) -> Result(Front, Error) {
  use layout_unit <- result.try(find_unit(units, "layout"))
  use layout <- result.try(parse_layout(face, layout_unit))
  let shell = shell_from_units(units, package_name)
  let pages =
    units
    |> list.filter(fn(unit) { string.starts_with(unit.path, "pages/") })
    |> list.filter_map(parse_page)
  let blocks =
    units
    |> list.filter(fn(unit) { string.starts_with(unit.path, "blocks/") })
    |> list.filter_map(parse_block)
  let components =
    units
    |> list.filter(fn(unit) { string.starts_with(unit.path, "components/") })
    |> list.filter_map(parse_component)
  let style =
    units
    |> list.find(fn(unit) { unit.path == "style" })
    |> result.map(parse_style)
    |> option_from_result
    |> option.unwrap(Style(tokens: [], media_variants: []))
  let widget_keys = widget_keys(layout, pages)
  let services_used = service_references(layout, pages, components)
  let violations =
    list.flatten(
      list.map(units, fn(unit) { unit_violations(unit, components) }),
    )
  Ok(Front(
    face: face,
    package_name: package_name,
    layout: layout,
    shell: shell,
    pages: pages,
    blocks: blocks,
    components: components,
    style: style,
    widget_keys: widget_keys,
    services: services_used,
    violations: violations,
  ))
}

/// model に対する停止診断。検査はここに集め、emit は呼ばない。
pub fn notes(front: Front, services: List(model.Service)) -> List(stop.Note) {
  list.flatten([
    shell_notes(front),
    violation_notes(front.face, front.violations),
    frame_notes(
      front.face,
      "layout",
      front.layout.sp,
      front.layout.pc,
      front.layout.tablet,
    ),
    list.flatten(
      list.map(front.pages, fn(page) {
        list.append(
          frame_notes(front.face, page.module, page.sp, page.pc, page.tablet),
          page_arg_notes(front.face, page, services),
        )
      }),
    ),
    layout_widget_notes(front.face, front.layout, services),
    widget_notes(front.face, front.pages, services),
    reads_type_notes(front, services),
    layout_nested_notes(front.face, front.layout),
    unknown_service_notes(front.face, front.services, services),
  ])
}

fn reads_type_notes(
  front: Front,
  services: List(model.Service),
) -> List(stop.Note) {
  let layout_notes =
    reads_context_notes(
      front.face,
      "layout",
      front.layout.reads,
      layout_frames(front.layout),
      front.blocks,
      services,
    )
  let page_notes =
    front.pages
    |> list.flat_map(fn(page) {
      reads_context_notes(
        front.face,
        page.module,
        page.reads,
        page_frames(page),
        front.blocks,
        services,
      )
    })
  list.append(layout_notes, page_notes)
}

fn reads_context_notes(
  face: String,
  context: String,
  reads: List(String),
  frames: List(Frame),
  blocks: List(Block),
  services: List(model.Service),
) -> List(stop.Note) {
  let placed_blocks =
    frames
    |> list.flat_map(fn(frame) {
      frame.placements
      |> list.filter_map(fn(placement) {
        case placement {
          Fixed(block:, ..) -> Ok(block)
          Widget(..) -> Error(Nil)
        }
      })
    })
    |> list.unique
  reads
  |> list.flat_map(fn(variant) {
    case service_by_variant(services, variant) {
      Some(service) ->
        placed_blocks
        |> list.filter_map(fn(name) {
          case list.find(blocks, fn(block) { block.name == name }) {
            Ok(block) ->
              case block_uses_service(block, service) {
                False -> Error(Nil)
                True ->
                  case block_matches_service_out(block, service) {
                    True -> Error(Nil)
                    False ->
                      Ok(stop.Note(
                        class: stop.Conflict,
                        text: face
                          <> "/"
                          <> context
                          <> ": reads の "
                          <> service.module
                          <> ".Out と Block "
                          <> block.name
                          <> " の In が一致しない",
                      ))
                  }
              }
            Error(_) -> Error(Nil)
          }
        })
      None -> []
    }
  })
}

fn service_by_variant(
  services: List(model.Service),
  variant: String,
) -> Option(model.Service) {
  services
  |> list.find(fn(service) {
    service.module == variant || naming.pascal(service.module) == variant
  })
  |> option_from_result
}

fn block_uses_service(block: Block, service: model.Service) -> Bool {
  case block.input_module, service.out_type {
    Some(module), Some(out_type) ->
      module == "gen/out/" <> service.module
      || module == service.module
      || module == "service/" <> service.module
      || Some(module) == out_type.module
    Some(module), None ->
      module == "gen/out/" <> service.module
      || module == service.module
      || module == "service/" <> service.module
    _, _ -> False
  }
}

fn block_matches_service_out(block: Block, service: model.Service) -> Bool {
  case block.input, block.input_module, service.out_type {
    Some(input), Some(module), Some(out_type) ->
      case module == "gen/out/" <> service.module {
        True -> input == "Out" || input == out_type.name
        False ->
          case
            module == service.module || module == "service/" <> service.module
          {
            True -> input == "Out" || input == out_type.name
            False ->
              module == option.unwrap(out_type.module, "")
              && input == out_type.name
          }
      }
    _, _, _ -> False
  }
}

fn shell_from_units(units: List(Unit), package_name: String) -> Shell {
  case list.find(units, fn(unit) { unit.path == "shell" }) {
    Error(_) ->
      Shell(
        lang: "",
        title: "",
        background: "",
        background_image: "",
        text: "",
        accent: "",
        present: False,
        missing: [],
      )
    Ok(unit) -> {
      let module = g.in_order(unit.module)
      let theme = public_named_constant(module, "theme")
      let lang = constant_string(module, "lang")
      let title = constant_string(module, "title")
      let background = theme_string(theme, "background")
      let background_image = theme_string(theme, "background_image")
      let text = theme_string(theme, "text")
      let accent = theme_string(theme, "accent")
      let missing_theme = case theme {
        None -> ["theme"]
        Some(_) ->
          list.flatten([
            missing_label("theme.background", background),
            missing_label("theme.background_image", background_image),
            missing_label("theme.text", text),
            missing_label("theme.accent", accent),
          ])
      }
      Shell(
        lang: option.unwrap(lang, "ja"),
        title: option.unwrap(title, package_name),
        background: option.unwrap(background, "#FAF7F0"),
        background_image: option.unwrap(background_image, "none"),
        text: option.unwrap(text, "#3D2419"),
        accent: option.unwrap(accent, "#A93632"),
        present: True,
        missing: list.flatten([
          missing_label("lang", lang),
          missing_label("title", title),
          missing_theme,
        ]),
      )
    }
  }
}

fn constant_string(module: glance.Module, name: String) -> Option(String) {
  public_named_constant(module, name)
  |> option.then(fn(constant) { g.string_value(constant.value) })
}

fn theme_string(
  theme: Option(glance.Constant),
  label: String,
) -> Option(String) {
  theme
  |> option.then(fn(constant) { g.labelled(constant.value, label) })
  |> option.then(g.string_value)
}

fn missing_label(name: String, value: Option(a)) -> List(String) {
  case value {
    None -> [name]
    Some(_) -> []
  }
}

fn shell_notes(front: Front) -> List(stop.Note) {
  case front.shell.present {
    True ->
      list.map(front.shell.missing, fn(name) {
        stop.Note(
          class: stop.Missing,
          text: front.face <> "/src/shell.gleam: " <> name <> " が無い",
        )
      })
    False -> [
      stop.Note(class: stop.Missing, text: front.face <> "/src/shell.gleam: 無い"),
    ]
  }
}

fn find_unit(units: List(Unit), path: String) -> Result(Unit, Error) {
  case list.find(units, fn(unit) { unit.path == path }) {
    Ok(unit) -> Ok(unit)
    Error(_) -> Error(Unsupported(path, "面の source が無い"))
  }
}

fn parse_layout(face: String, unit: Unit) -> Result(Layout, Error) {
  let module = g.in_order(unit.module)
  use constant <- result.try(public_constant(module, face, "layout"))
  use value <- result.try(expected_type(constant, "Layout", unit.path))
  use _ <- result.try(expected_constructor(value, "Layout", unit.path))
  Ok(Layout(
    name: face,
    sp: frame_field(value, "sp", "sp", unit.path),
    pc: frame_field(value, "pc", "pc", unit.path),
    tablet: frame_field(value, "tablet", "tablet", unit.path),
    reads: service_list_field(value, "reads"),
    nested: has_nested_constructor(value, "Layout"),
  ))
}

fn parse_page(unit: Unit) -> Result(Page, Nil) {
  let module = g.in_order(unit.module)
  case public_named_constant(module, "page") {
    Some(constant) ->
      case constant.annotation, g.ctor_name(constant.value) {
        Some(_annotation), Some("Page") ->
          Ok(Page(
            module: unit.path,
            path: page_path(unit.path),
            url: page_url(unit.path),
            of: option_service(g.labelled(constant.value, "of")),
            layout: option_name(g.labelled(constant.value, "layout")),
            theme: option_string_name(g.labelled(constant.value, "theme")),
            sp: frame_field(constant.value, "sp", "sp", unit.path),
            pc: frame_field(constant.value, "pc", "pc", unit.path),
            tablet: frame_field(constant.value, "tablet", "tablet", unit.path),
            reads: service_list_field(constant.value, "reads"),
          ))
        _, _ -> Error(Nil)
      }
    None -> Error(Nil)
  }
}

fn parse_block(unit: Unit) -> Result(Block, Nil) {
  let module = g.in_order(unit.module)
  let name = last_segment(unit.path) |> naming.pascal
  let view = public_function(module, "view")
  let #(input, input_module) =
    view
    |> option.then(fn(function) { first_parameter_input(module, function) })
    |> option.unwrap(#(None, None))
  Ok(Block(
    name: name,
    module: unit.path,
    input: input,
    input_module: input_module,
    has_view: view != None,
    has_sample: has_public_constant(module, "sample"),
  ))
}

fn parse_component(unit: Unit) -> Result(Component, Nil) {
  let module = g.in_order(unit.module)
  let name = last_segment(unit.path) |> naming.pascal
  let calls =
    list.append(
      call_target_list(module, "calls"),
      option_to_list(call_target_constant(module, "target")),
    )
  let reloads = reload_list(module, "reloads")
  let view = public_function(module, "view")
  Ok(
    Component(
      name: name,
      module: unit.path,
      calls: calls,
      reloads: reloads,
      has_view: view != None,
      after_send: after_send_of(module),
      nested_island: case view {
        Some(function) -> nested_island(function.body)
        None -> False
      },
    ),
  )
}

fn parse_style(unit: Unit) -> Style {
  let module = g.in_order(unit.module)
  let tokens =
    module.constants
    |> list.filter_map(fn(definition) {
      let constant = definition.definition
      case constant.publicity, constant.annotation {
        glance.Public, Some(annotation) ->
          case is_style_annotation(annotation) {
            True -> Ok(constant.name)
            False -> Error(Nil)
          }
        _, _ -> Error(Nil)
      }
    })
  let media_variants =
    module.custom_types
    |> list.filter_map(fn(definition) {
      let custom = definition.definition
      case custom.publicity, is_media_enum(custom.name) {
        glance.Public, True ->
          Ok(#(
            custom.name,
            list.map(custom.variants, fn(variant) { variant.name }),
          ))
        _, _ -> Error(Nil)
      }
    })
  Style(tokens: tokens, media_variants: media_variants)
}

fn is_style_annotation(annotation: glance.Type) -> Bool {
  case annotation {
    glance.NamedType(name: name, parameters: parameters, ..) ->
      list.contains(["Style", "Length", "Breakpoint"], name)
      || list.any(parameters, is_style_annotation)
    _ -> False
  }
}

fn frame_field(
  expression: glance.Expression,
  label: String,
  media: String,
  _where: String,
) -> Option(Frame) {
  case g.labelled(expression, label) {
    None -> None
    Some(value) ->
      case option_value(value) {
        None -> None
        Some(frame) -> parse_frame(frame, media)
      }
  }
}

fn parse_frame(expression: glance.Expression, media: String) -> Option(Frame) {
  case g.ctor_name(expression) {
    Some("Frame") ->
      Some(Frame(
        media: media,
        areas: g.labelled(expression, "areas")
          |> option.then(parse_areas)
          |> option.unwrap([]),
        placements: g.labelled(expression, "placements")
          |> option.then(parse_placements)
          |> option.unwrap([]),
        cols: g.labelled(expression, "cols")
          |> option.then(parse_tracks)
          |> option.unwrap([]),
        rows: g.labelled(expression, "rows")
          |> option.then(parse_tracks)
          |> option.unwrap([]),
        template: g.labelled(expression, "template")
          |> option.then(parse_template)
          |> option.unwrap([]),
      ))
    _ -> None
  }
}

fn parse_areas(expression: glance.Expression) -> Option(List(Area)) {
  case g.list_elements(expression) {
    [] ->
      case expression {
        glance.List(elements: [], ..) -> Some([])
        _ -> None
      }
    elements -> Some(list.filter_map(elements, parse_area_result))
  }
}

fn parse_area(expression: glance.Expression) -> Option(Area) {
  case g.ctor_name(expression) {
    Some("Area") ->
      Some(Area(
        name: string_label(expression, "name") |> option.unwrap(""),
        flow: constructor_label(expression, "flow") |> option.unwrap(""),
        grid_tracks: g.labelled(expression, "flow")
          |> option.then(parse_grid_tracks),
        pin: constructor_label(expression, "pin") |> option.unwrap(""),
        style: style_names(expression),
      ))
    _ -> None
  }
}

fn parse_area_result(expression: glance.Expression) -> Result(Area, Nil) {
  case parse_area(expression) {
    Some(area) -> Ok(area)
    None -> Error(Nil)
  }
}

fn parse_placements(expression: glance.Expression) -> Option(List(Placement)) {
  case expression {
    glance.List(elements: elements, ..) ->
      Some(list.filter_map(elements, parse_placement_result))
    _ -> None
  }
}

fn parse_placement(expression: glance.Expression) -> Option(Placement) {
  case g.ctor_name(expression) {
    Some("Fixed") ->
      Some(Fixed(
        area: string_label(expression, "area") |> option.unwrap(""),
        block: labelled_constructor(expression, "block") |> option.unwrap(""),
        cell: g.labelled(expression, "cell")
          |> option.then(parse_cell)
          |> option.unwrap(Flow),
      ))
    Some("Widget") ->
      Some(Widget(
        area: string_label(expression, "area") |> option.unwrap(""),
        name: string_label(expression, "name") |> option.unwrap(""),
        service: labelled_constructor(expression, "of") |> option.unwrap(""),
        render: render_of(expression),
      ))
    _ -> None
  }
}

fn parse_placement_result(
  expression: glance.Expression,
) -> Result(Placement, Nil) {
  case parse_placement(expression) {
    Some(placement) -> Ok(placement)
    None -> Error(Nil)
  }
}

fn parse_tracks(expression: glance.Expression) -> Option(List(Track)) {
  case expression {
    glance.List(elements: elements, ..) ->
      list.try_map(elements, parse_track) |> option_from_result
    _ -> None
  }
}

fn parse_track(expression: glance.Expression) -> Result(Track, Nil) {
  case g.ctor_name(expression) {
    Some("Fr") ->
      case g.args(expression) {
        [value] -> parse_int(value) |> option.map(Fr) |> option.to_result(Nil)
        _ -> Error(Nil)
      }
    Some("Rem") -> parse_float_arg(expression) |> result.map(Rem)
    Some("Px") -> parse_float_arg(expression) |> result.map(Px)
    Some("Minmax") ->
      case g.labelled(expression, "min"), g.labelled(expression, "max") {
        Some(min), Some(max) ->
          case parse_track_size(min), parse_track_size(max) {
            Ok(min), Ok(max) -> Ok(Minmax(min: min, max: max))
            _, _ -> Error(Nil)
          }
        _, _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

fn parse_track_size(expression: glance.Expression) -> Result(TrackSize, Nil) {
  case g.ctor_name(expression) {
    Some("FrSize") ->
      case g.args(expression) {
        [value] ->
          parse_int(value) |> option.map(FrSize) |> option.to_result(Nil)
        _ -> Error(Nil)
      }
    Some("RemSize") -> parse_float_arg(expression) |> result.map(RemSize)
    Some("PxSize") -> parse_float_arg(expression) |> result.map(PxSize)
    _ -> Error(Nil)
  }
}

fn parse_float_arg(expression: glance.Expression) -> Result(Float, Nil) {
  case g.args(expression) {
    [glance.Float(value:, ..)] -> float.parse(value)
    [glance.Int(value:, ..)] -> float.parse(value <> ".0")
    _ -> Error(Nil)
  }
}

fn parse_template(expression: glance.Expression) -> Option(List(List(String))) {
  case expression {
    glance.List(elements: rows, ..) ->
      rows
      |> list.try_map(fn(row) {
        case row {
          glance.List(elements: names, ..) ->
            names
            |> list.try_map(fn(name) {
              g.string_value(name) |> option.to_result(Nil)
            })
          _ -> Error(Nil)
        }
      })
      |> option_from_result
    _ -> None
  }
}

fn parse_grid_tracks(expression: glance.Expression) -> Option(GridTracks) {
  case g.ctor_name(expression) {
    Some("GridTracks") ->
      case g.labelled(expression, "cols"), g.labelled(expression, "gap") {
        Some(cols), Some(gap) ->
          case parse_tracks(cols), parse_length(gap) {
            Some(cols), Some(gap) -> Some(GridTracks(cols: cols, gap: gap))
            _, _ -> None
          }
        _, _ -> None
      }
    _ -> None
  }
}

fn parse_length(expression: glance.Expression) -> Option(Length) {
  case g.ctor_name(expression) {
    Some("Rem") ->
      parse_float_arg(expression) |> option_from_result |> option.map(RemLength)
    Some("Px") ->
      parse_float_arg(expression) |> option_from_result |> option.map(PxLength)
    _ -> None
  }
}

fn parse_cell(expression: glance.Expression) -> Option(Cell) {
  case g.ctor_name(expression) {
    Some("Flow") -> Some(Flow)
    Some("Span") ->
      case g.labelled(expression, "cols"), g.labelled(expression, "rows") {
        Some(cols), Some(rows) ->
          case parse_int(cols), parse_int(rows) {
            Some(cols), Some(rows) -> Some(Span(cols: cols, rows: rows))
            _, _ -> None
          }
        _, _ -> None
      }
    Some("At") ->
      case
        g.labelled(expression, "col"),
        g.labelled(expression, "row"),
        g.labelled(expression, "span")
      {
        Some(col), Some(row), Some(span) ->
          case parse_int(col), parse_int(row), parse_cell_span(span) {
            Some(col), Some(row), Some(span) ->
              Some(At(col: col, row: row, span: span))
            _, _, _ -> None
          }
        _, _, _ -> None
      }
    _ -> None
  }
}

fn parse_cell_span(expression: glance.Expression) -> Option(CellSpan) {
  case g.ctor_name(expression) {
    Some("CellSpan") ->
      case g.labelled(expression, "cols"), g.labelled(expression, "rows") {
        Some(cols), Some(rows) ->
          case parse_int(cols), parse_int(rows) {
            Some(cols), Some(rows) -> Some(CellSpan(cols: cols, rows: rows))
            _, _ -> None
          }
        _, _ -> None
      }
    _ -> None
  }
}

fn parse_int(expression: glance.Expression) -> Option(Int) {
  case g.int_value(expression) {
    Some(value) -> int.parse(value) |> option_from_result
    None -> None
  }
}

fn render_of(expression: glance.Expression) -> Render {
  case g.labelled(expression, "render") {
    Some(value) ->
      case g.ctor_name(value) {
        Some("One") ->
          One(g.args(value) |> first_constructor |> option.unwrap(""))
        Some("ByKind") -> {
          let by = string_label(value, "by") |> option.unwrap("")
          let table =
            g.labelled(value, "table")
            |> option.then(tuple_table)
            |> option.unwrap([])
          ByKind(by: by, table: table)
        }
        _ -> UnknownRender
      }
    None -> UnknownRender
  }
}

fn tuple_table(
  expression: glance.Expression,
) -> Option(List(#(String, String))) {
  case expression {
    glance.List(elements: elements, ..) ->
      Some(
        list.filter_map(elements, fn(item) {
          case item {
            glance.Tuple(elements: [key, block], ..) ->
              case g.string_value(key), g.ctor_name(block) {
                Some(key), Some(block) -> Ok(#(key, block))
                _, _ -> Error(Nil)
              }
            _ -> Error(Nil)
          }
        }),
      )
    _ -> None
  }
}

fn widget_keys(layout: Layout, pages: List(Page)) -> List(String) {
  let layout_keys = placement_widget_names(layout_frames(layout))
  let page_keys =
    pages
    |> list.flat_map(fn(page) { placement_widget_names(page_frames(page)) })
  layout_keys
  |> list.append(page_keys)
  |> list.unique
  |> list.map(naming.pascal)
}

fn placement_widget_names(frames: List(Frame)) -> List(String) {
  frames
  |> list.flat_map(fn(frame) {
    frame.placements
    |> list.filter_map(fn(placement) {
      case placement {
        Widget(name: name, ..) -> Ok(name)
        Fixed(..) -> Error(Nil)
      }
    })
  })
}

fn service_references(
  layout: Layout,
  pages: List(Page),
  components: List(Component),
) -> List(String) {
  let from_layout =
    list.append(layout.reads, placement_services(layout_frames(layout)))
  let from_pages =
    pages
    |> list.flat_map(fn(page) {
      list.flatten([
        option_to_list(page.of),
        page.reads,
        placement_services(page_frames(page)),
      ])
    })
  let from_components =
    list.flat_map(components, fn(component) {
      list.append(
        list.filter_map(component.calls, fn(target) {
          call_service(target) |> option.to_result(Nil)
        }),
        list.map(component.reloads, fn(reload) { reload.1 }),
      )
    })
  list.unique(list.flatten([from_layout, from_pages, from_components]))
}

fn placement_services(frames: List(Frame)) -> List(String) {
  frames
  |> list.flat_map(fn(frame) {
    frame.placements
    |> list.filter_map(fn(placement) {
      case placement {
        Widget(service: service, ..) -> Ok(service)
        Fixed(..) -> Error(Nil)
      }
    })
  })
}

fn layout_frames(layout: Layout) -> List(Frame) {
  option_to_list(layout.sp)
  |> list.append(option_to_list(layout.pc))
  |> list.append(option_to_list(layout.tablet))
}

fn page_frames(page: Page) -> List(Frame) {
  option_to_list(page.sp)
  |> list.append(option_to_list(page.pc))
  |> list.append(option_to_list(page.tablet))
}

fn page_arg_notes(
  face: String,
  page: Page,
  services: List(model.Service),
) -> List(stop.Note) {
  case page.of, find_service(services, page.of) {
    Some(service_name), Some(service) ->
      page.path
      |> list.filter_map(fn(segment) {
        case string.starts_with(segment, "arg_") {
          True -> {
            let name = argument_name(segment)
            case list.any(service.args, fn(arg) { arg.name == name }) {
              True -> Error(Nil)
              False ->
                Ok(stop.Note(
                  class: stop.Conflict,
                  text: face
                    <> "/"
                    <> page.module
                    <> ": Page のパス変数 "
                    <> name
                    <> " が Service."
                    <> service_name
                    <> " の Args に無い",
                ))
            }
          }
          False -> Error(Nil)
        }
      })
    _, _ -> []
  }
}

fn layout_widget_notes(
  face: String,
  layout: Layout,
  services: List(model.Service),
) -> List(stop.Note) {
  widget_placements(layout_frames(layout))
  |> list.filter_map(fn(placement) {
    note_result(widget_note(face <> "/layout", placement, services))
  })
}

fn widget_notes(
  face: String,
  pages: List(Page),
  services: List(model.Service),
) -> List(stop.Note) {
  pages
  |> list.flat_map(fn(page) {
    widget_placements(page_frames(page))
    |> list.filter_map(fn(placement) {
      note_result(widget_note(face <> "/" <> page.module, placement, services))
    })
  })
}

fn widget_note(
  where: String,
  placement: Placement,
  services: List(model.Service),
) -> Option(stop.Note) {
  case placement {
    Fixed(..) -> None
    Widget(area: area, name: name, service: service_name, ..) ->
      case find_service(services, Some(service_name)) {
        Some(service) ->
          case
            list.any(service.args, fn(arg) {
              arg.name == "widget" || arg.name == name || arg.name == area
            })
          {
            True -> None
            False ->
              Some(stop.Note(
                class: stop.Conflict,
                text: where
                  <> ": Widget."
                  <> name
                  <> " の Service."
                  <> service_name
                  <> " が枠の名前を Args に持たない",
              ))
          }
        None -> None
      }
  }
}

fn note_result(note: Option(stop.Note)) -> Result(stop.Note, Nil) {
  case note {
    Some(note) -> Ok(note)
    None -> Error(Nil)
  }
}

fn widget_placements(frames: List(Frame)) -> List(Placement) {
  frames
  |> list.flat_map(fn(frame) {
    frame.placements
    |> list.filter(fn(placement) {
      case placement {
        Widget(..) -> True
        Fixed(..) -> False
      }
    })
  })
}

fn frame_notes(
  face: String,
  module: String,
  sp: Option(Frame),
  pc: Option(Frame),
  tablet: Option(Frame),
) -> List(stop.Note) {
  let missing = case sp {
    None -> [
      stop.Note(class: stop.Missing, text: face <> "/" <> module <> ": sp: が無い"),
    ]
    Some(_) -> []
  }
  list.append(
    missing,
    list.flatten([
      duplicate_top_notes(face, module, sp),
      duplicate_top_notes(face, module, pc),
      duplicate_top_notes(face, module, tablet),
    ]),
  )
}

fn duplicate_top_notes(
  face: String,
  module: String,
  frame: Option(Frame),
) -> List(stop.Note) {
  case frame {
    Some(frame) ->
      case list.count(frame.areas, fn(area) { area.pin == "Top" }) > 1 {
        True -> [
          stop.Note(
            class: stop.Conflict,
            text: face
              <> "/"
              <> module
              <> "/"
              <> frame.media
              <> ": 同じ断点に pin: Top の Area が2つある",
          ),
        ]
        False -> []
      }
    None -> []
  }
}

fn layout_nested_notes(face: String, layout: Layout) -> List(stop.Note) {
  case layout.nested {
    True -> [
      stop.Note(
        class: stop.Conflict,
        text: face <> "/layout: Layout の中に Layout がある",
      ),
    ]
    False -> []
  }
}

fn unknown_service_notes(
  face: String,
  references: List(String),
  services: List(model.Service),
) -> List(stop.Note) {
  case services {
    [] -> []
    _ ->
      references
      |> list.filter(fn(name) { find_service(services, Some(name)) == None })
      |> list.map(fn(name) {
        stop.Note(
          class: stop.Conflict,
          text: face <> "/service: 未知の Service variant: " <> name,
        )
      })
  }
}

fn violation_notes(
  face: String,
  violations: List(Violation),
) -> List(stop.Note) {
  violations
  |> list.map(fn(violation) {
    case violation {
      DirectCall(module: module, target: target) ->
        stop.Note(
          class: stop.Conflict,
          text: face <> "/" <> module <> ": " <> target <> " を直接呼び出している",
        )
      InternalImport(module: module, imported: imported) ->
        stop.Note(
          class: stop.Conflict,
          text: face
            <> "/"
            <> module
            <> ": lustre 内部 module を import している: "
            <> imported,
        )
      NestedIsland(module: module) ->
        stop.Note(
          class: stop.Conflict,
          text: face <> "/" <> module <> ": 島の中に島がある",
        )
    }
  })
}

fn unit_violations(unit: Unit, components: List(Component)) -> List(Violation) {
  let module = g.in_order(unit.module)
  let imports =
    module.imports
    |> list.filter_map(fn(definition) {
      let imported = definition.definition.module
      case string.starts_with(imported, "lustre/internals") {
        True -> Ok(InternalImport(module: unit.path, imported: imported))
        False -> Error(Nil)
      }
    })
  let direct =
    list.append(
      module.functions
        |> list.flat_map(fn(definition) {
          let function = definition.definition
          forbidden_calls(function.body, module.imports)
          |> list.map(fn(target) {
            DirectCall(module: unit.path, target: target)
          })
        }),
      module.constants
        |> list.flat_map(fn(definition) {
          forbidden_in_expression(definition.definition.value, module.imports)
          |> list.map(fn(target) {
            DirectCall(module: unit.path, target: target)
          })
        }),
    )
  let islands = case
    list.find(components, fn(component) { component.module == unit.path })
  {
    Ok(component) if component.nested_island -> [NestedIsland(module: unit.path)]
    _ -> []
  }
  list.append(imports, list.append(direct, islands))
}

fn public_constant(
  module: glance.Module,
  name: String,
  where: String,
) -> Result(glance.Constant, Error) {
  case public_named_constant(module, name) {
    Some(constant) -> Ok(constant)
    None -> Error(Unsupported(where, "pub const " <> name <> " が無い"))
  }
}

fn public_named_constant(
  module: glance.Module,
  name: String,
) -> Option(glance.Constant) {
  case g.find_constant(module, name) {
    Some(constant) ->
      case constant.publicity {
        glance.Public -> Some(constant)
        glance.Private -> None
      }
    None -> None
  }
}

fn has_public_constant(module: glance.Module, name: String) -> Bool {
  public_named_constant(module, name) != None
}

fn public_function(
  module: glance.Module,
  name: String,
) -> Option(glance.Function) {
  case g.find_function(module, name) {
    Some(function) ->
      case function.publicity {
        glance.Public -> Some(function)
        glance.Private -> None
      }
    None -> None
  }
}

fn expected_type(
  constant: glance.Constant,
  expected: String,
  where: String,
) -> Result(glance.Expression, Error) {
  case constant.annotation {
    Some(annotation) ->
      case g.type_name(annotation) == Some(expected) {
        True -> Ok(constant.value)
        False ->
          Error(Unsupported(where, "pub const の型が " <> expected <> " でない"))
      }
    None -> Error(Unsupported(where, "pub const に型注釈が無い"))
  }
}

fn expected_constructor(
  expression: glance.Expression,
  expected: String,
  where: String,
) -> Result(Nil, Error) {
  case g.ctor_name(expression) {
    Some(name) if name == expected -> Ok(Nil)
    Some(name) ->
      Error(Unsupported(where, "構成子が " <> expected <> " でない: " <> name))
    None -> Error(Unsupported(where, expected <> " の構成子が読めない"))
  }
}

fn service_list_field(
  expression: glance.Expression,
  label: String,
) -> List(String) {
  g.labelled(expression, label)
  |> option.then(fn(value) {
    case value {
      glance.List(elements: elements, ..) ->
        Some(
          list.filter_map(elements, fn(item) {
            service_target(item) |> option.to_result(Nil)
          }),
        )
      _ -> None
    }
  })
  |> option.unwrap([])
}

fn call_target_list(module: glance.Module, name: String) -> List(CallTarget) {
  case public_named_constant(module, name) {
    Some(constant) ->
      case constant.value {
        glance.List(elements: elements, ..) ->
          list.filter_map(elements, fn(expression) {
            target_of(expression) |> option.to_result(Nil)
          })
        _ -> []
      }
    None -> []
  }
}

fn call_target_constant(
  module: glance.Module,
  name: String,
) -> Option(CallTarget) {
  public_named_constant(module, name)
  |> option.then(fn(constant) { target_of(constant.value) })
}

fn target_of(expression: glance.Expression) -> Option(CallTarget) {
  case g.ctor_name(expression) {
    Some("Of") ->
      case g.args(expression) {
        [service] -> g.ctor_name(service) |> option.map(ServiceCall)
        _ -> None
      }
    Some("Entry") ->
      case g.args(expression) {
        [attached] -> g.ctor_name(attached) |> option.map(AttachedCall)
        _ -> None
      }
    _ -> service_target(expression) |> option.map(ServiceCall)
  }
}

fn service_target(expression: glance.Expression) -> Option(String) {
  case g.ctor_module(expression), g.ctor_name(expression) {
    Some(_), Some(variant) -> Some(variant)
    _, _ -> None
  }
}

fn call_service(target: CallTarget) -> Option(String) {
  case target {
    ServiceCall(service) -> Some(service)
    AttachedCall(_) -> None
  }
}

fn reload_list(module: glance.Module, name: String) -> List(#(String, String)) {
  case public_named_constant(module, name) {
    Some(constant) ->
      case constant.value {
        glance.List(elements: elements, ..) ->
          list.filter_map(elements, fn(expression) {
            case expression {
              glance.Tuple(elements: [field, service], ..) ->
                case
                  g.ctor_name(field),
                  g.ctor_name(service),
                  g.ctor_module(service)
                {
                  Some(field), Some(service), Some("service") ->
                    Ok(#(field, service))
                  _, _, _ -> Error(Nil)
                }
              _ -> Error(Nil)
            }
          })
        _ -> []
      }
    None -> []
  }
}

fn after_send_of(module: glance.Module) -> Option(String) {
  case public_named_constant(module, "after_send") {
    Some(constant) ->
      case constant.annotation, g.ctor_name(constant.value) {
        Some(annotation), Some(value) ->
          case g.type_name(annotation) == Some("After") {
            True -> Some(value)
            False -> None
          }
        _, _ -> None
      }
    None -> None
  }
}

fn option_service(value: Option(glance.Expression)) -> Option(String) {
  value
  |> option_value_option
  |> option.then(fn(expression) { g.ctor_name(expression) })
}

fn option_name(value: Option(glance.Expression)) -> Option(String) {
  value
  |> option_value_option
  |> option.then(g.ctor_name)
}

fn option_string_name(value: Option(glance.Expression)) -> Option(String) {
  value
  |> option_value_option
  |> option.then(g.string_value)
}

fn option_value(expression: glance.Expression) -> Option(glance.Expression) {
  case g.ctor_name(expression) {
    Some("Some") ->
      case g.args(expression) {
        [value] -> Some(value)
        _ -> None
      }
    Some("None") -> None
    _ -> Some(expression)
  }
}

fn option_value_option(
  value: Option(glance.Expression),
) -> Option(glance.Expression) {
  case value {
    Some(expression) -> option_value(expression)
    None -> None
  }
}

fn first_constructor(expressions: List(glance.Expression)) -> Option(String) {
  case expressions {
    [expression, ..] -> g.ctor_name(expression)
    [] -> None
  }
}

fn first_parameter_input(
  module: glance.Module,
  function: glance.Function,
) -> Option(#(Option(String), Option(String))) {
  case function.parameters {
    [parameter, ..] ->
      case parameter.type_ {
        Some(annotation) -> Some(resolved_input(module, annotation))
        None -> None
      }
    [] -> None
  }
}

fn resolved_input(
  module: glance.Module,
  annotation: glance.Type,
) -> #(Option(String), Option(String)) {
  case annotation {
    glance.NamedType(name: name, module: Some(path), ..) -> #(
      Some(name),
      Some(path),
    )
    glance.NamedType(name: name, module: None, ..) ->
      case g.find_type_alias(module, name) {
        Some(alias) -> resolved_input(module, alias.aliased)
        None -> #(Some(name), None)
      }
    _ -> #(None, None)
  }
}

fn string_label(
  expression: glance.Expression,
  label: String,
) -> Option(String) {
  g.labelled(expression, label)
  |> option.then(g.string_value)
}

fn constructor_label(
  expression: glance.Expression,
  label: String,
) -> Option(String) {
  g.labelled(expression, label)
  |> option.then(g.ctor_name)
}

fn labelled_constructor(
  expression: glance.Expression,
  label: String,
) -> Option(String) {
  constructor_label(expression, label)
}

fn style_names(expression: glance.Expression) -> List(String) {
  case g.labelled(expression, "style") {
    Some(value) ->
      case value {
        glance.List(elements: elements, ..) ->
          list.filter_map(elements, fn(item) {
            case g.ctor_name(item) {
              Some(name) -> Ok(name)
              None -> Error(Nil)
            }
          })
        _ ->
          case g.ctor_name(value) {
            Some(name) -> [name]
            None -> []
          }
      }
    None -> []
  }
}

fn page_path(path: String) -> List(String) {
  let body = string.drop_start(path, 6)
  let segments = string.split(body, "/")
  case list.length(segments) {
    0 -> []
    length -> list.take(segments, length - 1)
  }
}

fn page_url(path: String) -> String {
  let segments = page_path(path)
  case segments {
    [] -> "/"
    _ -> {
      let rendered = segments |> list.map(url_segment) |> string.join("/")
      "/" <> rendered
    }
  }
}

/// Page の route 表だけが使う URL。back の HTTP route は `{name}`、面の
/// browser route は `:name` と表記が違うため、同じ page path からここで分ける。
pub fn route_path(path: List(String)) -> String {
  case path {
    [] -> "/"
    _ -> "/" <> string.join(list.map(path, route_segment), "/")
  }
}

fn route_segment(segment: String) -> String {
  case string.starts_with(segment, "arg_") {
    True -> ":" <> argument_name(segment)
    False ->
      case segment {
        "_" -> "-"
        _ -> trim_reserved(segment)
      }
  }
}

fn url_segment(segment: String) -> String {
  case string.starts_with(segment, "arg_") {
    True -> "{" <> argument_name(segment) <> "}"
    False ->
      case segment {
        "_" -> "-"
        _ -> trim_reserved(segment)
      }
  }
}

fn argument_name(segment: String) -> String {
  trim_reserved(string.drop_start(segment, 4))
}

fn trim_reserved(segment: String) -> String {
  case string.ends_with(segment, "_") {
    True -> {
      let stem = string.drop_end(segment, 1)
      case reserved_word(stem) {
        True -> stem
        False -> segment
      }
    }
    False -> segment
  }
}

fn reserved_word(value: String) -> Bool {
  list.contains(
    [
      "as", "assert", "case", "const", "derive", "else", "fn", "if", "import",
      "let", "opaque", "panic", "pub", "target", "todo", "type", "use", "when",
    ],
    value,
  )
}

fn last_segment(path: String) -> String {
  case list.last(string.split(path, "/")) {
    Ok(value) -> value
    Error(_) -> path
  }
}

fn option_to_list(value: Option(a)) -> List(a) {
  case value {
    Some(item) -> [item]
    None -> []
  }
}

fn option_from_result(value: Result(a, b)) -> Option(a) {
  case value {
    Ok(item) -> Some(item)
    Error(_) -> None
  }
}

fn find_service(
  services: List(model.Service),
  name: Option(String),
) -> Option(model.Service) {
  case name {
    Some(name) ->
      case
        list.find(services, fn(service) {
          naming.pascal(service.module) == name
        })
      {
        Ok(service) -> Some(service)
        Error(_) -> None
      }
    None -> None
  }
}

fn is_media_enum(name: String) -> Bool {
  string.contains(name, "Media") || string.contains(name, "Variant")
}

fn has_nested_constructor(expression: glance.Expression, name: String) -> Bool {
  let root = is_constructor_call(expression, name)
  root
  && list.any(expression_children(expression), fn(child) {
    contains_constructor(child, name)
  })
}

fn contains_constructor(expression: glance.Expression, name: String) -> Bool {
  is_constructor_call(expression, name)
  || list.any(expression_children(expression), fn(child) {
    contains_constructor(child, name)
  })
}

fn is_constructor_call(expression: glance.Expression, name: String) -> Bool {
  case expression {
    glance.Call(..) -> g.ctor_name(expression) == Some(name)
    _ -> False
  }
}

fn forbidden_calls(
  statements: List(glance.Statement),
  imports: List(glance.Definition(glance.Import)),
) -> List(String) {
  statements
  |> list.flat_map(fn(statement) { forbidden_in_statement(statement, imports) })
  |> list.unique
}

fn forbidden_in_statement(
  statement: glance.Statement,
  imports: List(glance.Definition(glance.Import)),
) -> List(String) {
  statement_expressions(statement)
  |> list.flat_map(fn(expression) {
    forbidden_in_expression(expression, imports)
  })
}

fn forbidden_in_expression(
  expression: glance.Expression,
  imports: List(glance.Definition(glance.Import)),
) -> List(String) {
  let own = case expression {
    glance.Call(function: function, ..) ->
      case forbidden_target(function, imports) {
        Some(target) -> [target]
        None -> []
      }
    _ -> []
  }
  list.append(
    own,
    expression_children(expression)
      |> list.flat_map(fn(child) { forbidden_in_expression(child, imports) }),
  )
}

fn forbidden_target(
  expression: glance.Expression,
  imports: List(glance.Definition(glance.Import)),
) -> Option(String) {
  case expression {
    glance.FieldAccess(
      container: glance.Variable(name: alias, ..),
      label: label,
      ..,
    ) ->
      case imported_module(imports, alias) {
        Some("lustre/attribute") if label == "class" || label == "style" ->
          Some("attribute." <> label)
        Some("lustre/element") if label == "element" -> Some("element.element")
        _ -> None
      }
    glance.Variable(name: name, ..) ->
      case unqualified_module(imports, name) {
        Some("lustre/attribute") if name == "class" || name == "style" ->
          Some("attribute." <> name)
        Some("lustre/element") if name == "element" -> Some("element.element")
        _ -> None
      }
    _ -> None
  }
}

fn imported_module(
  imports: List(glance.Definition(glance.Import)),
  alias: String,
) -> Option(String) {
  case
    list.find_map(imports, fn(definition) {
      let import_ = definition.definition
      let local = case import_.alias {
        Some(glance.Named(name)) -> name
        Some(glance.Discarded(name)) -> name
        None -> last_segment(import_.module)
      }
      case local == alias {
        True -> Ok(import_.module)
        False -> Error(Nil)
      }
    })
  {
    Ok(module) -> Some(module)
    Error(_) -> None
  }
}

fn unqualified_module(
  imports: List(glance.Definition(glance.Import)),
  name: String,
) -> Option(String) {
  case
    list.find_map(imports, fn(definition) {
      let import_ = definition.definition
      case
        list.any(import_.unqualified_values, fn(value) {
          case value.alias {
            Some(alias) -> alias == name
            None -> value.name == name
          }
        })
      {
        True -> Ok(import_.module)
        False -> Error(Nil)
      }
    })
  {
    Ok(module) -> Some(module)
    Error(_) -> None
  }
}

fn nested_island(statements: List(glance.Statement)) -> Bool {
  list.any(statements, fn(statement) {
    list.any(statement_expressions(statement), fn(expression) {
      island_inside(expression, False)
    })
  })
}

fn island_inside(expression: glance.Expression, inside: Bool) -> Bool {
  let here = g.ctor_name(expression) == Some("island")
  let nested = here && inside
  nested
  || list.any(expression_children(expression), fn(child) {
    island_inside(child, inside || here)
  })
}

fn statement_expressions(
  statement: glance.Statement,
) -> List(glance.Expression) {
  case statement {
    glance.Use(function: function, ..) -> [function]
    glance.Assignment(value: value, ..) -> [value]
    glance.Assert(expression: expression, message: message, ..) -> [
      expression,
      ..option_to_list(message)
    ]
    glance.Expression(expression) -> [expression]
  }
}

fn expression_children(
  expression: glance.Expression,
) -> List(glance.Expression) {
  case expression {
    glance.Int(..)
    | glance.Float(..)
    | glance.String(..)
    | glance.Variable(..) -> []
    glance.NegateInt(value: value, ..) | glance.NegateBool(value: value, ..) -> [
      value,
    ]
    glance.Block(statements: statements, ..) ->
      list.flat_map(statements, statement_expressions)
    glance.Panic(message: message, ..) | glance.Todo(message: message, ..) ->
      option_to_list(message)
    glance.Tuple(elements: elements, ..) -> elements
    glance.List(elements: elements, rest: rest, ..) ->
      list.append(elements, option_to_list(rest))
    glance.Fn(body: body, ..) -> list.flat_map(body, statement_expressions)
    glance.RecordUpdate(record: record, fields: fields, ..) -> [
      record,
      ..list.flat_map(fields, record_field_expressions)
    ]
    glance.FieldAccess(container: container, ..) -> [container]
    glance.Call(function: function, arguments: arguments, ..) -> [
      function,
      ..list.flat_map(arguments, field_expressions)
    ]
    glance.TupleIndex(tuple: tuple, ..) -> [tuple]
    glance.FnCapture(
      function: function,
      arguments_before: before,
      arguments_after: after,
      ..,
    ) -> [
      function,
      ..list.append(
        list.flat_map(before, field_expressions),
        list.flat_map(after, field_expressions),
      )
    ]
    glance.BitString(segments: segments, ..) ->
      list.flat_map(segments, bit_segment_expressions)
    glance.Case(subjects: subjects, clauses: clauses, ..) ->
      list.append(subjects, list.flat_map(clauses, clause_expressions))
    glance.BinaryOperator(left: left, right: right, ..) -> [left, right]
    glance.Echo(expression: expression, message: message, ..) ->
      list.append(option_to_list(expression), option_to_list(message))
  }
}

fn field_expressions(
  field: glance.Field(glance.Expression),
) -> List(glance.Expression) {
  case field {
    glance.LabelledField(item: item, ..) -> [item]
    glance.UnlabelledField(item: item) -> [item]
    glance.ShorthandField(..) -> []
  }
}

fn record_field_expressions(
  field: glance.RecordUpdateField(glance.Expression),
) -> List(glance.Expression) {
  case field {
    glance.RecordUpdateField(item: item, ..) -> option_to_list(item)
  }
}

fn bit_segment_expressions(
  segment: #(
    glance.Expression,
    List(glance.BitStringSegmentOption(glance.Expression)),
  ),
) -> List(glance.Expression) {
  let #(expression, options) = segment
  [expression, ..list.flat_map(options, bit_option_expressions)]
}

fn bit_option_expressions(
  option: glance.BitStringSegmentOption(glance.Expression),
) -> List(glance.Expression) {
  case option {
    glance.SizeValueOption(value) -> [value]
    _ -> []
  }
}

fn clause_expressions(clause: glance.Clause) -> List(glance.Expression) {
  let glance.Clause(guard: guard, body: body, ..) = clause
  [body, ..option_to_list(guard)]
}
