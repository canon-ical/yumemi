//// GENERATED from service.article_publish [sha256:3f1e2a9baa9c] — 手で編集しない

import entity/article
import entity/staff
import gen/allow/article as allow
import yumemi/step
import yumemi/time.{type Datetime}

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
    logic: fn(staff.Staff, Root, args) -> step.Step(out, err, step.Start),
  )
}
