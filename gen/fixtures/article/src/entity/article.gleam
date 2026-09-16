// ★ src/entity/article.gleam
//// Entity Article ── 記事。1 module 1 Entity。
import entity/category.{type Category}
import entity/tag.{type Tag}
import framework/er.{type Has, type Multi}
import gen/types/body.{type Body}
import gen/types/slug.{type Slug}
import gen/types/title.{type Title}

pub type Article {
  Article(
    slug: Slug,
    title: Title,
    body: Body,
    category: Has(Category),
    tags: Multi(Tag),
  )
}

/// Lifecycle。フェーズは Property ではないので Article レコードに入れない。
pub type Phase {
  Draft
  Published
  Retracted
}

/// 進める辺。ここに無い移りは gen/phase.gleam に名前として存在しない ── 書けない。
pub const edges: List(#(Phase, Phase)) = [
  #(Draft, Published),
  #(Published, Retracted),
]

pub fn key(it: Article) -> Slug {
  it.slug
}

pub const collection: String = "articles"
