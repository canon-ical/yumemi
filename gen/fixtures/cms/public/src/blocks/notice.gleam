import yumemi/front/el

pub type In =
  Nil

pub type Arg {
  Arg(slug: String)
}

pub fn view(_it: In, arg: Arg) -> el.Element {
  el.text("Current article: " <> arg.slug)
}
