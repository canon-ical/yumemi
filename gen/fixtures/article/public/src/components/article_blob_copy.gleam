//// interactive Component(0.12)── 上げ口(attached の `Entry`)も `calls` に並べる(`pub const target` は畳んだ)。

import yumemi/front
import gen/api
import gen/live/blob_copy as copy
import gen/service
import yumemi/front/css
import yumemi/front/el.{type Element}
import yumemi/front/html

pub const calls: List(front.Target(service.Service, api.Attached)) = [
  front.Entry(api.BlobCopy),
]

pub fn view(_copy: copy.Args) -> Element {
  html.div_([], [
    html.input_([copy.bind_file(copy.File)]),
    copy.send(css.class([]), [el.text("Upload article image")]),
    copy.when(copy.Succeeded, [html.p_([], [copy.out(copy.OutKey)])]),
    copy.when(copy.Failed, [html.p_([], [el.text("upload failed")])]),
    copy.when(copy.Idle, [html.p_([], [el.text("choose a file")])]),
  ])
}
