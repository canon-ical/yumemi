//// GENERATED from admin/src/pages/home/page.gleam [sha256:38b74da7dca1] — 手で編集しない

import blocks/admin_header
import framework/front/css
import framework/front/sketch_css
import gen/load/layout
import gleam/list
import lustre/attribute
import lustre/element/html as raw_html
import sketch
import sketch/css as raw_css
import sketch/lustre as sketch_lustre
import sketch/lustre/element
import sketch/lustre/element/html
import style

pub type Vars {
  Vars(subject: String)
}

pub type Data {
  Data(layout: layout.Data, vars: Vars)
}

pub fn load(vars: Vars) -> Data {
  Data(layout: layout.load(), vars: vars)
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
      raw_html.title([], "yumemi admin fixture"),
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
    styled_area("page", style.page, page_children(it)),
  ])
}

fn page_children(it: Data) -> List(element.Element(Nil)) {
  [
    html.div_(
      [attribute.attribute("data-yumemi-grid", "page:pages/home/page")],
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

fn page_placement_0(it: Data) -> List(element.Element(Nil)) {
  [admin_header.view(Nil, admin_header.Arg(subject: it.vars.subject))]
}
