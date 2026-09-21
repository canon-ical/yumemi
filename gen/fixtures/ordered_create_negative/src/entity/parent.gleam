import gen/types/parent_id.{type ParentId}

pub type Parent {
  Parent(id: ParentId)
}

pub fn key(it: Parent) -> ParentId {
  it.id
}

pub const collection: String = "parents"
