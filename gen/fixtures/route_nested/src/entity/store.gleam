pub type Store {
  Store(id: String)
}

pub fn key(it: Store) -> String {
  it.id
}

pub const collection: String = "stores"
