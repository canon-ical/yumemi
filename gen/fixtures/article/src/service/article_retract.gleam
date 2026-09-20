//// Service retract ── 公開済みを取り下げる。再公開はしない(新しい記事を作る)。

// ★ src/service/article_retract.gleam
import entity/article
import entity/staff
import framework/effect.{type Effect, Write}
import framework/step.{type Start, type Step}
import gen/allow/article as allow
import gen/face.{type Face, Admin}
import gen/phase
import gen/root/article_retract.{type Root, type Service, Service}
import gen/types/slug.{type Slug}
import gen/verb

pub const effect: Effect = Write

pub const faces: List(Face) = [Admin]

pub type Args {
  Args(slug: Slug)
}

pub type Error {
  NotPublished
}

pub const service: Service(Args, article.Article, Error) = Service(
  allow: [allow.staff],
  logic: logic,
)

pub fn logic(
  _by: staff.Staff,
  it: Root,
  _args: Args,
) -> Step(article.Article, Error, Start) {
  use <- step.guard(it.phase == article.Published, NotPublished)
  use _ <- step.apply(verb.advance_article(
    it.article.slug,
    phase.ArticlePublishedToRetracted,
  ))
  step.done(it.article)
}
