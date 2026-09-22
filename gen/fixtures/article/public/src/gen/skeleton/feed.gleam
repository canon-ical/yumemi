//// GENERATED from public/src/blocks/feed.gleam [sha256:76cc358704ae] — 手で編集しない

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
