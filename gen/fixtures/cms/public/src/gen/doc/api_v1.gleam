//// GENERATED from docs/api-v1.md [sha256:65851f722236] — 手で編集しない

import style
import yumemi/front/css
import yumemi/front/el
import yumemi/front/html

pub fn nodes() -> List(el.Element) {
  [
    heading1("Fixture API"),
    paragraph([el.text("Version: "), inline_code("v1")]),
    heading2("Authentication"),
    table_1(),
    heading2("Routes"),
    table_2(),
  ]
}

fn heading1(value: String) -> el.Element {
  html.h1(css.class([style.heading, style.ink]), [], [el.text(value)])
}

fn heading2(value: String) -> el.Element {
  html.h2(css.class([style.heading, style.ink]), [], [el.text(value)])
}

fn paragraph(children: List(el.Element)) -> el.Element {
  html.p(css.class([style.body, style.ink]), [], children)
}

fn inline_code(value: String) -> el.Element {
  html.code(css.class([style.body, style.ink]), [], [el.text(value)])
}

fn table_row(cells: List(el.Element)) -> el.Element {
  html.tr(css.class([style.body, style.ink]), [], cells)
}

fn header_cell(children: List(el.Element)) -> el.Element {
  html.th(css.class([style.body, style.ink]), [], children)
}

fn data_cell(children: List(el.Element)) -> el.Element {
  html.td(css.class([style.body, style.ink]), [], children)
}

fn table_1() -> el.Element {
  html.table(css.class([style.body, style.ink]), [], [
    html.thead(css.class([style.body, style.ink]), [], [
      table_row([
        header_cell([el.text("Method")]),
        header_cell([el.text("Path")]),
      ]),
    ]),
    html.tbody(css.class([style.body, style.ink]), [], [
      table_row([
        data_cell([el.text("POST")]),
        data_cell([inline_code("/session")]),
      ]),
    ]),
  ])
}

fn table_2() -> el.Element {
  html.table(css.class([style.body, style.ink]), [], [
    html.thead(css.class([style.body, style.ink]), [], [
      table_row([
        header_cell([el.text("Method")]),
        header_cell([el.text("Path")]),
        header_cell([el.text("Service")]),
      ]),
    ]),
    html.tbody(css.class([style.body, style.ink]), [], [
      table_row([
        data_cell([el.text("GET")]),
        data_cell([inline_code("/articles")]),
        data_cell([inline_code("article_list")]),
      ]),
    ]),
  ])
}
