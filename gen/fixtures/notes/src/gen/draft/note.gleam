//// GENERATED from entity.note [sha256:1603a38d9df4] — 手で編集しない

import gen/types/note_body.{type NoteBody}
import gen/types/note_id.{type NoteId}
import gen/types/note_title.{type NoteTitle}
import yumemi/time.{type Datetime}

pub type NoteDraft {
  NoteDraft(id: NoteId, title: NoteTitle, body: NoteBody, created_at: Datetime)
}

pub type NoteCreated {
  NoteCreated(
    id: NoteId,
    title: NoteTitle,
    body: NoteBody,
    created_at: Datetime,
  )
}
