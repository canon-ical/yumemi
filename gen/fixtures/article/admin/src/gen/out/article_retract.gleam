//// GENERATED from src/service/article_retract.gleam [sha256:4e7c9e6d1b77] — 手で編集しない

pub type Slug =
  String

pub type Title =
  String

pub type Body =
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

pub type Category

pub type Tag

pub type Out =
  Article
