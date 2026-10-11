//// ArticleSummary Block ── article_read の Out だけを描く純粋な view。

import yumemi/front/css
import yumemi/front/el
import gen/out/article_read
import gleam/option.{None}
import yumemi/front/attr
import yumemi/front/html

pub type In =
  article_read.Out

pub type Arg {
  Arg(slug: String)
}

pub const sample: In = article_read.Out(
  article: article_read.Article(
    slug: "article",
    title: "本日の記事",
    body: "夜のシフトが得意な新人です。よろしくお願いします。",
    version: 1,
    order: 0,
    category: article_read.Has(value: "news"),
    tags: article_read.Multi(values: ["fixture"]),
  ),
  category: article_read.Category(name: "本日の記事サマリー"),
  tags: [],
  theme: None,
)

const card: List(css.Style) = [
  css.Color(css.Hex("#123524")),
  css.Space(property: css.Padding, value: css.Px(24.0)),
  css.Space(property: css.Gap, value: css.Px(4.0)),
]

const title: List(css.Style) = [
  css.Color(css.Hex("#c8ffe0")),
  css.Text(
    family: css.Serif,
    size: css.Rem(2.0),
    weight: css.Medium,
    line_height: css.Rem(2.2),
  ),
]

pub fn view(it: In, arg: Arg) -> el.Element {
  html.section(
    css.class(card),
    [attr.data("slug", arg.slug)],
    [
      html.h1(css.class(title), [], [el.text(it.category.name)]),
      el.closer("article-dialog", [el.text("Close article options")]),
    ],
  )
}
