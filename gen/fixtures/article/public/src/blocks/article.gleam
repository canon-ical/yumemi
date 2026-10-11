//// Article Block ── article_read の Out だけを描く純粋な view。

import yumemi/front/css
import yumemi/front/el
import components/pick_tag
import gen/escapes
import gen/interactive
import gen/live/article_blob_save
import gen/live/article_create
import gen/live/article_publish
import gen/live/article_title
import gen/live/blob_copy
import gen/out/article_read
import gleam/option.{type Option, None, Some}
import yumemi/front/attr
import yumemi/front/html

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
  css.Color(css.Hex("#2b1d3a")),
  css.Space(property: css.Padding, value: css.Px(16.0)),
  css.Space(property: css.Gap, value: css.Px(8.0)),
]

const title: List(css.Style) = [
  css.Color(css.Hex("#f5e9ff")),
  css.Text(
    family: css.System,
    size: css.Rem(1.5),
    weight: css.Bold,
    line_height: css.Rem(1.8),
  ),
]

const body: List(css.Style) = [
  css.Color(css.Hex("#d9c6f0")),
  css.Text(
    family: css.System,
    size: css.Rem(1.0),
    weight: css.Normal,
    line_height: css.Rem(1.5),
  ),
]

pub fn view(it: In, arg: Arg) -> el.Element {
  html.section(
    css.class(card),
    [
      attr.data("slug", arg.slug),
      attr.data("term", option.unwrap(arg.term, "")),
      attr.data("subject", option.unwrap(arg.subject_handle, "")),
      attr.data("www-origin", arg.www_origin),
      attr.data("auth-origin", arg.auth_origin),
      attr.data("view-only", arg.view_only),
    ],
    [
      html.h1(css.class(title), [], [el.text(it.article.title)]),
      html.p(css.class(body), [], [el.text(it.article.body)]),
      el.opener("article-dialog", [el.text("Open article options")]),
      el.badge(None, [el.text("none")]),
      el.badge(Some(0), [el.text("zero")]),
      el.badge(Some(3), [el.text("three")]),
      html.div_([], [
        interactive.like_button(article_publish.Args(slug: it.article.slug)),
        interactive.pick_tag(
          article_create.Args(
            slug: "article",
            title: "本日の記事",
            body: "夜のシフトが得意な新人です。よろしくお願いします。",
            category: "news",
            tags: ["fixture"],
          ),
          pick_tag.With(
            choices: ["fixture", "gleam", "cloudflare"],
            selected: "fixture",
          ),
        ),
        interactive.blob_save(article_blob_save.Args(
          slug: it.article.slug,
          blob: "stored-image-key",
          existing: Some("stored-optional-key"),
        )),
        interactive.article_blob_copy(blob_copy.Args(file: "", from: "")),
        interactive.article_manage(
          article_publish.Args(slug: it.article.slug),
          article_create.Args(
            slug: it.article.slug <> "-copy",
            title: it.article.title,
            body: it.article.body,
            category: "news",
            tags: [],
          ),
        ),
        interactive.title_lookup(article_title.Args(slug: it.article.slug)),
        escapes.clock([attr.data("zone", "jst")], [el.text("時計")]),
      ]),
    ],
  )
}
