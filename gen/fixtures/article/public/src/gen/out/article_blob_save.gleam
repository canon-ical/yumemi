//// GENERATED from src/service/article_blob_save.gleam [sha256:482f4f95cd0f] — 手で編集しない

import gleam/dynamic/decode

pub type Out {
  Out(saved: Bool)
}

pub fn decoder() -> decode.Decoder(Out) {
  decode.field("saved", decode.bool, fn(saved) {
    decode.success(Out(saved: saved))
  })
}
