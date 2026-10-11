//// GENERATED from src/server.gleam (media) [sha256:b0add456a3cf] — 手で編集しない
//// 画像の variant と URL(`/media/<key>?v=<name>`)。頁の色の地の画像は `w1600`。

import gleam/list
import gleam/string
import gleam/uri
import yumemi/blob.{type Blob}

pub type Variant {
  /// 400×400、cover
  Thumb
  /// 800、scale-down
  W800
  /// 1600、contain
  W1600
}

/// 頁の色の地の画像に使う variant。
pub const theme_background: Variant = W1600

pub fn name(variant: Variant) -> String {
  case variant {
    Thumb -> "thumb"
    W800 -> "w800"
    W1600 -> "w1600"
  }
}

/// blob の key を `/` で割り、各節を百分率符号化する(`+` も `%2B`)。
pub fn url(blob: Blob, variant: Variant) -> String {
  let key =
    blob.to_string(blob)
    |> string.split(on: "/")
    |> list.map(fn(segment) {
      uri.percent_encode(segment) |> string.replace(each: "+", with: "%2B")
    })
    |> string.join(with: "/")
  "/media/" <> key <> "?v=" <> name(variant)
}
