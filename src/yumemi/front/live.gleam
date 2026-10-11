//// interactive Component の宣言の型(0.12、51 v6「After」「`reloads`」)。★ は `calls`・`after_send`・
//// 任意の `reloads` を const で書き、view は Args を受けて要素を返すだけ ── State・Event・update は
//// ★ の目に無い。状態は form の control と custom state(`:state()`)にあり、runtime(`client.mjs`)が
//// 付け替える。`@internal` の口は生成物(`src/gen/live/*`・`src/gen/interactive.gleam`)だけが呼ぶ。

import gleam/list
import gleam/option.{type Option}
import gleam/string
import yumemi/front/css
import yumemi/front/el.{type Attribute, type Element}

/// 書きの送りの、成功の後と失敗の後の行き先。
pub type After(route) {
  After(ok: Then(route), error: Then(route))
}

/// 行き先。留まる・頁を読み直す・面の Page へ移る。読み直した先と移った先で文言を 1 回出せる
/// (Layout の `el.notice` に入る)。`GoTo` の path の穴は、その送りの Service の Out の同じ名の欄で
/// 生成器が埋める。
pub type Then(route) {
  Stay
  ReloadPage(notice: Option(String))
  GoTo(route: route, notice: Option(String))
}

/// 読みの Service の欄が変わったら、その Service を今の Args で呼び直す。
pub type Reloads(service, field) {
  Reloads(read: service, on: List(field))
}

// 生成物だけが呼ぶ口 ---------------------------------------------------------

/// control の制約検証の属性(Spec から生成器が写す)。
@internal
pub type Constraint {
  MinLength(Int)
  MaxLength(Int)
  Required
  Pattern(String)
}

/// `name="<service>.<field>"`・制約検証・value。
@internal
pub fn bind(
  service: String,
  field: String,
  value: String,
  constraints: List(Constraint),
) -> Attribute {
  el.attributes([
    el.attribute("name", service <> "." <> field),
    el.attribute("value", value),
    ..list.map(constraints, constraint_attribute)
  ])
}

/// checkbox。`checked` と name。
@internal
pub fn bind_check(service: String, field: String, checked: Bool) -> Attribute {
  el.attributes([
    el.attribute("name", service <> "." <> field),
    case checked {
      True -> el.attribute("checked", "")
      False -> el.no_attribute()
    },
  ])
}

/// select と radio の name(選択肢は ★ が `attr.value` / `attr.selected` で書く)。
@internal
pub fn bind_choice(service: String, field: String) -> Attribute {
  el.attribute("name", service <> "." <> field)
}

/// file の control(Args の Blob の欄)。runtime が送る前に上げ口へ上げ、key を Args に入れる。
@internal
pub fn bind_file(service: String, field: String) -> Attribute {
  el.attributes([
    el.attribute("name", service <> "." <> field),
    el.attribute("type", "file"),
  ])
}

fn constraint_attribute(constraint: Constraint) -> Attribute {
  case constraint {
    MinLength(value) -> el.attribute("minlength", int_text(value))
    MaxLength(value) -> el.attribute("maxlength", int_text(value))
    Required -> el.attribute("required", "")
    Pattern(value) -> el.attribute("pattern", value)
  }
}

fn int_text(value: Int) -> String {
  string.inspect(value)
}

/// `data-yumemi-when="<service>.<state>"` を付けた枝。出し分けは生成器の CSS が `:state()` で持つ。
@internal
pub fn when(
  service: String,
  state: String,
  children: List(Element),
) -> Element {
  el.element(
    "div",
    [el.attribute("data-yumemi-when", service <> "." <> state)],
    children,
  )
}

/// `data-yumemi-out="<service>.<slot>"` の空の span。Done で runtime が textContent を入れる。
@internal
pub fn out(service: String, slot: String) -> Element {
  el.element(
    "span",
    [el.attribute("data-yumemi-out", service <> "." <> slot)],
    [],
  )
}

/// 送りのボタン。叩くのはこの Service 1 本。
@internal
pub fn send(
  service: String,
  class: css.Class,
  children: List(Element),
) -> Element {
  el.element(
    "button",
    [
      el.class_attribute(class),
      el.attribute("type", "submit"),
      el.attribute("formnovalidate", ""),
      el.attribute("data-yumemi-send", service),
    ],
    children,
  )
}

/// interactive Component の殻。タグ(module 名の `_` を `-`)の中に form と fieldset を置き、
/// Args の初期値を `data-yumemi-args` の JSON に持つ。
@internal
pub fn component(tag: String, args_json: String, view: Element) -> Element {
  el.element(
    tag,
    [
      el.attribute("data-yumemi-island", ""),
      el.attribute("data-yumemi-args", args_json),
    ],
    [el.element("form", [], [el.element("fieldset", [], [view])])],
  )
}

/// JSON の文字列の literal(`data-yumemi-args` を組む)。
@internal
pub fn json_string(value: String) -> String {
  "\""
  <> {
    value
    |> string.to_utf_codepoints
    |> list.map(fn(point) {
      case string.utf_codepoint_to_int(point) {
        0x22 -> "\\\""
        0x5C -> "\\\\"
        0x0A -> "\\n"
        0x0D -> "\\r"
        0x09 -> "\\t"
        code if code < 0x20 -> "\\u" <> string.pad_start(int_hex(code), 4, "0")
        _ -> string.from_utf_codepoints([point])
      }
    })
    |> string.concat
  }
  <> "\""
}

fn int_hex(value: Int) -> String {
  let digits = "0123456789abcdef"
  case value < 16 {
    True -> string.slice(digits, value, 1)
    False -> int_hex(value / 16) <> string.slice(digits, value % 16, 1)
  }
}

/// `{"<name>": <value>, ..}`(値は JSON の字)。
@internal
pub fn json_object(fields: List(#(String, String))) -> String {
  "{"
  <> string.join(
    list.map(fields, fn(field) { json_string(field.0) <> ":" <> field.1 }),
    ",",
  )
  <> "}"
}
