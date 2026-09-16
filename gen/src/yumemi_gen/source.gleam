//// 入力。`src/gen/` を除く `src/**/*.gleam` を読み、glance で parse する。
//// 1つでも parse に失敗したら止まる(20「第1段は全ファイル parse、失敗したら停止」)。

import glance
import gleam/list
import gleam/result
import gleam/string
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
    case glance.module(text) {
      Ok(module) -> Ok(Unit(path: path, text: text, module: module))
      Error(error) -> Error(ParseFailed(full, string.inspect(error)))
    }
  })
}

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
