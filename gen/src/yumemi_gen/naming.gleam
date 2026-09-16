//// snake_case と PascalCase の変換だけ。アプリ固有の名前は一切持たない。

import gleam/list
import gleam/string

/// "article_id" -> "ArticleId"
pub fn pascal(snake: String) -> String {
  snake
  |> string.split("_")
  |> list.map(capitalise)
  |> string.concat
}

/// "ArticleId" -> "article_id"
pub fn snake(pascal: String) -> String {
  pascal
  |> string.to_graphemes
  |> list.index_map(fn(char, index) {
    case is_upper(char), index {
      True, 0 -> string.lowercase(char)
      True, _ -> "_" <> string.lowercase(char)
      False, _ -> char
    }
  })
  |> string.concat
}

/// 先頭の英字を大文字にする。数で始まる区切り("2plus")は数を飛ばして "2Plus"。
pub fn capitalise(word: String) -> String {
  case string.pop_grapheme(word) {
    Ok(#(head, rest)) ->
      case is_digit(head) {
        True -> head <> capitalise(rest)
        False -> string.uppercase(head) <> rest
      }
    Error(_) -> word
  }
}

fn is_digit(char: String) -> Bool {
  list.contains(
    ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"],
    char,
  )
}

fn is_upper(char: String) -> Bool {
  char != string.lowercase(char)
}

/// 最後の区切りの頭文字。SQL の別名に使う("free_space" -> "s")。
pub fn initial(snake_name: String) -> String {
  let last =
    snake_name
    |> string.split("_")
    |> list.last
    |> unwrap_or(snake_name)
  case string.pop_grapheme(last) {
    Ok(#(head, _)) -> head
    Error(_) -> "x"
  }
}

fn unwrap_or(result: Result(String, a), fallback: String) -> String {
  case result {
    Ok(value) -> value
    Error(_) -> fallback
  }
}
