//// GENERATED from public/src/blocks/row_article.gleam [sha256:f43a7257e45a] — 手で編集しない

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
