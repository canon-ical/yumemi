import framework/effect.{type Effect, Read}
import gen/allow/photo as allow
import gen/face.{type Face, Test}
import gen/query as q
import gen/root/photo_filter.{type Service, Service}

pub const effect: Effect = Read

pub const faces: List(Face) = [Test]

pub type Args {
  Args
}

pub type Error

pub type P {
  None
}

pub const related: q.Select(P) = q.Select(
  from: q.Photo,
  join: [],
  where: [q.Has(q.PhotoToLabels, [])],
  group: [],
  having: [],
  agg: [],
  along: [],
  with: [],
  order: [],
  limit: q.NoLimit,
)

pub const service: Service(Args, Nil, Error) = Service(
  allow: [allow.Anyone],
  logic: logic,
)
