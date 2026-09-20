//// Entity Article ── 記事。1 module 1 Entity。

// ★ src/entity/article.gleam
import entity/category.{type Category}
import entity/tag.{type Tag}
import framework/er.{type Has, type Multi}
import framework/verbs
import gen/types/body.{type Body}
import gen/types/slug.{type Slug}
import gen/types/title.{type Title}

pub type Article {
  Article(
    slug: Slug,
    title: Title,
    body: Body,
    version: Int,
    order: Int,
    category: Has(Category),
    tags: Multi(Tag),
  )
}

/// Lifecycle。フェーズは Property ではないので Article レコードに入れない。
pub type Phase {
  Draft
  Scheduled
  Published
  Retracted
}

/// 進める辺。ここに無い移りは gen/phase.gleam に名前として存在しない ── 書けない。
pub const edges: List(#(Phase, Phase)) = [
  #(Draft, Published),
  #(Draft, Scheduled),
  #(Scheduled, Draft),
  #(Published, Retracted),
]

pub fn key(it: Article) -> Slug {
  it.slug
}

pub const collection: String = "articles"

pub const verbs: List(verbs.Rule(Phase)) = [
  verbs.Update(name: "pin", fields: ["title"], at: verbs.Only([Published])),
  verbs.Advance(bump: verbs.BumpUnless(Scheduled, Draft)),
  verbs.DeleteWhere(field: "title"),
  verbs.CreateMany,
]

pub const ordered_by: verbs.Order = verbs.Order(
  field: "order",
  within: ["category"],
)

pub const upsert_key: List(String) = ["category", "order"]
