//// GENERATED from service commit continuations / framework outbox [sha256:3e10e3ef3932] — 手で編集しない

import yumemi/io.{type Context, type Promise}
import yumemi/step.{type Committed, type Outcome, type Step}

pub fn resume(
  continuation: Step(out, err, Committed),
  context: Context,
) -> Promise(Outcome(out, err)) {
  step.resume(continuation, context)
}
