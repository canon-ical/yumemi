//// media の variant(0.12、51 v6「media の variant」)── app の `src/server.gleam` の `pub const media: Media` から、
//// 面ごとに `src/gen/media.gleam` を書く。Variant の閉じた enum と、blob の key を `/` で割って各節を百分率符号化し
//// `?v=<name>` を付けた URL を返す `url`。配る側(配信・edge cache・purge)は app のまま(別の起案)。
//// `media` の宣言が無い app は何も書かない。名の重なり・綴り・`theme_background` の検査は `reader/cms`(第 39 条)。

import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import yumemi/gen/digest
import yumemi/gen/emit/hash
import yumemi/gen/emit/types.{type File, File}
import yumemi/gen/model
import yumemi/gen/naming

pub fn emit(
  app: model.App,
  face_name: String,
  hashes: hash.Hashes,
) -> List(File) {
  case app.server.media {
    None -> []
    Some(media) -> [
      File(path: face_name <> "/src/gen/media.gleam", text: text(media, hashes)),
    ]
  }
}

fn text(media: model.Media, hashes: hash.Hashes) -> String {
  let variants =
    list.map(media.variants, fn(variant) {
      #(naming.pascal(variant.name), variant)
    })
  "//// GENERATED from src/server.gleam (media) [sha256:"
  <> digest.short(hash.entry(hashes) <> string.inspect(media))
  <> "] — 手で編集しない\n"
  <> "//// 画像の variant と URL(`"
  <> media.path
  <> "/<key>?v=<name>`)。頁の色の地の画像は `"
  <> media.theme_background
  <> "`。\n\n"
  <> "import gleam/list\n"
  <> "import gleam/string\n"
  <> "import gleam/uri\n"
  <> "import yumemi/blob.{type Blob}\n"
  <> "import yumemi/front/el\n\n"
  <> "pub type Variant {\n"
  <> string.concat(
    list.map(variants, fn(pair) {
      let #(name, variant) = pair
      "  /// "
      <> int.to_string(variant.width)
      <> case variant.height {
        Some(height) -> "×" <> int.to_string(height)
        None -> ""
      }
      <> "、"
      <> variant.fit
      <> "\n  "
      <> name
      <> "\n"
    }),
  )
  <> "}\n\n"
  <> "/// 頁の色の地の画像に使う variant。\n"
  <> "pub const theme_background: Variant = "
  <> naming.pascal(media.theme_background)
  <> "\n\n"
  <> "pub fn name(variant: Variant) -> String {\n"
  <> "  case variant {\n"
  <> string.concat(
    list.map(variants, fn(pair) {
      "    " <> pair.0 <> " -> \"" <> { pair.1 }.name <> "\"\n"
    }),
  )
  <> "  }\n}\n\n"
  <> "/// `el.img` の src(0.12 段 C、51 v6「media の variant」)。\n"
  <> "pub fn src(blob: Blob, variant: Variant) -> el.Src {\n"
  <> "  el.media_src(url(blob, variant))\n"
  <> "}\n\n"
  <> "/// blob の key を `/` で割り、各節を百分率符号化する(`+` も `%2B`)。\n"
  <> "pub fn url(blob: Blob, variant: Variant) -> String {\n"
  <> "  let key =\n"
  <> "    blob.to_string(blob)\n"
  <> "    |> string.split(on: \"/\")\n"
  <> "    |> list.map(fn(segment) {\n"
  <> "      uri.percent_encode(segment) |> string.replace(each: \"+\", with: \"%2B\")\n"
  <> "    })\n"
  <> "    |> string.join(with: \"/\")\n"
  <> "  \""
  <> media.path
  <> "/\" <> key <> \"?v=\" <> name(variant)\n"
  <> "}\n"
}
