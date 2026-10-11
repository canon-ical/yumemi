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
import yumemi/gen/glance_util as g
import yumemi/gen/model
import yumemi/gen/naming
import yumemi/gen/source.{type Unit}
import yumemi/gen/stop

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
    /// 記述面と Css の条文(第 1〜3・7・8・23〜25・31 条)の停止。
    surface_notes: List(stop.Note),
    /// `el.static_sheet` の path(第 28〜30 条の file の検査と規則の数えは emit が持つ)。
    static_sheets: List(#(String, String)),
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
    head: ShellHead,
  )
}

/// shell の任意の const(0.11.12)。在れば head(と client.mjs)に出す。無ければ 0.11.11 と同じ出力。
/// `invalid` は在るのに空でない String の定数でない const の名(`title` と同じく宣言の不足で止める)。
pub type ShellHead {
  ShellHead(
    manifest: Option(String),
    theme_color: Option(String),
    icon: Option(String),
    apple_touch_icon: Option(String),
    service_worker: Option(String),
    /// 0.11.15:`<head>` に出す stylesheet の href(並びの順)。const が無ければ空。
    stylesheets: List(String),
    invalid: List(String),
  )
}

pub const empty_shell_head = ShellHead(
  manifest: None,
  theme_color: None,
  icon: None,
  apple_touch_icon: None,
  service_worker: None,
  stylesheets: [],
  invalid: [],
)

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
  CurrentRoute
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
    style: FrameStyle,
  )
}

/// `StyledFrame(style:)` ── 格子の要素(`data-yumemi-grid`)に掛ける Style。Area の
/// style と同じく `style` の定数で書く。`Frame` と `style: []` は `NoFrameStyle`
/// (出力は 0.11.9 と同じ)。
pub type FrameStyle {
  NoFrameStyle
  /// `style: [style.a, style.b]`(各要素が `css.Style` の定数)。
  FrameStyleList(names: List(String))
  /// `style: style.shell`(`List(css.Style)` の定数)。
  FrameStyleConstant(name: String)
  /// `style` の定数でない要素を含む(`frame_notes` が止める)。
  FrameStyleInvalid
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
  /// `css.Var(name)`。名の検査(`[a-z0-9-]`)は `length_notes` が止める。
  VarLength(String)
  /// `css.Env(edge)`。辺は `top`・`right`・`bottom`・`left`。
  EnvLength(String)
  DvhLength(Float)
}

/// `pin: css.AnchoredOverlay(side:, align:)` ── 開いた `el.opener` の下か上へ寄せる。
/// side は `Below`・`Above`、align は `AlignStart`・`AlignEnd`。
pub type OverlayAnchor {
  OverlayAnchor(side: String, align: String)
}

/// Area の `flow` のうち、生成する grid の CSS へ写すもの(`GridTracks` は
/// `grid_tracks` が持つ)。gap は literal か `style` の定数を読んだ値。
pub type AreaFlow {
  StackFlow(gap: Length)
  RowFlow(gap: Length, wrap: Bool)
  GridFlow(cols: Int, gap: Length)
  ScrollerFlow
}

pub type Area {
  Area(
    name: String,
    flow: String,
    grid_tracks: Option(GridTracks),
    flow_layout: Option(AreaFlow),
    pin: String,
    anchor: Option(OverlayAnchor),
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

/// interactive Component(0.12、51 v6「interactive Component」)。宣言は `calls`・`after_send`・任意の
/// `reloads` と view だけ。検査(第 9〜22 条)は `component_notes` と、Service の model の要る分は
/// emit の `interactive_notes` が持つ。
pub type Component {
  Component(
    name: String,
    module: String,
    calls: List(CallTarget),
    /// `calls` が const の List で、どの要素も構成子の literal(第 10 条)
    calls_literal: Bool,
    reloads: Option(Reloads),
    /// `reloads` の const があるが形が読めない(第 17 条)
    reloads_unreadable: Bool,
    has_view: Bool,
    after_send: List(AfterRow),
    /// `after_send` の const があるが形が読めない(第 12 条)
    after_send_unreadable: Bool,
    nested_island: Bool,
    /// `pub fn app` がある(第 9 条)
    has_app: Bool,
    /// view の引数(順に、型の module の道と型名、引数の名)
    view_params: List(ViewParam),
    /// 同じ module の `pub type With` の欄(view が `with` を受けるとき)
    with_fields: Option(List(#(String, glance.Type))),
    /// import した `gen/live/*` の module 名
    live_imports: List(String),
    /// import の別名 → module の道(第 22 条で With の欄の型を解く)
    aliases: List(#(String, String)),
    /// view の中の live の口の呼び出し
    live_calls: List(LiveCall),
    /// 逃げ道(`gen/escapes`)の呼び出しの数
    escape_calls: Int,
    /// 生成器が止める形(第 9・10・11・13・19・21・22 条)
    notes: List(String),
  )
}

pub type ViewParam {
  ViewParam(name: String, module: Option(String), type_name: Option(String))
}

/// `#(service.X, live.After(ok: .., error: ..))` の 1 組。
pub type AfterRow {
  AfterRow(service: String, ok: Then, error: Then)
}

pub type Then {
  ThenStay
  ThenReload(notice: Option(String))
  ThenGoTo(route: String, notice: Option(String))
}

pub type Reloads {
  Reloads(read: String, on: List(String))
}

/// `<live>.bind(..)` ほかの呼び出し。`field` は構成子の literal のときだけ。
pub type LiveCall {
  LiveCall(live: String, function: String, field: Option(String))
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
  let lengths =
    units
    |> list.find(fn(unit) { unit.path == "style" })
    |> result.map(style_lengths)
    |> result.unwrap([])
  use layout_unit <- result.try(find_unit(units, "layout"))
  use layout <- result.try(parse_layout(face, layout_unit, lengths))
  let shell = shell_from_units(units, package_name)
  let pages =
    units
    |> list.filter(fn(unit) { string.starts_with(unit.path, "pages/") })
    |> list.filter_map(fn(unit) { parse_page(unit, lengths) })
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
  let surface_notes = list.flat_map(units, surface_unit_notes(face, _))
  let static_sheets = list.flat_map(units, static_sheet_paths)
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
    surface_notes: surface_notes,
    static_sheets: static_sheets,
  ))
}

/// model に対する停止診断。検査はここに集め、emit は呼ばない。
pub fn notes(front: Front, services: List(model.Service)) -> List(stop.Note) {
  list.flatten([
    shell_notes(front),
    front.surface_notes,
    component_notes(front),
    violation_notes(front.face, front.violations),
    overlay_template_notes(front),
    overlay_call_notes(front),
    length_notes(front),
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
        Some("yumemi/front/el") -> Some(label)
        _ -> None
      }
    glance.Variable(name: name, ..) ->
      case unqualified_module(imports, name) {
        Some("yumemi/front/el") -> Some(name)
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

/// Area の flow の gap に書いた `css.Var(name)` の名が `[a-z0-9-]` でなければ止める
/// (`;`・`}`・`)`・空白を生成の CSS に書かないため)。
fn length_notes(front: Front) -> List(stop.Note) {
  let layout = #(
    "layout",
    frames(front.layout.sp, front.layout.pc, front.layout.tablet),
  )
  let pages =
    list.map(front.pages, fn(page) {
      #(page.module, frames(page.sp, page.pc, page.tablet))
    })
  [layout, ..pages]
  |> list.flat_map(fn(entry) {
    let #(module, frames) = entry
    frames
    |> list.flat_map(fn(frame) {
      frame.areas
      |> list.flat_map(fn(area) { area_lengths(area) })
      |> list.filter_map(fn(length) {
        case length {
          VarLength(name) ->
            case valid_var_name(name) {
              True -> Error(Nil)
              False ->
                Ok(stop.Note(
                  class: stop.Conflict,
                  text: front.face
                    <> "/"
                    <> module
                    <> "/"
                    <> frame.media
                    <> ": css.Var(\""
                    <> name
                    <> "\") の名は a-z・0-9・- だけで書く",
                ))
            }
          _ -> Error(Nil)
        }
      })
    })
  })
}

fn area_lengths(area: Area) -> List(Length) {
  let flow = case area.flow_layout {
    Some(StackFlow(gap:))
    | Some(RowFlow(gap:, ..))
    | Some(GridFlow(gap:, ..)) -> [
      gap,
    ]
    _ -> []
  }
  case area.grid_tracks {
    Some(GridTracks(gap:, ..)) -> [gap, ..flow]
    None -> flow
  }
}

/// `css.Var` の名が `[a-z0-9-]` だけで、空でないか(root の `sketch_css` と同じ規則)。
pub fn valid_var_name(name: String) -> Bool {
  name != ""
  && list.all(string.to_utf_codepoints(name), fn(codepoint) {
    let code = string.utf_codepoint_to_int(codepoint)
    { code >= 97 && code <= 122 } || { code >= 48 && code <= 57 } || code == 45
  })
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
        head: empty_shell_head,
      )
    Ok(unit) -> {
      let module = g.in_order(unit.module)
      let theme = public_named_constant(module, "theme")
      let lang = constant_string(module, "lang")
      let title = constant_string(module, "title")
      let background = theme_string(theme, "background")
      let background_image = theme_image(theme)
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
        background_image: option.unwrap(background_image, ""),
        text: option.unwrap(text, "#3D2419"),
        accent: option.unwrap(accent, "#A93632"),
        present: True,
        missing: list.flatten([
          missing_label("lang", lang),
          missing_label("title", title),
          missing_theme,
        ]),
        head: shell_head(module),
      )
    }
  }
}

fn shell_head(module: glance.Module) -> ShellHead {
  let manifest = optional_shell_string(module, "manifest")
  let theme_color = optional_shell_string(module, "theme_color")
  let icon = optional_shell_string(module, "icon")
  let apple_touch_icon = optional_shell_string(module, "apple_touch_icon")
  let service_worker = optional_shell_string(module, "service_worker")
  let stylesheets = optional_shell_strings(module, "stylesheets")
  let named = [
    #("manifest", manifest),
    #("theme_color", theme_color),
    #("icon", icon),
    #("apple_touch_icon", apple_touch_icon),
    #("service_worker", service_worker),
  ]
  ShellHead(
    manifest: option.from_result(manifest),
    theme_color: option.from_result(theme_color),
    icon: option.from_result(icon),
    apple_touch_icon: option.from_result(apple_touch_icon),
    service_worker: option.from_result(service_worker),
    stylesheets: result.unwrap(stylesheets, []),
    invalid: list.filter_map(named, fn(pair) {
      case pair.1 {
        Error(True) -> Ok(pair.0)
        _ -> Error(Nil)
      }
    })
      |> list.append(case stylesheets {
        Error(True) -> ["stylesheets"]
        _ -> []
      }),
  )
}

/// 任意の String の List の const(0.11.15)。`Error(False)` は無い、`Error(True)` は在るのに List の literal で
/// ない・空でない String でない要素を持つ。
fn optional_shell_strings(
  module: glance.Module,
  name: String,
) -> Result(List(String), Bool) {
  case public_named_constant(module, name) {
    None -> Error(False)
    Some(constant) ->
      case constant.value {
        glance.List(elements: elements, rest: None, ..) ->
          list.try_map(elements, fn(element) {
            case g.string_value(element) {
              Some("") | None -> Error(True)
              Some(value) -> Ok(value)
            }
          })
        _ -> Error(True)
      }
  }
}

/// 任意の String の const。`Error(False)` は無い(出さない)、`Error(True)` は在るのに
/// 空でない String の定数でない(型違い・空文字)。
fn optional_shell_string(
  module: glance.Module,
  name: String,
) -> Result(String, Bool) {
  case public_named_constant(module, name) {
    None -> Error(False)
    Some(constant) ->
      case g.string_value(constant.value) {
        Some("") | None -> Error(True)
        Some(value) -> Ok(value)
      }
  }
}

fn constant_string(module: glance.Module, name: String) -> Option(String) {
  public_named_constant(module, name)
  |> option.then(fn(constant) { g.string_value(constant.value) })
}

/// Shell の `theme` の色。欄があって文字列の literal でなければ、第 26 条で止まる印の字(`#` で始まらない)
/// を返す(0.12 段 C、Y2 柏木 P1-9:欄の不足(exit 3)ではなく literal でない(exit 4))。
fn theme_string(
  theme: Option(glance.Constant),
  label: String,
) -> Option(String) {
  case
    theme |> option.then(fn(constant) { g.labelled(constant.value, label) })
  {
    Some(value) ->
      case g.string_value(value) {
        Some(text) -> Some(text)
        None -> Some("(文字列の literal でない)")
      }
    None -> None
  }
}

/// Shell の `theme.background_image`。`theme.Defaults` の `None` / `Some("<priv/static の path>")`
/// を ""(無い)/ path にする。0.11 の形の文字列(`"none"` は無い)も読む。
fn theme_image(theme: Option(glance.Constant)) -> Option(String) {
  case
    theme
    |> option.then(fn(constant) {
      g.labelled(constant.value, "background_image")
    })
  {
    Some(value) ->
      case g.string_value(value), value {
        Some("none"), _ -> Some("")
        Some(path), _ -> Some(path)
        None, glance.Variable(name: "None", ..) -> Some("")
        None,
          glance.Call(
            function: glance.Variable(name: "Some", ..),
            arguments: [glance.UnlabelledField(item: item)],
            ..,
          )
        -> g.string_value(item)
        None, _ -> None
      }
    None -> None
  }
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
      list.append(
        list.map(front.shell.missing, fn(name) {
          stop.Note(
            class: stop.Missing,
            text: front.face <> "/src/shell.gleam: " <> name <> " が無い",
          )
        }),
        list.map(front.shell.head.invalid, fn(name) {
          stop.Note(
            class: stop.Missing,
            text: front.face
              <> "/src/shell.gleam: "
              <> name
              <> case name {
              "stylesheets" -> " は空でない String の List の定数で書く"
              _ -> " は空でない String の定数で書く"
            },
          )
        }),
      )
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

fn parse_layout(
  face: String,
  unit: Unit,
  lengths: List(#(String, Length)),
) -> Result(Layout, Error) {
  let module = g.in_order(unit.module)
  use constant <- result.try(public_constant(module, face, "layout"))
  use value <- result.try(expected_type(constant, "Layout", unit.path))
  use _ <- result.try(expected_constructor(value, "Layout", unit.path))
  Ok(Layout(
    name: face,
    sp: frame_field(value, "sp", "sp", lengths),
    pc: frame_field(value, "pc", "pc", lengths),
    tablet: frame_field(value, "tablet", "tablet", lengths),
    vars: vars_field(value),
    nested: has_nested_constructor(value, "Layout"),
  ))
}

fn parse_page(
  unit: Unit,
  lengths: List(#(String, Length)),
) -> Result(Page, Nil) {
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
            sp: frame_field(constant.value, "sp", "sp", lengths),
            pc: frame_field(constant.value, "pc", "pc", lengths),
            tablet: frame_field(constant.value, "tablet", "tablet", lengths),
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
  let fallback = "invalid_var_" <> int.to_string(index)
  case g.ctor_name(expression) {
    Some("Var") -> {
      let name =
        constructor_field(expression, "name", ["name", "from"])
        |> option.then(g.string_value)
      let from = constructor_field(expression, "from", ["name", "from"])
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
      case
        constructor_field(expression, "face", ["face"])
        |> option.then(g.string_value)
      {
        Some(face) -> Origin(face)
        None -> InvalidFrom("Origin の face は文字列リテラルではない")
      }
    Some("AuthOrigin") ->
      case expression {
        glance.Call(..) -> InvalidFrom("AuthOrigin は値を持たない構成子リテラルでなければならない")
        _ -> AuthOrigin
      }
    Some("CurrentRoute") ->
      case expression {
        glance.Call(..) -> InvalidFrom("CurrentRoute は値を持たない構成子リテラルでなければならない")
        _ -> CurrentRoute
      }
    _ ->
      InvalidFrom(
        "from は Path / Query / Session / Origin / AuthOrigin / CurrentRoute のリテラルではない",
      )
  }
}

/// 構成子の named field は名前で読み、positional field は未指定の field
/// の宣言順へ割り当てる。混在した呼び出しでも named field は位置を消費しない。
fn constructor_field(
  expression: glance.Expression,
  name: String,
  fields: List(String),
) -> Option(glance.Expression) {
  case expression {
    glance.Call(arguments: arguments, ..) -> {
      let named =
        arguments
        |> list.find_map(fn(argument) {
          case argument {
            glance.LabelledField(label, _, value) if label == name -> Ok(value)
            _ -> Error(Nil)
          }
        })
      case named {
        Ok(value) -> Some(value)
        Error(_) -> {
          let supplied =
            arguments
            |> list.filter_map(fn(argument) {
              case argument {
                glance.LabelledField(label, _, _) -> Ok(label)
                glance.ShorthandField(label, _) -> Ok(label)
                _ -> Error(Nil)
              }
            })
          let positional_names =
            fields
            |> list.filter(fn(field) { !list.contains(supplied, field) })
          let position = field_position(positional_names, name)
          let positional_values =
            arguments
            |> list.filter_map(fn(argument) {
              case argument {
                glance.UnlabelledField(value) -> Ok(value)
                _ -> Error(Nil)
              }
            })
          case position {
            Some(index) -> list_at(positional_values, index)
            None -> None
          }
        }
      }
    }
    _ -> None
  }
}

fn field_position(fields: List(String), wanted: String) -> Option(Int) {
  case fields {
    [field, ..] if field == wanted -> Some(0)
    [_, ..rest] ->
      option.map(field_position(rest, wanted), fn(index) { index + 1 })
    [] -> None
  }
}

fn list_at(values: List(a), index: Int) -> Option(a) {
  case values {
    [value, ..] if index == 0 -> Some(value)
    [_, ..rest] if index > 0 -> list_at(rest, index - 1)
    _ -> None
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
  let calls_constant = public_named_constant(module, "calls")
  let calls = call_target_list(module, "calls")
  let calls_literal = case calls_constant {
    Some(glance.Constant(
      value: glance.List(elements: elements, rest: None, ..),
      ..,
    )) -> elements != [] && list.length(elements) == list.length(calls)
    _ -> False
  }
  let #(after_send, after_send_unreadable) = after_send_rows(module)
  let #(reloads, reloads_unreadable) = reloads_of(module)
  let view = public_function(module, "view")
  let view_params = case view {
    Some(function) ->
      list.map(function.parameters, fn(parameter) {
        let name = case parameter.name {
          glance.Named(name) -> name
          glance.Discarded(name) -> "_" <> name
        }
        case parameter.type_ {
          Some(glance.NamedType(name: type_name, module: alias, ..)) ->
            ViewParam(
              name: name,
              module: case alias {
                Some(alias) -> imported_module(module.imports, alias)
                None -> None
              },
              type_name: Some(type_name),
            )
          _ -> ViewParam(name: name, module: None, type_name: None)
        }
      })
    None -> []
  }
  let with_fields = case list.last(view_params) {
    Ok(ViewParam(type_name: Some("With"), module: None, ..)) ->
      case g.find_custom_type(module, "With") {
        Some(definition) ->
          case definition.variants {
            [variant] ->
              Some(
                list.filter_map(variant.fields, fn(field) {
                  case g.variant_field_label(field) {
                    Some(label) -> Ok(#(label, g.variant_field_type(field)))
                    None -> Error(Nil)
                  }
                }),
              )
            _ -> Some([])
          }
        None -> Some([])
      }
    _ -> None
  }
  let live_imports =
    module.imports
    |> list.filter_map(fn(definition) {
      case string.split_once(definition.definition.module, "gen/live/") {
        Ok(#("", live)) -> Ok(live)
        _ -> Error(Nil)
      }
    })
  let aliases =
    module.imports
    |> list.map(fn(definition) {
      let import_ = definition.definition
      let local = case import_.alias {
        Some(glance.Named(name)) -> name
        Some(glance.Discarded(name)) -> name
        None -> last_segment(import_.module)
      }
      #(local, import_.module)
    })
  let live_calls = component_live_calls(module)
  let escape_calls =
    references(module)
    |> list.count(fn(found) { found.0 == "gen/escapes" })
  let has_app = public_function(module, "app") != None
  let nested_island =
    list.any(module.imports, fn(definition) {
      definition.definition.module == "gen/interactive"
      || definition.definition.module == "gen/islands"
    })
  Ok(Component(
    name: name,
    module: unit.path,
    calls: calls,
    calls_literal: calls_literal,
    reloads: reloads,
    reloads_unreadable: reloads_unreadable,
    has_view: view != None,
    after_send: after_send,
    after_send_unreadable: after_send_unreadable,
    nested_island: nested_island,
    has_app: has_app,
    view_params: view_params,
    with_fields: with_fields,
    live_imports: live_imports,
    aliases: aliases,
    live_calls: live_calls,
    escape_calls: escape_calls,
    notes: component_shape_notes(module, has_app, calls_literal, calls),
  ))
}

/// `after_send` の組。const が無ければ空、読めない組があれば unreadable。
fn after_send_rows(module: glance.Module) -> #(List(AfterRow), Bool) {
  case public_named_constant(module, "after_send") {
    None -> #([], False)
    Some(constant) ->
      case constant.value {
        glance.List(elements: elements, rest: None, ..) -> {
          let rows =
            list.map(elements, fn(element) {
              case element {
                glance.Tuple(elements: [service, after], ..) ->
                  case service_target(service), g.ctor_name(after) {
                    Some(service), Some("After") ->
                      case g.labelled(after, "ok"), g.labelled(after, "error") {
                        Some(ok), Some(error) ->
                          case then_of(ok), then_of(error) {
                            Some(ok), Some(error) ->
                              Ok(AfterRow(service:, ok:, error:))
                            _, _ -> Error(Nil)
                          }
                        _, _ ->
                          case g.args(after) {
                            [ok, error] ->
                              case then_of(ok), then_of(error) {
                                Some(ok), Some(error) ->
                                  Ok(AfterRow(service:, ok:, error:))
                                _, _ -> Error(Nil)
                              }
                            _ -> Error(Nil)
                          }
                      }
                    _, _ -> Error(Nil)
                  }
                _ -> Error(Nil)
              }
            })
          #(result.values(rows), list.any(rows, result.is_error))
        }
        _ -> #([], True)
      }
  }
}

fn then_of(expression: glance.Expression) -> Option(Then) {
  case g.ctor_name(expression) {
    Some("Stay") -> Some(ThenStay)
    Some("ReloadPage") -> notice_of(expression, 0) |> option.map(ThenReload)
    Some("GoTo") -> {
      let route = case g.labelled(expression, "route") {
        Some(route) -> Some(route)
        None -> list.first(g.args(expression)) |> option.from_result
      }
      case route |> option.then(g.ctor_name), notice_of(expression, 1) {
        Some(route), Some(notice) -> Some(ThenGoTo(route:, notice:))
        _, _ -> None
      }
    }
    _ -> None
  }
}

/// `notice: Some("..")` / `None`。読めなければ None(外側の Option)。
fn notice_of(
  expression: glance.Expression,
  position: Int,
) -> Option(Option(String)) {
  let value = case g.labelled(expression, "notice") {
    Some(value) -> Some(value)
    None -> list_at(g.args(expression), position)
  }
  case value {
    Some(value) ->
      case g.ctor_name(value) {
        Some("None") -> Some(None)
        Some("Some") ->
          case g.args(value) {
            [text] -> g.string_value(text) |> option.map(Some)
            _ -> None
          }
        _ -> None
      }
    None -> None
  }
}

fn reloads_of(module: glance.Module) -> #(Option(Reloads), Bool) {
  case public_named_constant(module, "reloads") {
    None -> #(None, False)
    Some(constant) ->
      case g.ctor_name(constant.value) {
        Some("Reloads") -> {
          let read = case g.labelled(constant.value, "read") {
            Some(read) -> Some(read)
            None -> list.first(g.args(constant.value)) |> option.from_result
          }
          let on = case g.labelled(constant.value, "on") {
            Some(on) -> Some(on)
            None -> list_at(g.args(constant.value), 1)
          }
          case read |> option.then(service_target), on {
            Some(read), Some(glance.List(elements: elements, rest: None, ..)) -> {
              let fields =
                list.filter_map(elements, fn(element) {
                  case element {
                    glance.FieldAccess(label: label, ..) -> Ok(label)
                    _ -> Error(Nil)
                  }
                })
              #(
                Some(Reloads(read:, on: fields)),
                fields == [] || list.length(fields) != list.length(elements),
              )
            }
            _, _ -> #(None, True)
          }
        }
        _ -> #(None, True)
      }
  }
}

/// view と module の関数の中の `<gen/live/x>.<口>(..)` の呼び出し。pipe(`v |> x.bind(F)`)の左は
/// 第 1 引数に入るので、Field は残りの最初の引数で見る ── どちらでも Field の位置は同じ。
fn component_live_calls(module: glance.Module) -> List(LiveCall) {
  call_sites(module)
  |> list.filter_map(fn(call) {
    case string.split_once(call.module, "gen/live/") {
      Ok(#("", live)) ->
        case call.name {
          "bind" | "bind_check" | "bind_choice" | "send" | "when" | "out" ->
            Ok(
              LiveCall(
                live:,
                function: call.name,
                field: case call.name, call.arguments {
                  "send", _ -> None
                  _, [field, ..] ->
                    case field {
                      glance.FieldAccess(label: label, ..) -> Some(label)
                      glance.Variable(name: name, ..) ->
                        case is_upper_name(name) {
                          True -> Some(name)
                          False -> None
                        }
                      glance.Call(..) -> g.ctor_name(field)
                      _ -> None
                    }
                  _, _ -> None
                },
              ),
            )
          _ -> Error(Nil)
        }
      _ -> Error(Nil)
    }
  })
}

fn is_upper_name(name: String) -> Bool {
  case string.first(name) {
    Ok(first) ->
      string.uppercase(first) == first && string.lowercase(first) != first
    Error(_) -> False
  }
}

/// module だけで決まる形の検査(第 9・10・13・21 条)。
fn component_shape_notes(
  module: glance.Module,
  has_app: Bool,
  calls_literal: Bool,
  calls: List(CallTarget),
) -> List(String) {
  let app = case has_app {
    True -> [
      "4|`pub fn app` がある(第 9 条、0.12 の interactive Component は update も lustre の app も書かない)",
    ]
    False -> []
  }
  let services = list.map(calls, call_target_name)
  let calls_note = case calls_literal, duplicated(services) {
    False, _ -> [
      "4|`pub const calls` が Service の構成子の literal を 1 つ以上並べた const の List でない(第 10 条)",
    ]
    True, [] -> []
    True, found -> [
      "4|`calls` に同じ Service が 2 回ある(第 10 条): " <> string.join(found, ", "),
    ]
  }
  // 第 13 条:1 つの要素の属性の列に bind が 2 つ
  let double_bind =
    unit_expressions(module)
    |> list.flat_map(all_expressions)
    |> list.filter_map(fn(expression) {
      case expression {
        glance.List(elements: elements, ..) ->
          case
            list.count(elements, fn(element) {
              case element {
                glance.Call(function: function, ..) ->
                  case resolve_callee(function, module.imports) {
                    Some(#(path, "bind"))
                    | Some(#(path, "bind_check"))
                    | Some(#(path, "bind_choice")) ->
                      string.starts_with(path, "gen/live/")
                    _ -> False
                  }
                _ -> False
              }
            })
            > 1
          {
            True -> Ok("4|1 つの要素の属性の列に bind が 2 つある(第 13 条)")
            False -> Error(Nil)
          }
        _ -> Error(Nil)
      }
    })
    |> list.unique
  // 第 21 条:out を textarea / select / option の中に置く
  let out_in_control =
    call_sites(module)
    |> list.filter(fn(call) {
      call.module == "yumemi/front/html"
      && list.contains(
        ["textarea", "textarea_", "select", "select_", "option", "option_"],
        call.name,
      )
    })
    |> list.any(fn(call) {
      call.arguments
      |> list.flat_map(all_expressions)
      |> list.any(fn(expression) {
        case expression {
          glance.Call(function: function, ..) ->
            case resolve_callee(function, module.imports) {
              Some(#(path, "out")) -> string.starts_with(path, "gen/live/")
              _ -> False
            }
          _ -> False
        }
      })
    })
  let out_note = case out_in_control {
    True -> [
      "4|`out` を textarea / select / option の中に置いている(第 21 条、Out の値が送りの Args に入る抜け道)",
    ]
    False -> []
  }
  list.flatten([app, calls_note, double_bind, out_note])
}

pub fn call_target_name(target: CallTarget) -> String {
  case target {
    ServiceCall(name) -> name
    AttachedCall(name) -> name
  }
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
  lengths: List(#(String, Length)),
) -> Option(Frame) {
  case g.labelled(expression, label) {
    None -> None
    Some(value) ->
      case option_value(value) {
        None -> None
        Some(frame) -> parse_frame(frame, media, lengths)
      }
  }
}

fn parse_frame(
  expression: glance.Expression,
  media: String,
  lengths: List(#(String, Length)),
) -> Option(Frame) {
  case g.ctor_name(expression) {
    Some("Frame" as name) | Some("StyledFrame" as name) ->
      Some(
        Frame(
          media: media,
          areas: g.labelled(expression, "areas")
            |> option.then(fn(areas) { parse_areas(areas, lengths) })
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
          style: case name {
            "StyledFrame" -> parse_frame_style(expression)
            _ -> NoFrameStyle
          },
        ),
      )
    _ -> None
  }
}

fn parse_frame_style(expression: glance.Expression) -> FrameStyle {
  let constant = fn(item: glance.Expression) {
    case item {
      glance.FieldAccess(
        container: glance.Variable(name: "style", ..),
        label:,
        ..,
      ) -> Ok(label)
      _ -> Error(Nil)
    }
  }
  case g.labelled(expression, "style") {
    None -> NoFrameStyle
    Some(glance.List(elements: [], rest: None, ..)) -> NoFrameStyle
    Some(glance.List(elements:, rest: None, ..)) ->
      case list.try_map(elements, constant) {
        Ok(names) -> FrameStyleList(names)
        Error(_) -> FrameStyleInvalid
      }
    Some(value) ->
      case constant(value) {
        Ok(name) -> FrameStyleConstant(name)
        Error(_) -> FrameStyleInvalid
      }
  }
}

fn parse_areas(
  expression: glance.Expression,
  lengths: List(#(String, Length)),
) -> Option(List(Area)) {
  case g.list_elements(expression) {
    [] ->
      case expression {
        glance.List(elements: [], ..) -> Some([])
        _ -> None
      }
    elements ->
      Some(
        list.filter_map(elements, fn(element) {
          parse_area_result(element, lengths)
        }),
      )
  }
}

fn parse_area(
  expression: glance.Expression,
  lengths: List(#(String, Length)),
) -> Option(Area) {
  case g.ctor_name(expression) {
    Some("Area") ->
      Some(Area(
        name: string_label(expression, "name") |> option.unwrap(""),
        flow: constructor_label(expression, "flow") |> option.unwrap(""),
        grid_tracks: g.labelled(expression, "flow")
          |> option.then(parse_grid_tracks),
        flow_layout: g.labelled(expression, "flow")
          |> option.then(fn(flow) { parse_area_flow(flow, lengths) }),
        pin: case constructor_label(expression, "pin") {
          Some("AnchoredOverlay") -> "Overlay"
          pin -> option.unwrap(pin, "")
        },
        anchor: g.labelled(expression, "pin")
          |> option.then(parse_overlay_anchor),
        style: style_names(expression),
      ))
    _ -> None
  }
}

/// 寄せた Overlay の向き。側と揃えが構成子のリテラルでなければ None(中央に開く
/// 今の Overlay のまま)。
fn parse_overlay_anchor(
  expression: glance.Expression,
) -> Option(OverlayAnchor) {
  case g.ctor_name(expression) {
    Some("AnchoredOverlay") -> {
      let fields = ["side", "align"]
      let side =
        constructor_field(expression, "side", fields)
        |> option.then(g.ctor_name)
      let align =
        constructor_field(expression, "align", fields)
        |> option.then(g.ctor_name)
      case side, align {
        Some("Below" as side), Some("AlignStart" as align)
        | Some("Below" as side), Some("AlignEnd" as align)
        | Some("Above" as side), Some("AlignStart" as align)
        | Some("Above" as side), Some("AlignEnd" as align)
        -> Some(OverlayAnchor(side: side, align: align))
        _, _ -> None
      }
    }
    _ -> None
  }
}

fn parse_area_result(
  expression: glance.Expression,
  lengths: List(#(String, Length)),
) -> Result(Area, Nil) {
  case parse_area(expression, lengths) {
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

/// Area の `flow` を読む。`GridTracks` は `parse_grid_tracks` の側。gap が literal
/// でも `style` の定数でもなく読めないときは None ── grid の CSS に flow の行を出さない。
fn parse_area_flow(
  expression: glance.Expression,
  lengths: List(#(String, Length)),
) -> Option(AreaFlow) {
  let gap = fn() {
    g.labelled(expression, "gap")
    |> option.then(fn(gap) { parse_length_ref(gap, lengths) })
  }
  case g.ctor_name(expression) {
    Some("Stack") -> gap() |> option.map(StackFlow)
    Some("Row") ->
      case gap(), g.labelled(expression, "wrap") |> option.then(parse_bool) {
        Some(gap), Some(wrap) -> Some(RowFlow(gap: gap, wrap: wrap))
        _, _ -> None
      }
    Some("Grid") ->
      case gap(), g.labelled(expression, "cols") |> option.then(parse_int) {
        Some(gap), Some(cols) -> Some(GridFlow(cols: cols, gap: gap))
        _, _ -> None
      }
    Some("Scroller") -> Some(ScrollerFlow)
    _ -> None
  }
}

fn parse_bool(expression: glance.Expression) -> Option(Bool) {
  case g.ctor_name(expression) {
    Some("True") -> Some(True)
    Some("False") -> Some(False)
    _ -> None
  }
}

/// 長さの literal(`css.Px(8.0)`)か、`style` の定数(`style.s2`)。
fn parse_length_ref(
  expression: glance.Expression,
  lengths: List(#(String, Length)),
) -> Option(Length) {
  case parse_length(expression), expression {
    Some(length), _ -> Some(length)
    None,
      glance.FieldAccess(
        container: glance.Variable(name: "style", ..),
        label:,
        ..,
      )
    -> list.key_find(lengths, label) |> option_from_result
    None, _ -> None
  }
}

/// `style` の定数のうち長さになるもの。同じ module の別の定数を指すものも辿る。
fn style_lengths(unit: Unit) -> List(#(String, Length)) {
  let constants =
    g.in_order(unit.module).constants
    |> list.map(fn(definition) {
      #(definition.definition.name, definition.definition.value)
    })
  list.filter_map(constants, fn(entry) {
    style_length(entry.1, constants, 8)
    |> option.map(fn(length) { #(entry.0, length) })
    |> option.to_result(Nil)
  })
}

fn style_length(
  expression: glance.Expression,
  constants: List(#(String, glance.Expression)),
  depth: Int,
) -> Option(Length) {
  case parse_length(expression), expression, depth > 0 {
    Some(length), _, _ -> Some(length)
    None, glance.Variable(name:, ..), True ->
      case list.key_find(constants, name) {
        Ok(value) -> style_length(value, constants, depth - 1)
        Error(_) -> None
      }
    _, _, _ -> None
  }
}

fn parse_length(expression: glance.Expression) -> Option(Length) {
  case g.ctor_name(expression) {
    Some("Rem") ->
      parse_float_arg(expression) |> option_from_result |> option.map(RemLength)
    Some("Px") ->
      parse_float_arg(expression) |> option_from_result |> option.map(PxLength)
    Some("Dvh") ->
      parse_float_arg(expression) |> option_from_result |> option.map(DvhLength)
    Some("Var") ->
      case g.args(expression) {
        [name] -> g.string_value(name) |> option.map(VarLength)
        _ -> None
      }
    Some("Env") ->
      case g.args(expression) |> list.map(g.ctor_name) {
        [Some("SafeTop")] -> Some(EnvLength("top"))
        [Some("SafeRight")] -> Some(EnvLength("right"))
        [Some("SafeBottom")] -> Some(EnvLength("bottom"))
        [Some("SafeLeft")] -> Some(EnvLength("left"))
        _ -> None
      }
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
        case component.reloads {
          Some(reloads) -> [reloads.read]
          None -> []
        },
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
  let page_args =
    list.flat_map(page_frames(page), fn(frame) {
      list.flat_map(frame.placements, fn(placement) {
        placement_service_args(placement, blocks, services, page_scope)
      })
    })
  list.fold(page_args, layout_args, merge_service_args)
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
        // Layout の置き場(Widget)も Page の Var を受ける(resolve_page_service_args と同じ)。0.12 段 C:
        // Layout の Block の Component の reloads の一覧が Page の `Query` を読むため、Layout の分も使った数に入れる
        unused_var_notes(
          front,
          page.module,
          page.vars,
          list.append(page_frames(page), layout_frames(front.layout)),
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
      True, Path(_) -> Some("Layout に Path を置けない(今の page は CurrentRoute で受ける)")
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
      frame_style_notes(face, module, sp),
      frame_style_notes(face, module, pc),
      frame_style_notes(face, module, tablet),
    ]),
  )
}

fn frame_style_notes(
  face: String,
  module: String,
  frame: Option(Frame),
) -> List(stop.Note) {
  case frame {
    Some(Frame(style: FrameStyleInvalid, media:, ..)) -> [
      stop.Note(
        class: stop.Conflict,
        text: face
          <> "/"
          <> module
          <> "/"
          <> media
          <> ": StyledFrame の style は style の定数で書く(style: [style.shell] か style: style.shell)",
      ),
    ]
    _ -> []
  }
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
      // 0.11.15 の lustre の禁則(`lustre/internals` の import と `attribute.class`・
      // `attribute.style`・`element.element` の直呼び)は 0.12 で第 1 条に吸収した。
      let _ = imported
      Error(Nil)
    })
  let islands = case
    list.find(components, fn(component) { component.module == unit.path })
  {
    Ok(component) if component.nested_island -> [NestedIsland(module: unit.path)]
    _ -> []
  }
  list.append(imports, islands)
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

// ── 記述面と Css の条文(0.12 段 B、51 v6「生成器が止めるもの」)──────────────

/// ★ の module の中の関数呼び出しと構成子の呼び出し(module は import から解いた道)。
type CallSite {
  CallSite(module: String, name: String, arguments: List(glance.Expression))
}

fn unit_expressions(module: glance.Module) -> List(glance.Expression) {
  list.append(
    list.flat_map(module.functions, fn(definition) {
      list.flat_map(definition.definition.body, statement_expressions)
    }),
    list.map(module.constants, fn(definition) { definition.definition.value }),
  )
}

fn all_expressions(expression: glance.Expression) -> List(glance.Expression) {
  [
    expression,
    ..list.flat_map(expression_children(expression), all_expressions)
  ]
}

fn call_sites(module: glance.Module) -> List(CallSite) {
  let site = fn(function, arguments) {
    case resolve_callee(function, module.imports) {
      Some(#(path, name)) ->
        Ok(CallSite(module: path, name: name, arguments: arguments))
      None -> Error(Nil)
    }
  }
  unit_expressions(module)
  |> list.flat_map(all_expressions)
  |> list.filter_map(fn(expression) {
    case expression {
      // pipe の右が関数の参照なら、左を第 1 引数にした呼び出し(`x |> el.static_sheet`)
      glance.BinaryOperator(name: glance.Pipe, left: left, right: right, ..) ->
        case right {
          glance.Call(..) -> Error(Nil)
          _ -> site(right, [left])
        }
      glance.Call(function: function, arguments: arguments, ..) ->
        site(function, list.flat_map(arguments, field_expressions))
      _ -> Error(Nil)
    }
  })
}

/// 呼び出しでない参照(`list.map(xs, el.element)` のような関数の値)も第 3 条に掛ける。
fn references(module: glance.Module) -> List(#(String, String)) {
  unit_expressions(module)
  |> list.flat_map(all_expressions)
  |> list.filter_map(fn(expression) {
    case resolve_callee(expression, module.imports) {
      Some(found) -> Ok(found)
      None -> Error(Nil)
    }
  })
}

fn resolve_callee(
  expression: glance.Expression,
  imports: List(glance.Definition(glance.Import)),
) -> Option(#(String, String)) {
  case expression {
    glance.FieldAccess(
      container: glance.Variable(name: alias, ..),
      label: label,
      ..,
    ) ->
      imported_module(imports, alias)
      |> option.map(fn(path) { #(path, label) })
    glance.Variable(name: name, ..) ->
      unqualified_module(imports, name)
      |> option.map(fn(path) { #(path, name) })
    _ -> None
  }
}

fn is_lustre_module(path: String) -> Bool {
  path == "lustre"
  || string.starts_with(path, "lustre/")
  || path == "sketch/lustre"
  || string.starts_with(path, "sketch/lustre/")
}

/// yumemi の `@internal` の口(生成物と yumemi の html / attr だけが呼ぶ)。
fn is_internal_reference(path: String, name: String) -> Bool {
  case path, name {
    "yumemi/front/el", "element"
    | "yumemi/front/el", "namespaced"
    | "yumemi/front/el", "raw_text"
    | "yumemi/front/el", "attribute"
    | "yumemi/front/el", "no_attribute"
    | "yumemi/front/el", "class_attribute"
    | "yumemi/front/el", "styled"
    | "yumemi/front/el", "to_document_string"
    | "yumemi/front/el", "escape"
    | "yumemi/front/el", "escape_point"
    | "yumemi/front/el", "attributes"
    | "yumemi/front/el", "media_src"
    | "yumemi/front/el", "Node"
    | "yumemi/front/el", "RawText"
    | "yumemi/front/el", "Attribute"
    | "yumemi/front/html", "html"
    | "yumemi/front/html", "head"
    | "yumemi/front/html", "body"
    | "yumemi/front/html", "body_"
    | "yumemi/front/html", "meta"
    | "yumemi/front/html", "title"
    | "yumemi/front/css", "class_styles"
    | "yumemi/front/sketch_css", "class_name"
    | "yumemi/front/sketch_css", "stable_hash"
    | "yumemi/front/live", "bind"
    | "yumemi/front/live", "bind_check"
    | "yumemi/front/live", "bind_choice"
    | "yumemi/front/live", "bind_file"
    | "yumemi/front/live", "when"
    | "yumemi/front/live", "out"
    | "yumemi/front/live", "send"
    | "yumemi/front/live", "component"
    | "yumemi/front/live", "json_string"
    | "yumemi/front/live", "json_object"
    | "yumemi/front/live", "MinLength"
    | "yumemi/front/live", "MaxLength"
    | "yumemi/front/live", "Required"
    | "yumemi/front/live", "Pattern"
    | "yumemi/front/sketch_css", "collect"
    | "yumemi/front/theme", "body_rule"
    | "yumemi/front/theme", "has_image"
    -> True
    _, _ -> False
  }
}

fn surface_unit_notes(face: String, unit: Unit) -> List(stop.Note) {
  let module = g.in_order(unit.module)
  let where = face <> "/" <> unit.path
  let conflict = fn(text) {
    stop.Note(class: stop.Conflict, text: where <> ": " <> text)
  }
  // 第 1 条:lustre を import しない(0.12 段 C で例外は無くなった。面の `src/gen/` に手で置いた
  // file も ★ として読む ── `source.load` が生成の印の無い `gen/` の file を残す)
  let lustre =
    module.imports
    |> list.filter(fn(definition) {
      is_lustre_module(definition.definition.module)
    })
    |> list.map(fn(definition) {
      conflict(
        "★ が lustre を import している(第 1 条、0.12 の ★ は yumemi/front の el・html・attr で書く): "
        <> definition.definition.module,
      )
    })
  // 第 4 条:`@external` を書かない(FFI は `src/escapes/<name>.mjs` の名前付きの逃げ道だけ)
  let external =
    list.append(
      list.flat_map(module.functions, fn(definition) {
        list.filter_map(definition.attributes, fn(attribute) {
          case attribute.name {
            "external" -> Ok(definition.definition.name)
            _ -> Error(Nil)
          }
        })
      }),
      list.flat_map(module.custom_types, fn(definition) {
        list.filter_map(definition.attributes, fn(attribute) {
          case attribute.name {
            "external" -> Ok(definition.definition.name)
            _ -> Error(Nil)
          }
        })
      }),
    )
    |> list.map(fn(name) {
      conflict(
        "★ が `@external` を書いている(第 4 条、FFI は src/escapes/<name>.mjs の逃げ道で置く): "
        <> name,
      )
    })
  // 第 3 条:yumemi の @internal を呼ばない
  let internal =
    references(module)
    |> list.unique
    |> list.filter(fn(found) { is_internal_reference(found.0, found.1) })
    |> list.map(fn(found) {
      conflict(
        "yumemi の @internal の口を呼んでいる(第 3 条): "
        <> last_segment(found.0)
        <> "."
        <> found.1,
      )
    })
  let calls = call_sites(module)
  let literal_notes =
    list.flat_map(calls, fn(call) {
      case call.module, call.name, call.arguments {
        // 第 7 条
        "yumemi/front/attr", "data", [name, ..]
        | "yumemi/front/attr", "aria", [name, ..]
        ->
          case g.string_value(name) {
            Some(literal) ->
              case is_attribute_name(literal) {
                True if call.name == "data" ->
                  case string.starts_with(literal, "yumemi") {
                    True -> [
                      conflict(
                        "attr.data の名 \""
                        <> literal
                        <> "\" が yumemi で始まる(第 7 条、data-yumemi-* は framework の印)",
                      ),
                    ]
                    False -> []
                  }
                True -> []
                False -> [
                  conflict(
                    "attr."
                    <> call.name
                    <> " の名 \""
                    <> literal
                    <> "\" が [a-z][a-z0-9-]* でない(第 7 条)",
                  ),
                ]
              }
            None -> []
          }
        // 第 23 条
        "yumemi/front/css", "Hex", [value] ->
          case g.string_value(value) {
            Some(literal) ->
              case is_hex_color(literal) {
                True -> []
                False -> [
                  conflict(
                    "css.Hex の値 \"" <> literal <> "\" が # と 16 進 6 桁でない(第 23 条)",
                  ),
                ]
              }
            None -> [conflict("css.Hex の値が文字列の literal でない(第 23 条)")]
          }
        // 第 24 条
        "yumemi/front/css", "Token", [value] ->
          case g.string_value(value) {
            Some(literal) ->
              case is_token_name(literal) {
                True -> []
                False -> [
                  conflict(
                    "css.Token の名 \""
                    <> literal
                    <> "\" が [a-z0-9-]+ でない(第 24 条)",
                  ),
                ]
              }
            None -> []
          }
        // 第 25 条
        "yumemi/front/css", "Mix", [_, _, percent] ->
          case int_literal(percent) {
            Some(value) if value < 0 || value > 100 -> [
              conflict(
                "css.Mix の percent "
                <> int.to_string(value)
                <> " が 0〜100 の外(第 25 条)",
              ),
            ]
            _ -> []
          }
        _, _, _ -> []
      }
    })
  // 第 8 条:1 つの要素の属性の列に同じ名の属性が静的に 2 つ
  let duplicate_notes =
    unit_expressions(module)
    |> list.flat_map(all_expressions)
    |> list.filter_map(fn(expression) {
      case expression {
        glance.List(elements: elements, rest: None, ..) -> {
          let names =
            list.filter_map(elements, fn(element) {
              static_attribute_name(element, module.imports)
            })
          case duplicated(names) {
            [] -> Error(Nil)
            found ->
              Ok(conflict(
                "1 つの要素の属性の列に同じ名の属性が 2 つある(第 8 条): " <> string.join(found, ", "),
              ))
          }
        }
        _ -> Error(Nil)
      }
    })
  // 第 31・43 条:pipe・関数参照の static_sheet / static_src は literal の path として読めない
  let refs = references(module)
  let reference_notes =
    [#("static_sheet", "第 31 条"), #("static_src", "第 43 条")]
    |> list.filter_map(fn(pair) {
      let referenced =
        list.count(refs, fn(found) {
          found.0 == "yumemi/front/el" && found.1 == pair.0
        })
      let literal =
        list.count(calls, fn(call) {
          call.module == "yumemi/front/el"
          && call.name == pair.0
          && case call.arguments {
            [path] -> g.string_value(path) != None
            _ -> False
          }
        })
      case referenced > literal {
        True ->
          Ok(conflict(
            "el."
            <> pair.0
            <> " の path が文字列の literal でない(pipe・関数参照・変数を含む、"
            <> pair.1
            <> ")",
          ))
        False -> Error(Nil)
      }
    })
  list.flatten([
    lustre,
    external,
    internal,
    literal_notes,
    list.unique(reference_notes),
    duplicate_notes,
  ])
}

/// 属性の列の要素が `attr.<名>(..)` なら、出る属性の名(`data` / `aria` は literal の名から)。
fn static_attribute_name(
  expression: glance.Expression,
  imports: List(glance.Definition(glance.Import)),
) -> Result(String, Nil) {
  case expression {
    glance.Call(function: function, arguments: arguments, ..) ->
      case resolve_callee(function, imports) {
        Some(#("yumemi/front/attr", "none")) -> Error(Nil)
        Some(#("yumemi/front/attr", "data" as prefix))
        | Some(#("yumemi/front/attr", "aria" as prefix)) ->
          case list.flat_map(arguments, field_expressions) {
            [name, ..] ->
              case g.string_value(name) {
                Some(literal) -> Ok(prefix <> "-" <> literal)
                None -> Error(Nil)
              }
            [] -> Error(Nil)
          }
        Some(#("yumemi/front/attr", name)) -> Ok(name)
        _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

fn duplicated(names: List(String)) -> List(String) {
  names
  |> list.filter(fn(name) { list.count(names, fn(other) { other == name }) > 1 })
  |> list.unique
}

fn int_literal(expression: glance.Expression) -> Option(Int) {
  case expression {
    glance.Int(value: value, ..) -> option.from_result(int.parse(value))
    glance.NegateInt(value: glance.Int(value: value, ..), ..) ->
      int.parse(value)
      |> result.map(fn(value) { 0 - value })
      |> option.from_result
    _ -> None
  }
}

/// `[a-z][a-z0-9-]*`。
pub fn is_attribute_name(name: String) -> Bool {
  case string.to_graphemes(name) {
    [first, ..rest] ->
      string.contains("abcdefghijklmnopqrstuvwxyz", first)
      && list.all(rest, fn(char) {
        string.contains("abcdefghijklmnopqrstuvwxyz0123456789-", char)
      })
    [] -> False
  }
}

/// `[a-z0-9-]+`。
fn is_token_name(name: String) -> Bool {
  name != ""
  && list.all(string.to_graphemes(name), fn(char) {
    string.contains("abcdefghijklmnopqrstuvwxyz0123456789-", char)
  })
}

/// `#` と 16 進 6 桁。
pub fn is_hex_color(value: String) -> Bool {
  case string.to_graphemes(value) {
    ["#", ..digits] ->
      list.length(digits) == 6
      && list.all(digits, fn(char) {
        string.contains("0123456789abcdefABCDEF", char)
      })
    _ -> False
  }
}

/// `el.static_sheet("..")` の literal の path(#(module, path))。
fn static_sheet_paths(unit: Unit) -> List(#(String, String)) {
  call_sites(g.in_order(unit.module))
  |> list.filter_map(fn(call) {
    case call.module, call.name, call.arguments {
      "yumemi/front/el", "static_sheet", [path] ->
        case g.string_value(path) {
          Some(literal) -> Ok(#(unit.path, literal))
          None -> Error(Nil)
        }
      _, _, _ -> Error(Nil)
    }
  })
}

// ── interactive Component の条文(0.12 段 C、51 v6 第 9〜22 条のうち面の source だけで決まるもの)──

/// Component の Service(`calls` の要素)の live module の名。
pub fn live_module(target: CallTarget) -> String {
  naming.snake(call_target_name(target))
}

/// Component のタグ名(module 名の `_` を `-`)。
pub fn component_tag(component: Component) -> String {
  string.replace(naming.snake(last_segment(component.module)), "_", "-")
}

/// view が `calls` の順の Args(と任意の末尾の `with: With`)を受ける(第 11 条)。生成器はこの形の Component に
/// だけ置く関数と表を出す。
pub fn view_ok(component: Component) -> Bool {
  let lives = list.map(component.calls, live_module)
  let params = case component.with_fields {
    Some(_) ->
      list.take(component.view_params, list.length(component.view_params) - 1)
    None -> component.view_params
  }
  component.has_view
  && lives != []
  && list.length(params) == list.length(lives)
  && list.all(list.zip(params, lives), fn(pair) {
    let #(param, live) = pair
    param.module == Some("gen/live/" <> live) && param.type_name == Some("Args")
  })
  && case component.with_fields, list.last(component.view_params) {
    Some(_), Ok(param) -> param.name == "with" || param.name == "_with"
    None, _ -> True
    _, _ -> False
  }
}

fn component_notes(front: Front) -> List(stop.Note) {
  let note = fn(component: Component, coded: String) {
    let #(class, text) = case string.split_once(coded, "|") {
      Ok(#("3", text)) -> #(stop.Missing, text)
      Ok(#(_, text)) -> #(stop.Conflict, text)
      Error(_) -> #(stop.Conflict, coded)
    }
    stop.Note(
      class:,
      text: front.face <> "/" <> component.module <> ": " <> text,
    )
  }
  let per_component =
    list.flat_map(front.components, fn(component) {
      let lives = list.map(component.calls, live_module)
      // 第 11 条:view は calls の順の Args と、任意の末尾の `with: With`
      let view_ok = view_ok(component)
      let view = case view_ok || component.calls == [] {
        True -> []
        False -> [
          "4|view が `pub fn view(<calls の順に各 Service の live の Args>) -> Element`(末尾に任意の `with: With`)でない(第 11 条): calls = "
          <> string.join(lives, ", "),
        ]
      }
      // 第 19 条:calls に無い Service の live を import しない
      let foreign =
        component.live_imports
        |> list.filter(fn(live) { !list.contains(lives, live) })
        |> list.map(fn(live) {
          "4|calls に無い Service の gen/live/"
          <> live
          <> " を import している(第 19 条、client での連鎖の口)"
        })
      // 第 13・14 条:bind の Field は構成子の literal、List でない Field の 2 回目は emit が見る
      let non_literal =
        component.live_calls
        |> list.filter(fn(call) {
          list.contains(["bind", "bind_check", "bind_choice"], call.function)
          && call.field == None
        })
        |> list.map(fn(call) {
          "4|"
          <> call.live
          <> "."
          <> call.function
          <> " の Field が構成子の literal でない(第 13 条)"
        })
        |> list.unique
      // 第 22 条:With の欄に live の型・el.Element・el.Attribute・関数を入れない
      let with = case component.with_fields {
        Some(fields) ->
          fields
          |> list.filter(fn(field) {
            forbidden_with_type(front, component, field.1)
          })
          |> list.map(fn(field) {
            "4|With の欄 "
            <> field.0
            <> " の型に live の型・el.Element・el.Attribute・関数がある(第 22 条)"
          })
        None -> []
      }
      let tag = component_tag(component)
      let tag_note = case el_is_custom_element_name(tag) {
        True -> []
        False -> [
          "4|タグ名 "
          <> tag
          <> " が custom element の名の形でない(第 18 条、module 名に _ を含める)",
        ]
      }
      let nested = case component.nested_island {
        True -> [
          "4|interactive Component の中に interactive Component を置いている(gen/interactive の import)",
        ]
        False -> []
      }
      let reloads = case component.reloads_unreadable {
        True -> [
          "4|`reloads` が live.Reloads(read: <calls の読みの Service>, on: [<read の live の Field の literal>, ..]) でない(第 17 条)",
        ]
        False -> []
      }
      let after = case component.after_send_unreadable {
        True -> [
          "4|`after_send` の組が #(service.X, live.After(ok: <Then>, error: <Then>)) の literal でない(第 12 条)",
        ]
        False -> []
      }
      list.flatten([
        component.notes,
        view,
        foreign,
        non_literal,
        with,
        tag_note,
        nested,
        reloads,
        after,
      ])
      |> list.map(note(component, _))
    })
  // 第 18 条:2 つの Component のタグ名が重なる
  let tags = list.map(front.components, component_tag)
  let collisions =
    duplicated(tags)
    |> list.map(fn(tag) {
      stop.Note(
        class: stop.Conflict,
        text: front.face
          <> ": 2 つの interactive Component のタグ名が重なる(第 18 条): "
          <> tag,
      )
    })
  // 第 16 条:notice を書いた Component があるのに Layout の Block に el.notice が無い
  let uses_notice =
    list.any(front.components, fn(component) {
      list.any(component.after_send, fn(row) {
        then_notice(row.ok) || then_notice(row.error)
      })
    })
  let layout_blocks =
    list.flatten([
      frame_block_modules(front, front.layout.sp),
      frame_block_modules(front, front.layout.pc),
      frame_block_modules(front, front.layout.tablet),
    ])
  let has_notice =
    front.blocks
    |> list.filter(fn(block) { list.contains(layout_blocks, block.module) })
    |> list.any(fn(block) {
      list.any(call_sites(block.source), fn(call) {
        call.module == "yumemi/front/el" && call.name == "notice"
      })
    })
  let notice = case uses_notice && !has_notice {
    True -> [
      stop.Note(
        class: stop.Missing,
        text: front.face
          <> ": notice を書いた interactive Component があるのに、Layout の Block に el.notice が無い(第 16 条)",
      ),
    ]
    False -> []
  }
  list.flatten([per_component, collisions, notice])
}

fn then_notice(then: Then) -> Bool {
  case then {
    ThenStay -> False
    ThenReload(notice:) | ThenGoTo(notice:, ..) -> notice != None
  }
}

fn el_is_custom_element_name(tag: String) -> Bool {
  is_attribute_name(tag)
  && string.contains(tag, "-")
  && !list.contains(
    [
      "annotation-xml", "color-profile", "font-face", "font-face-src",
      "font-face-uri", "font-face-format", "font-face-name", "missing-glyph",
    ],
    tag,
  )
}

/// With の欄の型(List・Option ほかの型引数を辿る)。同じ module の import で解き、別 module の
/// record の中までは辿らない(51 v6 確認できなかったこと 16)。
fn forbidden_with_type(
  front: Front,
  component: Component,
  type_: glance.Type,
) -> Bool {
  let _ = front
  case type_ {
    glance.FunctionType(..) -> True
    glance.NamedType(name: name, module: alias, parameters: parameters, ..) -> {
      let path = case alias {
        Some(alias) -> component_import(component, alias)
        None -> None
      }
      let here = case path {
        Some(path) ->
          string.starts_with(path, "gen/live/")
          || {
            path == "yumemi/front/el"
            && { name == "Element" || name == "Attribute" }
          }
        None -> False
      }
      here || list.any(parameters, forbidden_with_type(front, component, _))
    }
    glance.TupleType(elements: elements, ..) ->
      list.any(elements, forbidden_with_type(front, component, _))
    _ -> False
  }
}

fn component_import(component: Component, alias: String) -> Option(String) {
  list.key_find(component.aliases, alias) |> option.from_result
}

/// unit の中の関数・構成子の参照の module の道(逃げ道の呼び出しの数え)。
pub fn module_references(unit: Unit) -> List(String) {
  references(g.in_order(unit.module))
  |> list.map(fn(found) { found.0 })
}

/// `el.static_src("..")` の literal の path(#(module, path))。
pub fn static_src_paths(unit: Unit) -> List(#(String, String)) {
  call_sites(g.in_order(unit.module))
  |> list.filter_map(fn(call) {
    case call.module, call.name, call.arguments {
      "yumemi/front/el", "static_src", [path] ->
        case g.string_value(path) {
          Some(literal) -> Ok(#(unit.path, literal))
          None -> Error(Nil)
        }
      _, _, _ -> Error(Nil)
    }
  })
}

/// Component を置く Block(`gen/interactive.<名>(..)` を呼ぶ Block)。第 17 条の一覧の読みの検査に使う。
pub fn placing_blocks(front: Front, component: Component) -> List(Block) {
  let name = naming.snake(last_segment(component.module))
  front.blocks
  |> list.filter(fn(block) {
    list.any(call_sites(block.source), fn(call) {
      { call.module == "gen/interactive" || call.module == "gen/islands" }
      && call.name == name
    })
  })
}

/// Block を載せる Page と、その Page の Var(Layout の Block なら全 Page、Var は Layout の分も)。
pub fn block_pages(front: Front, block: Block) -> List(#(Page, List(Var))) {
  let in_layout =
    list.contains(
      list.flatten([
        frame_block_modules(front, front.layout.sp),
        frame_block_modules(front, front.layout.pc),
        frame_block_modules(front, front.layout.tablet),
      ]),
      block.module,
    )
  front.pages
  |> list.filter(fn(page) {
    in_layout
    || list.contains(
      list.flatten([
        frame_block_modules(front, page.sp),
        frame_block_modules(front, page.pc),
        frame_block_modules(front, page.tablet),
      ]),
      block.module,
    )
  })
  |> list.map(fn(page) { #(page, list.append(page.vars, front.layout.vars)) })
}
