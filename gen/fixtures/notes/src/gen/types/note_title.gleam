//// GENERATED from types.note_title [sha256:b12ef82a04e6] — 手で編集しない

import gleam/result
import types
import yumemi/spec

pub opaque type NoteTitle {
  NoteTitle(value: String)
}

pub fn parse(raw: String) -> Result(NoteTitle, spec.Error) {
  spec.validate(raw, types.note_title) |> result.map(NoteTitle)
}

pub fn to_string(value: NoteTitle) -> String {
  value.value
}
