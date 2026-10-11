//// 生の CSS の逃げ道の検査と数え(0.12 段 B、51 v6「生の CSS の逃げ道」、第 29・30 条)。
//// `shell.stylesheets` と `el.static_sheet` の file を読み、生成物を名指す選択子と `@import` を
//// 見つけ、置いた規則を数える。規則は最上位の塊ごとに 1 つ(`@media` の塊も 1 つ)。

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
  let generated =
    preludes
    |> list.filter(fn(prelude) { !string.starts_with(prelude, "@") })
    |> list.filter(names_generated)
    |> list.unique
  let imports =
    list.any(list.append(statements, preludes), fn(item) {
      string.starts_with(string.lowercase(item), "@import")
    })
  Scan(rules: rules, generated: generated, imports: imports)
}

/// 選択子が生成物を名指すか:`[data-yumemi-` で始まる属性選択子、生成クラス名
/// (`.css-` + 16 進 8 桁)、`yumemi-` で始まる要素名。
pub fn names_generated(selector: String) -> Bool {
  let lowered = string.lowercase(selector)
  string.contains(lowered, "[data-yumemi-")
  || generated_class(lowered)
  || yumemi_element(lowered)
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
