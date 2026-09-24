//// GENERATED from src/components/like_button.gleam [sha256:0ca7721b0f95] — 手で編集しない

import framework/front/live
import framework/spec
import gen/out/article_publish
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import lustre/effect.{type Effect}

pub type Args {
  Args(slug: String)
}

pub type Field {
  Slug
}

pub type Error {
  AlreadyPublished
  AlreadyRetracted
}

pub type Failure {
  Refused(Error)
  Broke(String)
}

pub type State =
  live.State(Args, Nil, article_publish.Out, Failure)

pub type Event =
  live.Event(Field, Nil, article_publish.Out, Failure)

pub fn init(given: Nil) -> #(State, Effect(Event)) {
  #(
    live.State(args: Args(slug: ""), given: given, last: None, waiting: False),
    effect.none(),
  )
}

pub fn update(model: State, msg: Event) -> #(State, Effect(Event)) {
  case msg {
    live.Set(Slug, value) -> #(
      live.State(..model, args: Args(slug: value)),
      effect.none(),
    )
    live.Send ->
      case model.waiting {
        True -> #(model, effect.none())
        False ->
          case validate(model) {
            Error(errors) -> #(
              live.State(
                ..model,
                last: Some(Error(Broke(validation_error_text(errors)))),
              ),
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

fn validation_error_text(errors: List(#(Field, String))) -> String {
  errors |> list.map(fn(error) { error.1 }) |> string.join("; ")
}

fn error_failure(value: Dynamic) -> Failure {
  case error_text(value) {
    "already_published" -> Refused(AlreadyPublished)
    "already_retracted" -> Refused(AlreadyRetracted)
    code -> Broke(code)
  }
}

fn error_text(value: Dynamic) -> String {
  case decode.run(value, error_field_decoder("code")) {
    Ok(code) if code != "" -> code
    _ ->
      case decode.run(value, error_field_decoder("message")) {
        Ok(message) if message != "" -> message
        _ -> "invalid error payload"
      }
  }
}

fn error_field_decoder(field: String) -> decode.Decoder(String) {
  decode.optional_field(field, "", decode.string, fn(value) {
    decode.success(value)
  })
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

fn send(args: Args) -> Effect(Event) {
  effect.from(fn(dispatch) {
    transport_send(
      "POST",
      "/api/articles/" <> args.slug <> "/publish",
      json.object([
        #("slug", json.string(args.slug)),
      ]),
      [],
      fn(value) {
        case decode.run(value, article_publish.decoder()) {
          Ok(out) -> dispatch(live.Done(Ok(out)))
          Error(_) -> dispatch(live.Done(Error(Broke("invalid response"))))
        }
      },
      fn(value) { dispatch(live.Done(Error(error_failure(value)))) },
    )
  })
}
