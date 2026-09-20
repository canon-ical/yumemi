import entity/path_only
import framework/effect.{type Effect, Read}
import framework/step.{type Start, type Step}
import gen/allow/path_only as allow
import gen/face.{type Face, Test}
import gen/root/path_only_lookup.{type Root, type Service, Service}

pub const effect: Effect = Read

pub const faces: List(Face) = [Test]

pub type Args {
  Args(path: String)
}

pub type Error

pub const service: Service(Args, Nil, Error) = Service(
  allow: [allow.path_only],
  logic: logic,
)

pub fn logic(
  _by: path_only.PathOnly,
  _it: Root,
  _args: Args,
) -> Step(Nil, Error, Start) {
  todo
}
