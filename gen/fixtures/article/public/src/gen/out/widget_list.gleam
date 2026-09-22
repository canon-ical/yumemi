//// GENERATED from src/service/widget_list.gleam [sha256:b13b798cb2c9] — 手で編集しない

import gleam/dynamic/decode

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

pub type Row {
  ArticleRow(
    kind: String,
    article: Article,
  )
  Summary(
    kind: String,
    article: Article,
  )
}

pub type Out {
  Out(rows: List(Row))
}

pub fn decoder() -> decode.Decoder(Out) {
  decode.field("rows", decode.list(of: decode.field("kind", decode.string, fn(kind) {
    decode.field("article", decode.field("slug", decode.string, fn(slug) {
    decode.field("title", decode.string, fn(title) {
    decode.field("body", decode.string, fn(body) {
    decode.field("version", decode.int, fn(version) {
    decode.field("order", decode.int, fn(order) {
    decode.field("category", decode.field("value", decode.string, fn(value) { decode.success(Has(value: value)) }), fn(category) {
    decode.field("tags", decode.field("values", decode.list(of: decode.string), fn(values) { decode.success(Multi(values: values)) }), fn(tags) {
    decode.success(Article(slug: slug, title: title, body: body, version: version, order: order, category: category, tags: tags))
  })
  })
  })
  })
  })
  })
  }), fn(article) {
    decode.success(ArticleRow(kind: kind, article: article))
  })
  })), fn(rows) {
    decode.success(Out(rows: rows))
  })
}
