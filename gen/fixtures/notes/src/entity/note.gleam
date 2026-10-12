//// Entity Note ── 覚え書き 1 件。主体も相も持たない。

// ★ src/entity/note.gleam
import gen/types/note_body.{type NoteBody}
import gen/types/note_id.{type NoteId}
import gen/types/note_title.{type NoteTitle}
import yumemi/time.{type Datetime}
import yumemi/verbs

pub type Note {
  Note(id: NoteId, title: NoteTitle, body: NoteBody, created_at: Datetime)
}

pub fn key(it: Note) -> NoteId {
  it.id
}

pub const collection: String = "notes"

pub const verbs: List(verbs.Rule(Nil)) = [
  verbs.Update(name: "edit", fields: ["title", "body"], at: verbs.AnyPhase),
]
