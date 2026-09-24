import framework/front/css
import framework/front/track
import gleam/list
import gleam/option.{type Option}

pub type Layout(service, block) {
  Layout(
    sp: Frame(service, block),
    pc: Option(Frame(service, block)),
    tablet: Option(Frame(service, block)),
    reads: List(service),
  )
}

pub type Page(service, block) {
  Page(
    of: Option(service),
    layout: Layout(service, block),
    theme: Option(String),
    sp: Frame(service, block),
    pc: Option(Frame(service, block)),
    tablet: Option(Frame(service, block)),
    reads: List(service),
  )
}

pub type Frame(service, block) {
  Frame(
    areas: List(Area),
    placements: List(Placement(service, block)),
    cols: List(track.Track),
    rows: List(track.Track),
    template: List(List(String)),
  )
}

pub const default_sp_cols: List(track.Track) = [track.Fr(1)]

pub const default_wide_cols: List(track.Track) = [
  track.Fr(1),
  track.Minmax(min: track.RemSize(12.0), max: track.RemSize(20.0)),
]

pub fn resolved_cols(
  frame: Frame(service, block),
  at: css.Breakpoint,
) -> List(track.Track) {
  case frame.cols {
    [] ->
      case at {
        css.SP -> default_sp_cols
        css.PC -> default_wide_cols
        css.Tablet -> default_wide_cols
      }
    cols -> cols
  }
}

pub fn resolved_template(
  sp: Frame(service, block),
  frame: Frame(service, block),
  at: css.Breakpoint,
) -> List(List(String)) {
  case frame.template {
    [] ->
      case at {
        css.SP -> list.map(frame.areas, fn(area) { [area.name] })
        css.PC -> default_wide_template(sp.areas, frame.areas)
        css.Tablet -> default_wide_template(sp.areas, frame.areas)
      }
    template -> template
  }
}

fn default_wide_template(
  sp_areas: List(Area),
  wide_areas: List(Area),
) -> List(List(String)) {
  let extra_areas =
    list.filter(wide_areas, fn(area) {
      case area_name_in(sp_areas, area.name) {
        True -> False
        False -> True
      }
    })
  let extra_names = list.map(extra_areas, fn(area) { area.name })
  let columns = list.length(extra_names) + 1
  list.map(sp_areas, fn(area) {
    let adjacent = extra_areas_after(wide_areas, area.name, extra_names, False)
    pad_row([area.name, ..adjacent], columns, area.name)
  })
}

fn extra_areas_after(
  areas: List(Area),
  target: String,
  extra_names: List(String),
  started: Bool,
) -> List(String) {
  case areas {
    [] -> []
    [area, ..rest] ->
      case started {
        True ->
          case area_name_in_names(extra_names, area.name) {
            True -> [
              area.name,
              ..extra_areas_after(rest, target, extra_names, True)
            ]
            False -> []
          }
        False ->
          case area.name == target {
            True -> extra_areas_after(rest, target, extra_names, True)
            False -> extra_areas_after(rest, target, extra_names, False)
          }
      }
  }
}

fn pad_row(row: List(String), columns: Int, name: String) -> List(String) {
  case list.length(row) >= columns {
    True -> row
    False -> pad_row(list.append(row, [name]), columns, name)
  }
}

fn area_name_in(areas: List(Area), name: String) -> Bool {
  list.any(areas, fn(area) { area.name == name })
}

fn area_name_in_names(names: List(String), name: String) -> Bool {
  list.any(names, fn(candidate) { candidate == name })
}

pub type Area {
  Area(name: String, flow: css.Flow, pin: css.Pin, style: List(css.Style))
}

pub type Placement(service, block) {
  Fixed(area: String, block: block, cell: Cell)
  Widget(area: String, name: String, of: service, render: Render(block))
}

pub type Cell {
  Flow
  Span(cols: Int, rows: Int)
  At(col: Int, row: Int, span: CellSpan)
}

pub type CellSpan {
  CellSpan(cols: Int, rows: Int)
}

pub type Target(service, attached) {
  Of(service)
  Entry(attached)
}

pub type Render(block) {
  One(block: block)
  ByKind(by: String, table: List(#(String, block)))
}
