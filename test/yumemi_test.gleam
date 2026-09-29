import framework/front
import framework/front/css
import framework/front/el
import framework/front/sketch_css as front_sketch_css
import framework/front/track
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import lustre/element as lustre_element
import sketch
import sketch/css as sketch_class

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
  vars_are_typed_sources()
  calls_use_one_target_shape()
  frame_defaults_resolve_from_empty_fields()
  fixed_cells_and_grid_tracks_are_typed()
  overlay_pin_is_supported()
  area_overlay_controls_share_the_area_id()
  badge_counts_keep_the_same_dom_shape()
  each_modals_use_stable_scoped_ids()
  look_background_border_and_outline_render_to_css()
  look_min_max_named_family_and_weight_render_to_css()
  look_crop_renders_to_css()
  look_styles_work_inside_state_and_responsive()
  look_styles_reach_island_shadow_style()
  io.println("Framework checks passed: 13 groups")
}

fn vars_are_typed_sources() {
  let layout: front.Layout(Service, Block) =
    front.Layout(
      vars: [
        front.Var(name: "idp_origin", from: front.AuthOrigin),
        front.Var(name: "www_origin", from: front.Origin(face: "www")),
      ],
      sp: empty_frame(),
      pc: None,
      tablet: None,
    )
  let page: front.Page(Service, Block) =
    front.Page(
      of: Some(ArticleRead),
      layout: layout,
      theme: None,
      vars: [
        front.Var(name: "muse", from: front.Path("muse")),
        front.Var(name: "range", from: front.Query("range")),
        front.Var(name: "subject", from: front.Session(front.SubjectHandle)),
      ],
      sp: empty_frame(),
      pc: None,
      tablet: None,
    )
  let page_vars: List(front.Var) = page.vars
  let layout_vars: List(front.Var) = layout.vars
  assert_equal(
    page_vars,
    [
      front.Var(name: "muse", from: front.Path("muse")),
      front.Var(name: "range", from: front.Query("range")),
      front.Var(name: "subject", from: front.Session(front.SubjectHandle)),
    ],
    "Page.vars",
  )
  assert_equal(
    layout_vars,
    [
      front.Var(name: "idp_origin", from: front.AuthOrigin),
      front.Var(name: "www_origin", from: front.Origin(face: "www")),
    ],
    "Layout.vars",
  )
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
  assert_equal(track.to_css(track.Auto), "auto", "automatic track CSS")
  assert_equal(track.to_css(track.Rem(1.5)), "1.5rem", "rem track CSS")
  assert_equal(track.to_css(track.Px(16.0)), "16.0px", "pixel track CSS")
  assert_equal(
    track.to_css(track.Minmax(min: track.RemSize(12.0), max: track.AutoSize)),
    "minmax(12.0rem, auto)",
    "minmax track CSS",
  )
  assert_equal(list.length(rendered), 3, "GridTracks CSS styles")
}

fn overlay_pin_is_supported() {
  let overlay =
    front.Area(
      name: "dialog",
      flow: css.Stack(gap: css.Rem(0.0)),
      pin: css.Overlay,
      style: [],
    )
  assert_equal(overlay.pin, css.Overlay, "Overlay Pin constructor")
}

fn area_overlay_controls_share_the_area_id() {
  let opener = el.opener("settings", [el.text("Open")])
  let closer = el.closer("settings", [el.text("Close")])
  let opener_html = lustre_element.to_string(opener)
  let closer_html = lustre_element.to_string(closer)

  assert_equal(
    el.overlay_id_prefix,
    "yumemi-overlay-",
    "area overlay id prefix",
  )
  assert_equal(
    string.contains(opener_html, "popovertarget=\"yumemi-overlay-settings\""),
    True,
    "area opener target",
  )
  assert_equal(
    string.contains(opener_html, "popovertargetaction=\"show\""),
    True,
    "area opener action",
  )
  assert_equal(
    string.contains(closer_html, "popovertarget=\"yumemi-overlay-settings\""),
    True,
    "area closer target",
  )
  assert_equal(
    string.contains(closer_html, "popovertargetaction=\"hide\""),
    True,
    "area closer action",
  )
}

fn badge_counts_keep_the_same_dom_shape() {
  let no_count =
    el.badge(None, [el.text("Inbox")])
    |> lustre_element.to_string
  let zero_count =
    el.badge(Some(0), [el.text("Inbox")])
    |> lustre_element.to_string
  let positive_count =
    el.badge(Some(3), [el.text("Inbox")])
    |> lustre_element.to_string

  assert_equal(
    no_count,
    "<span data-count data-yumemi-badge>Inbox</span>",
    "None badge markup",
  )
  assert_equal(
    zero_count,
    "<span data-count=\"0\" data-yumemi-badge>Inbox</span>",
    "Some(0) badge markup",
  )
  assert_equal(
    positive_count,
    "<span data-count=\"3\" data-yumemi-badge>Inbox</span>",
    "Some(3) badge markup",
  )
}

fn each_modals_use_stable_scoped_ids() {
  let rendered = render_two_each_modals()
  let first_id = "yumemi-row-overlay-8-list-one-8-same-row"
  let second_id = "yumemi-row-overlay-8-list-two-8-same-row"

  assert_equal(first_id == second_id, False, "different list scopes")
  assert_equal(
    list.length(string.split(rendered, on: first_id)),
    4,
    "first id is shared by opener, closer, and popover",
  )
  assert_equal(
    list.length(string.split(rendered, on: second_id)),
    4,
    "second id is shared by opener, closer, and popover",
  )
  assert_equal(
    string.contains(rendered, "id=\"" <> first_id <> "\" popover"),
    True,
    "first row modal is a native popover",
  )
  assert_equal(
    string.contains(rendered, "id=\"" <> second_id <> "\" popover"),
    True,
    "second row modal is a native popover",
  )
  assert_equal(
    rendered,
    render_two_each_modals(),
    "same row inputs render the same ids",
  )
}

fn render_two_each_modals() -> String {
  let first_list =
    el.each(["same-row"], fn(row_key) {
      el.each_modal(
        "list-one",
        row_key,
        [el.text("Open first")],
        [el.text("Close first")],
        [el.text("First body")],
      )
    })
  let second_list =
    el.each(["same-row"], fn(row_key) {
      el.each_modal(
        "list-two",
        row_key,
        [el.text("Open second")],
        [el.text("Close second")],
        [el.text("Second body")],
      )
    })

  lustre_element.fragment([first_list, second_list])
  |> lustre_element.to_string
}

// ── yumemi-look(0.11.7)── Style に足した見た目の語彙 7 つ ─────────────────

@external(javascript, "./yumemi_look_ffi.mjs", "island_shadow_style")
fn island_shadow_style(class: sketch_class.Class) -> String

fn css_of(styles: List(css.Style)) -> String {
  let assert Ok(sheet) = sketch.stylesheet(strategy: sketch.Ephemeral)
  let #(sheet, _) = sketch.class_name(front_sketch_css.class(styles), sheet)
  sketch.render(sheet)
}

fn look_background_border_and_outline_render_to_css() {
  let background = css_of([css.Background("var(--ma-color-bg)")])
  assert_contains(
    background,
    "background-color: var(--ma-color-bg);",
    "Background renders background-color",
  )
  let mixed = css_of([css.Background("color-mix(in srgb, #000 50%, #fff)")])
  assert_contains(
    mixed,
    "background-color: color-mix(in srgb, #000 50%, #fff);",
    "Background passes color-mix through",
  )
  let around =
    css_of([
      css.Border(
        edge: css.AllEdges,
        width: css.Px(1.0),
        style: css.Solid,
        color: "var(--ma-color-line)",
      ),
    ])
  assert_contains(
    around,
    "border: 1.0px solid var(--ma-color-line);",
    "Border AllEdges renders border",
  )
  let tab_underline =
    css_of([
      css.Border(
        edge: css.BottomEdge,
        width: css.Px(2.0),
        style: css.Dashed,
        color: "#b92c22",
      ),
    ])
  assert_contains(
    tab_underline,
    "border-bottom: 2.0px dashed #b92c22;",
    "Border BottomEdge renders the 2px tab underline",
  )
  let outline =
    css_of([
      css.Outline(
        width: css.Px(3.0),
        offset: css.Px(3.0),
        color: "var(--ma-color-focus)",
      ),
    ])
  assert_contains(outline, "outline-width: 3.0px;", "Outline width")
  assert_contains(
    outline,
    "outline-offset: 3.0px;",
    "Outline offset reaches 3px outside",
  )
  assert_contains(
    outline,
    "outline-color: var(--ma-color-focus);",
    "Outline color",
  )
}

fn look_min_max_named_family_and_weight_render_to_css() {
  let sizes =
    css_of([
      css.Space(property: css.MinHeight, value: css.Rem(12.0)),
      css.Space(property: css.MinWidth, value: css.Px(320.0)),
      css.Space(property: css.MaxWidth, value: css.Rem(60.0)),
    ])
  assert_contains(sizes, "min-height: 12.0rem;", "min-height")
  assert_contains(sizes, "min-width: 320.0px;", "min-width")
  assert_contains(sizes, "max-width: 60.0rem;", "max-width")
  let text =
    css_of([
      css.Text(
        family: css.Named("var(--ma-font-ui)"),
        size: css.Rem(1.0),
        weight: css.SemiBold,
        line_height: css.Rem(1.5),
      ),
    ])
  assert_contains(
    text,
    "font-family: var(--ma-font-ui);",
    "Named family passes a CSS variable through",
  )
  assert_contains(text, "font-weight: 600;", "SemiBold renders 600")
  let named_family =
    css_of([
      css.Text(
        family: css.Named("\"Noto Sans JP\", sans-serif"),
        size: css.Rem(1.0),
        weight: css.Normal,
        line_height: css.Rem(1.5),
      ),
    ])
  assert_contains(
    named_family,
    "font-family: \"Noto Sans JP\", sans-serif;",
    "Named family names Noto Sans JP",
  )
}

fn look_crop_renders_to_css() {
  let crop =
    css_of([
      css.Crop(fit: css.Cover, ratio: css.Ratio(width: 16.0, height: 9.0)),
    ])
  assert_contains(crop, "object-fit: cover;", "Crop renders object-fit")
  assert_contains(
    crop,
    "aspect-ratio: 16.0 / 9.0;",
    "Crop renders aspect-ratio",
  )
}

fn look_styles_work_inside_state_and_responsive() {
  let focused =
    css_of([
      css.State(css.Focus, [
        css.Outline(
          width: css.Px(3.0),
          offset: css.Px(3.0),
          color: "var(--ma-color-focus)",
        ),
        css.Background("var(--ma-color-focus-bg)"),
      ]),
    ])
  assert_contains(focused, ":focus", "State Focus selector")
  assert_contains(
    focused,
    "outline-offset: 3.0px;",
    "Outline inside State(Focus)",
  )
  assert_contains(
    focused,
    "background-color: var(--ma-color-focus-bg);",
    "Background inside State(Focus)",
  )
  let pc =
    css_of([
      css.Responsive(css.PC, [
        css.Border(
          edge: css.BottomEdge,
          width: css.Px(2.0),
          style: css.Solid,
          color: "var(--ma-color-line)",
        ),
        css.Space(property: css.MaxWidth, value: css.Rem(60.0)),
      ]),
    ])
  assert_contains(pc, "@media", "Responsive PC media query")
  assert_contains(
    pc,
    "border-bottom: 2.0px solid var(--ma-color-line);",
    "Border inside Responsive(PC)",
  )
  assert_contains(pc, "max-width: 60.0rem;", "MaxWidth inside Responsive(PC)")
}

fn look_styles_reach_island_shadow_style() {
  let class =
    front_sketch_css.class([
      css.Background("var(--ma-color-bg)"),
      css.Border(
        edge: css.BottomEdge,
        width: css.Px(2.0),
        style: css.Solid,
        color: "var(--ma-color-line)",
      ),
      css.Outline(
        width: css.Px(3.0),
        offset: css.Px(3.0),
        color: "var(--ma-color-focus)",
      ),
      css.Crop(fit: css.Cover, ratio: css.Ratio(width: 1.0, height: 1.0)),
    ])
  let html = island_shadow_style(class)
  assert_contains(html, "<style>", "island renders a shadow style tag")
  assert_contains(
    html,
    "background-color: var(--ma-color-bg);",
    "island style has the new Background",
  )
  assert_contains(
    html,
    "border-bottom: 2.0px solid var(--ma-color-line);",
    "island style has the new Border",
  )
  assert_contains(
    html,
    "outline-offset: 3.0px;",
    "island style has the new Outline",
  )
  assert_contains(html, "object-fit: cover;", "island style has the new Crop")
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

fn assert_contains(haystack: String, needle: String, _label: String) -> Nil {
  case string.contains(haystack, needle) {
    True -> Nil
    False -> panic as "test failed"
  }
}
