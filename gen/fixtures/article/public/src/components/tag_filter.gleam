//// interactive Component(0.12)── `reloads` の一覧。読みの Out(widget_list の rows)に List があるので、選んだら
//// query(`?widget=`)を替えた同じ頁へ履歴を積まずに移り、行は置いた Block(Feed、In が widget_list)が SSR で描く。

import gen/live/widget_list as widget
import gen/route
import gen/service
import yumemi/front/attr
import yumemi/front/el.{type Element}
import yumemi/front/html
import yumemi/front/live

pub const calls: List(service.Service) = [service.WidgetList]

pub const after_send: List(#(service.Service, live.After(route.Route))) = []

pub const reloads: live.Reloads(service.Service, widget.Field) = live.Reloads(
  read: service.WidgetList,
  on: [widget.Widget],
)

pub type With {
  With(choices: List(String))
}

pub fn view(_it: widget.Args, with: With) -> Element {
  html.select_([widget.bind_choice(widget.Widget)], [
    el.each(with.choices, fn(choice) {
      html.option_([attr.value(choice)], [el.text(choice)])
    }),
  ])
}
