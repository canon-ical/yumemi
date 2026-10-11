//// SiteHeader Block ── 入力無しの静的ヘッダ。

import yumemi/front/el
import yumemi/front/css
import yumemi/front/html
import style

pub type In = Nil

pub fn view(_it: In) -> el.Element {
  html.header(css.class([style.heading]), [], [el.text("記事")])
}
