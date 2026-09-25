//// GENERATED from src/service/article_list.gleam [sha256:c641e915671e] — 手で編集しない

import framework/page.{type Page}

pub type Slug =
  String

pub type Title =
  String

pub type Body =
  String

pub type CategoryName =
  String

pub type Has(entity) {
  Has(value: String)
}

pub type Multi(entity) {
  Multi(values: List(String))
}

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

pub type Category {
  Category(name: CategoryName)
}

pub type Tag

pub type Out {
  Out(page: Page(Article), counts: List(#(Category, Int)))
}
