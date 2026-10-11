//// Keyset pagination; transformations preserve the cursor.

import gleam/list
import gleam/option.{type Option}

pub opaque type Cursor {
  Cursor(value: String)
}

pub type Page(item) {
  Page(items: List(item), next: Option(Cursor))
}

pub fn cursor(raw: String) -> Result(Cursor, Nil) {
  case raw {
    "" -> Error(Nil)
    _ -> Ok(Cursor(raw))
  }
}

pub fn cursor_to_string(value: Cursor) -> String {
  value.value
}

pub fn map(page: Page(a), transform: fn(a) -> b) -> Page(b) {
  Page(items: list.map(page.items, transform), next: page.next)
}
