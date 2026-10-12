//// Service note_edit ── 覚え書きの題と本文を直す。

// ★ src/service/note_edit.gleam
import gen/allow/note as allow
import gen/face.{type Face, Api}
import gen/root/note_edit.{type Actor, type Root, type Service, Service}
import gen/types/note_body.{type NoteBody}
import gen/types/note_id.{type NoteId}
import gen/types/note_title.{type NoteTitle}
import gen/verb
import yumemi/effect.{type Effect, Write}
import yumemi/step.{type Start, type Step}

pub const effect: Effect = Write

pub const faces: List(Face) = [Api]

pub type Args {
  Args(id: NoteId, title: NoteTitle, body: NoteBody)
}

pub type Error

pub const service: Service(Args, Nil, Error) = Service(
  allow: [
    allow.Clause(who: allow.Anyone, at: allow.AnyPhase, owner: allow.NoOwner),
  ],
  logic: logic,
)

pub fn logic(_by: Actor, it: Root, args: Args) -> Step(Nil, Error, Start) {
  use _ <- step.apply(verb.edit_note(it.note.id, args.title, args.body))
  step.done(Nil)
}
