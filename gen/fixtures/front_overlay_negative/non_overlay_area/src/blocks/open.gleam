import yumemi/front/el

pub type In =
  Nil

pub fn view(_it: In) -> el.Element(Nil) {
  el.opener("plain-dialog", [el.text("Open")])
}
