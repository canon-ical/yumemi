//// interactive Component(0.12)── `reloads` の単一の値。slug を替えたら article_title を読み直し、out に入れる。

import gen/live/article_title as title
import gen/route
import gen/service
import yumemi/front/attr
import yumemi/front/el.{type Element}
import yumemi/front/html
import yumemi/front/live

pub const calls: List(service.Service) = [service.ArticleTitle]

pub const after_send: List(#(service.Service, live.After(route.Route))) = []

pub const reloads: live.Reloads(service.Service, title.Field) = live.Reloads(
  read: service.ArticleTitle,
  on: [title.Slug],
)

pub fn view(it: title.Args) -> Element {
  html.div_([], [
    html.input_([attr.type_("text"), title.bind(title.Slug, it.slug)]),
    html.p_([], [title.out(title.OutTitle)]),
    title.when(title.Waiting, [html.span_([], [el.text("読んでいます")])]),
  ])
}
