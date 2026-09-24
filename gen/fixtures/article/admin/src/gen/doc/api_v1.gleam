//// GENERATED from docs/api-v1.md [sha256:65851f722236] — 手で編集しない

import framework/front/el
import framework/front/sketch_css
import sketch/lustre/element/html
import style

pub fn nodes() -> List(el.Element(Nil)) {
  [
    heading1("Fixture API"),
    paragraph([el.text("Version: "), inline_code("v1")]),
    heading2("Authentication"),
    table_1(),
    heading2("Routes"),
    table_2(),
  ]
}

fn heading1(value: String) -> el.Element(Nil) {
  html.h1(sketch_css.class([style.heading, style.ink]), [], [el.text(value)])
}

fn heading2(value: String) -> el.Element(Nil) {
  html.h2(sketch_css.class([style.heading, style.ink]), [], [el.text(value)])
}

fn paragraph(children: List(el.Element(Nil))) -> el.Element(Nil) {
  html.p(sketch_css.class([style.body, style.ink]), [], children)
}

fn inline_code(value: String) -> el.Element(Nil) {
  html.code(sketch_css.class([style.body, style.ink]), [], [el.text(value)])
}

fn table_row(cells: List(el.Element(Nil))) -> el.Element(Nil) {
  html.tr(sketch_css.class([style.body, style.ink]), [], cells)
}

fn header_cell(children: List(el.Element(Nil))) -> el.Element(Nil) {
  html.th(sketch_css.class([style.body, style.ink]), [], children)
}

fn data_cell(children: List(el.Element(Nil))) -> el.Element(Nil) {
  html.td(sketch_css.class([style.body, style.ink]), [], children)
}

fn table_1() -> el.Element(Nil) {
  html.table(sketch_css.class([style.body, style.ink]), [], [
    html.thead(sketch_css.class([style.body, style.ink]), [], [
      table_row([
        header_cell([el.text("Method")]),
        header_cell([el.text("Path")]),
      ]),
    ]),
    html.tbody(sketch_css.class([style.body, style.ink]), [], [
      table_row([
        data_cell([el.text("POST")]),
        data_cell([inline_code("/session")]),
      ]),
    ]),
  ])
}

fn table_2() -> el.Element(Nil) {
  html.table(sketch_css.class([style.body, style.ink]), [], [
    html.thead(sketch_css.class([style.body, style.ink]), [], [
      table_row([
        header_cell([el.text("Method")]),
        header_cell([el.text("Path")]),
        header_cell([el.text("Service")]),
      ]),
    ]),
    html.tbody(sketch_css.class([style.body, style.ink]), [], [
      table_row([
        data_cell([el.text("GET")]),
        data_cell([inline_code("/articles")]),
        data_cell([inline_code("article_list")]),
      ]),
    ]),
  ])
}
