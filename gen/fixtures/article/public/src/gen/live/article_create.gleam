//// GENERATED from src/components/pick_tag.gleam [sha256:cb6c05f590ba] — 手で編集しない

import framework/front/live
import framework/spec
import gen/out/article_create
import gen/out/article_list
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import lustre/effect.{type Effect}
import lustre/event

pub type Args {
  Args(
    slug: String,
    title: String,
    body: String,
    category: String,
    tags: String,
  )
}

pub type Field {
  Slug
  Title
  Body
  Category
  Tags
}

pub type Error

pub type Failure {
  Broke(String)
}

pub type State =
  live.State(Args, article_list.Out, article_create.Out, Failure)

pub type Event =
  live.Event(Field, article_list.Out, article_create.Out, Failure)

pub fn init(given: article_list.Out) -> #(State, Effect(Event)) {
  #(
    live.State(
      args: Args(slug: "", title: "", body: "", category: "", tags: ""),
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
    live.Set(Title, value) -> #(
      live.State(..model, args: Args(..model.args, title: value)),
      effect.none(),
    )
    live.Set(Body, value) -> #(
      live.State(..model, args: Args(..model.args, body: value)),
      effect.none(),
    )
    live.Set(Category, value) -> #(
      live.State(..model, args: Args(..model.args, category: value)),
      effect.none(),
    )
    live.Set(Tags, value) -> #(
      live.State(..model, args: Args(..model.args, tags: value)),
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
        Ok(_) -> #(next, reload_page())
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
      validate_field(
        Title,
        model.args.title,
        spec.Text(min: 1, max: 120),
        "must contain 1 to 120 characters",
      ),
      validate_field(
        Body,
        model.args.body,
        spec.Markdown,
        "must be valid Markdown",
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
      "/api/articles",
      json.object([
        #("slug", json.string(args.slug)),
        #("title", json.string(args.title)),
        #("body", json.string(args.body)),
        #("category", json.string(args.category)),
        #("tags", case list_items(args.tags) {
          Ok(items) -> json.array(items, fn(value) { json.string(value) })
          Error(_) -> json.string(args.tags)
        }),
      ]),
      [],
      fn(value) {
        case decode.run(value, article_create.decoder()) {
          Ok(out) -> dispatch(live.Done(Ok(out)))
          Error(_) -> dispatch(live.Done(Error(Broke("invalid response"))))
        }
      },
      fn(value) { dispatch(live.Done(Error(error_failure(value)))) },
    )
  })
}

/// List の欄は JSON の文字列の配列(`["a","b"]`、空の欄は `[]`)。
fn list_items(text: String) -> Result(List(String), Nil) {
  case text {
    "" -> Ok([])
    _ ->
      case json.parse(text, decode.list(decode.string)) {
        Ok(items) -> Ok(items)
        Error(_) -> Error(Nil)
      }
  }
}

fn reload_page() -> Effect(Event) {
  event.emit("yumemi-done", json.null())
}
