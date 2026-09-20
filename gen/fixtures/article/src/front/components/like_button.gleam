//// interactive Component ── framework/front/live の State / Event を使う島。

import framework/front/el
import framework/front/live
import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/option.{None, Some}
import lustre
import lustre/attribute
import lustre/component
import lustre/effect.{type Effect}
import lustre/element/html
import lustre/event

pub type Model =
  live.State(Nil, Int, Nil)

pub type Msg =
  live.Event(Nil, Int, Nil)

fn init(_args: Nil) -> #(Model, Effect(Msg)) {
  #(live.State(args: Nil, last: None, waiting: False), effect.none())
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
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

fn view(model: Model) -> el.Element(Msg) {
  html.button([event.on_click(live.Send), attribute.disabled(model.waiting)], [
    el.text(label(model)),
  ])
}

fn label(model: Model) -> String {
  case model.last {
    Some(Ok(count)) -> "❤ " <> int.to_string(count)
    Some(Error(_)) -> "いいね"
    None -> "いいね"
  }
}

fn fetch_count() -> Effect(Msg) {
  use dispatch <- effect.from
  let _ =
    promise.map(fetch_like(), fn(count) { dispatch(live.Done(Ok(count))) })
  Nil
}

@external(javascript, "./like_button_ffi.mjs", "fetchLike")
fn fetch_like() -> Promise(Int)

pub fn app() -> lustre.App(Nil, Model, Msg) {
  lustre.component(init, update, view, [
    component.on_attribute_change("count", fn(value) {
      case int.parse(value) {
        Ok(count) -> Ok(live.Done(Ok(count)))
        Error(_) -> Error(Nil)
      }
    }),
  ])
}
