//// GENERATED from service.article_list [sha256:c08ca5f2a540] — 手で編集しない

import entity/article
import entity/category
import gen/root/article_list.{type Root}
import gleam/option.{type Option}
import yumemi/io.{type Context, type Promise}
import yumemi/page.{type Cursor, type Page}
import yumemi/step.{type Step}

@external(javascript, "../operations_ffi.mjs", "read")
fn query(ctx: Context, name: String, input: a) -> Promise(b)

pub fn items(
  limit limit: Int,
  cursor cursor: Option(Cursor),
  then then: fn(Page(#(article.Article, article.Phase))) ->
    Step(out, err, state),
) -> Step(out, err, state) {
  step.read(
    fn(ctx) { query(ctx, "article_list/items", #(limit, cursor)) },
    then,
  )
}

pub fn counts(
  then then: fn(List(#(category.Category, Int))) -> Step(out, err, state),
) -> Step(out, err, state) {
  step.read(fn(ctx) { query(ctx, "article_list/counts", Nil) }, then)
}
