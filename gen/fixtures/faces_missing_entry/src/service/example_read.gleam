import framework/effect.{type Effect, Read}
import gen/allow/example as allow
import gen/root/example_read.{type Service, Service}

pub const effect: Effect = Read

pub type Args {
  Args
}

pub type Error

pub const service: Service(Args, Nil, Error) = Service(
  allow: [allow.Anyone],
  logic: logic,
)
