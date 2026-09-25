import gen/out/article_read
import gen/out/widget_list

pub type In {
  In(article: article_read.Out, widgets: widget_list.Out)
}

pub fn view(it: In) -> el.Element(Nil) {
  it
}
