pub type FreeSpace {
  FreeSpace(id: String)
}

pub fn key(it: FreeSpace) -> String {
  it.id
}

pub const collection: String = "free_spaces"
