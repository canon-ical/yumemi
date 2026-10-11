//// GENERATED from public/src/layout.gleam [sha256:2dd6c1c1480d] — 手で編集しない

import gen/out/widget_list
import gleam/option.{type Option}

pub type Data {
  Data(widget_list: Option(widget_list.Out))
}

pub fn load(widget_list: Option(widget_list.Out)) -> Data {
  Data(widget_list: widget_list)
}
