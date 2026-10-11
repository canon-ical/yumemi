//// GENERATED from service.article_title [sha256:f57707b2787e] — 手で編集しない

import entity/article
import gen/allow/article as allow
import yumemi/step
import yumemi/time.{type Datetime}

pub type Actor =
  allow.Actor

pub type Root {
  Root(
    article: article.Article,
    phase: article.Phase,
    at: Datetime,
    seed: String,
  )
}

pub type Service(args, out, err) {
  Service(
    allow: List(allow.Clause),
    logic: fn(Actor, Root, args) -> step.Step(out, err, step.Start),
  )
}
