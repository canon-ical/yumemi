// ★ src/entity/shelf.gleam ── 置き場。任意の関係(Link)の先。
import gen/types/shelf_id.{type ShelfId}
import gen/types/shelf_name.{type ShelfName}

pub type Shelf {
  Shelf(id: ShelfId, name: ShelfName)
}

pub fn key(it: Shelf) -> ShelfId {
  it.id
}

pub const collection: String = "shelves"
