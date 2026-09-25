//// GENERATED from src/service/article_publish.gleam [sha256:a8e19d850e4b] — 手で編集しない

import gleam/dynamic/decode

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

pub fn decoder() -> decode.Decoder(Out) {
  decode.field("slug", decode.string, fn(slug) {
    decode.field("title", decode.string, fn(title) {
      decode.field("body", decode.string, fn(body) {
        decode.field("version", decode.int, fn(version) {
          decode.field("order", decode.int, fn(order) {
            decode.field(
              "category",
              decode.map(decode.string, fn(value) { Has(value: value) }),
              fn(category) {
                decode.field(
                  "tags",
                  decode.field("keys", decode.list(of: decode.string), fn(keys) {
                    decode.success(Multi(values: keys))
                  }),
                  fn(tags) {
                    decode.success(Article(
                      slug: slug,
                      title: title,
                      body: body,
                      version: version,
                      order: order,
                      category: category,
                      tags: tags,
                    ))
                  },
                )
              },
            )
          })
        })
      })
    })
  })
}
