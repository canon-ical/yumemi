//// 型付きの属性(0.12、51 v6「属性の型」)。名前は固定で、値から名前を作れるのは `data` と
//// `aria` だけ(名は `[a-z][a-z0-9-]*`、外れた名の属性は出さない)。名前を自由に渡す口・`class`・
//// `style`・`on*` は置かない。名前と引数の順は lustre の `attribute` に揃える。

import gleam/int
import gleam/list
import gleam/string
import yumemi/front/el.{type Attribute}

pub type Role {
  Alert
  Button
  Dialog
  Group
  List
  Listitem
  Radio
  Radiogroup
  Status
  Textbox
  Toolbar
}

/// 何も出さない属性。
pub fn none() -> Attribute {
  el.no_attribute()
}

fn string(name: String, value: String) -> Attribute {
  el.attribute(name, value)
}

fn flag(name: String, on: Bool) -> Attribute {
  case on {
    True -> el.attribute(name, "")
    False -> el.no_attribute()
  }
}

fn named(prefix: String, name: String, value: String) -> Attribute {
  case el.is_name(name) {
    True -> el.attribute(prefix <> name, value)
    False -> el.no_attribute()
  }
}

/// `data-<name>`。名が `[a-z][a-z0-9-]*` でなければ出さない(頁を落とさない)。
///
/// `yumemi` で始まる名は出さない(0.12 段 C)── `data-yumemi-*` は framework と runtime の印で、★ が
/// 書けると送り先・状態・逃げ道の印を偽れる。生成器も第 7 条で止める。
pub fn data(name: String, value: String) -> Attribute {
  case string.starts_with(name, "yumemi") {
    True -> el.no_attribute()
    False -> named("data-", name, value)
  }
}

/// `aria-<name>`。名の扱いは `data` と同じ。
pub fn aria(name: String, value: String) -> Attribute {
  named("aria-", name, value)
}

fn url(name: String, value: String) -> Attribute {
  case safe_url(value) {
    True -> el.attribute(name, value)
    False -> el.no_attribute()
  }
}

/// scheme が http・https・mailto・tel か、scheme の無い相対の URL か。scheme は最初の `:` の
/// 前で、そこまでに `/`・`?`・`#` があれば相対。HTML の URL の parser が捨てる先頭と末尾の
/// 空白・制御文字と、途中のタブ・改行は除いてから見る。
pub fn safe_url(value: String) -> Bool {
  let cleaned =
    value
    |> string.to_graphemes
    |> list.filter(fn(char) { char != "\t" && char != "\n" && char != "\r" })
    |> string.concat
    |> string.trim_start
    |> trim_end
  case string.split_once(cleaned, ":") {
    Error(_) -> True
    Ok(#(scheme, _)) ->
      case
        string.contains(scheme, "/")
        || string.contains(scheme, "?")
        || string.contains(scheme, "#")
      {
        True -> True
        False ->
          case string.lowercase(scheme) {
            "http" | "https" | "mailto" | "tel" -> True
            _ -> False
          }
      }
  }
}

/// `string.trim_end` と同じ(JS の stdlib の正規表現は、字の中の長い空白の連なりで長さの 2 乗かかる)。
@external(javascript, "./text_ffi.mjs", "trim_end")
fn trim_end(text: String) -> String {
  string.trim_end(text)
}

pub fn role(role: Role) -> Attribute {
  string("role", case role {
    Alert -> "alert"
    Button -> "button"
    Dialog -> "dialog"
    Group -> "group"
    List -> "list"
    Listitem -> "listitem"
    Radio -> "radio"
    Radiogroup -> "radiogroup"
    Status -> "status"
    Textbox -> "textbox"
    Toolbar -> "toolbar"
  })
}

pub fn type_(value: String) -> Attribute {
  string("type", value)
}

/// `href`。scheme が http・https・mailto・tel か相対(scheme の無い値)でなければ出さない
/// (`javascript:` の URL を escape は止めないため。DB から来る URL の柵)。
pub fn href(value: String) -> Attribute {
  url("href", value)
}

pub fn value(value: String) -> Attribute {
  string("value", value)
}

pub fn name(value: String) -> Attribute {
  string("name", value)
}

/// `src`。`href` と同じ柵。
pub fn src(value: String) -> Attribute {
  url("src", value)
}

pub fn alt(value: String) -> Attribute {
  string("alt", value)
}

pub fn id(value: String) -> Attribute {
  string("id", value)
}

pub fn method(value: String) -> Attribute {
  string("method", value)
}

/// `action`。`href` と同じ柵(送信で `javascript:` の URL が走るため)。
pub fn action(value: String) -> Attribute {
  url("action", value)
}

pub fn for(value: String) -> Attribute {
  string("for", value)
}

pub fn placeholder(value: String) -> Attribute {
  string("placeholder", value)
}

pub fn rel(value: String) -> Attribute {
  string("rel", value)
}

pub fn accept(values: List(String)) -> Attribute {
  string("accept", string.join(values, ","))
}

pub fn target(value: String) -> Attribute {
  string("target", value)
}

pub fn title(value: String) -> Attribute {
  string("title", value)
}

pub fn inputmode(value: String) -> Attribute {
  string("inputmode", value)
}

pub fn referrerpolicy(value: String) -> Attribute {
  string("referrerpolicy", value)
}

pub fn loading(value: String) -> Attribute {
  string("loading", value)
}

pub fn label(value: String) -> Attribute {
  string("label", value)
}

pub fn scope(value: String) -> Attribute {
  string("scope", value)
}

pub fn min(value: String) -> Attribute {
  string("min", value)
}

pub fn aria_label(value: String) -> Attribute {
  string("aria-label", value)
}

pub fn aria_controls(value: String) -> Attribute {
  string("aria-controls", value)
}

pub fn aria_haspopup(value: String) -> Attribute {
  string("aria-haspopup", value)
}

pub fn rows(value: Int) -> Attribute {
  string("rows", int.to_string(value))
}

pub fn width(value: Int) -> Attribute {
  string("width", int.to_string(value))
}

pub fn height(value: Int) -> Attribute {
  string("height", int.to_string(value))
}

pub fn minlength(value: Int) -> Attribute {
  string("minlength", int.to_string(value))
}

pub fn maxlength(value: Int) -> Attribute {
  string("maxlength", int.to_string(value))
}

pub fn disabled(on: Bool) -> Attribute {
  flag("disabled", on)
}

pub fn selected(on: Bool) -> Attribute {
  flag("selected", on)
}

pub fn checked(on: Bool) -> Attribute {
  flag("checked", on)
}

pub fn hidden(on: Bool) -> Attribute {
  flag("hidden", on)
}

pub fn required(on: Bool) -> Attribute {
  flag("required", on)
}

pub fn readonly(on: Bool) -> Attribute {
  flag("readonly", on)
}

pub fn aria_expanded(on: Bool) -> Attribute {
  string("aria-expanded", bool_string(on))
}

pub fn aria_hidden(on: Bool) -> Attribute {
  string("aria-hidden", bool_string(on))
}

fn bool_string(on: Bool) -> String {
  case on {
    True -> "true"
    False -> "false"
  }
}

/// SVG の属性(試作では icon に要る 4 つだけ)。
pub fn view_box(value: String) -> Attribute {
  string("viewBox", value)
}

pub fn fill(value: String) -> Attribute {
  string("fill", value)
}

pub fn focusable(on: Bool) -> Attribute {
  string("focusable", bool_string(on))
}

pub fn d(value: String) -> Attribute {
  string("d", value)
}
