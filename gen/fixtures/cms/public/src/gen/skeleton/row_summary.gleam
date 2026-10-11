//// GENERATED from public/src/blocks/row_summary.gleam [sha256:ff8e436807e8] — 手で編集しない

import gen/out/widget_list
import gleam/string
import sketch/lustre/element/html
import yumemi/front/el

pub type In =
  widget_list.Out

pub fn view(it: In) -> el.Element(Nil) {
  html.div_([], [
    el.text("rows" <> ": " <> string.inspect(it.rows)),
  ])
}
