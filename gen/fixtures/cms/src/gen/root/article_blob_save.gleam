//// GENERATED from service.article_blob_save [sha256:1570ec33f9ef] — 手で編集しない

import gen/allow/article as allow
import yumemi/step
import yumemi/time.{type Datetime}

pub type Actor =
  allow.Actor

pub type Root {
  Root(at: Datetime, seed: String)
}

pub type Service(args, out, err) {
  Service(
    allow: List(allow.Clause),
    logic: fn(Actor, Root, args) -> step.Step(out, err, step.Start),
  )
}
