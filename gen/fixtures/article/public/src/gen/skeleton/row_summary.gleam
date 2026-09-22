//// GENERATED from public/src/blocks/row_summary.gleam [sha256:afdb74236ed0] — 手で編集しない

import framework/front/el
import gen/out/widget_list
import gleam/string
import sketch/lustre/element/html

pub type In = widget_list.Out

pub fn view(it: In) -> el.Element(Nil) {
  html.div_([], [
    el.text("rows" <> ": " <> string.inspect(it.rows)),
  ])
}
