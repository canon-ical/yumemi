//// Article Block ── article_read の Out だけを描く純粋な view。

import framework/front/css
import framework/front/el
import framework/front/sketch_css
import gen/out/article_read
import gleam/int
import lustre/attribute
import sketch/lustre/element/html

pub type In = article_read.Out

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
  category: article_read.Category(name: "news"),
  tags: [article_read.Tag(name: "fixture")],
)

const card: List(css.Style) = [
  css.Color("#2b1d3a"),
  css.Space(property: css.Padding, value: css.Px(16.0)),
  css.Space(property: css.Gap, value: css.Px(8.0)),
]

const title: List(css.Style) = [
  css.Color("#f5e9ff"),
  css.Text(
    family: css.System,
    size: css.Rem(1.5),
    weight: css.Bold,
    line_height: css.Rem(1.8),
  ),
]

const body: List(css.Style) = [
  css.Color("#d9c6f0"),
  css.Text(
    family: css.System,
    size: css.Rem(1.0),
    weight: css.Normal,
    line_height: css.Rem(1.5),
  ),
]

pub fn view(it: In) -> el.Element(Nil) {
  html.section(sketch_css.class(card), [], [
    html.h1(sketch_css.class(title), [], [el.text(it.article.title)]),
    html.p(sketch_css.class(body), [], [el.text(it.article.body)]),
    html.div_([], [
      el.island("like-button", [
        attribute.attribute("count", int.to_string(it.article.version)),
      ]),
    ]),
  ])
}
