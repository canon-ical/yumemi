//// GENERATED from public/src/pages/status/page.gleam [sha256:0a96921a41ae] — 手で編集しない

import blocks/feed
import blocks/site_header
import gen/load/layout
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
  Vars(widget: Option(String), www_origin: String, auth_origin: String)
}

pub type Data {
  Data(layout: layout.Data, vars: Vars)
}

pub fn load(vars: Vars, widget_list: Option(widget_list.Out)) -> Data {
  Data(layout: layout.load(widget_list), vars: vars)
}

pub fn render(it: Data) -> el.Element {
  let page_theme = None
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
  blob.to_string(value)
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
      [el.attribute("data-yumemi-grid", "page:pages/status/page")],
      list.flatten([
        [styled_area("page", style.page, page_placement_0(it))],
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

fn layout_placement_0(_it: Data) -> List(el.Element) {
  [site_header.view(Nil)]
}

fn layout_placement_1(it: Data) -> List(el.Element) {
  case it.layout.widget_list {
    Some(out) -> [feed.view(out)]
    None -> []
  }
}

fn page_placement_0(_it: Data) -> List(el.Element) {
  [site_header.view(Nil)]
}

pub type BlockSiteHeader {
  BlockSiteHeader(vars: Vars)
}

/// `Fixed` の Block SiteHeader の断片(shell の `x-yumemi-block: site_header` の口)。
pub fn block_site_header(vars: Vars) -> el.Element {
  el.styled(
    fn() { el.fragment(block_site_header_view(BlockSiteHeader(vars: vars))) },
    "",
  )
}

fn block_site_header_view(it: BlockSiteHeader) -> List(el.Element) {
  let block_children = {
    [site_header.view(Nil)]
  }
  [
    el.element(
      "yumemi-block",
      [el.attribute("name", "site_header")],
      block_children,
    ),
  ]
}
