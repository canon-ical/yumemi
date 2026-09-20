import gen/types/child_id.{type ChildId}

pub type Child {
  Child(id: ChildId)
}

pub fn key(it: Child) -> ChildId {
  it.id
}

pub const collection: String = "children"
