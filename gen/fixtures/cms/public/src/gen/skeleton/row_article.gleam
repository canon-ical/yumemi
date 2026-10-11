//// GENERATED from public/src/blocks/row_article.gleam [sha256:7f91276f0c6a] — 手で編集しない

import gen/out/widget_list
import gleam/string
import yumemi/front/el
import yumemi/front/html

pub type In =
  widget_list.Out

pub fn view(it: In) -> el.Element {
  html.div_([], [
    el.text("rows" <> ": " <> string.inspect(it.rows)),
  ])
}
