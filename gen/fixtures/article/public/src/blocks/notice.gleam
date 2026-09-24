import framework/front/el

pub type In =
  Nil

pub type Arg {
  Arg(slug: String)
}

pub fn view(_it: In, arg: Arg) -> el.Element(Nil) {
  el.text("Current article: " <> arg.slug)
}
