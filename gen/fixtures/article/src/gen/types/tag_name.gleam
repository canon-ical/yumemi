//// GENERATED from types.tag_name [sha256:f2f33ff2c712] — 手で編集しない

import gleam/result
import types
import yumemi/spec

pub opaque type TagName {
  TagName(value: String)
}

pub fn parse(raw: String) -> Result(TagName, spec.Error) {
  spec.validate(raw, types.tag_name) |> result.map(TagName)
}

pub fn to_string(value: TagName) -> String {
  value.value
}
