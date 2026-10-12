//// Service note_create ── 覚え書きを 1 件足す。誰でも書ける。id は要求の seed(UUID)から作る。

// ★ src/service/note_create.gleam
import gen/allow/note as allow
import gen/draft/note.{type NoteCreated, NoteDraft} as note_draft
import gen/face.{type Face, Api}
import gen/root/note_create.{type Actor, type Root, type Service, Service}
import gen/types/note_body.{type NoteBody}
import gen/types/note_id
import gen/types/note_title.{type NoteTitle}
import gen/verb
import yumemi/effect.{type Effect, Write}
import yumemi/step.{type Start, type Step}

pub const effect: Effect = Write

pub const faces: List(Face) = [Api]

pub type Args {
  Args(title: NoteTitle, body: NoteBody)
}

pub type Error

pub const service: Service(Args, NoteCreated, Error) = Service(
  allow: [
    allow.Clause(who: allow.Anyone, at: allow.AnyPhase, owner: allow.NoOwner),
  ],
  logic: logic,
)

pub fn logic(
  _by: Actor,
  it: Root,
  args: Args,
) -> Step(NoteCreated, Error, Start) {
  let assert Ok(id) = note_id.parse(it.seed)
  use created <- step.apply(
    verb.create_note(NoteDraft(
      id: id,
      title: args.title,
      body: args.body,
      created_at: it.at,
    )),
  )
  step.done(created)
}
