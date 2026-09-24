pub type Thing {
  Thing(id: String)
}

pub fn key(it: Thing) -> String {
  it.id
}

pub const collection: String = "things"
