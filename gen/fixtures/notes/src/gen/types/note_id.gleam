//// GENERATED from types.note_id [sha256:b12ef82a04e6] — 手で編集しない

import gleam/result
import types
import yumemi/spec

pub opaque type NoteId {
  NoteId(value: String)
}

pub fn parse(raw: String) -> Result(NoteId, spec.Error) {
  spec.validate(raw, types.note_id) |> result.map(NoteId)
}

pub fn to_string(value: NoteId) -> String {
  value.value
}
