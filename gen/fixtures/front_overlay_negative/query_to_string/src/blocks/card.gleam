import gleam/option.{type Option}

pub type In =
  Nil

pub type Arg {
  Arg(term: String)
}

pub fn view(it: In, arg: Arg) -> el.Element(Nil) {
  it
}
