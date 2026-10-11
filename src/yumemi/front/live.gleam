import gleam/option.{type Option}

pub type State(args, given, out, error) {
  State(
    args: args,
    given: given,
    last: Option(Result(out, error)),
    waiting: Bool,
  )
}

pub type Event(field, given, out, error) {
  Set(field, String)
  Send
  Given(given)
  Done(Result(out, error))
}

pub type After {
  Stay
  ReloadPage
}
