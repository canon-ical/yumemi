//// GENERATED from entity declarations [sha256:7e3f483b7578] — 手で編集しない

import gen/draft/note as draft_note
import gen/types/note_body.{type NoteBody}
import gen/types/note_id.{type NoteId}
import gen/types/note_title.{type NoteTitle}
import yumemi/io.{type Context, type Promise}
import yumemi/time.{type Datetime}
import yumemi/verb.{type Verb}

@external(javascript, "./operations_ffi.mjs", "stage")
fn stage(ctx: Context, name: String, input: a) -> Promise(b)

pub fn create_note(
  input: draft_note.NoteDraft,
) -> Verb(draft_note.NoteCreated) {
  verb.staged(fn(ctx) { stage(ctx, "create_note", input) })
}

pub fn update_note_created_at(id: NoteId, created_at: Datetime) -> Verb(Nil) {
  verb.staged(fn(ctx) {
    stage(ctx, "update_note_created_at", #(id, created_at))
  })
}

pub fn edit_note(id: NoteId, title: NoteTitle, body: NoteBody) -> Verb(Nil) {
  verb.staged(fn(ctx) { stage(ctx, "edit_note", #(id, title, body)) })
}

pub fn delete_note(id: NoteId) -> Verb(Nil) {
  verb.staged(fn(ctx) { stage(ctx, "delete_note", id) })
}
