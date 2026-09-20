pub type Muse {
  Muse(id: String)
}

pub fn key(it: Muse) -> String {
  it.id
}

pub const collection: String = "muses"
