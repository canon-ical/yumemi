import framework/effect.{type Effect, Read}
import gen/allow/parent as allow
import gen/face.{type Face, Test}
import gen/root/child_read.{type Service, Service}
import gen/types/child_id.{type ChildId}
import gen/types/parent_a.{type ParentA}
import gen/types/parent_b.{type ParentB}

pub const effect: Effect = Read

pub const faces: List(Face) = [Test]

pub type Args {
  Args(a: ParentA, b: ParentB, id: ChildId)
}

pub type Error

pub const service: Service(Args, Nil, Error) = Service(
  allow: [allow.Anyone],
  logic: logic,
)
