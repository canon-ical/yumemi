import framework/front/el

const target = "article-dialog"

pub type In =
  Nil

pub fn view(_it: In) -> el.Element(Nil) {
  el.opener(target, [el.text("Open")])
}
