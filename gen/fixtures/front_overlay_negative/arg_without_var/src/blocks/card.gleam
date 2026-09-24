pub type In =
  Nil

pub type Arg {
  Arg(slug: String)
}

pub fn view(it: In, arg: Arg) -> el.Element(Nil) {
  it
}
