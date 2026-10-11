//// GENERATED from entity.article [sha256:88033c339651] — 手で編集しない

import entity/category as entity_category
import gen/types/body.{type Body}
import gen/types/slug.{type Slug}
import gen/types/title.{type Title}
import yumemi/er.{type Key}

pub type ArticleDraft {
  ArticleDraft(
    slug: Slug,
    title: Title,
    body: Body,
    version: Int,
    category: Key(entity_category.Category),
  )
}

pub type ArticleCreated {
  ArticleCreated(
    slug: Slug,
    title: Title,
    body: Body,
    version: Int,
    order: Int,
    category: Key(entity_category.Category),
  )
}
