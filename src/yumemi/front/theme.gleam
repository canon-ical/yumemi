//// 頁の色(0.12、51 v6「頁の色」)。地・地の画像・字・差し色の 4 値で、色は `color.Color`、
//// 地の画像は `blob.Blob`。Entity の Property や Service の Out が直に持ち、Page の
//// `theme: Some(name)` がその欄を名指す。framework は body の custom property 4 本に出し、
//// ★ は `css.Theme(..)` で読む。

import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import yumemi/blob.{type Blob}
import yumemi/front/color.{type Color}

pub type PageTheme {
  PageTheme(
    background: Option(Color),
    background_image: Option(Blob),
    text: Option(Color),
    accent: Option(Color),
  )
}

/// Shell の既定(`pub const theme: theme.Defaults`)。3 色は `#rrggbb` の literal、地の画像は
/// `priv/static` の path か `None`(生成器が検査する、第 26 条)。
pub type Defaults {
  Defaults(
    background: String,
    text: String,
    accent: String,
    background_image: Option(String),
  )
}

pub fn decoder() -> decode.Decoder(PageTheme) {
  use background <- decode.optional_field(
    "background",
    None,
    decode.optional(color.decoder()),
  )
  use background_image <- decode.optional_field(
    "background_image",
    None,
    decode.optional(blob_decoder()),
  )
  use text <- decode.optional_field(
    "text",
    None,
    decode.optional(color.decoder()),
  )
  use accent <- decode.optional_field(
    "accent",
    None,
    decode.optional(color.decoder()),
  )
  decode.success(PageTheme(background:, background_image:, text:, accent:))
}

fn blob_decoder() -> decode.Decoder(Blob) {
  decode.then(decode.string, fn(raw) {
    case blob.parse(raw) {
      Ok(value) -> decode.success(value)
      Error(_) ->
        decode.failure(
          case blob.parse("placeholder") {
            Ok(value) -> value
            Error(_) -> panic as "valid built-in Blob decoder placeholder"
          },
          "Blob",
        )
    }
  })
}

/// body の custom property の規則(`body { --yumemi-theme-bg: ..; .. }`)。色は Type から字を
/// 組み直し、地の画像は `url("..")` の CSS の文字列にする。`image_url` は Blob を URL にする
/// 関数(app の media の variant)。
@internal
pub fn body_rule(
  value: Option(PageTheme),
  defaults: Defaults,
  image_url: fn(Blob) -> String,
) -> String {
  let #(background, image, text, accent) = resolved(value, defaults, image_url)
  "body {\n"
  <> "  --yumemi-theme-bg: "
  <> background
  <> ";\n"
  <> "  --yumemi-theme-bg-image: "
  <> image
  <> ";\n"
  <> "  --yumemi-theme-text: "
  <> text
  <> ";\n"
  <> "  --yumemi-theme-accent: "
  <> accent
  <> ";\n"
  <> "}"
}

/// 地の画像がある頁か(body に `data-yumemi-theme-image` を立てる)。
@internal
pub fn has_image(value: Option(PageTheme), defaults: Defaults) -> Bool {
  case value {
    Some(PageTheme(background_image: Some(_), ..)) -> True
    _ -> option.is_some(defaults.background_image)
  }
}

fn resolved(
  value: Option(PageTheme),
  defaults: Defaults,
  image_url: fn(Blob) -> String,
) -> #(String, String, String, String) {
  let default_image = case defaults.background_image {
    Some(path) -> css_url(path)
    None -> "none"
  }
  case value {
    Some(PageTheme(background:, background_image:, text:, accent:)) -> #(
      color_or(background, defaults.background),
      case background_image {
        Some(blob) -> css_url(image_url(blob))
        None -> default_image
      },
      color_or(text, defaults.text),
      color_or(accent, defaults.accent),
    )
    None -> #(
      default_color(defaults.background),
      default_image,
      default_color(defaults.text),
      default_color(defaults.accent),
    )
  }
}

fn color_or(value: Option(Color), default: String) -> String {
  case value {
    Some(value) -> color.to_css(value)
    None -> default_color(default)
  }
}

/// Shell の既定は生成器が `#rrggbb` を検査している。ここでも parse を通し、通らなければ `unset`。
fn default_color(raw: String) -> String {
  case color.parse(raw) {
    Ok(value) -> color.to_css(value)
    Error(_) -> "unset"
  }
}

/// `url("..")`。CSS の文字列の中で意味を持つ `\`・`"`・改行を escape する。
fn css_url(raw: String) -> String {
  let escaped =
    raw
    |> string.to_graphemes
    |> list.map(fn(char) {
      case char {
        "\\" -> "\\\\"
        "\"" -> "\\\""
        "\n" | "\r" | "\f" -> "\\a "
        _ -> char
      }
    })
    |> string.concat
  "url(\"" <> escaped <> "\")"
}
