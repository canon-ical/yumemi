//// interactive Component(0.12)── 送り 1 つ。view は Args を受けて要素を返すだけ。

import gen/live/article_publish as publish
import gen/route
import gen/service
import yumemi/front/css
import yumemi/front/el.{type Element}
import yumemi/front/html
import yumemi/front/live

pub const calls: List(service.Service) = [service.ArticlePublish]

pub const after_send: List(#(service.Service, live.After(route.Route))) = [
  #(service.ArticlePublish, live.After(ok: live.Stay, error: live.Stay)),
]

const button: List(css.Style) = [
  css.State(css.Waiting, [css.Background(css.Hex("#cccccc"))]),
]

pub fn view(_publish: publish.Args) -> Element {
  html.div_([], [
    publish.send(css.class(button), [el.text("いいね")]),
    publish.when(publish.Succeeded, [
      html.span_([], [el.text("❤ "), publish.out(publish.OutVersion)]),
    ]),
    publish.when(publish.Refused(publish.AlreadyPublished), [
      html.span_([], [el.text("公開済み")]),
    ]),
    publish.when(publish.Failed, [html.span_([], [el.text("送れませんでした")])]),
  ])
}
