//// SiteHeader Block ── 入力無しの静的ヘッダ。

import yumemi/front/el
import yumemi/front/sketch_css
import sketch/lustre/element/html
import style

pub type In = Nil

pub fn view(_it: In) -> el.Element(Nil) {
  html.header(sketch_css.class([style.heading]), [], [el.text("記事")])
}
