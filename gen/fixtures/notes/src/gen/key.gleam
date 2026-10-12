//// GENERATED from entity declarations [sha256:54f6b8da8abb] — 手で編集しない

import entity/note
import gen/types/note_id.{type NoteId}
import yumemi/er.{type Key}

pub fn note(id: NoteId) -> Key(note.Note) {
  er.key(note_id.to_string(id))
}
