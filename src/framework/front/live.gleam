import gleam/option.{type Option}

pub type State(args, out, error) {
  State(args: args, last: Option(Result(out, error)), waiting: Bool)
}

pub type Event(field, out, error) {
  Set(field, String)
  Send
  Done(Result(out, error))
}
