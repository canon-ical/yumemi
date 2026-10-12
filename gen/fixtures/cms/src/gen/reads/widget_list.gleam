//// GENERATED from service.widget_list.items [sha256:1e7a06b5b259] — 手で編集しない

import entity/article
import gen/root/widget_list.{type Root}
import yumemi/io.{type Context, type Promise}
import yumemi/step.{type Step}

@external(javascript, "../operations_ffi.mjs", "read_of")
fn query(ctx: Context, owner: String, name: String, input: a) -> Promise(b)

pub fn items(
  then then: fn(List(#(article.Article, article.Phase))) ->
    Step(out, err, state),
) -> Step(out, err, state) {
  step.read(fn(ctx) { query(ctx, "widget_list", "items", Nil) }, then)
}
