//// GENERATED from admin/src/{layout.gleam,pages/**/page.gleam,blocks/*.gleam} [sha256:5eda0a4ec120] — 手で編集しない

import blocks/admin_header
import framework/front/el
import lustre/attribute
import lustre/element/html as raw_html
import sketch/lustre as sketch_lustre
import sketch/lustre/element
import sketch/lustre/element/html

pub fn view() -> element.Element(Nil) {
  html.div_([attribute.attribute("data-yumemi-blocks-preview", "pc")], [
    html.div_([attribute.attribute("data-yumemi-area", "page")], [
      html.div_([], [
        el.text("blocks/admin_header | of Nil | Nil"),
        admin_header.view(Nil, admin_header.Arg(subject: "preview")),
      ]),
    ]),
  ])
}

pub fn render() -> element.Element(Nil) {
  let assert Ok(stylesheet) =
    sketch_lustre.construct(fn(stylesheet) { stylesheet })
  let output =
    sketch_lustre.render(stylesheet, in: [sketch_lustre.node()], after: fn() {
      view()
    })
  let assert Ok(_) = sketch_lustre.teardown(stylesheet)
  raw_html.html([], [
    raw_html.head([], []),
    raw_html.body([], [output]),
  ])
}
