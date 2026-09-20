pub type Link {
  Link(id: String)
}

pub fn key(it: Link) -> String {
  it.id
}

pub const collection: String = "links"
