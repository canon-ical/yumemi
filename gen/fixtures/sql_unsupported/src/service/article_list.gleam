import framework/effect.{type Effect, Read}
import gen/allow/article as allow
import gen/face.{type Face, Test}
import gen/query as q
import gen/root/article_list.{type Service, Service}

pub const effect: Effect = Read

pub const faces: List(Face) = [Test]

pub type Args {
  Args
}

pub type Error

pub type P {
  None
}

pub const items: q.Select(P) = q.Select(
  from: q.Article,
  join: [],
  where: [],
  group: [],
  having: [],
  agg: [],
  along: [],
  with: [q.ArticleToCategory],
  order: [],
  limit: q.NoLimit,
)

pub const service: Service(Args, Nil, Error) = Service(
  allow: [allow.Anyone],
  logic: logic,
)
