//// GENERATED from src/components/like_button.gleam [sha256:0ca7721b0f95] — 手で編集しない

import framework/front/live
import framework/spec
import gen/out/article_publish
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import lustre/effect.{type Effect}

pub type Args {
  Args(slug: String)
}

pub type Field {
  Slug
}

pub type Error {
  Invalid(List(#(Field, String)))
  Failed
}

pub type State =
  live.State(Args, Nil, article_publish.Out, Error)

pub type Event =
  live.Event(Field, Nil, article_publish.Out, Error)

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
      "/api/articles/" <> args.slug <> "/publish",
      json.object([
        #("slug", json.string(args.slug)),
      ]),
      [],
      fn(value) {
        case decode.run(value, article_publish.decoder()) {
          Ok(out) -> dispatch(live.Done(Ok(out)))
          Error(_) -> dispatch(live.Done(Error(Failed)))
        }
      },
      fn(_unit) { dispatch(live.Done(Error(Failed))) },
    )
  })
}
