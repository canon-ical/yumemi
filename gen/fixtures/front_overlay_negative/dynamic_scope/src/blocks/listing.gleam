import framework/front/el

const scope = "article-row"

pub type In =
  Nil

pub fn view(_it: In) -> el.Element(Nil) {
  el.each_modal(scope, "row-key", [el.text("Open")], [el.text("Close")], [])
}
