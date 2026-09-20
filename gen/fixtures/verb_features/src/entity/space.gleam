import gen/types/space_id.{type SpaceId}

pub type Space {
  Space(id: SpaceId)
}

pub fn key(it: Space) -> SpaceId {
  it.id
}

