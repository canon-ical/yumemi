//// Service read ── 記事の題と版だけを読む(0.12 段 C の fixture、interactive Component の `reloads` の単一の値)。

import entity/article
import yumemi/effect.{type Effect, Read}
import yumemi/step.{type Start, type Step}
import gen/allow/article as allow
import gen/face.{type Face, Public}
import gen/root/article_title.{type Actor, type Root, type Service, Service}
import gen/types/slug.{type Slug}
import gen/types/title.{type Title}

pub const effect: Effect = Read

pub const faces: List(Face) = [Public]

pub type Args {
  Args(slug: Slug)
}

pub type Out {
  Out(title: Title, version: Int)
}

pub type Error

pub const service: Service(Args, Out, Error) = Service(
  allow: [
    allow.staff,
    allow.Clause(
      who: allow.Anyone,
      at: allow.Only([article.Published]),
      owner: allow.NoOwner,
    ),
  ],
  logic: logic,
)

pub fn logic(_by: Actor, it: Root, _args: Args) -> Step(Out, Error, Start) {
  step.done(Out(title: it.article.title, version: it.article.version))
}
