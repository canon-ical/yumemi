//// interactive Component ── framework/front/live の State / Event を使う島。

import framework/front/el
import framework/front/live
import gen/service
import gleam/int
import gleam/option.{None, Some}
import lustre
import lustre/attribute
import lustre/component
import lustre/effect.{type Effect}
import lustre/event
import sketch/lustre/element/html

pub type State = live.State(Nil, Int, Nil)

pub type Event = live.Event(Nil, Int, Nil)

pub const calls: List(service.Service) = []

fn init(_args: Nil) -> #(State, Effect(Event)) {
  #(live.State(args: Nil, last: None, waiting: False), effect.none())
}

fn update(model: State, msg: Event) -> #(State, Effect(Event)) {
  case msg {
    live.Set(_, _) -> #(model, effect.none())
    live.Send ->
      case model.waiting {
        True -> #(model, effect.none())
        False -> #(live.State(..model, waiting: True), fetch_count())
      }
    live.Done(result) -> #(
      live.State(..model, last: Some(result), waiting: False),
      effect.none(),
    )
  }
}

pub fn view(it: State) -> el.Element(Event) {
  html.button_([event.on_click(live.Send), attribute.disabled(it.waiting)], [
    el.text(label(it)),
  ])
}

fn label(model: State) -> String {
  case model.last {
    Some(Ok(count)) -> "❤ " <> int.to_string(count)
    Some(Error(_)) -> "いいね"
    None -> "いいね"
  }
}

fn fetch_count() -> Effect(Event) {
  use dispatch <- effect.from
  fetch_like(fn(count) { dispatch(live.Done(Ok(count))) })
  Nil
}

@external(javascript, "./like_button_ffi.mjs", "fetchLike")
fn fetch_like(dispatch: fn(Int) -> Nil) -> Nil

pub fn app() -> lustre.App(Nil, State, Event) {
  lustre.component(init, update, view, [
    component.on_attribute_change("count", fn(value) {
      case int.parse(value) {
        Ok(count) -> Ok(live.Done(Ok(count)))
        Error(_) -> Error(Nil)
      }
    }),
  ])
}
