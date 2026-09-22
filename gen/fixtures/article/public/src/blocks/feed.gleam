//// Feed Block ── widget_list の行数を描く。

import framework/front/el
import framework/front/sketch_css
import gen/out/widget_list
import gleam/int
import gleam/list
import sketch/lustre/element/html
import style

pub type In = widget_list.Out

pub const sample: In = widget_list.Out(rows: [
  widget_list.ArticleRow(
    kind: "Article",
    article: widget_list.Article(
      slug: "sample",
      title: "サンプル記事",
      body: "本文",
      version: 1,
      order: 0,
      category: widget_list.Has(value: "news"),
      tags: widget_list.Multi(values: []),
    ),
  ),
])

pub fn view(it: In) -> el.Element(Nil) {
  html.p(sketch_css.class([style.body]), [], [
    el.text("記事の件数: " <> int.to_string(list.length(it.rows))),
  ])
}
