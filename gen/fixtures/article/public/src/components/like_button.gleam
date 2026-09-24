//// Interactive Component ── the generated live module owns State / Event / update.

import framework/front
import framework/front/el
import framework/front/live as front_live
import gen/live/article_publish
import gen/service
import gleam/int
import gleam/option.{None, Some}
import lustre
import lustre/attribute
import lustre/component
import lustre/event
import sketch/lustre/element/html

pub const calls: List(front.Target(service.Service, Nil)) = [
  front.Of(service.ArticlePublish),
]

pub const after_send: front_live.After = front_live.Stay

pub fn view(it: article_publish.State) -> el.Element(article_publish.Event) {
  html.button_(
    [event.on_click(front_live.Send), attribute.disabled(it.waiting)],
    [
      el.text(label(it)),
    ],
  )
}

fn label(model: article_publish.State) -> String {
  case model.last {
    Some(Ok(article)) -> "❤ " <> int.to_string(article.version)
    Some(Error(_)) -> "いいね"
    None -> "いいね"
  }
}

pub fn app() -> lustre.App(Nil, article_publish.State, article_publish.Event) {
  lustre.component(article_publish.init, article_publish.update, view, [
    component.on_attribute_change("slug", fn(value) {
      Ok(front_live.Set(article_publish.Slug, value))
    }),
  ])
}
