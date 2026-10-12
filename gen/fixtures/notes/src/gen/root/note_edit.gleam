//// GENERATED from service.note_edit [sha256:2f0e7a85f2c5] — 手で編集しない

import entity/note
import gen/allow/note as allow
import yumemi/step
import yumemi/time.{type Datetime}

pub type Actor =
  allow.Actor

pub type Root {
  Root(note: note.Note, at: Datetime, seed: String)
}

pub type Service(args, out, err) {
  Service(
    allow: List(allow.Clause),
    logic: fn(Actor, Root, args) -> step.Step(out, err, step.Start),
  )
}
