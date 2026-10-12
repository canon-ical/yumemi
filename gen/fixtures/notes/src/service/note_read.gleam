//// Service note_read ── 覚え書きを 1 件読む。

// ★ src/service/note_read.gleam
import entity/note
import gen/allow/note as allow
import gen/face.{type Face, Api}
import gen/root/note_read.{type Actor, type Root, type Service, Service}
import gen/types/note_id.{type NoteId}
import yumemi/effect.{type Effect, Read}
import yumemi/step.{type Start, type Step}

pub const effect: Effect = Read

pub const faces: List(Face) = [Api]

pub type Args {
  Args(id: NoteId)
}

pub type Error

pub const service: Service(Args, note.Note, Error) = Service(
  allow: [
    allow.Clause(who: allow.Anyone, at: allow.AnyPhase, owner: allow.NoOwner),
  ],
  logic: logic,
)

pub fn logic(
  _by: Actor,
  it: Root,
  _args: Args,
) -> Step(note.Note, Error, Start) {
  step.done(it.note)
}
