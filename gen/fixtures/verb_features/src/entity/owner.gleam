import gen/types/owner_id.{type OwnerId}

pub type Owner {
  Owner(id: OwnerId)
}

pub fn key(it: Owner) -> OwnerId {
  it.id
}

