//// GENERATED from public/src/layout.gleam [sha256:dcbfa6a66d1a] — 手で編集しない

import gen/out/widget_list
import gleam/option.{type Option}

pub type Data {
  Data(widget_list: Option(widget_list.Out))
}

pub fn load(widget_list: Option(widget_list.Out)) -> Data {
  Data(widget_list: widget_list)
}
