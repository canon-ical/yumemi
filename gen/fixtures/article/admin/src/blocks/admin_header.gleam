import yumemi/front/el

pub type In =
  Nil

pub type Arg {
  Arg(subject: String)
}

pub fn view(_it: In, arg: Arg) -> el.Element {
  el.text("Signed-in subject: " <> arg.subject)
}
