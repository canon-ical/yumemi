pub type Label {
  Label(id: Int)
}

pub fn key(it: Label) -> Int {
  it.id
}

pub const collection: String = "labels"
