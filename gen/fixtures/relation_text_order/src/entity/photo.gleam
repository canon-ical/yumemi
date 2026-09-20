// ★ 順序列が文字列 ── 生成器が名指しで止まる(exit 4)。
import entity/album.{type Album}
import framework/er.{type Held}
import framework/verbs
import gen/types/photo_caption.{type PhotoCaption}
import gen/types/photo_id.{type PhotoId}

pub type Photo {
  Photo(id: PhotoId, album: Held(Album), caption: PhotoCaption)
}

pub fn key(it: Photo) -> PhotoId {
  it.id
}

pub const collection: String = "photos"

pub const ordered_by: verbs.Order = verbs.Order(
  field: "caption",
  within: "album",
)
