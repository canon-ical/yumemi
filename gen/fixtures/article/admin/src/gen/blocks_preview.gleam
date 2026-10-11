//// GENERATED from admin/src/{layout.gleam,pages/**/page.gleam,blocks/*.gleam} [sha256:5c5aa2e7d1f7] — 手で編集しない

import blocks/admin_header
import yumemi/front/el
import yumemi/front/html

pub fn view() -> el.Element {
  html.div_([el.attribute("data-yumemi-blocks-preview", "pc")], [
    html.div_([el.attribute("data-yumemi-area", "page")], [
      html.div_([], [
        el.text("blocks/admin_header | of Nil | Nil"),
        admin_header.view(Nil, admin_header.Arg(subject: "preview")),
      ]),
    ]),
  ])
}

pub fn render() -> el.Element {
  html.html([], [
    html.head([], []),
    html.body_([], [el.styled(fn() { view() }, "")]),
  ])
}
