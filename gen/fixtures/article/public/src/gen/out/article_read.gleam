//// GENERATED from src/service/article_read.gleam [sha256:1b23b9f30356] — 手で編集しない

import gleam/option.{type Option}
import gleam/dynamic/decode

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

pub fn decoder() -> decode.Decoder(Out) {
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
    decode.field("category", decode.field("name", decode.string, fn(name) {
    decode.success(Category(name: name))
  }), fn(category) {
    decode.field("tags", decode.list(of: decode.field("name", decode.string, fn(name) {
    decode.success(Tag(name: name))
  })), fn(tags) {
    decode.field("theme", decode.optional(decode.field("background", decode.optional(decode.string), fn(background) {
    decode.field("background_image", decode.optional(decode.string), fn(background_image) {
    decode.field("text", decode.optional(decode.string), fn(text) {
    decode.field("accent", decode.optional(decode.string), fn(accent) {
    decode.success(PageTheme(background: background, background_image: background_image, text: text, accent: accent))
  })
  })
  })
  })), fn(theme) {
    decode.success(Out(article: article, category: category, tags: tags, theme: theme))
  })
  })
  })
  })
}
