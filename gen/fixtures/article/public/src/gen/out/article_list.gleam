//// GENERATED from src/service/article_list.gleam [sha256:c641e915671e] — 手で編集しない

import framework/page.{type Page, Page, cursor}
import gleam/dynamic/decode

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

pub fn decoder() -> decode.Decoder(Out) {
  decode.field(
    "page",
    decode.field(
      "items",
      decode.list(
        of: decode.field("slug", decode.string, fn(slug) {
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
                        decode.field(
                          "keys",
                          decode.list(of: decode.string),
                          fn(keys) { decode.success(Multi(values: keys)) },
                        ),
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
        }),
      ),
      fn(items) {
        decode.field(
          "next",
          decode.optional(
            decode.map(decode.string, fn(raw) {
              let assert Ok(value) = cursor(raw)
              value
            }),
          ),
          fn(next) { decode.success(Page(items: items, next: next)) },
        )
      },
    ),
    fn(page) {
      decode.field(
        "counts",
        decode.list(
          of: decode.then(
            decode.at(
              [0],
              decode.field("name", decode.string, fn(name) {
                decode.success(Category(name: name))
              }),
            ),
            fn(first) {
              decode.map(decode.at([1], decode.int), fn(second) {
                #(first, second)
              })
            },
          ),
        ),
        fn(counts) { decode.success(Out(page: page, counts: counts)) },
      )
    },
  )
}
