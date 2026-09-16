// ★ src/entity/tag.gleam
//// Entity Tag ── 付箋。Lifecycle は無い。
import gen/types/tag_name.{type TagName}

pub type Tag {
  Tag(name: TagName)
}

pub fn key(it: Tag) -> TagName {
  it.name
}

pub const collection: String = "tags"
