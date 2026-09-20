//// ArticleSummary Block ── isolate cross-check 用の別 Style。

import framework/front/css
import framework/front/el
import framework/front/sketch_css
import sketch/lustre/element/html

pub type In {
  In(headline: String)
}

pub const sample: In = In(headline: "本日の記事サマリー")

const card: List(css.Style) = [
  css.Color("#123524"),
  css.Space(property: css.Padding, value: css.Px(24.0)),
  css.Space(property: css.Gap, value: css.Px(4.0)),
]

const title: List(css.Style) = [
  css.Color("#c8ffe0"),
  css.Text(
    family: css.Serif,
    size: css.Rem(2.0),
    weight: css.Medium,
    line_height: css.Rem(2.2),
  ),
]

pub fn view(it: In) -> el.Element(Nil) {
  html.section(sketch_css.class(card), [], [
    html.h1(sketch_css.class(title), [], [el.text(it.headline)]),
  ])
}
