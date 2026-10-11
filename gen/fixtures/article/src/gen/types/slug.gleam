//// GENERATED from types.slug [sha256:f2f33ff2c712] — 手で編集しない

import gleam/result
import types
import yumemi/spec

pub opaque type Slug {
  Slug(value: String)
}

pub fn parse(raw: String) -> Result(Slug, spec.Error) {
  spec.validate(raw, types.slug) |> result.map(Slug)
}

pub fn to_string(value: Slug) -> String {
  value.value
}
