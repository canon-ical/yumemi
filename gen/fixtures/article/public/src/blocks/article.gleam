//// Article Block ── article_read の Out だけを描く純粋な view。

import framework/front/css
import framework/front/el
import framework/front/sketch_css
import gen/out/article_read
import gleam/option.{type Option, None, Some}
import lustre/attribute
import sketch/lustre/element/html

pub type In =
  article_read.Out

pub type Arg {
  Arg(
    slug: String,
    term: Option(String),
    subject_handle: Option(String),
    www_origin: String,
    auth_origin: String,
    view_only: String,
  )
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
  category: article_read.Category(name: "news"),
  tags: [article_read.Tag(name: "fixture")],
  theme: None,
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

pub fn view(it: In, arg: Arg) -> el.Element(Nil) {
  html.section(
    sketch_css.class(card),
    [
      attribute.attribute("data-slug", arg.slug),
      attribute.attribute("data-term", option.unwrap(arg.term, "")),
      attribute.attribute("data-subject", option.unwrap(arg.subject_handle, "")),
      attribute.attribute("data-www-origin", arg.www_origin),
      attribute.attribute("data-auth-origin", arg.auth_origin),
      attribute.attribute("data-view-only", arg.view_only),
    ],
    [
      html.h1(sketch_css.class(title), [], [el.text(it.article.title)]),
      html.p(sketch_css.class(body), [], [el.text(it.article.body)]),
      el.opener("article-dialog", [el.text("Open article options")]),
      el.badge(None, [el.text("none")]),
      el.badge(Some(0), [el.text("zero")]),
      el.badge(Some(3), [el.text("three")]),
      html.div_([], [
        el.island("like-button", [
          attribute.attribute("slug", it.article.slug),
        ]),
        el.island("pick-tag", [
          attribute.attribute("slug", "article"),
          attribute.attribute("title", "本日の記事"),
          attribute.attribute("body", "夜のシフトが得意な新人です。よろしくお願いします。"),
          attribute.attribute("category", "news"),
          attribute.attribute("tags", "fixture,gleam,cloudflare"),
          attribute.attribute("selected", "fixture"),
        ]),
        el.island("blob-save", [
          attribute.attribute("slug", it.article.slug),
          attribute.attribute("blob", "stored-image-key"),
          attribute.attribute("existing", "stored-optional-key"),
        ]),
        el.island("article-blob-copy", []),
      ]),
    ],
  )
}
