// ★ src/entity/label.gleam ── 付箋。複数の関係(Multi)の先。
import gen/types/label_id.{type LabelId}
import gen/types/label_name.{type LabelName}

pub type Label {
  Label(id: LabelId, name: LabelName)
}

pub fn key(it: Label) -> LabelId {
  it.id
}

pub const collection: String = "labels"
