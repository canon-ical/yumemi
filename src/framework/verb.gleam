import framework/io.{type Context, type Promise}

pub opaque type Verb(value) {
  Verb(stage: fn(Context) -> Promise(value))
}

/// Generated adapters may stage SQL. They never execute it here.
pub fn staged(stage: fn(Context) -> Promise(value)) -> Verb(value) {
  Verb(stage)
}

/// Stage two database operations in one transaction. The second operation is
/// used by reorder so a unique order column can be cleared into temporary
/// values before the requested values are assigned.
pub fn compound(
  first: fn(Context) -> Promise(intermediate),
  then: fn(Context, intermediate) -> Promise(value),
) -> Verb(value) {
  Verb(fn(context) {
    use value <- io.then(first(context))
    then(context, value)
  })
}

pub fn stage(verb: Verb(value), context: Context) -> Promise(value) {
  verb.stage(context)
}
