import framework/effect.{type Effect, Write}
import gen/face.{type Face, Test}
import gen/root/thing_put.{type Root, type Service, Service}

pub const effect: Effect = Write

pub const faces: List(Face) = [Test]

pub type Args {
  Args(id: String)
}

pub type Error

pub const service: Service(Args, Nil, Error) = Service(allow: [], logic: logic)
