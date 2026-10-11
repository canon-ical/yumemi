//// GENERATED from public/src/blocks/feed.gleam [sha256:d9b74186d43c] — 手で編集しない

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
