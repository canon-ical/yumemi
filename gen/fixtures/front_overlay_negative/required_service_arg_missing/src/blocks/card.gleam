import gen/out/article_read

pub type In =
  article_read.Out

pub fn view(it: In) -> el.Element(Nil) {
  it
}
