//// GENERATED from src/service/article_publish.gleam [sha256:245f2d709f7e] — 手で編集しない

pub type Slug = String

pub type Title = String

pub type Body = String

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

pub type Out = Article
