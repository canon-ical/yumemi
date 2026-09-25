//// GENERATED from service commit continuations / framework outbox [sha256:032d56dd277b] — 手で編集しない

import framework/io.{type Context, type Promise}
import framework/step.{type Committed, type Outcome, type Step}

pub fn resume(
  continuation: Step(out, err, Committed),
  context: Context,
) -> Promise(Outcome(out, err)) {
  step.resume(continuation, context)
}
