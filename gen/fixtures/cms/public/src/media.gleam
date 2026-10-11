//// 地の画像の URL(fixture)。app の media の variant を写す最小の形。

import yumemi/blob.{type Blob}

pub type Variant {
  W1600
}

pub fn url(value: Blob, variant: Variant) -> String {
  case variant {
    W1600 -> "/media/w1600/" <> blob.to_string(value)
  }
}
