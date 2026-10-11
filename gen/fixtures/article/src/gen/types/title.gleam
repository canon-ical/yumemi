//// GENERATED from types.title [sha256:f2f33ff2c712] — 手で編集しない

import gleam/result
import types
import yumemi/spec

pub opaque type Title {
  Title(value: String)
}

pub fn parse(raw: String) -> Result(Title, spec.Error) {
  spec.validate(raw, types.title) |> result.map(Title)
}

pub fn to_string(value: Title) -> String {
  value.value
}
