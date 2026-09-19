//// Interpreter capabilities supplied by the generated runtime or a test.

pub type Context

pub type Promise(value)

@external(javascript, "./io_ffi.mjs", "resolve")
pub fn resolve(value: value) -> Promise(value)

@external(javascript, "./io_ffi.mjs", "then")
pub fn then(value: Promise(a), next: fn(a) -> Promise(b)) -> Promise(b)

@external(javascript, "./io_ffi.mjs", "commit")
pub fn commit(context: Context, carry: carry) -> Promise(Bool)

@external(javascript, "./io_ffi.mjs", "finish")
pub fn finish(context: Context) -> Promise(Nil)

@external(javascript, "./io_ffi.mjs", "reject")
pub fn reject(
  context: Context,
  stage: fn(Context) -> Promise(value),
) -> Promise(Nil)

/// Read a relation from a Service root. The runtime supplies this capability
/// on Context so generated reads do not depend on an app-owned FFI module.
@external(javascript, "./io_ffi.mjs", "rootArrow")
pub fn root_arrow(
  context: Context,
  service: String,
  arrow: String,
  root: root,
) -> Promise(value)
