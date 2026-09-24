import framework/blob.{type Blob}
import framework/effect.{type Effect, Write}
import gen/face.{type Face, Public}
import gen/root/article_blob_save.{type Root, type Service, Service}
import gen/types/slug.{type Slug}
import gleam/option.{type Option}

pub const effect: Effect = Write

pub const faces: List(Face) = [Public]

pub type Args {
  Args(slug: Slug, blob: Blob, existing: Option(Blob))
}

pub type Out {
  Out(saved: Bool)
}

pub type Error

pub const service: Service(Args, Out, Error) = Service(allow: [], logic: logic)
