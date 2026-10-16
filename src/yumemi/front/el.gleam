//// 要素の木と SSR の文字列化(0.12、51 v6「要素の木」)。構成子は外から見えず、★ が作れるのは
//// `yumemi/front/html` のタグ、`yumemi/front/attr` の属性と、ここの `text` / `each` / `none` ほか
//// framework の語だけ。`@internal` の口は生成物と yumemi の html / attr が呼ぶ(★ が呼べば生成器が
//// 止める、第 3 条)。

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import yumemi/front/css
import yumemi/front/sketch_css

pub opaque type Element {
  Node(
    namespace: String,
    tag: String,
    attributes: List(Attribute),
    children: List(Element),
  )
  Text(content: String)
  /// 生成物の `<style>` だけ。中身の `</` と `<!--` は作るときに無害化する。
  RawText(tag: String, attributes: List(Attribute), content: String)
  Fragment(children: List(Element))
}

pub opaque type Attribute {
  Attribute(name: String, value: String)
  /// 出さない属性(`attr.disabled(False)`・名の不正な `attr.data` など)。
  NoAttribute
  /// 生成物の口(live の `bind` ほか)が 1 つの Attribute で複数の属性を出すための束。
  Attributes(List(Attribute))
}

pub fn text(content: String) -> Element {
  Text(content)
}

pub fn fragment(children: List(Element)) -> Element {
  Fragment(children)
}

pub fn none() -> Element {
  Fragment([])
}

pub fn each(items: List(a), view: fn(a) -> Element) -> Element {
  Fragment(list.map(items, view))
}

/// 並びの各要素の根に `data-yumemi-key` を付ける(0.14、`Live` の Block の当て方の鍵)。view の根が要素で
/// なければ鍵は付かない。鍵は並びの中で一意にする(発言の id など)。
pub fn each_keyed(
  items: List(a),
  key: fn(a) -> String,
  view: fn(a) -> Element,
) -> Element {
  Fragment(list.map(items, fn(item) { keyed(view(item), key(item)) }))
}

fn keyed(element: Element, key: String) -> Element {
  case element {
    Node(namespace:, tag:, attributes:, children:) ->
      Node(
        namespace:,
        tag:,
        attributes: list.append(attributes, [Attribute("data-yumemi-key", key)]),
        children:,
      )
    _ -> element
  }
}

/// `Live` の Block の中に置く「新着」の印(0.14)。追っていない間に取り直しが入ったときだけ出て、押すと端へ
/// 送る。JS 無しでは出ない(`hidden` のまま)。
pub fn fresh(class: css.Class, children: List(Element)) -> Element {
  element(
    "button",
    [
      Attribute("type", "button"),
      class_attribute(class),
      Attribute("data-yumemi-fresh", ""),
      Attribute("hidden", ""),
    ],
    children,
  )
}

/// Prefix for area overlay ids. Append the exact area name to form the id.
pub const overlay_id_prefix = "yumemi-overlay-"

/// A button that opens the overlay belonging to `area`.
pub fn opener(area: String, child: List(Element)) -> Element {
  element(
    "button",
    [
      Attribute("type", "button"),
      Attribute("data-yumemi-overlay-opener", ""),
      Attribute("popovertarget", overlay_id(area)),
      Attribute("popovertargetaction", "show"),
    ],
    child,
  )
}

/// A button that closes the overlay belonging to `area`.
pub fn closer(area: String, child: List(Element)) -> Element {
  element(
    "button",
    [
      Attribute("type", "button"),
      Attribute("data-yumemi-overlay-closer", ""),
      Attribute("popovertarget", overlay_id(area)),
      Attribute("popovertargetaction", "hide"),
    ],
    child,
  )
}

/// A badge marker whose optional count is always represented by one element.
pub fn badge(count: Option(Int), child: List(Element)) -> Element {
  element(
    "span",
    [
      Attribute("data-yumemi-badge", ""),
      Attribute("data-count", badge_count(count)),
    ],
    child,
  )
}

/// A popover and its controls for one row rendered inside `each`.
///
/// `scope` identifies the `each` call site and `row_key` identifies one row
/// within that scope. A generator should provide stable, distinct tokens for
/// both. The id format is `yumemi-row-overlay-{scope length}-{scope}-{key
/// length}-{key}`. The length fields make the pair unambiguous. The id is
/// constructed here, so callers provide neither an id nor an id attribute.
pub fn each_modal(
  scope: String,
  row_key: String,
  opener_child: List(Element),
  closer_child: List(Element),
  child: List(Element),
) -> Element {
  let id = each_modal_id(scope, row_key)
  let open_button =
    element(
      "button",
      [
        Attribute("data-yumemi-each-modal-opener", ""),
        Attribute("type", "button"),
        Attribute("popovertarget", id),
        Attribute("popovertargetaction", "show"),
      ],
      opener_child,
    )
  let close_button =
    element(
      "button",
      [
        Attribute("data-yumemi-each-modal-closer", ""),
        Attribute("type", "button"),
        Attribute("popovertarget", id),
        Attribute("popovertargetaction", "hide"),
      ],
      closer_child,
    )
  let popover =
    element(
      "div",
      [
        Attribute("id", id),
        Attribute("popover", ""),
        Attribute("data-yumemi-each-modal", ""),
      ],
      [close_button, ..child],
    )
  element("div", [Attribute("data-yumemi-each-modal-host", "")], [
    open_button,
    popover,
  ])
}

/// 画像。src は `gen/media.src`(Blob の variant)か `el.static_src`(`priv/static` の file)だけが作る。
pub fn img(
  class: css.Class,
  src: Src,
  alt: String,
  attributes: List(Attribute),
) -> Element {
  element(
    "img",
    [class_attribute(class), ..attributes]
      |> list.append([Attribute("src", src.url), Attribute("alt", alt)]),
    [],
  )
}

/// 画像の在り処。`gen/media.src` と `el.static_src` だけが作る(51 v6「html と el」)。
pub opaque type Src {
  Src(url: String)
}

/// `priv/static` の file。path は文字列の literal で書く(第 43 条)。`static_sheet` と同じ柵。
pub fn static_src(path: String) -> Src {
  Src(static_path(path))
}

/// 生成物(`gen/media.src`)が組んだ URL の Src。
@internal
pub fn media_src(url: String) -> Src {
  Src(url)
}

/// Layout の Block に置く、読み直した先・移った先の文言の置き場(51 v6「After」)。runtime が 1 回だけ
/// textContent を入れる。
pub fn notice(class: css.Class) -> Element {
  element(
    "p",
    [
      class_attribute(class),
      Attribute("data-yumemi-notice", ""),
      Attribute("role", "status"),
      Attribute("hidden", ""),
    ],
    [],
  )
}

/// 確認の 1 段などに使う `<dialog>`(51 v6「invoker commands」)。`key` は literal。
pub fn dialog(
  key: String,
  class: css.Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  element(
    "dialog",
    [class_attribute(class), ..attributes]
      |> list.append([Attribute("id", dialog_id(key))]),
    children,
  )
}

/// `dialog` を開くボタン(`command="show-modal"`)。invoker commands の無い browser は runtime が代わる。
pub fn dialog_opener(
  key: String,
  class: css.Class,
  children: List(Element),
) -> Element {
  dialog_button("show-modal", key, class, children)
}

/// `dialog` を閉じるボタン(`command="close"`)。
pub fn dialog_closer(
  key: String,
  class: css.Class,
  children: List(Element),
) -> Element {
  dialog_button("close", key, class, children)
}

fn dialog_button(
  command: String,
  key: String,
  class: css.Class,
  children: List(Element),
) -> Element {
  element(
    "button",
    [
      class_attribute(class),
      Attribute("type", "button"),
      Attribute("command", command),
      Attribute("commandfor", dialog_id(key)),
    ],
    children,
  )
}

fn dialog_id(key: String) -> String {
  "yumemi-dialog-" <> key
}

/// 生の CSS の逃げ道(51 v6「生の CSS の逃げ道」)。`priv/static` の .css を `<link>` で読む。
/// 生成器が file を検査し、置いた規則を数える(第 28〜31 条)。
pub fn stylesheet(sheet: Sheet) -> Element {
  element(
    "link",
    [Attribute("rel", "stylesheet"), Attribute("href", sheet.href)],
    [],
  )
}

/// `el.static_sheet` だけが作る、`priv/static` の .css の在り処。
pub opaque type Sheet {
  Sheet(href: String)
}

/// `priv/static` の .css。path は文字列の literal で書く(第 31 条)。`/` で始めても始めなくてもよい。
pub fn static_sheet(path: String) -> Sheet {
  Sheet(static_path(path))
}

/// `priv/static` の中の道。外の origin へ出る字(`//`・`\`・`:`)と `..` の段を含めば、何も指さない
/// `/`(読み込みは空振り)にする ── 生成器が literal を検査するが、実行時にも外を読ませない。
fn static_path(path: String) -> String {
  let path = case string.starts_with(path, "/") {
    True -> path
    False -> "/" <> path
  }
  case
    string.contains(path, "//")
    || string.contains(path, "\\")
    || string.contains(path, ":")
    || list.contains(string.split(path, "/"), "..")
  {
    True -> "/"
    False -> path
  }
}

fn badge_count(count: Option(Int)) -> String {
  case count {
    None -> ""
    Some(value) -> int.to_string(value)
  }
}

fn overlay_id(area: String) -> String {
  overlay_id_prefix <> area
}

fn each_modal_id(scope: String, row_key: String) -> String {
  "yumemi-row-overlay-"
  <> int.to_string(string.length(scope))
  <> "-"
  <> scope
  <> "-"
  <> int.to_string(string.length(row_key))
  <> "-"
  <> row_key
}

// 生成物と html / attr だけが呼ぶ口 -------------------------------------------

@internal
pub fn element(
  tag: String,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  Node("", tag, attributes, children)
}

@internal
pub fn namespaced(
  namespace: String,
  tag: String,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  Node(namespace, tag, attributes, children)
}

/// `<style>`。中身は raw text なので escape では守れない。`</` と `<!--` を壊して要素から出られなくする。
@internal
pub fn raw_text(
  tag: String,
  attributes: List(Attribute),
  content: String,
) -> Element {
  RawText(tag, attributes, neutralize(content))
}

@internal
pub fn attribute(name: String, value: String) -> Attribute {
  Attribute(name, value)
}

/// 名前付きの逃げ道の置き場(生成物 `gen/escapes` だけが呼ぶ)。runtime が接続で `mount` を呼ぶ。
@internal
pub fn escape_point(
  name: String,
  attributes: List(Attribute),
  fallback: List(Element),
) -> Element {
  element(
    "yumemi-escape",
    list.append(attributes, [Attribute("name", name)]),
    fallback,
  )
}

/// 複数の属性を 1 つの Attribute に束ねる(生成物の live の `bind` ほか)。
@internal
pub fn attributes(attributes: List(Attribute)) -> Attribute {
  Attributes(attributes)
}

@internal
pub fn no_attribute() -> Attribute {
  NoAttribute
}

/// `css.Class` を class 属性にする(class 名は描いている頁の stylesheet に規則を足して得る)。
@internal
pub fn class_attribute(class: css.Class) -> Attribute {
  Attribute("class", sketch_css.class_name(class))
}

/// 頁の body を描き、使った class の CSS(と `extra_css`)を body の先頭の `<style>` に出す。
/// 戻りは `<style>` と body の中身を並べた Fragment。
@internal
pub fn styled(body: fn() -> Element, extra_css: String) -> Element {
  let #(css, child) = sketch_css.collect(body)
  let css = case css, extra_css {
    "", extra -> extra
    css, "" -> css
    css, extra -> css <> "\n\n" <> extra
  }
  case css {
    "" -> child
    _ -> Fragment([RawText("style", [], neutralize(css)), child])
  }
}

// 名前の検査 -----------------------------------------------------------------

/// `[a-z][a-z0-9-]*`。`attr.data` / `attr.aria` の名はこれに縛り、外れた名の属性は出さない。
pub fn is_name(name: String) -> Bool {
  case string.to_graphemes(name) {
    [first, ..] as chars -> is_lower(first) && list.all(chars, is_name_char)
    [] -> False
  }
}

fn is_name_char(char: String) -> Bool {
  is_lower(char) || string.contains("0123456789-", char)
}

fn is_lower(char: String) -> Bool {
  string.contains("abcdefghijklmnopqrstuvwxyz", char)
}

pub fn is_custom_element_name(tag: String) -> Bool {
  is_name(tag) && string.contains(tag, "-") && !is_reserved(tag)
}

fn is_reserved(tag: String) -> Bool {
  case tag {
    "annotation-xml"
    | "color-profile"
    | "font-face"
    | "font-face-src"
    | "font-face-uri"
    | "font-face-format"
    | "font-face-name"
    | "missing-glyph" -> True
    _ -> False
  }
}

// SSR の文字列化 -------------------------------------------------------------

/// 要素を HTML の字にする(test と Block リストのため)。
pub fn to_string(element: Element) -> String {
  render(element, "")
}

/// `<!doctype html>` を付け、html / body で包む(lustre の `to_document_string` と同じ規則)。
@internal
pub fn to_document_string(element: Element) -> String {
  "<!doctype html>\n" <> render(wrap_document(element), "")
}

fn render(element: Element, parent_namespace: String) -> String {
  case element {
    Text(content) -> escape(content)
    Fragment(children) -> render_all(children, parent_namespace)
    RawText(tag:, attributes:, content:) ->
      "<"
      <> tag
      <> render_attributes(attributes)
      <> ">"
      <> content
      <> "</"
      <> tag
      <> ">"
    Node(namespace:, tag:, attributes:, children:) -> {
      let #(attributes, children) =
        textarea_value(namespace, tag, attributes, children)
      let xmlns = case namespace != "" && namespace != parent_namespace {
        True -> " xmlns=\"" <> escape(namespace) <> "\""
        False -> ""
      }
      let open = "<" <> tag <> xmlns <> render_attributes(attributes) <> ">"
      case namespace == "" && is_void(tag) {
        True -> open
        False ->
          open
          <> leading_newline(tag, children)
          <> render_all(children, namespace)
          <> "</"
          <> tag
          <> ">"
      }
    }
  }
}

fn render_all(children: List(Element), namespace: String) -> String {
  children
  |> list.map(render(_, namespace))
  |> string.concat
}

/// textarea は `value` 属性を読まない(初めの値は中身の字)。`value`(live の `bind`・`attr.value`)は、中身が
/// 無ければ中身の字に移して属性から外す ── 属性のままだと空の textarea が描かれ、送りが初めの値を "" で上書き
/// する(0.12 段 C、柏木 ゲート 2)。中身を書いたなら中身が勝つ。
fn textarea_value(
  namespace: String,
  tag: String,
  attributes: List(Attribute),
  children: List(Element),
) -> #(List(Attribute), List(Element)) {
  case namespace, tag {
    "", "textarea" -> {
      let flat = flatten_attributes(attributes)
      let value =
        list.fold(flat, None, fn(found, attribute) {
          case attribute {
            Attribute("value", value) -> Some(value)
            _ -> found
          }
        })
      case value {
        None -> #(attributes, children)
        Some(value) -> #(
          list.filter(flat, fn(attribute) {
            case attribute {
              Attribute("value", _) -> False
              _ -> True
            }
          }),
          case children {
            [] -> [Text(value)]
            _ -> children
          },
        )
      }
    }
    _, _ -> #(attributes, children)
  }
}

/// textarea / pre / listing は、直後の最初の改行を HTML の parser が 1 つ捨てる。本文が改行で始まるなら 1 つ足して落とさない。
fn leading_newline(tag: String, children: List(Element)) -> String {
  case tag, children {
    "textarea", [Text(content), ..]
    | "pre", [Text(content), ..]
    | "listing", [Text(content), ..]
    ->
      case string.starts_with(content, "\n") {
        True -> "\n"
        False -> ""
      }
    _, _ -> ""
  }
}

fn is_void(tag: String) -> Bool {
  case tag {
    "area"
    | "base"
    | "br"
    | "col"
    | "embed"
    | "hr"
    | "img"
    | "input"
    | "link"
    | "meta"
    | "param"
    | "source"
    | "track"
    | "wbr" -> True
    _ -> False
  }
}

/// 名前の順に並べ、同じ名前は後に書いたものを 1 つ残す(lustre の出力を parser が読んだ結果と
/// 同じ値)。class だけは空白でつなぐ。空の class は出さない。
fn render_attributes(attributes: List(Attribute)) -> String {
  attributes
  |> flatten_attributes
  |> list.filter_map(fn(attribute) {
    case attribute {
      Attribute("class", "") | Attribute("", _) | NoAttribute | Attributes(_) ->
        Error(Nil)
      Attribute(name, value) -> Ok(#(name, value))
    }
  })
  |> last_wins
  |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
  |> list.map(fn(pair) {
    case pair.1 {
      "" -> " " <> pair.0
      value -> " " <> pair.0 <> "=\"" <> escape(value) <> "\""
    }
  })
  |> string.concat
}

fn flatten_attributes(attributes: List(Attribute)) -> List(Attribute) {
  list.flat_map(attributes, fn(attribute) {
    case attribute {
      Attributes(inner) -> flatten_attributes(inner)
      _ -> [attribute]
    }
  })
}

/// 後ろから見て、初めて出た名だけを残す(class は値をつなぐ)。並びの安定に頼らない。
fn last_wins(pairs: List(#(String, String))) -> List(#(String, String)) {
  list.fold(list.reverse(pairs), [], fn(kept, pair) {
    case list.key_find(kept, pair.0), pair.0 {
      Ok(later), "class" -> list.key_set(kept, "class", pair.1 <> " " <> later)
      Ok(_), _ -> kept
      Error(_), _ -> [pair, ..kept]
    }
  })
}

/// 本文と属性値の escape は同じ 5 文字(houdini と同じ置き換え)。HTML が要るのは本文の `& < >` と属性値の `& "` で、その上位集合。
@internal
pub fn escape(content: String) -> String {
  content
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
  |> string.replace("\"", "&quot;")
  |> string.replace("'", "&#39;")
}

fn neutralize(content: String) -> String {
  content
  |> string.replace("</", "<\\/")
  |> string.replace("<!--", "<\\!--")
}

type DocumentKind {
  Html
  HeadOnly
  BodyOnly
  HeadAndBody
  Other
}

fn document_kind(element: Element) -> DocumentKind {
  case element {
    Node(tag: "html", ..) -> Html
    Node(tag: "head", ..) -> HeadOnly
    Node(tag: "body", ..) -> BodyOnly
    Fragment([child]) -> document_kind(child)
    Fragment([head, body]) ->
      case document_kind(head), document_kind(body) {
        HeadOnly, BodyOnly -> HeadAndBody
        _, _ -> Other
      }
    _ -> Other
  }
}

fn wrap_document(element: Element) -> Element {
  case document_kind(element) {
    Html -> element
    HeadOnly | BodyOnly | HeadAndBody -> Node("", "html", [], [element])
    Other -> Node("", "html", [], [Node("", "body", [], [element])])
  }
}
