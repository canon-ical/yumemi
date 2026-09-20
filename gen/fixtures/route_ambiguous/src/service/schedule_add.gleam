import framework/effect.{type Effect, Write}
import gen/face.{type Face, Test}
import gen/root/schedule_add.{type Root, type Service, Service}

pub const effect: Effect = Write

pub const faces: List(Face) = [Test]

pub type Args {
  Args
}

pub type Error

pub const service: Service(Args, Nil, Error) = Service(allow: [], logic: logic)
