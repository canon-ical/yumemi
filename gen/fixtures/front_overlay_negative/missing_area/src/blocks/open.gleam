import framework/front/el

pub type In =
  Nil

pub fn view(_it: In) -> el.Element(Nil) {
  el.opener("missing-dialog", [el.text("Open")])
}
