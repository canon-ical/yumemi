//// interactive Component(0.12)── 送り 2 つ(公開する・写しを作る)。写しは dialog の中の送り(確認の 1 段)。
//// 公開したら記事の頁へ移る(GoTo の path の穴 `:slug` は article_publish の Out の `slug` で埋まる)。
//// 逃げ道(gen/escapes)は Component の中にも置ける。

import gen/escapes
import gen/live/article_publish as publish
import gen/live/article_create as create
import gen/route
import gen/service
import gleam/option.{None, Some}
import yumemi/front/attr
import yumemi/front/css
import yumemi/front/el.{type Element}
import yumemi/front/html
import yumemi/front/live

pub const calls: List(service.Service) = [
  service.ArticlePublish,
  service.ArticleCreate,
]

pub const after_send: List(#(service.Service, live.After(route.Route))) = [
  #(
    service.ArticlePublish,
    live.After(
      ok: live.GoTo(route.ArticleArgSlug, notice: Some("公開しました")),
      error: live.Stay,
    ),
  ),
  #(
    service.ArticleCreate,
    live.After(ok: live.ReloadPage(notice: None), error: live.Stay),
  ),
]

pub fn view(p: publish.Args, c: create.Args) -> Element {
  html.div_([], [
    html.input_([attr.type_("text"), publish.bind(publish.Slug, p.slug)]),
    html.input_([attr.type_("text"), create.bind(create.Slug, c.slug)]),
    publish.send(css.class([]), [el.text("公開する")]),
    el.dialog_opener("copy", css.class([]), [el.text("写しを作る")]),
    el.dialog("copy", css.class([]), [], [
      html.p_([], [el.text("写しを作りますか。")]),
      create.send(css.class([]), [el.text("作る")]),
      el.dialog_closer("copy", css.class([]), [el.text("やめる")]),
    ]),
    publish.when(publish.Failed, [html.p_([], [el.text("公開できませんでした")])]),
    create.when(create.Failed, [html.p_([], [el.text("作れませんでした")])]),
    escapes.clock([], [el.text("時計(JS が無いとき)")]),
  ])
}
