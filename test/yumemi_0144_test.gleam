//// yumemi-0144(0.14.4)── `PaddingLeft`:左の内側の余白だけを置く。

import gleam/string
import gleeunit/should
import yumemi/front/css
import yumemi/front/el
import yumemi/front/html

fn css_of(styles: List(css.Style)) -> String {
  let #(css_text, _) =
    el.styled(fn() { html.div(css.class(styles), [], []) }, "")
    |> el.to_string
    |> fn(text) { #(text, Nil) }
  css_text
}

pub fn padding_left_only_test() {
  let text = css_of([css.Space(property: css.PaddingLeft, value: css.Px(8.0))])
  string.contains(text, "padding-left: 8") |> should.be_true
  string.replace(text, "padding-left:", "")
  |> string.contains("padding:")
  |> should.be_false
}

pub fn padding_left_beside_border_test() {
  let text =
    css_of([
      css.Border(
        edge: css.LeftEdge,
        width: css.Px(4.0),
        style: css.Solid,
        color: css.Hex("#123456"),
      ),
      css.Space(property: css.PaddingLeft, value: css.Px(8.0)),
    ])
  string.contains(text, "border-left: 4.0px solid #123456;") |> should.be_true
  string.contains(text, "padding-left: 8") |> should.be_true
  string.replace(text, "padding-left:", "")
  |> string.contains("padding:")
  |> should.be_false
}
