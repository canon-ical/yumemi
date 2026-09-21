//// Interactive Component ── a write-first island with SSR-provided choices.

import framework/front/el
import framework/front/live
import gen/service
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import lustre
import lustre/attribute
import lustre/component
import lustre/effect.{type Effect}
import lustre/event
import sketch/lustre/element/html

pub type State =
  live.State(String, List(String), Nil, Nil)

pub type Event =
  live.Event(Nil, List(String), Nil, Nil)

pub const calls: List(service.Service) = []

pub const after_send: live.After = live.ReloadPage

fn init(_args: Nil) -> #(State, Effect(Event)) {
  #(live.State(args: "", given: [], last: None, waiting: False), effect.none())
}

fn update(model: State, msg: Event) -> #(State, Effect(Event)) {
  case msg {
    live.Set(_, tag) -> #(live.State(..model, args: tag), effect.none())
    live.Send ->
      case model.waiting {
        True -> #(model, effect.none())
        False -> #(live.State(..model, waiting: True), post_tag(model.args))
      }
    live.Given(tags) -> #(live.State(..model, given: tags), effect.none())
    live.Done(result) ->
      case result {
        Ok(_) -> #(
          live.State(..model, last: Some(result), waiting: False),
          event.emit("yumemi-done", json.null()),
        )
        Error(_) -> #(
          live.State(..model, last: Some(result), waiting: False),
          effect.none(),
        )
      }
  }
}

pub fn view(it: State) -> el.Element(Event) {
  html.div_([], [
    html.select_(
      [
        attribute.value(it.args),
        event.on_change(fn(value) { live.Set(Nil, value) }),
      ],
      list.map(it.given, fn(tag) {
        html.option_([attribute.value(tag)], [el.text(tag)])
      }),
    ),
    html.button_([event.on_click(live.Send), attribute.disabled(it.waiting)], [
      el.text("タグを保存"),
    ]),
  ])
}

fn post_tag(tag: String) -> Effect(Event) {
  use dispatch <- effect.from
  post_tag_request(tag, fn(_unit) { dispatch(live.Done(Ok(Nil))) })
  Nil
}

@external(javascript, "./pick_tag_ffi.mjs", "postTag")
fn post_tag_request(tag: String, dispatch: fn(Nil) -> Nil) -> Nil

pub fn app() -> lustre.App(Nil, State, Event) {
  lustre.component(init, update, view, [
    component.on_attribute_change("tags", fn(value) {
      let tags =
        value
        |> string.split(",")
        |> list.filter(fn(tag) { tag != "" })

      Ok(live.Given(tags))
    }),
    component.on_attribute_change("selected", fn(value) {
      Ok(live.Set(Nil, value))
    }),
  ])
}
