//// GENERATED from src/service/article_read.gleam — 手で編集しない

pub type Slug = String

pub type Title = String

pub type Body = String

pub type CategoryName = String

pub type TagName = String

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

pub type Out {
  Out(
    article: Article,
    category: Category,
    tags: List(Tag),
  )
}
