// ★ src/entity/album.gleam ── 写真の親。必須の関係(Held)の先。
import gen/types/album_id.{type AlbumId}
import gen/types/album_title.{type AlbumTitle}

pub type Album {
  Album(id: AlbumId, title: AlbumTitle)
}

pub fn key(it: Album) -> AlbumId {
  it.id
}

pub const collection: String = "albums"
