// ★ src/entity/photo.gleam ── 矢印 3 形を 1 つの root に持つ Entity。album の中で並ぶ。
import entity/album.{type Album}
import entity/label.{type Label}
import entity/shelf.{type Shelf}
import framework/er.{type Held, type Link, type Multi}
import framework/verbs
import gen/types/photo_caption.{type PhotoCaption}
import gen/types/photo_id.{type PhotoId}
import gen/types/photo_order.{type PhotoOrder}

pub type Photo {
  Photo(
    id: PhotoId,
    album: Held(Album),
    shelf: Link(Shelf),
    labels: Multi(Label),
    caption: PhotoCaption,
    order: PhotoOrder,
  )
}

pub fn key(it: Photo) -> PhotoId {
  it.id
}

pub const collection: String = "photos"

/// 順序列は値域つき(`Range(min: 1, max: 10)`)── 確定値は 1 から、一時値は 10 から下へ。
pub const ordered_by: verbs.Order = verbs.Order(field: "order", within: "album")
