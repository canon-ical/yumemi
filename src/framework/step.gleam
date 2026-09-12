//// CPS interpreter. State is a pure phantom; every operation rewraps.

import framework/connector
import framework/io.{type Context, type Promise}
import framework/verb.{type Verb}

pub type Start

pub type Open

pub type Committed

pub type Outcome(out, err) {
  Done(out)
  Fail(err)
  Accepted
}

pub opaque type Step(out, err, state) {
  Step(run: fn(Context) -> Promise(Outcome(out, err)))
}

fn go(
  step: Step(out, err, state),
  context: Context,
) -> Promise(Outcome(out, err)) {
  step.run(context)
}

pub fn read(
  read: fn(Context) -> Promise(value),
  then: fn(value) -> Step(out, err, state),
) -> Step(out, err, state) {
  Step(fn(context) {
    use value <- io.then(read(context))
    go(then(value), context)
  })
}

pub fn guard(
  condition: Bool,
  error: err,
  then: fn() -> Step(out, err, state),
) -> Step(out, err, state) {
  Step(fn(context) {
    case condition {
      True -> go(then(), context)
      False -> io.resolve(Fail(error))
    }
  })
}

pub fn apply(
  operation: Verb(value),
  then: fn(value) -> Step(out, err, Open),
) -> Step(out, err, state) {
  Step(fn(context) {
    use value <- io.then(verb.stage(operation, context))
    go(then(value), context)
  })
}

pub fn call(
  request: connector.Read(value),
  then: fn(value) -> Step(out, err, state),
) -> Step(out, err, state) {
  Step(fn(context) {
    use value <- io.then(connector.run_read(request, context))
    go(then(value), context)
  })
}

pub fn commit(
  carry: value,
  then: fn(value) -> Step(out, err, Committed),
) -> Step(out, err, state) {
  Step(fn(context) {
    use continue <- io.then(io.commit(context, carry))
    case continue {
      True -> go(then(carry), context)
      False -> io.resolve(Accepted)
    }
  })
}

pub fn call_write(
  request: connector.Write(value),
  then: fn(value) -> Step(out, err, Committed),
) -> Step(out, err, Committed) {
  Step(fn(context) {
    use value <- io.then(connector.run_write(request, context))
    go(then(value), context)
  })
}

pub fn done(value: out) -> Step(out, err, state) {
  Step(fn(context) {
    use _ <- io.then(io.finish(context))
    io.resolve(Done(value))
  })
}

pub fn fail(error: err) -> Step(out, err, state) {
  Step(fn(_) { io.resolve(Fail(error)) })
}

pub fn interpret(
  step: Step(out, err, Start),
  context: Context,
) -> Promise(Outcome(out, err)) {
  go(step, context)
}

/// Queue adapters may only enter a continuation at a committed boundary.
pub fn resume(
  step: Step(out, err, Committed),
  context: Context,
) -> Promise(Outcome(out, err)) {
  go(step, context)
}

/// Discard staged normal work; confirm only this verb in its own transaction.
/// A failed save rejects the promise and is mapped to infrastructure failure.
pub fn reject(operation: Verb(value), error: err) -> Step(out, err, state) {
  Step(fn(context) {
    use _ <- io.then(io.reject(context, fn(isolated) {
      verb.stage(operation, isolated)
    }))
    io.resolve(Fail(error))
  })
}
