//// 生の CSS の逃げ道の検査と数え(0.12 段 B、51 v6「生の CSS の逃げ道」、第 29・30 条)。
//// `shell.stylesheets` と `el.static_sheet` の file を読み、生成物を名指す選択子と `@import` を
//// 見つけ、置いた規則を数える。規則は最上位の塊ごとに 1 つ(`@media` の塊も 1 つ)。

import gleam/int
import gleam/list
import gleam/string

pub type Scan {
  Scan(
    /// 最上位の塊の数(規則の数)。
    rules: Int,
    /// 生成物を名指す選択子(第 29 条)。
    generated: List(String),
    /// `@import` があるか(第 30 条)。
    imports: Bool,
  )
}

pub fn scan(css: String) -> Scan {
  let text = strip_comments(css)
  let #(rules, preludes, statements) = blocks(string.to_graphemes(text))
  // at-rule の前置き(`@scope ([data-yumemi-…])` ほか)も同じ検査に掛ける(0.12 段 C、Y2 柏木 P1-3)
  let generated =
    preludes
    |> list.filter(names_generated)
    |> list.unique
  let imports =
    list.any(list.append(statements, preludes), fn(item) {
      string.starts_with(string.lowercase(item), "@import")
    })
  Scan(rules: rules, generated: generated, imports: imports)
}

/// 選択子が生成物を名指すか:`[data-yumemi-` で始まる属性選択子、生成クラス名
/// (`.css-` + 16 進 8 桁)、`yumemi-` で始まる要素名、class の属性選択子で `css` を含む値
/// (`[class*="css-"]` ほか)。CSS の escape(`\2d`・`\-`)を解き、括弧の中の空白を詰めてから見る
/// (0.12 段 C、Y2 柏木 P1-3)。
pub fn names_generated(selector: String) -> Bool {
  let lowered = unescape(string.lowercase(selector))
  let compact =
    lowered
    |> string.to_graphemes
    |> list.filter(fn(char) { !string.contains(" \t\n\r\f", char) })
    |> string.concat
  string.contains(compact, "[data-yumemi-")
  || generated_class(compact)
  || yumemi_element(lowered)
  || class_attribute(compact)
}

/// `[class…css…]`(`[class*="css-"]`・`[class^=css]`・`[class~="css-0a1b2c3d"]`)。
fn class_attribute(compact: String) -> Bool {
  case string.split(compact, "[class") {
    [_, ..rest] ->
      list.any(rest, fn(after) {
        case string.split_once(after, "]") {
          Ok(#(inside, _)) -> string.contains(inside, "css")
          Error(_) -> string.contains(after, "css")
        }
      })
    [] -> False
  }
}

/// CSS の escape を解く:`\` + 16 進 1〜6 桁(続く空白 1 つを食う)は文字に、`\` + 他の文字はその文字に。
fn unescape(text: String) -> String {
  unescape_loop(string.to_graphemes(text), "")
}

fn unescape_loop(chars: List(String), done: String) -> String {
  case chars {
    [] -> done
    ["\\", ..rest] -> {
      let #(digits, after) = take_hex(rest, "", 0)
      case digits {
        "" ->
          case after {
            [char, ..tail] -> unescape_loop(tail, done <> char)
            [] -> done
          }
        _ -> {
          let after = case after {
            [" ", ..tail] -> tail
            _ -> after
          }
          let char = case int.base_parse(digits, 16) {
            Ok(code) ->
              case string.utf_codepoint(code) {
                Ok(point) -> string.from_utf_codepoints([point])
                Error(_) -> ""
              }
            Error(_) -> ""
          }
          unescape_loop(after, done <> string.lowercase(char))
        }
      }
    }
    [char, ..rest] -> unescape_loop(rest, done <> char)
  }
}

fn take_hex(
  chars: List(String),
  digits: String,
  count: Int,
) -> #(String, List(String)) {
  case chars, count < 6 {
    [char, ..rest], True ->
      case string.contains("0123456789abcdef", char) {
        True -> take_hex(rest, digits <> char, count + 1)
        False -> #(digits, chars)
      }
    _, _ -> #(digits, chars)
  }
}

fn generated_class(selector: String) -> Bool {
  case string.split(selector, ".css-") {
    [_, ..rest] ->
      list.any(rest, fn(after) {
        let digits = string.slice(after, 0, 8)
        string.length(digits) == 8
        && list.all(string.to_graphemes(digits), fn(char) {
          string.contains("0123456789abcdef", char)
        })
      })
    [] -> False
  }
}

fn yumemi_element(selector: String) -> Bool {
  case string.split(selector, "yumemi-") {
    [first, _, ..] as parts -> {
      let befores = list.take(parts, list.length(parts) - 1)
      let _ = first
      list.any(befores, fn(before) {
        case string.last(before) {
          Error(_) -> True
          Ok(char) -> string.contains(" >+~,(\t\n", char)
        }
      })
    }
    _ -> False
  }
}

fn strip_comments(css: String) -> String {
  case string.split_once(css, "/*") {
    Ok(#(before, after)) ->
      case string.split_once(after, "*/") {
        Ok(#(_, rest)) -> before <> " " <> strip_comments(rest)
        Error(_) -> before
      }
    Error(_) -> css
  }
}

/// #(最上位の塊の数, 全ての深さの塊の前置き, 最上位の `;` で終わる文)。
fn blocks(chars: List(String)) -> #(Int, List(String), List(String)) {
  walk(chars, 0, "", 0, [], [], "")
}

fn walk(
  chars: List(String),
  depth: Int,
  current: String,
  rules: Int,
  preludes: List(String),
  statements: List(String),
  quote: String,
) -> #(Int, List(String), List(String)) {
  case chars, quote {
    [], _ -> #(rules, list.reverse(preludes), list.reverse(statements))
    [char, ..rest], "" ->
      case char {
        "\"" | "'" ->
          walk(rest, depth, current <> char, rules, preludes, statements, char)
        "{" -> {
          let prelude = string.trim(current)
          let rules = case depth {
            0 -> rules + 1
            _ -> rules
          }
          walk(
            rest,
            depth + 1,
            "",
            rules,
            [prelude, ..preludes],
            statements,
            "",
          )
        }
        "}" ->
          walk(rest, int_max(depth - 1, 0), "", rules, preludes, statements, "")
        ";" ->
          case depth {
            0 ->
              walk(
                rest,
                depth,
                "",
                rules,
                preludes,
                [string.trim(current), ..statements],
                "",
              )
            _ -> walk(rest, depth, "", rules, preludes, statements, "")
          }
        _ -> walk(rest, depth, current <> char, rules, preludes, statements, "")
      }
    [char, ..rest], quote ->
      case char == quote {
        True ->
          walk(rest, depth, current <> char, rules, preludes, statements, "")
        False ->
          walk(rest, depth, current <> char, rules, preludes, statements, quote)
      }
  }
}

fn int_max(a: Int, b: Int) -> Int {
  case a > b {
    True -> a
    False -> b
  }
}
