import framework/effect.{type Effect, Read}
import gen/allow/example as allow
import gen/face.{type Face, Missing}
import gen/root/example_read.{type Service, Service}

pub const effect: Effect = Read

pub const faces: List(Face) = [Missing]

pub type Args {
  Args
}

pub type Error

pub const service: Service(Args, Nil, Error) = Service(
  allow: [allow.Anyone],
  logic: logic,
)
