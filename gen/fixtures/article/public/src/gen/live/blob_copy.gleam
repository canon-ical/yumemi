//// GENERATED from src/server.gleam [sha256:91b6b08d9d7a] — 手で編集しない

import framework/front/live
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/option.{None, Some}
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/event

pub type Args {
  Args(file: String)
}

pub type Field {
  File
}

pub type State =
  live.State(Args, Nil, String, String)

pub type Event =
  live.Event(Field, Nil, String, String)

pub fn init(_given: Nil) -> #(State, Effect(Event)) {
  #(
    live.State(args: Args(file: ""), given: Nil, last: None, waiting: False),
    effect.none(),
  )
}

pub fn update(model: State, msg: Event) -> #(State, Effect(Event)) {
  case msg {
    live.Set(File, value) -> #(
      live.State(..model, args: Args(file: value)),
      effect.none(),
    )
    live.Send ->
      case model.waiting {
        True -> #(model, effect.none())
        False -> #(live.State(..model, waiting: True), send(model.args))
      }
    live.Given(_) -> #(model, effect.none())
    live.Done(result) -> #(
      live.State(..model, last: Some(result), waiting: False),
      effect.none(),
    )
  }
}

pub fn file_input() -> List(attribute.Attribute(Event)) {
  [
    attribute.attribute("type", "file"),
    attribute.attribute("data-yumemi-file-input", ""),
    event.on("change", file_input_event()),
  ]
}

fn file_input_event() -> decode.Decoder(Event) {
  decode.map(decode.dynamic, fn(event) { live.Set(File, file_token(event)) })
}

@external(javascript, "./transport_ffi.mjs", "file_token")
fn file_token(event: Dynamic) -> String

@external(javascript, "./transport_ffi.mjs", "upload_file")
fn transport_upload(
  method: String,
  path: String,
  token: String,
  on_ok: fn(String) -> Nil,
  on_error: fn(Nil) -> Nil,
) -> Nil

fn send(args: Args) -> Effect(Event) {
  effect.from(fn(dispatch) {
    transport_upload(
      "POST",
      "/api/blobs",
      args.file,
      fn(key) { dispatch(live.Done(Ok(key))) },
      fn(_unit) { dispatch(live.Done(Error("file upload failed"))) },
    )
    Nil
  })
}

/// URL の写し(`{from: url}` を JSON で送る)。成功は写した key、失敗は本文の `code`(無ければ `url copy failed`)。
/// `Send`(file の upload)と同じ State を使い、送りの間は `waiting`。
pub fn copy_from(model: State, url: String) -> #(State, Effect(Event)) {
  case model.waiting || url == "" {
    True -> #(model, effect.none())
    False -> #(live.State(..model, waiting: True), send_from(url))
  }
}

@external(javascript, "./transport_ffi.mjs", "send")
fn transport_send(
  method: String,
  path: String,
  body: json.Json,
  blob_fields: List(String),
  on_ok: fn(Dynamic) -> Nil,
  on_error: fn(Dynamic) -> Nil,
) -> Nil

fn send_from(url: String) -> Effect(Event) {
  effect.from(fn(dispatch) {
    transport_send(
      "POST",
      "/api/blobs",
      json.object([#("from", json.string(url))]),
      [],
      fn(value) {
        case decode.run(value, decode.at(["key"], decode.string)) {
          Ok(key) if key != "" -> dispatch(live.Done(Ok(key)))
          _ -> dispatch(live.Done(Error("invalid response")))
        }
      },
      fn(value) {
        case decode.run(value, decode.at(["code"], decode.string)) {
          Ok(code) if code != "" -> dispatch(live.Done(Error(code)))
          _ -> dispatch(live.Done(Error("url copy failed")))
        }
      },
    )
  })
}
