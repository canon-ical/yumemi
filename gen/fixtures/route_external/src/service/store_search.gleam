import framework/effect.{type Effect, Read}
import gen/face.{type Face, Test}
import gen/root/store_search.{type Root, type Service, Service}

pub const effect: Effect = Read

pub const faces: List(Face) = [Test]

pub type Args {
  Args
}

pub type Error

pub const service: Service(Args, Nil, Error) = Service(allow: [], logic: logic)
