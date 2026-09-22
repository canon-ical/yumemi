//// GENERATED from src/components/like_button.gleam [sha256:1d679d906019] — 手で編集しない

import framework/front/live
import framework/spec
import gen/out/article_publish
import gleam/list
import gleam/option.{None, Some}
import lustre/effect.{type Effect}

pub type Args {
  Args(
    slug: String,
  )
}

pub type Field {
  Slug
}

pub type Error = Nil

pub type State = live.State(Args, Nil, article_publish.Out, Error)

pub type Event = live.Event(Field, Nil, article_publish.Out, Error)

pub fn init(given: Nil) -> #(State, Effect(Event)) {
  #(
    live.State(
      args: Args(
        slug: "",
      ),
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
      live.State(..model, args: Args(slug: value)),
      effect.none(),
    )
    live.Send ->
      case model.waiting {
        True -> #(model, effect.none())
        False -> #(
          live.State(..model, waiting: True),
          send(model.args),
        )
      }
    live.Given(given) -> #(
      live.State(..model, given: given),
      effect.none(),
    )
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
  let errors = list.flatten([
    validate_field(Slug, model.args.slug, spec.Pattern(min: 1, max: 64, regex: "^[a-z0-9]+(-[a-z0-9]+)*$")),
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
) -> List(#(Field, String)) {
  case spec.validate(raw, constraint) {
    Ok(_) -> []
    Error(_) -> [#(field, "invalid")]
  }
}

fn send(_args: Args) -> Effect(Event) {
  effect.none()
}

