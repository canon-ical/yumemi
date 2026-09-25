//// GENERATED from public/src/pages/status/page.gleam [sha256:4132bcde7cd7] — 手で編集しない

import blocks/feed
import blocks/site_header
import framework/front/css
import framework/front/sketch_css
import gen/load/layout
import gen/out/widget_list
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element/html as raw_html
import sketch
import sketch/css as raw_css
import sketch/lustre as sketch_lustre
import sketch/lustre/element
import sketch/lustre/element/html
import style

pub type Vars {
  Vars(www_origin: String, auth_origin: String)
}

pub type Data {
  Data(layout: layout.Data, vars: Vars)
}

pub fn load(vars: Vars, widget_list: Option(widget_list.Out)) -> Data {
  Data(layout: layout.load(widget_list), vars: vars)
}

pub fn render(it: Data) -> element.Element(Nil) {
  let assert Ok(stylesheet) =
    sketch_lustre.construct(fn(stylesheet) {
      sketch.global(stylesheet, theme_global())
    })
  let output = render_view(stylesheet, fn() { view(it) })
  let assert Ok(_) = sketch_lustre.teardown(stylesheet)
  output
}

fn render_view(
  stylesheet: sketch.StyleSheet,
  body: fn() -> element.Element(Nil),
) -> element.Element(Nil) {
  let styled_body =
    sketch_lustre.render(stylesheet, in: [sketch_lustre.node()], after: body)

  raw_html.html([attribute.attribute("lang", "ja")], [
    raw_html.head([], [
      raw_html.meta([attribute.attribute("charset", "utf-8")]),
      raw_html.meta([
        attribute.attribute("name", "viewport"),
        attribute.attribute(
          "content",
          "width=device-width, initial-scale=1, viewport-fit=cover",
        ),
      ]),
      raw_html.title([], "yumemi front fixture"),
    ]),
    raw_html.body([], [styled_body]),
  ])
}

fn theme_global() -> raw_css.Global {
  let #(background, background_image, text, accent) = #(
    "#FAF7F0",
    "none",
    "#3D2419",
    "#A93632",
  )

  raw_css.global("body", [
    raw_css.property("--bg", background),
    raw_css.property("--bg-image", background_image),
    raw_css.property("--text", text),
    raw_css.property("--accent", accent),
  ])
}

pub fn view(it: Data) -> element.Element(Nil) {
  html.div_([attribute.attribute("data-yumemi-grid", "layout")], [
    styled_area("header", style.bar, layout_placement_0(it)),
    styled_area(
      "page",
      style.page,
      list.flatten([layout_placement_1(it), page_children(it)]),
    ),
    styled_area("footer", style.bar, []),
  ])
}

fn page_children(it: Data) -> List(element.Element(Nil)) {
  [
    html.div_(
      [attribute.attribute("data-yumemi-grid", "page:pages/status/page")],
      list.flatten([
        [styled_area("page", style.page, page_placement_0(it))],
      ]),
    ),
  ]
}

fn styled_area(
  name: String,
  styles: List(css.Style),
  children: List(element.Element(Nil)),
) -> element.Element(Nil) {
  html.div(
    sketch_css.class(styles),
    [attribute.attribute("data-yumemi-area", name)],
    children,
  )
}

fn layout_placement_0(_it: Data) -> List(element.Element(Nil)) {
  [site_header.view(Nil)]
}

fn layout_placement_1(it: Data) -> List(element.Element(Nil)) {
  case it.layout.widget_list {
    Some(out) -> [feed.view(out)]
    None -> []
  }
}

fn page_placement_0(_it: Data) -> List(element.Element(Nil)) {
  [site_header.view(Nil)]
}
