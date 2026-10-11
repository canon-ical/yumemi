//// 入力。`src/gen/` を除く `src/**/*.gleam` を読み、glance で parse する。
//// 1つでも parse に失敗したら止まる(20「第1段は全ファイル parse、失敗したら停止」)。

import glance
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import glexer
import glexer/token
import simplifile

pub type Unit {
  Unit(
    /// module の道。"types" / "entity/article" / "service/article_list"
    path: String,
    /// 生ソース。doc comment を Span から遡って拾うために残す
    text: String,
    module: glance.Module,
  )
}

pub type Error {
  ReadFailed(path: String)
  ParseFailed(path: String, detail: String)
}

/// `<app>/src` の下を歩いて、生成物(`src/gen/`)以外の .gleam を全部読む。
pub fn load(app_dir: String) -> Result(List(Unit), Error) {
  let src = app_dir <> "/src"
  let files =
    gleam_files(src, "")
    |> list.filter(fn(rel) { !string.starts_with(rel, "gen/") })
    |> list.sort(string.compare)
  list.try_map(files, fn(rel) {
    let full = src <> "/" <> rel
    use text <- result.try(
      simplifile.read(full) |> result.replace_error(ReadFailed(full)),
    )
    let path = string.drop_end(rel, 6)
    case glance.module(preprocess_spread_trailing_commas(text)) {
      Ok(module) -> Ok(Unit(path: path, text: text, module: module))
      Error(error) -> Error(ParseFailed(full, string.inspect(error)))
    }
  })
}

type Bracket {
  ListBracket(saw_spread: Bool)
  OtherBracket
}

/// glance 7.0.0 rejects Gleam's `[items, ..rest,]` form. Blank only that
/// comma, using token positions so the parser's source locations stay stable.
fn preprocess_spread_trailing_commas(source_text: String) -> String {
  let offsets =
    glexer.new(source_text)
    |> glexer.lex
    |> list.filter(fn(entry) { !trivia(entry.0) })
    |> spread_trailing_commas([], [])
  case offsets {
    [] -> source_text
    _ ->
      replace_commas_with_spaces(
        source_text,
        list.map(offsets, int.to_string) |> string.join(","),
      )
  }
}

fn trivia(item: token.Token) -> Bool {
  case item {
    token.Space(_)
    | token.CommentDoc(_)
    | token.CommentNormal(_)
    | token.CommentModule(_) -> True
    _ -> False
  }
}

fn spread_trailing_commas(
  tokens: List(#(token.Token, glexer.Position)),
  brackets: List(Bracket),
  offsets: List(Int),
) -> List(Int) {
  case tokens {
    [] -> list.reverse(offsets)
    [#(token.LeftSquare, _), ..rest] ->
      spread_trailing_commas(rest, [ListBracket(False), ..brackets], offsets)
    [#(token.LeftParen, _), ..rest] | [#(token.LeftBrace, _), ..rest] ->
      spread_trailing_commas(rest, [OtherBracket, ..brackets], offsets)
    [#(token.RightSquare, _), ..rest]
    | [#(token.RightParen, _), ..rest]
    | [#(token.RightBrace, _), ..rest] ->
      spread_trailing_commas(rest, pop_bracket(brackets), offsets)
    [#(token.DotDot, _), ..rest] ->
      spread_trailing_commas(rest, mark_spread(brackets), offsets)
    [#(token.Comma, glexer.Position(byte_offset: offset)), ..rest] ->
      case comma_closes_spread_list(brackets, rest) {
        True -> spread_trailing_commas(rest, brackets, [offset, ..offsets])
        False -> spread_trailing_commas(rest, brackets, offsets)
      }
    [_, ..rest] -> spread_trailing_commas(rest, brackets, offsets)
  }
}

fn pop_bracket(brackets: List(Bracket)) -> List(Bracket) {
  case brackets {
    [_, ..rest] -> rest
    [] -> []
  }
}

fn mark_spread(brackets: List(Bracket)) -> List(Bracket) {
  case brackets {
    [ListBracket(_), ..rest] -> [ListBracket(True), ..rest]
    _ -> brackets
  }
}

fn comma_closes_spread_list(
  brackets: List(Bracket),
  remaining: List(#(token.Token, glexer.Position)),
) -> Bool {
  case brackets, remaining {
    [ListBracket(True), ..], [#(token.RightSquare, _), ..] -> True
    _, _ -> False
  }
}

@external(javascript, "./source_ffi.mjs", "replace_commas_with_spaces")
fn replace_commas_with_spaces(source_text: String, offsets: String) -> String

fn gleam_files(root: String, prefix: String) -> List(String) {
  let dir = case prefix {
    "" -> root
    _ -> root <> "/" <> string.drop_end(prefix, 1)
  }
  case simplifile.read_directory(dir) {
    Error(_) -> []
    Ok(entries) ->
      list.flat_map(list.sort(entries, string.compare), fn(entry) {
        let rel = prefix <> entry
        case simplifile.is_directory(dir <> "/" <> entry) {
          Ok(True) -> gleam_files(root, rel <> "/")
          _ ->
            case string.ends_with(entry, ".gleam") {
              True -> [rel]
              False -> []
            }
        }
      })
  }
}
