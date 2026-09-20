// ★ src/service/photo_read.gleam ── root Photo から矢印 3 本を辿る。
import entity/album
import entity/label
import entity/photo
import entity/shelf
import framework/effect.{type Effect, Read}
import framework/step.{type Start, type Step}
import gen/allow/photo as allow
import gen/face.{type Face, Test}
import gen/reads/photo_read as reads
import gen/root/photo_read.{type Actor, type Root, type Service, Service}
import gen/types/photo_id.{type PhotoId}
import gleam/option.{type Option}

pub const effect: Effect = Read

pub const faces: List(Face) = [Test]

pub type Args {
  Args(id: PhotoId)
}

pub type Out {
  Out(
    photo: photo.Photo,
    album: album.Album,
    shelf: Option(shelf.Shelf),
    labels: List(label.Label),
  )
}

pub type Error

pub const service: Service(Args, Out, Error) = Service(
  allow: [
    allow.Clause(who: allow.Anyone, at: allow.AnyPhase, owner: allow.NoOwner),
  ],
  logic: logic,
)

pub fn logic(_by: Actor, it: Root, _args: Args) -> Step(Out, Error, Start) {
  use album <- reads.to_album(it)
  use shelf <- reads.to_shelf(it)
  use labels <- reads.to_labels(it)
  step.done(Out(photo: it.photo, album: album, shelf: shelf, labels: labels))
}
