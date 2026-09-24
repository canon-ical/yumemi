import framework/front/el

pub type In =
  Nil

pub fn view(_it: In) -> el.Element(Nil) {
  el.each_modal(
    "shared-row",
    "first",
    [el.text("Open")],
    [el.text("Close")],
    [],
  )
}
