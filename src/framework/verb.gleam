import framework/io.{type Context, type Promise}

pub opaque type Verb(value) {
  Verb(stage: fn(Context) -> Promise(value))
}

/// Generated adapters may stage SQL. They never execute it here.
pub fn staged(stage: fn(Context) -> Promise(value)) -> Verb(value) {
  Verb(stage)
}

pub fn stage(verb: Verb(value), context: Context) -> Promise(value) {
  verb.stage(context)
}
