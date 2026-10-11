//// GENERATED from admin/src/pages/home/page.gleam [sha256:a2a327ea7269] — 手で編集しない

import blocks/admin_header
import gen/load/layout
import gleam/list
import gleam/option.{type Option, None}
import style
import yumemi/blob.{type Blob}
import yumemi/front/css
import yumemi/front/el
import yumemi/front/html
import yumemi/front/theme

pub type Vars {
  Vars(subject: String)
}

pub type Data {
  Data(layout: layout.Data, vars: Vars)
}

pub fn load(vars: Vars) -> Data {
  Data(layout: layout.load(), vars: vars)
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
      html.title([], "yumemi admin fixture"),
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
    styled_area("page", style.page, page_children(it)),
  ])
}

fn page_children(it: Data) -> List(el.Element) {
  [
    html.div_(
      [el.attribute("data-yumemi-grid", "page:pages/home/page")],
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

fn page_placement_0(it: Data) -> List(el.Element) {
  [admin_header.view(Nil, admin_header.Arg(subject: it.vars.subject))]
}
