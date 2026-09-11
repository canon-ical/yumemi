import framework/io.{type Context, type Promise}

pub opaque type Read(value) {
  Read(run: fn(Context) -> Promise(value))
}

pub opaque type Write(value) {
  Write(run: fn(Context) -> Promise(value))
}

pub fn read(run: fn(Context) -> Promise(value)) -> Read(value) {
  Read(run)
}

pub fn write(run: fn(Context) -> Promise(value)) -> Write(value) {
  Write(run)
}

pub fn run_read(call: Read(value), context: Context) -> Promise(value) {
  call.run(context)
}

pub fn run_write(call: Write(value), context: Context) -> Promise(value) {
  call.run(context)
}
