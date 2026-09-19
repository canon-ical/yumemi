pub type Widget {
  Widget(id: Int)
}

pub fn key(it: Widget) -> Int {
  it.id
}

pub const collection: String = "widgets"
