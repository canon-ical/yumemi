//// interactive Component(0.12)── 選択肢は置いた Block が `with` で渡す(SSR で 1 回描く値、状態ではない)。

import gen/live/article_create as create
import gen/route
import gen/service
import gleam/option.{Some}
import yumemi/front/attr
import yumemi/front/css
import yumemi/front/el.{type Element}
import yumemi/front/html
import yumemi/front/live

pub const calls: List(service.Service) = [service.ArticleCreate]

pub const after_send: List(#(service.Service, live.After(route.Route))) = [
  #(
    service.ArticleCreate,
    live.After(
      ok: live.ReloadPage(notice: Some("タグを保存しました")),
      error: live.Stay,
    ),
  ),
]

pub type With {
  With(choices: List(String), selected: String)
}

pub fn view(it: create.Args, with: With) -> Element {
  html.div_([], [
    html.input_([attr.type_("text"), create.bind(create.Title, it.title)]),
    html.select_(
      [create.bind_choice(create.Tags)],
      el.each(with.choices, fn(choice) {
        html.option_(
          [attr.value(choice), attr.selected(choice == with.selected)],
          [el.text(choice)],
        )
      })
        |> fn(options) { [options] },
    ),
    create.send(css.class([]), [el.text("タグを保存")]),
    create.when(create.Failed, [html.p_([], [el.text("保存できませんでした")])]),
  ])
}
