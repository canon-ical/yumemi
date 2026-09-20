// ★ src/service/photo_filter.gleam ── Has / HasNone の相関述語を固定する。
import entity/photo
import framework/effect.{type Effect, Read}
import framework/step.{type Start, type Step}
import gen/query as q
import gen/root/photo_filter.{type Actor, type Root, type Service, Service}

pub const effect: Effect = Read

pub type Args {
  Args(name: String)
}

pub type Out {
  Out
}

pub type Error

pub type P {
  Name
}

pub const related: q.Select(P) = q.Select(
  from: q.Photo,
  join: [],
  where: [
    q.Has(q.PhotoToAlbum, [q.Eq(q.AlbumId, q.Param(Name))]),
    q.HasNone(q.PhotoToShelf, [q.Eq(q.ShelfId, q.Param(Name))]),
  ],
  group: [],
  having: [],
  agg: [],
  along: [],
  with: [],
  order: [q.Asc(q.PhotoId)],
  limit: q.NoLimit,
)

pub const album_photos: q.Select(P) = q.Select(
  from: q.Album,
  join: [],
  where: [],
  group: [],
  having: [],
  agg: [],
  along: [],
  with: [q.AlbumToPhotos],
  order: [q.Asc(q.AlbumId)],
  limit: q.NoLimit,
)

pub const service: Service(Args, Out, Error) = Service(allow: [], logic: logic)

pub fn logic(_by: Actor, _it: Root, _args: Args) -> Step(Out, Error, Start) {
  step.done(Out)
}
