//// Service note_delete ── 覚え書きを 1 件消す。

// ★ src/service/note_delete.gleam
import gen/allow/note as allow
import gen/face.{type Face, Api}
import gen/root/note_delete.{type Actor, type Root, type Service, Service}
import gen/types/note_id.{type NoteId}
import gen/verb
import yumemi/effect.{type Effect, Write}
import yumemi/step.{type Start, type Step}

pub const effect: Effect = Write

pub const faces: List(Face) = [Api]

pub type Args {
  Args(id: NoteId)
}

pub type Error

pub const service: Service(Args, Nil, Error) = Service(
  allow: [
    allow.Clause(who: allow.Anyone, at: allow.AnyPhase, owner: allow.NoOwner),
  ],
  logic: logic,
)

pub fn logic(_by: Actor, it: Root, _args: Args) -> Step(Nil, Error, Start) {
  use _ <- step.apply(verb.delete_note(it.note.id))
  step.done(Nil)
}
