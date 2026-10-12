//// GENERATED from entity declarations [sha256:4d63034cce6e] — 手で編集しない

import entity/category as entity_category
import gen/draft/article as draft_article
import gen/draft/category as draft_category
import gen/draft/staff as draft_staff
import gen/draft/tag as draft_tag
import gen/phase.{type ArticleStep}
import gen/types/body.{type Body}
import gen/types/category_name.{type CategoryName}
import gen/types/slug.{type Slug}
import gen/types/tag_name.{type TagName}
import gen/types/title.{type Title}
import yumemi/er.{type Key}
import yumemi/idp.{type Email, type Name}
import yumemi/io.{type Context, type Promise}
import yumemi/party.{type PartyId}
import yumemi/time.{type Datetime}
import yumemi/verb.{type Verb}

@external(javascript, "./operations_ffi.mjs", "stage")
fn stage(ctx: Context, name: String, input: a) -> Promise(b)

pub fn create_article(
  input: draft_article.ArticleDraft,
) -> Verb(draft_article.ArticleCreated) {
  verb.staged(fn(ctx) { stage(ctx, "create_article", input) })
}

pub fn delete_article_by_title(title: Title) -> Verb(Nil) {
  verb.staged(fn(ctx) { stage(ctx, "delete_article_by_title", title) })
}

pub fn create_articles(
  input: List(draft_article.ArticleDraft),
  at: Datetime,
) -> Verb(List(draft_article.ArticleCreated)) {
  verb.staged(fn(ctx) { stage(ctx, "create_articles", #(input, at)) })
}

pub fn update_article_body(slug: Slug, version: Int, body: Body) -> Verb(Nil) {
  verb.staged(fn(ctx) {
    stage(ctx, "update_article_body", #(slug, version, body))
  })
}

pub fn update_article_order(slug: Slug, version: Int, order: Int) -> Verb(Nil) {
  verb.staged(fn(ctx) {
    stage(ctx, "update_article_order", #(slug, version, order))
  })
}

pub fn pin_article(slug: Slug, version: Int, title: Title) -> Verb(Nil) {
  verb.staged(fn(ctx) { stage(ctx, "pin_article", #(slug, version, title)) })
}

pub fn advance_article(
  slug: Slug,
  version: Int,
  step: ArticleStep,
) -> Verb(Nil) {
  verb.staged(fn(ctx) { stage(ctx, "advance_article", #(slug, version, step)) })
}

pub fn delete_article(slug: Slug) -> Verb(Nil) {
  verb.staged(fn(ctx) { stage(ctx, "delete_article", slug) })
}

pub fn reorder_articles(
  category: Key(entity_category.Category),
  ids: List(Slug),
) -> Verb(Nil) {
  verb.compound(
    fn(ctx) { stage(ctx, "reorder_articles_stage", #(category, ids)) },
    fn(ctx, _) { stage(ctx, "reorder_articles", #(category, ids)) },
  )
}

pub fn put_article(
  category: Key(entity_category.Category),
  order: Int,
  slug: Slug,
  title: Title,
  body: Body,
  version: Int,
) -> Verb(Nil) {
  verb.staged(fn(ctx) {
    stage(ctx, "put_article", #(category, order, slug, title, body, version))
  })
}

pub fn create_category(
  input: draft_category.CategoryDraft,
) -> Verb(draft_category.CategoryCreated) {
  verb.staged(fn(ctx) { stage(ctx, "create_category", input) })
}

pub fn delete_category(name: CategoryName) -> Verb(Nil) {
  verb.staged(fn(ctx) { stage(ctx, "delete_category", name) })
}

pub fn create_staff(
  input: draft_staff.StaffDraft,
) -> Verb(draft_staff.StaffCreated) {
  verb.staged(fn(ctx) { stage(ctx, "create_staff", input) })
}

pub fn update_staff_name(party: PartyId, name: Name) -> Verb(Nil) {
  verb.staged(fn(ctx) { stage(ctx, "update_staff_name", #(party, name)) })
}

pub fn update_staff_email(party: PartyId, email: Email) -> Verb(Nil) {
  verb.staged(fn(ctx) { stage(ctx, "update_staff_email", #(party, email)) })
}

pub fn delete_staff(party: PartyId) -> Verb(Nil) {
  verb.staged(fn(ctx) { stage(ctx, "delete_staff", party) })
}

pub fn create_tag(input: draft_tag.TagDraft) -> Verb(draft_tag.TagCreated) {
  verb.staged(fn(ctx) { stage(ctx, "create_tag", input) })
}

pub fn delete_tag(name: TagName) -> Verb(Nil) {
  verb.staged(fn(ctx) { stage(ctx, "delete_tag", name) })
}
