import framework/front
import framework/front/el
import framework/front/live as front_live
import gen/api
import gen/live/article_blob_save
import gen/service
import gleam/option.{None, Some}
import lustre
import lustre/attribute
import lustre/component
import lustre/event
import sketch/lustre/element/html

pub const calls: List(front.Target(service.Service, api.Attached)) = [
  front.Of(service.ArticleBlobSave),
]

pub fn view(
  it: article_blob_save.State,
) -> el.Element(article_blob_save.Event) {
  html.div_([], [
    html.input_(article_blob_save.blob_file_input()),
    html.button_(
      [event.on_click(front_live.Send), attribute.disabled(it.waiting)],
      [el.text("Save image")],
    ),
    case it.last {
      Some(Ok(_)) -> html.p_([], [el.text("saved")])
      Some(Error(_)) -> html.p_([], [el.text("failed")])
      None -> html.p_([], [el.text("ready")])
    },
  ])
}

pub fn app() -> lustre.App(
  Nil,
  article_blob_save.State,
  article_blob_save.Event,
) {
  lustre.component(article_blob_save.init, article_blob_save.update, view, [
    component.on_attribute_change("slug", fn(value) {
      Ok(front_live.Set(article_blob_save.Slug, value))
    }),
    component.on_attribute_change("blob", fn(value) {
      Ok(front_live.Set(article_blob_save.Blob, value))
    }),
    component.on_attribute_change("existing", fn(value) {
      Ok(front_live.Set(article_blob_save.Existing, value))
    }),
  ])
}
