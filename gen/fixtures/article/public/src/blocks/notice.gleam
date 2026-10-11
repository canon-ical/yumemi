//// Notice Block ── 今の記事の slug を描き、記事の書体の CSS を生の CSS の逃げ道で読む。

import yumemi/front/el

pub type In =
  Nil

pub type Arg {
  Arg(slug: String)
}

pub fn view(_it: In, arg: Arg) -> el.Element {
  el.fragment([
    el.stylesheet(el.static_sheet("article_font.css")),
    el.text("Current article: " <> arg.slug),
  ])
}
