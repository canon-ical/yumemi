import framework/effect.{type Effect, Read}
import framework/step.{type Start, type Step}
import gen/allow/widget as allow
import gen/face.{type Face, Test}
import gen/root/store_check.{type Root, type Service, Service}

pub const effect: Effect = Read

pub const faces: List(Face) = [Test]

pub type Args {
  Args(id: Int)
}

pub type Error

pub const service: Service(Args, Nil, Error) = Service(
  allow: [
    allow.Clause(who: allow.Anyone, at: allow.AnyPhase, owner: allow.NoOwner),
  ],
  logic: logic,
)

pub fn logic(_by: Actor, _it: Root, _args: Args) -> Step(Nil, Error, Start) {
  todo
}
