//// GENERATED from public/src/pages/article/arg_slug/page.gleam [sha256:4ced8cac33da] — 手で編集しない

import blocks/article
import blocks/feed
import blocks/notice
import blocks/row_article
import blocks/row_summary
import blocks/site_header
import blocks/summary
import framework/front/css
import framework/front/el
import framework/front/sketch_css
import gen/load/layout
import gen/out/article_read
import gen/out/widget_list
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element/html as raw_html
import sketch
import sketch/css as raw_css
import sketch/lustre as sketch_lustre
import sketch/lustre/element
import sketch/lustre/element/html
import style

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
    theme: Option(article_read.PageTheme),
  )
}

pub fn load(
  vars: Vars,
  widget_list: Option(widget_list.Out),
  article_read: article_read.Out,
  theme: Option(article_read.PageTheme),
) -> Data {
  Data(
    layout: layout.load(widget_list),
    vars: vars,
    article_read: article_read,
    widget_list: widget_list,
    theme: theme,
  )
}

pub fn render(it: Data) -> element.Element(Nil) {
  let assert Ok(stylesheet) =
    sketch_lustre.construct(fn(stylesheet) {
      sketch.global(stylesheet, theme_global(it.theme))
    })
  let output = render_view(stylesheet, fn() { view(it) })
  let assert Ok(_) = sketch_lustre.teardown(stylesheet)
  output
}

fn render_view(
  stylesheet: sketch.StyleSheet,
  body: fn() -> element.Element(Nil),
) -> element.Element(Nil) {
  let styled_body =
    sketch_lustre.render(stylesheet, in: [sketch_lustre.node()], after: body)

  raw_html.html([attribute.attribute("lang", "ja")], [
    raw_html.head([], [
      raw_html.meta([attribute.attribute("charset", "utf-8")]),
      raw_html.meta([
        attribute.attribute("name", "viewport"),
        attribute.attribute(
          "content",
          "width=device-width, initial-scale=1, viewport-fit=cover",
        ),
      ]),
      raw_html.title([], "yumemi front fixture"),
    ]),
    raw_html.body([], [styled_body]),
  ])
}

fn theme_global(value: Option(article_read.PageTheme)) -> raw_css.Global {
  let #(background, background_image, text, accent) = case value {
    Some(article_read.PageTheme(background:, background_image:, text:, accent:)) -> #(
      option_string(background, "#FAF7F0"),
      option_background(background_image),
      option_string(text, "#3D2419"),
      option_string(accent, "#A93632"),
    )
    None -> #("#FAF7F0", "none", "#3D2419", "#A93632")
  }

  raw_css.global("body", [
    raw_css.property("--bg", background),
    raw_css.property("--bg-image", background_image),
    raw_css.property("--text", text),
    raw_css.property("--accent", accent),
  ])
}

fn option_string(value: Option(String), default: String) -> String {
  case value {
    Some(value) -> value
    None -> default
  }
}

fn option_background(value: Option(String)) -> String {
  case value {
    Some(value) -> value
    None -> "none"
  }
}

pub fn view(it: Data) -> element.Element(Nil) {
  html.div_([attribute.attribute("data-yumemi-grid", "layout")], [
    styled_area("header", style.bar, layout_placement_0(it)),
    styled_area(
      "page",
      style.page,
      list.flatten([layout_placement_1(it), page_children(it)]),
    ),
    styled_area("footer", style.bar, []),
  ])
}

fn page_children(it: Data) -> List(element.Element(Nil)) {
  [
    html.div_(
      [
        attribute.attribute(
          "data-yumemi-grid",
          "page:pages/article/arg_slug/page",
        ),
      ],
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

fn overlay_area(
  name: String,
  styles: List(css.Style),
  children: List(element.Element(Nil)),
) -> element.Element(Nil) {
  let attributes = [
    attribute.attribute("id", el.overlay_id_prefix <> name),
    attribute.attribute("popover", ""),
    attribute.attribute("data-yumemi-area", name),
    attribute.attribute("data-yumemi-overlay", ""),
  ]
  case styles {
    [] -> html.div_(attributes, children)
    _ -> html.div(sketch_css.class(styles), attributes, children)
  }
}

fn layout_placement_0(_it: Data) -> List(element.Element(Nil)) {
  [site_header.view(Nil)]
}

fn layout_placement_1(it: Data) -> List(element.Element(Nil)) {
  case it.layout.widget_list {
    Some(out) -> [feed.view(out)]
    None -> []
  }
}

fn page_placement_0(it: Data) -> List(element.Element(Nil)) {
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

fn page_placement_1(it: Data) -> List(element.Element(Nil)) {
  [summary.view(it.article_read, summary.Arg(slug: it.vars.slug))]
}

fn page_placement_2(it: Data) -> List(element.Element(Nil)) {
  [notice.view(Nil, notice.Arg(slug: it.vars.slug))]
}

fn page_placement_3(it: Data) -> List(element.Element(Nil)) {
  case it.widget_list {
    Some(out) -> render_page_placement_3(out.rows)
    None -> []
  }
}

fn render_page_placement_3(
  rows: List(widget_list.Row),
) -> List(element.Element(Nil)) {
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
