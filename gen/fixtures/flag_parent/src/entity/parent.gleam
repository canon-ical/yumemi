pub type Parent {
  Parent(id: String)
}

pub fn key(it: Parent) -> String {
  it.id
}
