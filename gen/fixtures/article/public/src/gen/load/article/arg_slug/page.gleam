//// GENERATED from public/src/pages/article/arg_slug/page.gleam [sha256:37acb1946f42] — 手で編集しない

import blocks/article
import blocks/feed
import blocks/row_article
import blocks/row_summary
import blocks/site_header
import blocks/summary
import framework/front/css
import framework/front/sketch_css
import gen/load/layout
import gen/out/article_read
import gen/out/widget_list
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import sketch/lustre/element
import sketch/lustre/element/html
import style

pub type Data {
  Data(
    layout: layout.Data,
    article_read: article_read.Out,
    article_kinds: Option(widget_list.Out),
  )
}

pub fn load(
  article_feed: Option(widget_list.Out),
  article_read: article_read.Out,
  article_kinds: Option(widget_list.Out),
) -> Data {
  Data(
    layout: layout.load(article_feed),
    article_read: article_read,
    article_kinds: article_kinds,
  )
}

pub fn view(it: Data) -> element.Element(Nil) {
  html.div_([attribute.attribute("data-yumemi-grid", "layout")], [
    styled_area("header", style.bar, layout_placement_0(it)),
    styled_area("page", style.page, list.flatten([layout_placement_1(it), page_children(it)])),
    styled_area("footer", style.bar, []),
  ])
}

fn page_children(it: Data) -> List(element.Element(Nil)) {
  list.flatten([
    page_placement_0(it),
    page_placement_1(it),
    [plain_area("rail", page_placement_2(it))],
  ])
}

fn styled_area(
  name: String,
  styles: List(css.Style),
  children: List(element.Element(Nil)),
) -> element.Element(Nil) {
  html.div(
    sketch_css.class(styles),
    [attribute.attribute("data-yumemi-area", name)],
    children,
  )
}

fn plain_area(
  name: String,
  children: List(element.Element(Nil)),
) -> element.Element(Nil) {
  html.div_([attribute.attribute("data-yumemi-area", name)], children)
}

fn layout_placement_0(_it: Data) -> List(element.Element(Nil)) {
  [site_header.view(Nil)]
}

fn layout_placement_1(it: Data) -> List(element.Element(Nil)) {
  case it.layout.article_feed {
    Some(out) -> [feed.view(out)]
    None -> []
  }
}
fn page_placement_0(it: Data) -> List(element.Element(Nil)) {
  [summary.view(it.article_read)]
}

fn page_placement_1(it: Data) -> List(element.Element(Nil)) {
  [article.view(it.article_read)]
}

fn page_placement_2(it: Data) -> List(element.Element(Nil)) {
  case it.article_kinds {
    Some(out) -> render_page_placement_2(out.rows)
    None -> []
  }
}

fn render_page_placement_2(rows: List(widget_list.Row)) -> List(element.Element(Nil)) {
  case rows {
    [] -> []
    [row, ..rest] ->
      case row {
        widget_list.ArticleRow(..) -> [
          row_article.view(row),
          ..render_page_placement_2(rest),
        ]
        widget_list.Summary(..) -> [
          row_summary.view(row),
          ..render_page_placement_2(rest),
        ]
      }
  }
}