//// GENERATED from public/src/blocks/summary.gleam [sha256:445557a0840d] — 手で編集しない

import framework/front/el
import gen/out/article_read
import gleam/string
import sketch/lustre/element/html

pub type In =
  article_read.Out

pub fn view(it: In) -> el.Element(Nil) {
  html.div_([], [
    el.text("article" <> ": " <> string.inspect(it.article)),
    el.text("category" <> ": " <> string.inspect(it.category)),
    el.text("tags" <> ": " <> string.inspect(it.tags)),
    el.text("theme" <> ": " <> string.inspect(it.theme)),
  ])
}
