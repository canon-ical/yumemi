//// GENERATED from entity declarations [sha256:fe4ede23cb20] — 手で編集しない

import entity/note
import gen/types/note_id.{type NoteId}
import yumemi/er.{type Key}

pub fn note(id: NoteId) -> Key(note.Note) {
  er.key(note_id.to_string(id))
}
