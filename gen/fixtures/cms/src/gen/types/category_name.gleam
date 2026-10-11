//// GENERATED from types.category_name [sha256:f2f33ff2c712] — 手で編集しない

import gleam/result
import types
import yumemi/spec

pub opaque type CategoryName {
  CategoryName(value: String)
}

pub fn parse(raw: String) -> Result(CategoryName, spec.Error) {
  spec.validate(raw, types.category_name) |> result.map(CategoryName)
}

pub fn to_string(value: CategoryName) -> String {
  value.value
}
