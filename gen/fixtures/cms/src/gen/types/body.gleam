//// GENERATED from types.body [sha256:f2f33ff2c712] — 手で編集しない

import gleam/result
import types
import yumemi/spec

pub opaque type Body {
  Body(value: String)
}

pub fn parse(raw: String) -> Result(Body, spec.Error) {
  spec.validate(raw, types.body) |> result.map(Body)
}

pub fn to_string(value: Body) -> String {
  value.value
}
