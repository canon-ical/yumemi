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
    services: List(String),
    http_entries: List(HttpEntry),
    page_service_args: List(PageServiceArgs),
    violations: List(Violation),
    overlay_calls: List(OverlayCall),
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
    vars: List(Var),
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
    vars: List(Var),
    sp: Option(Frame),
    pc: Option(Frame),
    tablet: Option(Frame),
  )
}

pub type Var {
  Var(name: String, from: From)
}

pub type From {
  Path(String)
  Query(String)
  Session(String)
  Origin(String)
  AuthOrigin
  InvalidFrom(String)
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
  Auto
  Fr(Int)
  Rem(Float)
  Px(Float)
  Minmax(min: TrackSize, max: TrackSize)
}

pub type TrackSize {
  AutoSize
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
  Widget(area: String, service: String, render: Render)
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
    input_definition: Option(glance.CustomType),
    input_imports: List(glance.Definition(glance.Import)),
    input_kind: BlockInput,
    args: List(BlockArg),
    view_arity: Int,
    view_arg_type: Option(String),
    arg_type_valid: Bool,
    source: glance.Module,
    has_view: Bool,
    has_sample: Bool,
  )
}

pub type BlockInput {
  ServiceOut(String)
  NilInput
  OtherInput(String)
}

pub type BlockArg {
  BlockArg(name: String, type_: BlockArgType)
}

pub type BlockArgType {
  StringArg
  OptionalStringArg
  OtherArg(String)
}

pub type HttpEntry {
  HttpEntry(name: String, authenticated: Bool)
}

pub type PageServiceArgs {
  PageServiceArgs(page: String, services: List(ServiceArgs))
}

pub type ServiceArgs {
  ServiceArgs(service: String, args: List(ResolvedArg))
}

pub type ResolvedArg {
  ResolvedArg(name: String, source: ResolvedArgSource)
}

pub type ResolvedArgSource {
  VariableSource(name: String, from: From)
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

pub type OverlayCall {
  OverlayCall(module: String, function: String, literal: Option(String))
}

/// 面の source units を model にする。Service の variant と Args は back reader の
/// model を受け取るが、back の読み方そのものは呼ばない。
pub fn read(
  face: String,
  units: List(Unit),
  services: List(model.Service),
) -> Result(Front, Error) {
  read_with_package_and_warning(face, face, units, services, [])
}

pub fn read_with_package(
  face: String,
  package_name: String,
  units: List(Unit),
  services: List(model.Service),
) -> Result(Front, Error) {
  read_with_package_and_warning(face, package_name, units, services, [])
}

pub fn read_with_package_and_entries(
  face: String,
  package_name: String,
  units: List(Unit),
  services: List(model.Service),
  entries: List(model.Entry),
) -> Result(Front, Error) {
  read_with_package_and_warning(face, package_name, units, services, entries)
}

fn read_with_package_and_warning(
  face: String,
  package_name: String,
  units: List(Unit),
  services: List(model.Service),
  entries: List(model.Entry),
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
    |> list.filter_map(fn(unit) { parse_block(unit, services) })
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
  let services_used = service_references(layout, pages, blocks, components)
  let page_service_args =
    list.map(pages, fn(page) {
      PageServiceArgs(
        page: page.module,
        services: resolve_page_service_args(layout, page, blocks, services),
      )
    })
  let violations =
    list.flatten(
      list.map(units, fn(unit) { unit_violations(unit, components) }),
    )
  let overlay_calls = overlay_calls(units)
  Ok(Front(
    face: face,
    package_name: package_name,
    layout: layout,
    shell: shell,
    pages: pages,
    blocks: blocks,
    components: components,
    style: style,
    services: services_used,
    http_entries: http_entries(units, entries),
    page_service_args: page_service_args,
    violations: violations,
    overlay_calls: overlay_calls,
  ))
}

/// model に対する停止診断。検査はここに集め、emit は呼ばない。
pub fn notes(front: Front, services: List(model.Service)) -> List(stop.Note) {
  list.flatten([
    shell_notes(front),
    violation_notes(front.face, front.violations),
    overlay_template_notes(front),
    overlay_call_notes(front),
    frame_notes(
      front.face,
      "layout",
      front.layout.sp,
      front.layout.pc,
      front.layout.tablet,
    ),
    list.flatten(
      list.map(front.pages, fn(page) {
        frame_notes(front.face, page.module, page.sp, page.pc, page.tablet)
      }),
    ),
    variable_notes(front, services),
    block_input_notes(front, services),
    block_argument_notes(front, services),
    service_argument_notes(front, services),
    of_placement_notes(front, services),
    layout_nested_notes(front.face, front.layout),
    unknown_service_notes(front.face, front.services, services),
  ])
}

fn overlay_calls(units: List(Unit)) -> List(OverlayCall) {
  units
  |> list.filter_map(fn(unit) {
    case string.starts_with(unit.path, "blocks/") {
      False -> Error(Nil)
      True -> {
        let module = g.in_order(unit.module)
        case public_function(module, "view") {
          Some(view) ->
            Ok(overlay_calls_in_statements(unit.path, view.body, module.imports))
          None -> Error(Nil)
        }
      }
    }
  })
  |> list.flatten
}

fn overlay_calls_in_statements(
  module: String,
  statements: List(glance.Statement),
  imports: List(glance.Definition(glance.Import)),
) -> List(OverlayCall) {
  statements
  |> list.flat_map(fn(statement) {
    statement_expressions(statement)
    |> list.flat_map(fn(expression) {
      overlay_calls_in_expression(module, expression, imports)
    })
  })
}

fn overlay_calls_in_expression(
  module: String,
  expression: glance.Expression,
  imports: List(glance.Definition(glance.Import)),
) -> List(OverlayCall) {
  let own = case expression {
    glance.Call(function: function, ..) ->
      case front_el_function(function, imports) {
        Some(name) ->
          case name {
            "opener" | "closer" | "each_modal" -> [
              OverlayCall(
                module: module,
                function: name,
                literal: first_argument_literal(expression),
              ),
            ]
            _ -> []
          }
        None -> []
      }
    _ -> []
  }
  list.append(
    own,
    expression_children(expression)
      |> list.flat_map(fn(child) {
        overlay_calls_in_expression(module, child, imports)
      }),
  )
}

fn front_el_function(
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
        Some("framework/front/el") -> Some(label)
        _ -> None
      }
    glance.Variable(name: name, ..) ->
      case unqualified_module(imports, name) {
        Some("framework/front/el") -> Some(name)
        _ -> None
      }
    _ -> None
  }
}

fn first_argument_literal(expression: glance.Expression) -> Option(String) {
  case g.args(expression) {
    [first, ..] -> g.string_value(first)
    [] -> None
  }
}

fn overlay_template_notes(front: Front) -> List(stop.Note) {
  let layout_frames =
    frames(front.layout.sp, front.layout.pc, front.layout.tablet)
  let layout_notes =
    overlay_template_notes_for_frames(front.face, "layout", layout_frames)
  let page_notes =
    front.pages
    |> list.flat_map(fn(page) {
      overlay_template_notes_for_frames(
        front.face,
        page.module,
        frames(page.sp, page.pc, page.tablet),
      )
    })
  list.append(layout_notes, page_notes)
}

fn overlay_template_notes_for_frames(
  face: String,
  module: String,
  frames: List(Frame),
) -> List(stop.Note) {
  frames
  |> list.flat_map(fn(frame) {
    let template_areas = list.flatten(frame.template)
    frame.areas
    |> list.filter(fn(area) {
      area.pin == "Overlay" && list.contains(template_areas, area.name)
    })
    |> list.map(fn(area) {
      stop.Note(
        class: stop.Conflict,
        text: face
          <> "/"
          <> module
          <> "/"
          <> frame.media
          <> ": 明示 template に Overlay area \""
          <> area.name
          <> "\" を指定できない",
      )
    })
  })
}

fn overlay_call_notes(front: Front) -> List(stop.Note) {
  front.pages
  |> list.flat_map(fn(page) {
    let layout_frames =
      frames(front.layout.sp, front.layout.pc, front.layout.tablet)
    let page_frames = frames(page.sp, page.pc, page.tablet)
    let areas =
      list.append(
        list.flatten(list.map(layout_frames, fn(frame) { frame.areas })),
        list.flatten(list.map(page_frames, fn(frame) { frame.areas })),
      )
    let modules =
      list.append(
        frame_block_modules(front, front.layout.sp),
        frame_block_modules(front, page.sp),
      )
    let calls =
      modules
      |> list.flat_map(fn(module) {
        front.overlay_calls
        |> list.filter(fn(call) { call.module == module })
      })
    list.append(
      overlay_area_call_notes(front.face, areas, calls),
      overlay_scope_notes(front.face, page.module, calls),
    )
  })
}

fn overlay_area_call_notes(
  face: String,
  areas: List(Area),
  calls: List(OverlayCall),
) -> List(stop.Note) {
  calls
  |> list.filter_map(fn(call) {
    case call.function {
      "opener" | "closer" ->
        case call.literal {
          None ->
            Ok(stop.Note(
              class: stop.Conflict,
              text: face
                <> "/"
                <> call.module
                <> ": el."
                <> call.function
                <> " の area は文字列リテラルでなければならない",
            ))
          Some(name) -> {
            let found = list.filter(areas, fn(area) { area.name == name })
            case found {
              [] ->
                Ok(stop.Note(
                  class: stop.Conflict,
                  text: face
                    <> "/"
                    <> call.module
                    <> ": el."
                    <> call.function
                    <> " が同じ Page / Layout に無い area \""
                    <> name
                    <> "\" を名指している",
                ))
              _ ->
                case list.any(found, fn(area) { area.pin != "Overlay" }) {
                  True ->
                    Ok(stop.Note(
                      class: stop.Conflict,
                      text: face
                        <> "/"
                        <> call.module
                        <> ": el."
                        <> call.function
                        <> " の area \""
                        <> name
                        <> "\" は pin: Overlay ではない",
                    ))
                  False -> Error(Nil)
                }
            }
          }
        }
      _ -> Error(Nil)
    }
  })
}

fn overlay_scope_notes(
  face: String,
  page_module: String,
  calls: List(OverlayCall),
) -> List(stop.Note) {
  let modal_calls =
    list.filter(calls, fn(call) { call.function == "each_modal" })
  let dynamic_notes =
    modal_calls
    |> list.filter_map(fn(call) {
      case call.literal {
        None ->
          Ok(stop.Note(
            class: stop.Conflict,
            text: face
              <> "/"
              <> call.module
              <> ": el.each_modal の scope は文字列リテラルでなければならない",
          ))
        Some(_) -> Error(Nil)
      }
    })
  let duplicate_notes =
    modal_calls
    |> list.filter_map(fn(call) {
      case call.literal {
        Some(scope) -> Ok(scope)
        None -> Error(Nil)
      }
    })
    |> list.unique
    |> list.filter(fn(scope) {
      list.count(modal_calls, fn(call) { call.literal == Some(scope) }) > 1
    })
    |> list.map(fn(scope) {
      stop.Note(
        class: stop.Conflict,
        text: face
          <> "/"
          <> page_module
          <> ": el.each_modal の scope \""
          <> scope
          <> "\" が同じ Page + Layout 内で重複している",
      )
    })
  list.append(dynamic_notes, duplicate_notes)
}

fn frame_block_modules(front: Front, frame: Option(Frame)) -> List(String) {
  case frame {
    None -> []
    Some(frame) ->
      frame.placements
      |> list.flat_map(placement_block_names)
      |> list.filter_map(fn(name) {
        case list.find(front.blocks, fn(block) { block.name == name }) {
          Ok(block) -> Ok(block.module)
          Error(_) -> Error(Nil)
        }
      })
  }
}

fn placement_block_names(placement: Placement) -> List(String) {
  case placement {
    Fixed(block: block, ..) -> [block]
    Widget(render: One(block), ..) -> [block]
    Widget(render: ByKind(table: table, ..), ..) ->
      list.map(table, fn(row) { row.1 })
    Widget(render: UnknownRender, ..) -> []
  }
}

fn frames(
  sp: Option(Frame),
  pc: Option(Frame),
  tablet: Option(Frame),
) -> List(Frame) {
  list.append(
    option_to_list(sp),
    list.append(option_to_list(pc), option_to_list(tablet)),
  )
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
    vars: vars_field(value),
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
            vars: vars_field(constant.value),
            sp: frame_field(constant.value, "sp", "sp", unit.path),
            pc: frame_field(constant.value, "pc", "pc", unit.path),
            tablet: frame_field(constant.value, "tablet", "tablet", unit.path),
          ))
        _, _ -> Error(Nil)
      }
    None -> Error(Nil)
  }
}

fn vars_field(expression: glance.Expression) -> List(Var) {
  case g.labelled(expression, "vars") {
    None -> []
    Some(glance.List(elements: elements, ..)) ->
      elements
      |> list.index_map(parse_var)
    Some(_) -> [Var(name: "vars", from: InvalidFrom("vars はリテラルの列ではない"))]
  }
}

fn parse_var(expression: glance.Expression, index: Int) -> Var {
  let fallback = "vars[" <> int.to_string(index) <> "]"
  case g.ctor_name(expression) {
    Some("Var") -> {
      let name = g.labelled(expression, "name") |> option.then(g.string_value)
      let from = g.labelled(expression, "from")
      Var(name: option.unwrap(name, fallback), from: case name, from {
        Some(_), Some(value) -> parse_from(value)
        None, _ -> InvalidFrom("Var の name は文字列リテラルではない")
        _, None -> InvalidFrom("Var の from が無い")
      })
    }
    _ -> Var(name: fallback, from: InvalidFrom("Var の構成子がリテラルではない"))
  }
}

fn parse_from(expression: glance.Expression) -> From {
  case g.ctor_name(expression) {
    Some("Path") -> from_result(string_argument(expression), "Path")
    Some("Query") -> from_result(string_argument(expression), "Query")
    Some("Session") ->
      case g.args(expression) {
        [key] ->
          case g.ctor_name(key) {
            Some("SubjectHandle") -> Session("SubjectHandle")
            Some("SubjectId") -> Session("SubjectId")
            _ -> InvalidFrom("Session のキーが SubjectHandle / SubjectId のリテラルでない")
          }
        _ -> InvalidFrom("Session のキーが無い")
      }
    Some("Origin") ->
      case g.labelled(expression, "face") |> option.then(g.string_value) {
        Some(face) -> Origin(face)
        None -> InvalidFrom("Origin の face は文字列リテラルではない")
      }
    Some("AuthOrigin") ->
      case expression {
        glance.Call(..) -> InvalidFrom("AuthOrigin は値を持たない構成子リテラルでなければならない")
        _ -> AuthOrigin
      }
    _ ->
      InvalidFrom(
        "from は Path / Query / Session / Origin / AuthOrigin のリテラルではない",
      )
  }
}

fn string_argument(expression: glance.Expression) -> Option(String) {
  case g.args(expression) {
    [value] -> g.string_value(value)
    _ -> None
  }
}

fn from_result(value: Option(String), tag: String) -> From {
  case value {
    Some(text) ->
      case tag {
        "Path" -> Path(text)
        _ -> Query(text)
      }
    None -> InvalidFrom(tag <> " の値は文字列リテラルではない")
  }
}

fn block_args(module: glance.Module) -> List(BlockArg) {
  case g.find_custom_type(module, "Arg") {
    Some(definition) ->
      case definition.variants {
        [variant] if variant.name == "Arg" ->
          variant.fields
          |> list.index_map(fn(field, index) {
            let name =
              g.variant_field_label(field)
              |> option.unwrap("arg[" <> int.to_string(index) <> "]")
            BlockArg(
              name: name,
              type_: block_arg_type(g.variant_field_type(field)),
            )
          })
        _ -> []
      }
    None -> []
  }
}

fn block_arg_type(type_: glance.Type) -> BlockArgType {
  case type_ {
    glance.NamedType(name: "String", parameters: [], ..) -> StringArg
    glance.NamedType(name: "Option", parameters: [inner], ..) ->
      case inner {
        glance.NamedType(name: "String", parameters: [], ..) ->
          OptionalStringArg
        _ -> OtherArg(type_text(type_))
      }
    _ -> OtherArg(type_text(type_))
  }
}

fn type_text(type_: glance.Type) -> String {
  case type_ {
    glance.NamedType(name: name, parameters: [], ..) -> name
    glance.NamedType(name: name, parameters: parameters, ..) ->
      name <> "(" <> string.join(list.map(parameters, type_text), ", ") <> ")"
    _ -> "型"
  }
}

fn block_input_kind(
  input: Option(String),
  input_module: Option(String),
  services: List(model.Service),
) -> BlockInput {
  case input, input_module {
    Some("Nil"), _ -> NilInput
    Some(name), Some(module) ->
      case
        list.find(services, fn(service) {
          let module_matches =
            module == "gen/out/" <> service.module
            || module == service.module
            || module == "service/" <> service.module
            || Some(module)
            == option.map(service.out_type, fn(out) {
              option.unwrap(out.module, "")
            })
          let type_matches =
            name == "Out"
            || case service.out_type {
              Some(out) -> name == out.name
              None -> False
            }
          module_matches && type_matches
        })
      {
        Ok(service) -> ServiceOut(service.module)
        Error(_) -> OtherInput(name)
      }
    Some(name), None -> OtherInput(name)
    None, _ -> OtherInput("view input")
  }
}

fn parse_block(
  unit: Unit,
  services: List(model.Service),
) -> Result(Block, Nil) {
  let module = g.in_order(unit.module)
  let name = last_segment(unit.path) |> naming.pascal
  let view = public_function(module, "view")
  let parameters = case view {
    Some(function) -> function.parameters
    None -> []
  }
  let #(input, input_module) =
    view
    |> option.then(fn(function) { first_parameter_input(module, function) })
    |> option.unwrap(#(None, None))
  let input_definition = input |> option.then(g.find_custom_type(module, _))
  let view_arity = list.length(parameters)
  let view_arg_type = case parameters {
    [_, parameter, ..] -> parameter.type_ |> option.then(g.type_name)
    _ -> None
  }
  let local_arg_parameter = case parameters {
    [_, parameter, ..] ->
      case parameter.type_ {
        Some(glance.NamedType(name: "Arg", module: None, parameters: [], ..)) ->
          True
        _ -> False
      }
    _ -> False
  }
  let public_arg_type = case g.find_custom_type(module, "Arg") {
    Some(definition) if definition.publicity == glance.Public ->
      case definition.variants {
        [variant] ->
          variant.name == "Arg"
          && list.all(variant.fields, fn(field) {
            g.variant_field_label(field) != None
          })
        _ -> False
      }
    _ -> False
  }
  let arg_type_valid = local_arg_parameter && public_arg_type
  Ok(Block(
    name: name,
    module: unit.path,
    input: input,
    input_module: input_module,
    input_definition: input_definition,
    input_imports: module.imports,
    input_kind: block_input_kind(input, input_module, services),
    args: case arg_type_valid {
      True -> block_args(module)
      False -> []
    },
    view_arity: view_arity,
    view_arg_type: view_arg_type,
    arg_type_valid: arg_type_valid,
    source: module,
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
    Some("Auto") -> Ok(Auto)
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
    Some("AutoSize") -> Ok(AutoSize)
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

fn service_references(
  layout: Layout,
  pages: List(Page),
  blocks: List(Block),
  components: List(Component),
) -> List(String) {
  let from_layout = placement_service_references(layout_frames(layout), blocks)
  let from_pages =
    pages
    |> list.flat_map(fn(page) {
      placement_service_references(page_frames(page), blocks)
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

fn placement_service_references(
  frames: List(Frame),
  blocks: List(Block),
) -> List(String) {
  frames
  |> list.flat_map(fn(frame) {
    frame.placements
    |> list.flat_map(fn(placement) {
      case placement {
        Widget(service: service, ..) -> [service]
        Fixed(block: name, ..) ->
          case list.find(blocks, fn(block) { block.name == name }) {
            Ok(Block(input_kind: ServiceOut(service), ..)) -> [
              naming.pascal(service),
            ]
            _ -> []
          }
      }
    })
  })
}

fn resolve_page_service_args(
  layout: Layout,
  page: Page,
  blocks: List(Block),
  services: List(model.Service),
) -> List(ServiceArgs) {
  let layout_args =
    list.flat_map(layout_frames(layout), fn(frame) {
      list.flat_map(frame.placements, fn(placement) {
        placement_service_args(placement, blocks, services, layout.vars)
      })
    })
  let page_scope = list.append(page.vars, layout.vars)
  let root_args = case find_service(services, page.of) {
    Some(service) -> [
      ServiceArgs(
        service: service.module,
        args: service.args
          |> list.filter_map(fn(arg) {
            case list.find(page_scope, fn(var) { var.name == arg.name }) {
              Ok(var) ->
                Ok(ResolvedArg(
                  name: arg.name,
                  source: VariableSource(name: var.name, from: var.from),
                ))
              Error(_) -> Error(Nil)
            }
          }),
      ),
    ]
    None -> []
  }
  let page_args =
    list.flat_map(page_frames(page), fn(frame) {
      list.flat_map(frame.placements, fn(placement) {
        placement_service_args(placement, blocks, services, page_scope)
      })
    })
  list.fold(list.append(page_args, root_args), layout_args, merge_service_args)
}

fn placement_service_args(
  placement: Placement,
  blocks: List(Block),
  services: List(model.Service),
  vars: List(Var),
) -> List(ServiceArgs) {
  case placement {
    Fixed(block: block_name, ..) ->
      case list.find(blocks, fn(block) { block.name == block_name }) {
        Ok(Block(input_kind: ServiceOut(service_name), args: block_args, ..)) ->
          case
            list.find(services, fn(service) { service.module == service_name })
          {
            Ok(service) -> [
              ServiceArgs(
                service: service.module,
                args: service.args
                  |> list.filter_map(fn(arg) {
                    case
                      list.find(block_args, fn(field) { field.name == arg.name })
                    {
                      Ok(_) ->
                        case list.find(vars, fn(var) { var.name == arg.name }) {
                          Ok(var) ->
                            Ok(ResolvedArg(
                              name: arg.name,
                              source: VariableSource(
                                name: var.name,
                                from: var.from,
                              ),
                            ))
                          Error(_) -> Error(Nil)
                        }
                      Error(_) -> Error(Nil)
                    }
                  }),
              ),
            ]
            Error(_) -> []
          }
        _ -> []
      }
    Widget(service: service_name, ..) ->
      case find_service(services, Some(service_name)) {
        Some(service) -> [
          ServiceArgs(
            service: service.module,
            args: service.args
              |> list.filter_map(fn(arg) {
                case list.find(vars, fn(var) { var.name == arg.name }) {
                  Ok(var) ->
                    Ok(ResolvedArg(
                      name: arg.name,
                      source: VariableSource(name: var.name, from: var.from),
                    ))
                  Error(_) -> Error(Nil)
                }
              }),
          ),
        ]
        None -> []
      }
  }
}

fn merge_service_args(
  existing: List(ServiceArgs),
  addition: ServiceArgs,
) -> List(ServiceArgs) {
  case list.find(existing, fn(item) { item.service == addition.service }) {
    Error(_) -> list.append(existing, [addition])
    Ok(found) -> {
      let merged =
        list.fold(addition.args, found.args, fn(args, arg) {
          case list.any(args, fn(item) { item.name == arg.name }) {
            True -> args
            False -> list.append(args, [arg])
          }
        })
      list.map(existing, fn(item) {
        case item.service == addition.service {
          True -> ServiceArgs(..item, args: merged)
          False -> item
        }
      })
    }
  }
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

fn variable_notes(
  front: Front,
  services: List(model.Service),
) -> List(stop.Note) {
  let layout_scope = front.layout.vars
  let layout_shape_notes =
    list.append(
      invalid_var_notes(front.face, "layout", layout_scope),
      placement_var_location_notes(front.face, "layout", layout_scope, True),
    )
  let layout_duplicate_notes =
    duplicate_var_notes(front.face, "layout", layout_scope, [])
  let layout_origin_notes = origin_notes(front, "layout", layout_scope)
  let page_notes =
    front.pages
    |> list.flat_map(fn(page) {
      let scope = list.append(page.vars, layout_scope)
      list.flatten([
        invalid_var_notes(front.face, page.module, page.vars),
        placement_var_location_notes(front.face, page.module, page.vars, False),
        duplicate_var_notes(front.face, page.module, page.vars, layout_scope),
        path_notes(front.face, page),
        origin_notes(front, page.module, page.vars),
        unused_var_notes(
          front,
          page.module,
          page.vars,
          page_frames(page),
          front.blocks,
          services,
          scope,
        ),
      ])
    })
  let layout_unused = unused_layout_var_notes(front, layout_scope, services)
  list.flatten([
    layout_shape_notes,
    layout_duplicate_notes,
    layout_origin_notes,
    layout_unused,
    page_notes,
  ])
}

fn invalid_var_notes(
  face: String,
  context: String,
  vars: List(Var),
) -> List(stop.Note) {
  vars
  |> list.filter_map(fn(var) {
    case var.from {
      InvalidFrom(reason) ->
        Ok(variable_note(
          face,
          context,
          2,
          reason <> " (" <> var.name <> ")",
          stop.Conflict,
        ))
      _ -> Error(Nil)
    }
  })
}

fn placement_var_location_notes(
  face: String,
  context: String,
  vars: List(Var),
  layout: Bool,
) -> List(stop.Note) {
  vars
  |> list.filter_map(fn(var) {
    let invalid = case layout, var.from {
      True, Path(_) -> Some("Layout に Path を置けない")
      True, Query(_) -> Some("Layout に Query を置けない")
      True, Session(_) -> Some("Layout に Session を置けない")
      False, Origin(_) -> Some("Page に Origin を置けない")
      False, AuthOrigin -> Some("Page に AuthOrigin を置けない")
      _, _ -> None
    }
    case invalid {
      Some(reason) ->
        Ok(variable_note(
          face,
          context,
          5,
          var.name <> ": " <> reason,
          stop.Conflict,
        ))
      None -> Error(Nil)
    }
  })
}

fn duplicate_var_notes(
  face: String,
  context: String,
  vars: List(Var),
  inherited: List(Var),
) -> List(stop.Note) {
  let repeated = duplicate_names(list.map(vars, fn(var) { var.name }))
  let local_notes =
    repeated
    |> list.map(fn(name) {
      variable_note(
        face,
        context,
        5,
        "Var." <> name <> " が重複している",
        stop.Conflict,
      )
    })
  let shadowed =
    vars
    |> list.filter_map(fn(var) {
      case list.any(inherited, fn(parent) { parent.name == var.name }) {
        True ->
          Ok(variable_note(
            face,
            context,
            5,
            "Var." <> var.name <> " が Layout の同名 Var を覆っている",
            stop.Conflict,
          ))
        False -> Error(Nil)
      }
    })
  list.append(local_notes, shadowed)
}

fn duplicate_names(names: List(String)) -> List(String) {
  case names {
    [] -> []
    [name, ..rest] -> {
      let duplicates = case list.contains(rest, name) {
        True -> [name]
        False -> []
      }
      list.append(
        duplicates,
        duplicate_names(list.filter(rest, fn(item) { item != name })),
      )
    }
  }
}

fn path_notes(face: String, page: Page) -> List(stop.Note) {
  let path_vars =
    page.vars
    |> list.filter_map(fn(var) {
      case var.from {
        Path(name) -> Ok(#(var, name))
        _ -> Error(Nil)
      }
    })
  let bad_sources =
    path_vars
    |> list.filter_map(fn(item) {
      let #(var, name) = item
      case
        list.any(page.path, fn(segment) {
          string.starts_with(segment, "arg_") && argument_name(segment) == name
        })
      {
        True -> Error(Nil)
        False ->
          Ok(variable_note(
            face,
            page.module,
            2,
            "Var." <> var.name <> " の Path(\"" <> name <> "\") に対応する arg_ 段が無い",
            stop.Conflict,
          ))
      }
    })
  let missing_vars =
    page.path
    |> list.filter_map(fn(segment) {
      case string.starts_with(segment, "arg_") {
        True -> {
          let name = argument_name(segment)
          case list.any(path_vars, fn(item) { item.1 == name }) {
            True -> Error(Nil)
            False ->
              Ok(variable_note(
                face,
                page.module,
                2,
                "arg_" <> name <> " 段を指す Path Var が無い",
                stop.Conflict,
              ))
          }
        }
        False -> Error(Nil)
      }
    })
  list.append(bad_sources, missing_vars)
}

fn origin_notes(
  front: Front,
  context: String,
  vars: List(Var),
) -> List(stop.Note) {
  vars
  |> list.filter_map(fn(var) {
    let face = case var.from {
      Origin(name) -> Some(name)
      _ -> None
    }
    case face {
      Some(name) ->
        case list.any(front.http_entries, fn(entry) { entry.name == name }) {
          True -> Error(Nil)
          False ->
            Ok(variable_note(
              front.face,
              context,
              2,
              "Var."
                <> var.name
                <> " の Origin(\""
                <> name
                <> "\") が entry.gleam の Http(name:) に無い",
              stop.Conflict,
            ))
        }
      None -> Error(Nil)
    }
  })
}

fn block_input_notes(
  front: Front,
  _services: List(model.Service),
) -> List(stop.Note) {
  let layout =
    fixed_input_notes(
      front.face,
      "layout",
      layout_frames(front.layout),
      front.blocks,
    )
  let pages =
    front.pages
    |> list.flat_map(fn(page) {
      fixed_input_notes(
        front.face,
        page.module,
        page_frames(page),
        front.blocks,
      )
    })
  list.append(layout, pages)
}

fn fixed_input_notes(
  face: String,
  context: String,
  frames: List(Frame),
  blocks: List(Block),
) -> List(stop.Note) {
  frames
  |> list.flat_map(fn(frame) {
    frame.placements
    |> list.filter_map(fn(placement) {
      case placement {
        Fixed(block: name, ..) ->
          case list.find(blocks, fn(block) { block.name == name }) {
            Ok(Block(input_kind: OtherInput(type_name), ..)) ->
              Ok(variable_note(
                face,
                context,
                6,
                "Block "
                  <> name
                  <> " In "
                  <> type_name
                  <> " は Service.Out / Nil ではない",
                stop.Conflict,
              ))
            _ -> Error(Nil)
          }
        Widget(..) -> Error(Nil)
      }
    })
  })
}

fn block_argument_notes(
  front: Front,
  services: List(model.Service),
) -> List(stop.Note) {
  let layout =
    context_block_notes(
      front,
      "layout",
      layout_frames(front.layout),
      front.layout.vars,
      services,
    )
  let pages =
    front.pages
    |> list.flat_map(fn(page) {
      context_block_notes(
        front,
        page.module,
        page_frames(page),
        list.append(page.vars, front.layout.vars),
        services,
      )
    })
  list.append(layout, pages)
}

fn context_block_notes(
  front: Front,
  context: String,
  frames: List(Frame),
  vars: List(Var),
  _services: List(model.Service),
) -> List(stop.Note) {
  frames
  |> list.flat_map(fn(frame) {
    frame.placements
    |> list.flat_map(fn(placement) {
      placement_block_names(placement)
      |> list.flat_map(fn(name) {
        case list.find(front.blocks, fn(block) { block.name == name }) {
          Ok(block) -> {
            let missing =
              block.args
              |> list.filter_map(fn(arg) {
                case var_by_name(vars, arg.name) {
                  Some(_) -> Error(Nil)
                  None ->
                    Ok(variable_note(
                      front.face,
                      context,
                      1,
                      "Block " <> name <> " Arg." <> arg.name <> " に同名 Var が無い",
                      stop.Conflict,
                    ))
                }
              })
            let invalid_shape = case block.view_arity {
              2 if !block.arg_type_valid -> [
                variable_note(
                  front.face,
                  context,
                  3,
                  "Block "
                    <> name
                    <> " の2引数 view に pub type Arg { Arg(...) } が無い",
                  stop.Conflict,
                ),
              ]
              arity if arity > 2 -> [
                variable_note(
                  front.face,
                  context,
                  3,
                  "Block " <> name <> " の view は1引数か2引数でなければならない",
                  stop.Conflict,
                ),
              ]
              _ -> []
            }
            let types =
              block.args
              |> list.flat_map(fn(arg) {
                let field_notes = case arg.type_ {
                  OtherArg(type_name) -> [
                    variable_note(
                      front.face,
                      context,
                      3,
                      "Block "
                        <> name
                        <> " Arg."
                        <> arg.name
                        <> " の型 "
                        <> type_name
                        <> " は String / Option(String) ではない",
                      stop.Conflict,
                    ),
                  ]
                  _ -> []
                }
                let source_notes = case var_by_name(vars, arg.name) {
                  Some(var) ->
                    block_var_type_notes(front, context, name, arg, var)
                  None -> []
                }
                list.append(field_notes, source_notes)
              })
            list.flatten([missing, invalid_shape, types])
          }
          Error(_) -> []
        }
      })
    })
  })
}

fn block_var_type_notes(
  front: Front,
  context: String,
  block: String,
  arg: BlockArg,
  var: Var,
) -> List(stop.Note) {
  let query_string = case var.from, arg.type_ {
    Query(_), StringArg -> True
    _, _ -> False
  }
  let anonymous_session_string = case
    var.from,
    arg.type_,
    face_authenticated(front)
  {
    Session(_), StringArg, False -> True
    _, _, _ -> False
  }
  let query_notes = case query_string {
    True -> [
      variable_note(
        front.face,
        context,
        3,
        "Block "
          <> block
          <> " Arg."
          <> arg.name
          <> " は Query の Option(String) を String で受ける",
        stop.Conflict,
      ),
    ]
    False -> []
  }
  let session_notes = case anonymous_session_string {
    True -> [
      variable_note(
        front.face,
        context,
        3,
        "Block "
          <> block
          <> " Arg."
          <> arg.name
          <> " は Anonymous 面の Session(Option(String)) を String で受ける",
        stop.Conflict,
      ),
    ]
    False -> []
  }
  list.append(query_notes, session_notes)
}

fn service_argument_notes(
  front: Front,
  services: List(model.Service),
) -> List(stop.Note) {
  let layout =
    context_service_notes(
      front,
      "layout",
      layout_frames(front.layout),
      front.layout.vars,
      services,
    )
  let pages =
    front.pages
    |> list.flat_map(fn(page) {
      context_service_notes(
        front,
        page.module,
        page_frames(page),
        list.append(page.vars, front.layout.vars),
        services,
      )
    })
  list.append(layout, pages)
}

fn context_service_notes(
  front: Front,
  context: String,
  frames: List(Frame),
  vars: List(Var),
  services: List(model.Service),
) -> List(stop.Note) {
  frames
  |> list.flat_map(fn(frame) {
    frame.placements
    |> list.flat_map(fn(placement) {
      let #(service, block_args) = case placement {
        Fixed(block: name, ..) ->
          case list.find(front.blocks, fn(block) { block.name == name }) {
            Ok(Block(input_kind: ServiceOut(module), args: args, ..)) -> #(
              service_by_module(services, module),
              args,
            )
            _ -> #(None, [])
          }
        Widget(service: service_name, ..) -> #(
          find_service(services, Some(service_name)),
          [],
        )
      }
      case service {
        Some(service) ->
          service.args
          |> list.flat_map(fn(service_arg) {
            let block_arg =
              list.find(block_args, fn(arg) { arg.name == service_arg.name })
            let var = var_by_name(vars, service_arg.name)
            let has_binding = case placement {
              Fixed(..) ->
                case block_arg {
                  Ok(_) -> True
                  Error(_) -> False
                }
              Widget(..) ->
                case var {
                  Some(_) -> True
                  None -> False
                }
            }
            let missing = !has_binding
            let required = !service_arg_optional(service_arg)
            let missing_note = case missing && required {
              True -> [
                variable_note(
                  front.face,
                  context,
                  4,
                  "Block/Widget "
                    <> placement_name(placement)
                    <> " の Service."
                    <> service.module
                    <> " Args."
                    <> service_arg.name
                    <> " が Block Arg / Var に無い",
                  stop.Conflict,
                ),
              ]
              False -> []
            }
            let option_from_block = case block_arg {
              Ok(BlockArg(type_: OptionalStringArg, ..)) -> required
              _ -> False
            }
            let option_from_var = case placement, var {
              Widget(..), Some(value) ->
                var_is_optional(value, face_authenticated(front)) && required
              _, _ -> False
            }
            let option_notes = case option_from_block || option_from_var {
              True -> [
                variable_note(
                  front.face,
                  context,
                  3,
                  "Block/Widget "
                    <> placement_name(placement)
                    <> " の Args."
                    <> service_arg.name
                    <> " は Option(String) を必須 Service Args に流す",
                  stop.Conflict,
                ),
              ]
              False -> []
            }
            list.append(missing_note, option_notes)
          })
        None -> []
      }
    })
  })
}

fn of_placement_notes(
  front: Front,
  services: List(model.Service),
) -> List(stop.Note) {
  front.pages
  |> list.filter_map(fn(page) {
    case page.of {
      None -> Error(Nil)
      Some(name) ->
        case find_service(services, Some(name)) {
          Some(service) -> {
            let found =
              page_frames(page)
              |> list.any(fn(frame) {
                list.any(frame.placements, fn(placement) {
                  placement_uses_service(
                    placement,
                    service.module,
                    front.blocks,
                    services,
                  )
                })
              })
            case found {
              True -> Error(Nil)
              False ->
                Ok(variable_note(
                  front.face,
                  page.module,
                  7,
                  "Page.of Service." <> name <> " を描く Block が placements に無い",
                  stop.Conflict,
                ))
            }
          }
          None ->
            Ok(variable_note(
              front.face,
              page.module,
              7,
              "Page.of Service." <> name <> " を描く Block が placements に無い",
              stop.Conflict,
            ))
        }
    }
  })
}

fn placement_uses_service(
  placement: Placement,
  service: String,
  blocks: List(Block),
  services: List(model.Service),
) -> Bool {
  case placement {
    Fixed(block: name, ..) ->
      case list.find(blocks, fn(block) { block.name == name }) {
        Ok(Block(input_kind: ServiceOut(module), ..)) -> module == service
        _ -> False
      }
    Widget(service: service_name, ..) ->
      case find_service(services, Some(service_name)) {
        Some(found) -> found.module == service
        None -> False
      }
  }
}

fn service_by_module(
  services: List(model.Service),
  module: String,
) -> Option(model.Service) {
  services
  |> list.find(fn(service) { service.module == module })
  |> option_from_result
}

fn service_arg_optional(arg: model.Arg) -> Bool {
  case arg.type_ {
    model.NamedShape(name: "Option", ..) -> True
    _ -> False
  }
}

fn var_by_name(vars: List(Var), name: String) -> Option(Var) {
  vars |> list.find(fn(var) { var.name == name }) |> option_from_result
}

fn var_is_optional(var: Var, authenticated: Bool) -> Bool {
  case var.from {
    Query(_) -> True
    Session(_) if !authenticated -> True
    _ -> False
  }
}

fn face_authenticated(front: Front) -> Bool {
  list.any(front.http_entries, fn(entry) {
    entry.name == front.face && entry.authenticated
  })
}

fn variable_note(
  face: String,
  context: String,
  number: Int,
  detail: String,
  class: stop.Class,
) -> stop.Note {
  stop.Note(
    class: class,
    text: face
      <> "/"
      <> context
      <> ": [変数 "
      <> int.to_string(number)
      <> "] "
      <> detail,
  )
}

fn placement_name(placement: Placement) -> String {
  case placement {
    Fixed(block: name, ..) -> "Block " <> name
    Widget(..) -> "Widget"
  }
}

fn unused_var_notes(
  front: Front,
  context: String,
  vars: List(Var),
  frames: List(Frame),
  blocks: List(Block),
  services: List(model.Service),
  scope: List(Var),
) -> List(stop.Note) {
  let used =
    frames
    |> list.flat_map(fn(frame) {
      list.flat_map(frame.placements, fn(placement) {
        placement_used_var_names(placement, blocks, services, scope)
      })
    })
  vars
  |> list.filter_map(fn(var) {
    case list.contains(used, var.name) {
      True -> Error(Nil)
      False ->
        Ok(variable_note(
          front.face,
          context,
          0,
          "未使用の Var." <> var.name,
          stop.Warning,
        ))
    }
  })
}

fn unused_layout_var_notes(
  front: Front,
  vars: List(Var),
  services: List(model.Service),
) -> List(stop.Note) {
  let layout_used =
    layout_frames(front.layout)
    |> list.flat_map(fn(frame) {
      list.flat_map(frame.placements, fn(placement) {
        placement_used_var_names(placement, front.blocks, services, vars)
      })
    })
  let page_used =
    front.pages
    |> list.flat_map(fn(page) {
      let visible = list.append(page.vars, vars)
      let names =
        page_frames(page)
        |> list.flat_map(fn(frame) {
          list.flat_map(frame.placements, fn(placement) {
            placement_used_var_names(placement, front.blocks, services, visible)
          })
        })
      list.filter(names, fn(name) { var_by_name(page.vars, name) == None })
    })
  let used = list.append(layout_used, page_used)
  vars
  |> list.filter_map(fn(var) {
    case list.contains(used, var.name) {
      True -> Error(Nil)
      False ->
        Ok(variable_note(
          front.face,
          "layout",
          0,
          "未使用の Var." <> var.name,
          stop.Warning,
        ))
    }
  })
}

fn placement_used_var_names(
  placement: Placement,
  blocks: List(Block),
  services: List(model.Service),
  vars: List(Var),
) -> List(String) {
  case placement {
    Fixed(block: name, ..) ->
      case list.find(blocks, fn(block) { block.name == name }) {
        Ok(block) ->
          block.args
          |> list.filter_map(fn(arg) {
            case var_by_name(vars, arg.name) {
              Some(var) -> Ok(var.name)
              None -> Error(Nil)
            }
          })
        Error(_) -> []
      }
    Widget(service: service_name, render: render, ..) -> {
      let service_names = case find_service(services, Some(service_name)) {
        Some(service) ->
          service.args
          |> list.filter_map(fn(arg) {
            case var_by_name(vars, arg.name) {
              Some(var) -> Ok(var.name)
              None -> Error(Nil)
            }
          })
        None -> []
      }
      let block_names = case render {
        One(block) -> [block]
        ByKind(by: _, table: rows) -> list.map(rows, fn(row) { row.1 })
        UnknownRender -> []
      }
      let block_vars =
        block_names
        |> list.flat_map(fn(name) {
          case list.find(blocks, fn(block) { block.name == name }) {
            Ok(block) ->
              block.args
              |> list.filter_map(fn(arg) {
                case var_by_name(vars, arg.name) {
                  Some(var) -> Ok(var.name)
                  None -> Error(Nil)
                }
              })
            Error(_) -> []
          }
        })
      list.append(service_names, block_vars)
    }
  }
}

fn http_entries(
  units: List(Unit),
  entries: List(model.Entry),
) -> List(HttpEntry) {
  let from_model =
    entries
    |> list.map(fn(entry) {
      let authenticated = case entry.admit {
        model.AuthenticatedAdmit -> True
        model.AnonymousAdmit -> False
      }
      HttpEntry(name: entry.name, authenticated: authenticated)
    })
  case from_model {
    [] ->
      units
      |> list.filter_map(fn(unit) {
        case unit.path == "entry" {
          False -> Error(Nil)
          True -> {
            let module = g.in_order(unit.module)
            case public_named_constant(module, "entries") {
              Some(constant) ->
                case constant.value {
                  glance.List(elements: elements, ..) ->
                    Ok(
                      elements
                      |> list.filter_map(fn(expression) {
                        case
                          g.ctor_name(expression),
                          g.labelled(expression, "name")
                          |> option.then(g.string_value)
                        {
                          Some("Http"), Some(name) ->
                            Ok(HttpEntry(
                              name: name,
                              authenticated: g.labelled(expression, "admit")
                              |> option.then(g.ctor_name)
                                == Some("Authenticated"),
                            ))
                          _, _ -> Error(Nil)
                        }
                      }),
                    )
                  _ -> Error(Nil)
                }
              None -> Error(Nil)
            }
          }
        }
      })
      |> list.flatten
    _ -> from_model
  }
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
      Some(imported_module(module.imports, path) |> option.unwrap(path)),
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
          naming.pascal(service.module) == name || service.module == name
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
