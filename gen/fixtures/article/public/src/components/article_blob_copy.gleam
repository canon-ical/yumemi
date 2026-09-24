import framework/front
import framework/front/el
import framework/front/live as front_live
import gen/api
import gen/live/blob_copy
import gleam/option.{None, Some}
import lustre
import lustre/attribute
import lustre/event
import sketch/lustre/element/html

pub const target: api.Target = front.Entry(api.BlobCopy)

pub fn view(it: blob_copy.State) -> el.Element(blob_copy.Event) {
  html.div_([], [
    html.input_(blob_copy.file_input()),
    html.button_(
      [event.on_click(front_live.Send), attribute.disabled(it.waiting)],
      [el.text("Upload article image")],
    ),
    case it.last {
      Some(Ok(key)) ->
        html.p_([attribute.attribute("data-blob-key", key)], [el.text(key)])
      Some(Error(_)) -> html.p_([], [el.text("upload failed")])
      None -> html.p_([], [el.text("choose a file")])
    },
  ])
}

pub fn app() -> lustre.App(Nil, blob_copy.State, blob_copy.Event) {
  lustre.component(blob_copy.init, blob_copy.update, view, [])
}
