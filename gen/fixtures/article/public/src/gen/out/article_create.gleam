//// GENERATED from src/service/article_create.gleam [sha256:f1d1d3f20711] — 手で編集しない

import gleam/dynamic/decode

pub type Slug =
  String

pub type Phase {
  Draft
  Scheduled
  Published
  Retracted
}

pub type Out {
  Out(slug: Slug, phase: Phase)
}

pub fn decoder() -> decode.Decoder(Out) {
  decode.field("slug", decode.string, fn(slug) {
    decode.field(
      "phase",
      decode.then(decode.string, fn(value) {
        case value {
          "Draft" -> decode.success(Draft)
          "Scheduled" -> decode.success(Scheduled)
          "Published" -> decode.success(Published)
          "Retracted" -> decode.success(Retracted)
          _ -> decode.failure(Draft, expected: "Phase")
        }
      }),
      fn(phase) { decode.success(Out(slug: slug, phase: phase)) },
    )
  })
}
