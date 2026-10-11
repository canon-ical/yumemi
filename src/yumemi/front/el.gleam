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

pub fn img(class: css.Class, attributes: List(Attribute)) -> Element {
  element("img", [class_attribute(class), ..attributes], [])
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
  case string.starts_with(path, "/") {
    True -> Sheet(path)
    False -> Sheet("/" <> path)
  }
}

/// 0.11 の形の interactive Component(`pub fn app` を持つ module)を置く一時の口。段 C の
/// Y3 で生成物 `gen/islands` の関数に替わって消える。タグ名が custom element の名の形で
/// なければ何も出さず、引数の名が `[a-z][a-z0-9-]*` でないか `on` で始まるか
/// `style` / `class` / `srcdoc` なら、その引数を出さない。
pub fn legacy_island(tag: String, args: List(#(String, String))) -> Element {
  case is_custom_element_name(tag) {
    True ->
      Node(
        "",
        tag,
        list.map(args, fn(arg) {
          case is_island_argument(arg.0) {
            True -> Attribute(arg.0, arg.1)
            False -> NoAttribute
          }
        }),
        [],
      )
    False -> Fragment([])
  }
}

fn is_island_argument(name: String) -> Bool {
  is_name(name)
  && !string.starts_with(name, "on")
  && name != "style"
  && name != "class"
  && name != "srcdoc"
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
  |> list.filter_map(fn(attribute) {
    case attribute {
      Attribute("class", "") | Attribute("", _) | NoAttribute -> Error(Nil)
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
