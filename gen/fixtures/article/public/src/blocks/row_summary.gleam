//// RowSummary Block ── widget_list の Summary 行だけを描く。

import framework/front/el
import framework/front/sketch_css
import gen/out/widget_list
import sketch/lustre/element/html
import style

pub type In = widget_list.Row

pub const sample: In = widget_list.Summary(
  kind: "Summary",
  article: widget_list.Article(
    slug: "summary",
    title: "サマリー",
    body: "本文",
    version: 1,
    order: 0,
    category: widget_list.Has(value: "news"),
    tags: widget_list.Multi(values: []),
  ),
)

pub fn view(it: In) -> el.Element(Nil) {
  case it {
    widget_list.Summary(article: article, ..) ->
      html.p(sketch_css.class([style.body]), [], [el.text(article.title)])
    _ -> el.text("")
  }
}
