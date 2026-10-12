//// GENERATED from service.note_list.items [sha256:b5ae9fbf02b1] — 手で編集しない

import entity/note
import gen/root/note_list.{type Root}
import gleam/option.{type Option}
import yumemi/io.{type Context, type Promise}
import yumemi/page.{type Cursor, type Page}
import yumemi/step.{type Step}

@external(javascript, "../operations_ffi.mjs", "read_of")
fn query(ctx: Context, owner: String, name: String, input: a) -> Promise(b)

pub fn items(
  limit limit: Int,
  cursor cursor: Option(Cursor),
  then then: fn(Page(note.Note)) -> Step(out, err, state),
) -> Step(out, err, state) {
  step.read(
    fn(ctx) { query(ctx, "note_list", "items", #(limit, cursor)) },
    then,
  )
}
