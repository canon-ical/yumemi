//// Interactive Component ── choices come from the generated reload Out.

import framework/front/el
import framework/front/live as front_live
import gen/live/article_create
import gen/out/article_list
import gen/service
import gleam/list
import lustre
import lustre/attribute
import lustre/component
import lustre/event
import sketch/lustre/element/html

pub const calls: List(service.Service) = [service.ArticleCreate]

pub const reloads: List(#(article_create.Field, service.Service)) = [
  #(article_create.Slug, service.ArticleList),
]

pub const after_send: front_live.After = front_live.ReloadPage

pub fn view(it: article_create.State) -> el.Element(article_create.Event) {
  html.div_([], [
    html.select_(
      [
        event.on_change(fn(value) {
          front_live.Set(article_create.Tags, value)
        }),
      ],
      list.map(it.given.counts, fn(item) {
        let #(category, _count) = item
        html.option_([attribute.value(category.name)], [el.text(category.name)])
      }),
    ),
    html.button_([event.on_click(front_live.Send), attribute.disabled(it.waiting)], [
      el.text("タグを保存"),
    ]),
  ])
}

pub fn app() -> lustre.App(article_list.Out, article_create.State, article_create.Event) {
  lustre.component(article_create.init, article_create.update, view, [
    component.on_attribute_change("selected", fn(value) {
      Ok(front_live.Set(article_create.Tags, value))
    }),
  ])
}
