//// GENERATED from src/service/article_read.gleam [sha256:1b23b9f30356] — 手で編集しない

import gleam/option.{type Option}

pub type Slug =
  String

pub type Title =
  String

pub type Body =
  String

pub type CategoryName =
  String

pub type TagName =
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

pub type Tag {
  Tag(name: TagName)
}

pub type PageTheme {
  PageTheme(
    background: Option(String),
    background_image: Option(String),
    text: Option(String),
    accent: Option(String),
  )
}

pub type Out {
  Out(
    article: Article,
    category: Category,
    tags: List(Tag),
    theme: Option(PageTheme),
  )
}
