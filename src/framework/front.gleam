import framework/front/css
import framework/front/sketch_css
import framework/front/track
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/string

pub type Var {
  Var(name: String, from: From)
}

pub type From {
  Path(String)
  Query(String)
  Session(SessionKey)
  Origin(face: String)
  AuthOrigin
  /// 今描いている Page の route の綴り(例 `/rosters/:id`)。生成器が Page ごとに
  /// 知っている定数で、要求の URL の字(引数の実値・query)は入らない。Layout にも
  /// Page にも置ける ── Layout の帯の block がナビの今いる所を出すため。
  CurrentRoute
}

pub type SessionKey {
  SubjectHandle
  SubjectId
}

pub type Layout(service, block) {
  Layout(
    vars: List(Var),
    sp: Frame(service, block),
    pc: Option(Frame(service, block)),
    tablet: Option(Frame(service, block)),
  )
}

pub type Page(service, block) {
  Page(
    of: Option(service),
    layout: Layout(service, block),
    theme: Option(String),
    vars: List(Var),
    sp: Frame(service, block),
    pc: Option(Frame(service, block)),
    tablet: Option(Frame(service, block)),
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
  /// 格子の要素(`data-yumemi-grid`)そのものに Style を掛ける Frame。他の欄は
  /// `Frame` と同じ。`style: [style.shell]` に `css.Space(MinHeight, Dvh(100.0))` を
  /// 書き `rows` に `Fr(1)` を置けば、格子が画面の高さまで伸び本文の行が残りを埋める。
  /// sp の style は全幅に、pc・tablet の style はその幅の media の中に効く。Area の
  /// style と同じく `style` の定数で書く。列・行・gap は Frame の欄が書く(生成の CSS が
  /// 先に持つ)ので、style では他の性質を書く。
  StyledFrame(
    areas: List(Area),
    placements: List(Placement(service, block)),
    cols: List(track.Track),
    rows: List(track.Track),
    template: List(List(String)),
    style: List(css.Style),
  )
}

/// Frame の格子の要素に掛ける Style。`Frame` は空。
pub fn frame_style(frame: Frame(service, block)) -> List(css.Style) {
  case frame {
    Frame(..) -> []
    StyledFrame(style:, ..) -> style
  }
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

/// Area の `flow` を、生成される grid の CSS(その Area の規則)に書く宣言にする。
/// `Stack` は縦の flex で、中の block は幅いっぱいのまま(`align-items: stretch`)。
/// 各 variant は並びの向きまで書き切る ── pc・tablet の Frame で別の flow に替えても、
/// sp の規則の向きが残らない。
pub fn area_flow_css(flow: css.Flow) -> List(String) {
  case flow {
    css.Stack(gap:) -> [
      "display: flex;",
      "flex-direction: column;",
      "align-items: stretch;",
      "gap: " <> length_css(gap) <> ";",
    ]
    css.Row(gap:, wrap:) -> [
      "display: flex;",
      "flex-direction: row;",
      "flex-wrap: "
        <> case wrap {
        True -> "wrap"
        False -> "nowrap"
      }
        <> ";",
      "gap: " <> length_css(gap) <> ";",
    ]
    css.Grid(cols:, gap:) -> [
      "display: grid;",
      "grid-template-columns: repeat("
        <> int.to_string(cols)
        <> ", minmax(0, 1fr));",
      "gap: " <> length_css(gap) <> ";",
    ]
    css.GridTracks(cols:, gap:) -> [
      "display: grid;",
      "grid-template-columns: "
        <> string.join(list.map(cols, track.to_css), " ")
        <> ";",
      "gap: " <> length_css(gap) <> ";",
    ]
    css.Scroller -> [
      "display: flex;",
      "flex-direction: row;",
      "overflow-x: auto;",
    ]
  }
}

fn length_css(value: css.Length) -> String {
  sketch_css.length_to_string(value)
}

pub type Placement(service, block) {
  Fixed(area: String, block: block, cell: Cell)
  Widget(area: String, of: service, render: Render(block))
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
