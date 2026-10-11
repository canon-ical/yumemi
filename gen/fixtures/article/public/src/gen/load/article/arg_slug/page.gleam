//// GENERATED from public/src/pages/article/arg_slug/page.gleam [sha256:1ffbb352c48f] — 手で編集しない

import blocks/article
import blocks/feed
import blocks/notice
import blocks/row_article
import blocks/row_summary
import blocks/site_header
import blocks/summary
import gen/load/layout
import gen/media
import gen/out/article_read
import gen/out/widget_list
import gleam/list
import gleam/option.{type Option, None, Some}
import style
import yumemi/blob.{type Blob}
import yumemi/front/css
import yumemi/front/el
import yumemi/front/html
import yumemi/front/theme

pub type Vars {
  Vars(
    widget: Option(String),
    slug: String,
    view_only: String,
    term: Option(String),
    subject_handle: Option(String),
    www_origin: String,
    auth_origin: String,
  )
}

pub type Data {
  Data(
    layout: layout.Data,
    vars: Vars,
    article_read: article_read.Out,
    widget_list: Option(widget_list.Out),
    theme: Option(theme.PageTheme),
  )
}

pub fn load(
  vars: Vars,
  widget_list: Option(widget_list.Out),
  article_read: article_read.Out,
  theme: Option(theme.PageTheme),
) -> Data {
  Data(
    layout: layout.load(widget_list),
    vars: vars,
    article_read: article_read,
    widget_list: widget_list,
    theme: theme,
  )
}

pub fn render(it: Data) -> el.Element {
  let page_theme = it.theme
  html.html([el.attribute("lang", "ja")], [
    html.head([], [
      html.meta([el.attribute("charset", "utf-8")]),
      html.meta([
        el.attribute("name", "viewport"),
        el.attribute(
          "content",
          "width=device-width, initial-scale=1, viewport-fit=cover",
        ),
      ]),
      html.title([], "yumemi front fixture"),
      el.element(
        "link",
        [
          el.attribute("rel", "stylesheet"),
          el.attribute("href", "/fixture.css"),
        ],
        [],
      ),
    ]),
    html.body_([theme_image_attribute(page_theme)], [
      el.styled(
        fn() { view(it) },
        theme.body_rule(page_theme, theme_defaults(), theme_image_url),
      ),
    ]),
  ])
}

fn theme_defaults() -> theme.Defaults {
  theme.Defaults(
    background: "#FAF7F0",
    text: "#3D2419",
    accent: "#A93632",
    background_image: None,
  )
}

fn theme_image_attribute(value: Option(theme.PageTheme)) -> el.Attribute {
  case theme.has_image(value, theme_defaults()) {
    True -> el.attribute("data-yumemi-theme-image", "")
    False -> el.no_attribute()
  }
}

fn theme_image_url(value: Blob) -> String {
  media.url(value, media.theme_background)
}

pub fn view(it: Data) -> el.Element {
  html.div_([el.attribute("data-yumemi-grid", "layout")], [
    styled_area("header", style.bar, layout_placement_0(it)),
    styled_area(
      "page",
      style.page,
      list.flatten([layout_placement_1(it), page_children(it)]),
    ),
    styled_area("footer", style.bar, []),
  ])
}

fn page_children(it: Data) -> List(el.Element) {
  [
    html.div_(
      [el.attribute("data-yumemi-grid", "page:pages/article/arg_slug/page")],
      list.flatten([
        [
          styled_area(
            "page",
            style.page,
            list.flatten([page_placement_0(it), page_placement_2(it)]),
          ),
        ],
        [plain_area("rail", page_placement_3(it))],
        [overlay_area("article-dialog", [], page_placement_1(it))],
      ]),
    ),
  ]
}

fn styled_area(
  name: String,
  styles: List(css.Style),
  children: List(el.Element),
) -> el.Element {
  html.div(
    css.class(styles),
    [el.attribute("data-yumemi-area", name)],
    children,
  )
}

fn plain_area(name: String, children: List(el.Element)) -> el.Element {
  html.div_([el.attribute("data-yumemi-area", name)], children)
}

fn overlay_area(
  name: String,
  styles: List(css.Style),
  children: List(el.Element),
) -> el.Element {
  let attributes = [
    el.attribute("id", el.overlay_id_prefix <> name),
    el.attribute("popover", ""),
    el.attribute("data-yumemi-area", name),
    el.attribute("data-yumemi-overlay", ""),
  ]
  case styles {
    [] -> html.div_(attributes, children)
    _ -> html.div(css.class(styles), attributes, children)
  }
}

fn layout_placement_0(_it: Data) -> List(el.Element) {
  [site_header.view(Nil)]
}

fn layout_placement_1(it: Data) -> List(el.Element) {
  case it.layout.widget_list {
    Some(out) -> [feed.view(out)]
    None -> []
  }
}

fn page_placement_0(it: Data) -> List(el.Element) {
  [
    article.view(
      it.article_read,
      article.Arg(
        slug: it.vars.slug,
        term: it.vars.term,
        subject_handle: it.vars.subject_handle,
        www_origin: it.vars.www_origin,
        auth_origin: it.vars.auth_origin,
        view_only: it.vars.view_only,
      ),
    ),
  ]
}

fn page_placement_1(it: Data) -> List(el.Element) {
  [summary.view(it.article_read, summary.Arg(slug: it.vars.slug))]
}

fn page_placement_2(it: Data) -> List(el.Element) {
  [notice.view(Nil, notice.Arg(slug: it.vars.slug))]
}

fn page_placement_3(it: Data) -> List(el.Element) {
  case it.widget_list {
    Some(out) -> render_page_placement_3(out.rows)
    None -> []
  }
}

fn render_page_placement_3(rows: List(widget_list.Row)) -> List(el.Element) {
  case rows {
    [] -> []
    [row, ..rest] ->
      case row {
        widget_list.ArticleRow(..) -> [
          row_article.view(row),
          ..render_page_placement_3(rest)
        ]
        widget_list.Summary(..) -> [
          row_summary.view(row),
          ..render_page_placement_3(rest)
        ]
      }
  }
}
