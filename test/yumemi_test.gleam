import framework/front
import framework/front/css
import framework/front/sketch_css as front_sketch_css
import framework/front/track
import gleam/io
import gleam/list
import gleam/option.{None, Some}

pub type Service {
  ArticleRead
  SubscriptionRead
}

pub type Block {
  ArticleBlock
}

pub type Attached {
  SessionRead
}

pub fn main() {
  reads_are_typed_service_lists()
  calls_use_one_target_shape()
  frame_defaults_resolve_from_empty_fields()
  fixed_cells_and_grid_tracks_are_typed()
  io.println("Framework checks passed: 4 groups, 23 assertions")
}

fn reads_are_typed_service_lists() {
  let layout: front.Layout(Service, Block) =
    front.Layout(sp: empty_frame(), pc: None, tablet: None, reads: [
      ArticleRead,
      SubscriptionRead,
    ])
  let page: front.Page(Service, Block) =
    front.Page(
      of: Some(ArticleRead),
      layout: layout,
      theme: None,
      sp: empty_frame(),
      pc: None,
      tablet: None,
      reads: [ArticleRead, SubscriptionRead],
    )
  let page_reads: List(Service) = page.reads
  let layout_reads: List(Service) = layout.reads
  assert_equal(page_reads, [ArticleRead, SubscriptionRead], "Page.reads")
  assert_equal(layout_reads, [ArticleRead, SubscriptionRead], "Layout.reads")
}

fn calls_use_one_target_shape() {
  let calls: List(front.Target(Service, Attached)) = [
    front.Of(ArticleRead),
    front.Entry(SessionRead),
  ]
  let service_only_calls: List(front.Target(Service, Nil)) = [
    front.Of(ArticleRead),
  ]
  assert_equal(
    calls,
    [front.Of(ArticleRead), front.Entry(SessionRead)],
    "Target call list",
  )
  assert_equal(
    service_only_calls,
    [front.Of(ArticleRead)],
    "service-only Target call list",
  )
}

fn frame_defaults_resolve_from_empty_fields() {
  let sp =
    front.Frame(
      areas: [area("header"), area("page"), area("footer")],
      placements: [],
      cols: [],
      rows: [],
      template: [],
    )
  let pc =
    front.Frame(
      areas: [area("header"), area("page"), area("aside"), area("footer")],
      placements: [],
      cols: [],
      rows: [],
      template: [],
    )
  let custom =
    front.Frame(
      areas: [],
      placements: [],
      cols: [track.Rem(1.5)],
      rows: [track.Px(24.0)],
      template: [["content", "aside"]],
    )
  let sp_cols: List(track.Track) = front.resolved_cols(sp, css.SP)
  let pc_cols: List(track.Track) = front.resolved_cols(pc, css.PC)

  assert_equal(sp.cols, [], "empty SP cols")
  assert_equal(sp.rows, [], "empty rows")
  assert_equal(sp.template, [], "empty template")
  assert_equal(sp_cols, [track.Fr(1)], "SP single-column default")
  assert_equal(
    pc_cols,
    [
      track.Fr(1),
      track.Minmax(min: track.RemSize(12.0), max: track.RemSize(20.0)),
    ],
    "PC columns default",
  )
  assert_equal(
    front.resolved_template(sp, sp, css.SP),
    [["header"], ["page"], ["footer"]],
    "SP row stacking default",
  )
  assert_equal(
    front.resolved_template(sp, pc, css.PC),
    [["header", "header"], ["page", "aside"], ["footer", "footer"]],
    "PC area default",
  )
  assert_equal(
    front.resolved_cols(custom, css.PC),
    [track.Rem(1.5)],
    "explicit columns",
  )
  assert_equal(custom.rows, [track.Px(24.0)], "explicit rows")
  assert_equal(
    front.resolved_template(sp, custom, css.PC),
    [["content", "aside"]],
    "explicit template",
  )
}

fn fixed_cells_and_grid_tracks_are_typed() {
  let flow_cell: front.Placement(Service, Block) =
    front.Fixed(area: "page", block: ArticleBlock, cell: front.Flow)
  let span_cell: front.Placement(Service, Block) =
    front.Fixed(
      area: "page",
      block: ArticleBlock,
      cell: front.Span(cols: 2, rows: 1),
    )
  let placed_cell: front.Placement(Service, Block) =
    front.Fixed(
      area: "page",
      block: ArticleBlock,
      cell: front.At(col: 2, row: 1, span: front.CellSpan(cols: 2, rows: 1)),
    )
  let old_grid: css.Flow = css.Grid(cols: 3, gap: css.Rem(1.0))
  let tracks = [
    track.Fr(1),
    track.Minmax(min: track.RemSize(12.0), max: track.RemSize(20.0)),
  ]
  let new_grid: css.Flow = css.GridTracks(cols: tracks, gap: css.Rem(1.0))
  let rendered = front_sketch_css.to_sketch(css.Flow(new_grid))

  assert_equal(
    flow_cell,
    front.Fixed(area: "page", block: ArticleBlock, cell: front.Flow),
    "Fixed Flow cell",
  )
  assert_equal(
    span_cell,
    front.Fixed(
      area: "page",
      block: ArticleBlock,
      cell: front.Span(cols: 2, rows: 1),
    ),
    "Fixed Span cell",
  )
  assert_equal(
    placed_cell,
    front.Fixed(
      area: "page",
      block: ArticleBlock,
      cell: front.At(col: 2, row: 1, span: front.CellSpan(cols: 2, rows: 1)),
    ),
    "Fixed At cell",
  )
  assert_equal(old_grid, css.Grid(cols: 3, gap: css.Rem(1.0)), "legacy Grid")
  assert_equal(track.to_css(track.Fr(1)), "1fr", "fractional track CSS")
  assert_equal(track.to_css(track.Rem(1.5)), "1.5rem", "rem track CSS")
  assert_equal(track.to_css(track.Px(16.0)), "16.0px", "pixel track CSS")
  assert_equal(
    track.to_css(track.Minmax(
      min: track.RemSize(12.0),
      max: track.RemSize(20.0),
    )),
    "minmax(12.0rem, 20.0rem)",
    "minmax track CSS",
  )
  assert_equal(list.length(rendered), 3, "GridTracks CSS styles")
}

fn empty_frame() -> front.Frame(Service, Block) {
  front.Frame(areas: [], placements: [], cols: [], rows: [], template: [])
}

fn area(name: String) -> front.Area {
  front.Area(
    name: name,
    flow: css.Stack(gap: css.Rem(0.0)),
    pin: css.NoPin,
    style: [],
  )
}

fn assert_equal(actual: a, expected: a, _label: String) -> Nil {
  case actual == expected {
    True -> Nil
    False -> panic as "test failed"
  }
}
