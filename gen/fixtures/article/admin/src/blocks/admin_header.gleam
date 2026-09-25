import framework/front/el

pub type In =
  Nil

pub type Arg {
  Arg(subject: String)
}

pub fn view(_it: In, arg: Arg) -> el.Element(Nil) {
  el.text("Signed-in subject: " <> arg.subject)
}
