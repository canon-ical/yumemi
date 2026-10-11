//// 色の Type(0.12、51 v6「頁の色」)。`#rrggbb` だけを parse する opaque な値で、出力は r・g・b
//// の数から字を組み直す。DB から来た字が CSS の本文へ素で入る道を型の側で閉じる。

import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/string

/// 中身は r・g・b の数から組み直した `#rrggbb`(小文字)。1 欄なので back の JSON の写しでは
/// 字のまま出る(`blob.Blob` と同じ形)。
pub opaque type Color {
  Color(value: String)
}

/// `#` と 16 進 6 桁だけを通す。大文字は小文字と同じ値。
pub fn parse(raw: String) -> Result(Color, Nil) {
  case string.to_graphemes(raw) {
    ["#", r1, r2, g1, g2, b1, b2] -> {
      use red <- result_try(channel(r1, r2))
      use green <- result_try(channel(g1, g2))
      use blue <- result_try(channel(b1, b2))
      Ok(Color("#" <> hex(red) <> hex(green) <> hex(blue)))
    }
    _ -> Error(Nil)
  }
}

fn result_try(
  value: Result(a, Nil),
  next: fn(a) -> Result(b, Nil),
) -> Result(b, Nil) {
  case value {
    Ok(value) -> next(value)
    Error(_) -> Error(Nil)
  }
}

fn channel(high: String, low: String) -> Result(Int, Nil) {
  case digit(high), digit(low) {
    Ok(high), Ok(low) -> Ok(high * 16 + low)
    _, _ -> Error(Nil)
  }
}

fn digit(char: String) -> Result(Int, Nil) {
  let digits = string.to_graphemes("0123456789abcdef")
  let char = string.lowercase(char)
  list.index_fold(digits, Error(Nil), fn(found, candidate, index) {
    case candidate == char {
      True -> Ok(index)
      False -> found
    }
  })
}

/// `#rrggbb`(小文字)。parse で r・g・b の数から組み直した字で、parse に渡した字はそのまま出ない。
pub fn to_css(color: Color) -> String {
  color.value
}

/// 保存と転送の字(`to_css` と同じ)。
pub fn to_string(color: Color) -> String {
  to_css(color)
}

fn hex(value: Int) -> String {
  let text = string.lowercase(int.to_base16(int.clamp(value, 0, 255)))
  case string.length(text) {
    1 -> "0" <> text
    _ -> text
  }
}

pub fn decoder() -> decode.Decoder(Color) {
  let placeholder = Color("#000000")
  decode.new_primitive_decoder("Color", fn(value) {
    case decode.run(value, decode.string) {
      Ok(raw) ->
        case parse(raw) {
          Ok(color) -> Ok(color)
          Error(_) -> Error(placeholder)
        }
      Error(_) -> Error(placeholder)
    }
  })
}
