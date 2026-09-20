// ★ 順序列が Option ── 生成器が名指しで止まる(exit 4)。
import entity/album.{type Album}
import framework/er.{type Held}
import framework/verbs
import gen/types/photo_id.{type PhotoId}
import gen/types/photo_order.{type PhotoOrder}
import gleam/option.{type Option}

pub type Photo {
  Photo(id: PhotoId, album: Held(Album), order: Option(PhotoOrder))
}

pub fn key(it: Photo) -> PhotoId {
  it.id
}

pub const collection: String = "photos"

pub const ordered_by: verbs.Order = verbs.Order(field: "order", within: "album")
