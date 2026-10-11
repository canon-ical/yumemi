import yumemi/front/el

pub type In =
  Nil

pub fn view(_it: In) -> el.Element(Nil) {
  el.each_modal(
    "shared-row",
    "second",
    [el.text("Open")],
    [el.text("Close")],
    [],
  )
}
