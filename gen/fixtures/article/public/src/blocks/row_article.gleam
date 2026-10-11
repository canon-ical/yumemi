//// RowArticle Block ── widget_list の Article 行だけを描く。

import yumemi/front/el
import yumemi/front/css
import gen/out/widget_list
import yumemi/front/html
import style

pub type In =
  widget_list.Row

pub const sample: In = widget_list.ArticleRow(
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
)

pub fn view(it: In) -> el.Element {
  case it {
    widget_list.ArticleRow(article: article, ..) ->
      html.div_([], [
        html.p(css.class([style.body]), [], [el.text(article.title)]),
        el.each_modal(
          "article-row",
          article.slug,
          [el.text("Open article row")],
          [el.text("Close article row")],
          [el.text(article.title)],
        ),
      ])
    _ -> el.text("")
  }
}
