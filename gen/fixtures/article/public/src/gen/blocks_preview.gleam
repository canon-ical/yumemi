//// GENERATED from public/src/{layout.gleam,pages/**/page.gleam,blocks/*.gleam} [sha256:a69b93f48bbc] — 手で編集しない

import blocks/article
import blocks/feed
import blocks/row_article
import blocks/row_summary
import blocks/site_header
import blocks/summary
import framework/front/el
import lustre/attribute
import lustre/element/html as raw_html
import sketch/lustre as sketch_lustre
import sketch/lustre/element
import sketch/lustre/element/html

pub fn view() -> element.Element(Nil) {
  html.div_([attribute.attribute("data-yumemi-blocks-preview", "pc")], [
    html.header_([attribute.attribute("data-yumemi-area", "header")], [
      html.div_([], [
        el.text("blocks/site_header | of Nil | Nil"),
        site_header.view(Nil),
      ]),
    ]),
    html.div_([attribute.attribute("data-yumemi-area", "page")], [
      html.div_([], [
        el.text("blocks/article | of ArticleRead | article_read.Out"),
        article.view(article.sample),
      ]),
      html.div_([], [
        el.text("blocks/feed | of WidgetList | widget_list.Out"),
        feed.view(feed.sample),
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
        summary.view(summary.sample),
      ]),
    ]),
    html.div_([attribute.attribute("data-yumemi-area", "aside")], [
      el.text("aside"),
    ]),
    html.footer_([attribute.attribute("data-yumemi-area", "footer")], [
      el.text("footer"),
    ]),
  ])
}

pub fn render() -> element.Element(Nil) {
  let assert Ok(stylesheet) =
    sketch_lustre.construct(fn(stylesheet) { stylesheet })
  let output =
    sketch_lustre.render(stylesheet, in: [sketch_lustre.node()], after: fn() {
      view()
    })
  let assert Ok(_) = sketch_lustre.teardown(stylesheet)
  raw_html.html([], [
    raw_html.head([], []),
    raw_html.body([], [output]),
  ])
}
