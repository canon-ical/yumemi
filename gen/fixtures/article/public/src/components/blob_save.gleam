//// interactive Component(0.12)── Blob の欄は file の control。送る前に runtime が上げて key を Args に入れる
//// (「上げる → key を Args」は Service の連鎖に当たらない)。

import gen/live/article_blob_save as save
import gen/route
import gen/service
import yumemi/front/css
import yumemi/front/el.{type Element}
import yumemi/front/html
import yumemi/front/live

pub const calls: List(service.Service) = [service.ArticleBlobSave]

pub const after_send: List(#(service.Service, live.After(route.Route))) = [
  #(service.ArticleBlobSave, live.After(ok: live.Stay, error: live.Stay)),
]

pub fn view(_save: save.Args) -> Element {
  html.div_([], [
    html.input_([save.bind_file(save.Blob)]),
    save.send(css.class([]), [el.text("Save image")]),
    save.when(save.Idle, [html.p_([], [el.text("ready")])]),
    save.when(save.Succeeded, [html.p_([], [el.text("saved")])]),
    save.when(save.Failed, [html.p_([], [el.text("failed")])]),
  ])
}
