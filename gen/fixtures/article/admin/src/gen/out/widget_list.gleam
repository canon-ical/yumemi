//// GENERATED from src/service/widget_list.gleam [sha256:a637e6dc3b1d] — 手で編集しない

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

pub type Row {
  ArticleRow(kind: String, article: Article)
  Summary(kind: String, article: Article)
}

pub type Out {
  Out(rows: List(Row))
}
