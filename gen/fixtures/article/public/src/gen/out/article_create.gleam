//// GENERATED from src/service/article_create.gleam [sha256:caec1ec0813b] — 手で編集しない

import gleam/dynamic/decode

pub type Slug = String

pub type Out = Slug

pub fn decoder() -> decode.Decoder(Out) {
  decode.string
}
