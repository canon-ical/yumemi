//// GENERATED from src/components/blob_save.gleam [sha256:5f2785f02d66] — 手で編集しない

import framework/front/live
import framework/spec
import gen/out/article_blob_save
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/event

pub type Args {
  Args(slug: String, blob: String, existing: String)
}

pub type Field {
  Slug
  Blob
  Existing
}

pub type Error {
  Invalid(List(#(Field, String)))
  Failed
}

pub type State =
  live.State(Args, Nil, article_blob_save.Out, Error)

pub type Event =
  live.Event(Field, Nil, article_blob_save.Out, Error)

pub fn init(given: Nil) -> #(State, Effect(Event)) {
  #(
    live.State(
      args: Args(slug: "", blob: "", existing: ""),
      given: given,
      last: None,
      waiting: False,
    ),
    effect.none(),
  )
}

pub fn update(model: State, msg: Event) -> #(State, Effect(Event)) {
  case msg {
    live.Set(Slug, value) -> #(
      live.State(..model, args: Args(..model.args, slug: value)),
      effect.none(),
    )
    live.Set(Blob, value) -> #(
      live.State(..model, args: Args(..model.args, blob: value)),
      effect.none(),
    )
    live.Set(Existing, value) -> #(
      live.State(..model, args: Args(..model.args, existing: value)),
      effect.none(),
    )
    live.Send ->
      case model.waiting {
        True -> #(model, effect.none())
        False ->
          case validate(model) {
            Error(errors) -> #(
              live.State(..model, last: Some(Error(Invalid(errors)))),
              effect.none(),
            )
            Ok(args) -> #(live.State(..model, waiting: True), send(args))
          }
      }
    live.Given(given) -> #(live.State(..model, given: given), effect.none())
    live.Done(result) -> {
      let next = live.State(..model, last: Some(result), waiting: False)
      case result {
        Ok(_) -> #(next, effect.none())
        Error(_) -> #(next, effect.none())
      }
    }
  }
}

pub fn blob_file_input() -> List(attribute.Attribute(Event)) {
  file_input(Blob)
}

pub fn existing_file_input() -> List(attribute.Attribute(Event)) {
  file_input(Existing)
}

fn file_input(field: Field) -> List(attribute.Attribute(Event)) {
  [
    attribute.attribute("type", "file"),
    attribute.attribute("data-yumemi-file-input", ""),
    event.on("change", file_input_event(field)),
  ]
}

fn file_input_event(field: Field) -> decode.Decoder(Event) {
  decode.map(decode.dynamic, fn(event) { live.Set(field, file_token(event)) })
}

@external(javascript, "./transport_ffi.mjs", "file_token")
fn file_token(event: Dynamic) -> String

pub fn validate(model: State) -> Result(Args, List(#(Field, String))) {
  let errors =
    list.flatten([
      validate_field(
        Slug,
        model.args.slug,
        spec.Pattern(min: 1, max: 64, regex: "^[a-z0-9]+(-[a-z0-9]+)*$"),
        "must contain 1 to 64 characters and match /^[a-z0-9]+(-[a-z0-9]+)*$/",
      ),
    ])
  case errors {
    [] -> Ok(model.args)
    _ -> Error(errors)
  }
}

fn validate_field(
  field: Field,
  raw: String,
  constraint: spec.Spec,
  message: String,
) -> List(#(Field, String)) {
  case spec.validate(raw, constraint) {
    Ok(_) -> []
    Error(_) -> [#(field, message)]
  }
}

@external(javascript, "./transport_ffi.mjs", "send")
fn transport_send(
  method: String,
  path: String,
  body: json.Json,
  blob_fields: List(String),
  on_ok: fn(Dynamic) -> Nil,
  on_error: fn(Nil) -> Nil,
) -> Nil

fn send(args: Args) -> Effect(Event) {
  effect.from(fn(dispatch) {
    transport_send(
      "POST",
      "/api/articles/" <> args.slug <> "/blob_save",
      json.object([
        #("slug", json.string(args.slug)),
        #("blob", json.string(args.blob)),
        #("existing", case args.existing {
          "" -> json.null()
          value -> json.string(value)
        }),
      ]),
      ["blob", "existing"],
      fn(value) {
        case decode.run(value, article_blob_save.decoder()) {
          Ok(out) -> dispatch(live.Done(Ok(out)))
          Error(_) -> dispatch(live.Done(Error(Failed)))
        }
      },
      fn(_unit) { dispatch(live.Done(Error(Failed))) },
    )
  })
}
