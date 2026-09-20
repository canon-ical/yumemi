pub type Category {
  Category(id: Int)
}

pub fn key(it: Category) -> Int {
  it.id
}

pub const collection: String = "categories"
