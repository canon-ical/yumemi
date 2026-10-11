//// GENERATED from public/src/{layout.gleam,pages/**/page.gleam,blocks/*.gleam} [sha256:bb2b076e125b] — 手で編集しない

import blocks/article
import blocks/feed
import blocks/notice
import blocks/row_article
import blocks/row_summary
import blocks/site_header
import blocks/summary
import gleam/option.{None}
import yumemi/front/el
import yumemi/front/html

pub fn view() -> el.Element {
  html.div_([el.attribute("data-yumemi-blocks-preview", "pc")], [
    html.header_([el.attribute("data-yumemi-area", "header")], [
      html.div_([], [
        el.text("blocks/site_header | of Nil | Nil"),
        site_header.view(Nil),
      ]),
    ]),
    html.div_([el.attribute("data-yumemi-area", "page")], [
      html.div_([], [
        el.text("blocks/article | of ArticleRead | article_read.Out"),
        article.view(
          article.sample,
          article.Arg(
            slug: "preview",
            term: None,
            subject_handle: None,
            www_origin: "preview",
            auth_origin: "preview",
            view_only: "preview",
          ),
        ),
      ]),
      html.div_([], [
        el.text("blocks/feed | of WidgetList | widget_list.Out"),
        feed.view(feed.sample),
      ]),
      html.div_([], [
        el.text("blocks/notice | of Nil | Nil"),
        notice.view(Nil, notice.Arg(slug: "preview")),
      ]),
      html.div_([], [
        el.text("blocks/row_article | of WidgetList | widget_list.Out"),
        row_article.view(row_article.sample),
      ]),
      html.div_([], [
        el.text("blocks/row_summary | of WidgetList | widget_list.Out"),
        row_summary.view(row_summary.sample),
      ]),
      html.div_([], [
        el.text("blocks/site_header | of Nil | Nil"),
        site_header.view(Nil),
      ]),
      html.div_([], [
        el.text("blocks/summary | of ArticleRead | article_read.Out"),
        summary.view(summary.sample, summary.Arg(slug: "preview")),
      ]),
    ]),
    html.div_([el.attribute("data-yumemi-area", "aside")], [
      el.text("aside"),
    ]),
    html.footer_([el.attribute("data-yumemi-area", "footer")], [
      el.text("footer"),
    ]),
  ])
}

pub fn render() -> el.Element {
  html.html([], [
    html.head([], []),
    html.body_([], [el.styled(fn() { view() }, "")]),
  ])
}
