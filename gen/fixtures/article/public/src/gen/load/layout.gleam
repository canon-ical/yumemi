//// GENERATED from public/src/layout.gleam [sha256:05838fe44232] — 手で編集しない

import gen/out/widget_list
import gleam/option.{type Option}

pub type Data {
  Data(article_feed: Option(widget_list.Out))
}

pub fn load(article_feed: Option(widget_list.Out)) -> Data {
  Data(article_feed: article_feed)
}
