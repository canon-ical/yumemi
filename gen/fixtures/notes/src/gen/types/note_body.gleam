//// GENERATED from types.note_body [sha256:b12ef82a04e6] — 手で編集しない

import gleam/result
import types
import yumemi/spec

pub opaque type NoteBody {
  NoteBody(value: String)
}

pub fn parse(raw: String) -> Result(NoteBody, spec.Error) {
  spec.validate(raw, types.note_body) |> result.map(NoteBody)
}

pub fn to_string(value: NoteBody) -> String {
  value.value
}
