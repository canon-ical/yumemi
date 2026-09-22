//// 面 package の発見。back の `source.load` とは別に、入口の隣の package を読む。
////
//// 探索は dirname(app_dir) と app_dir の直下だけに限る。ここで再帰すると、
//// fixture の親を app として渡したときに別 fixture の面まで混ざる。

import glance
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile
import yumemi_gen/glance_util as g
import yumemi_gen/source
import yumemi_gen/stop

pub type Pages {
  /// pages 欄が無い。面を持つかどうかは folder の有無で決める。
  UndeclaredPages
  AllPages
  NoPages
}

pub type HttpEntry {
  HttpEntry(name: String, pages: Pages)
}

/// 見つけた package の候補。テストでは source 文字列から直接組める。
pub type Candidate {
  Candidate(name: String, path: String, has_package: Bool, has_layout: Bool)
}

pub type Package {
  Package(name: String, path: String, pages: Pages, units: List(source.Unit))
}

pub type Discovery {
  Discovery(packages: List(Package), notes: List(stop.Note))
}

pub type Selection {
  Selection(packages: List(Candidate), notes: List(stop.Note))
}

/// `<app>/src/entry.gleam` の Http 入口と、直下の面 package を突き合わせる。
pub fn discover(
  app_dir: String,
  units: List(source.Unit),
) -> Result(Discovery, source.Error) {
  let candidates =
    list.unique(list.append(
      candidates_in(parent(app_dir)),
      candidates_in(app_dir),
    ))
  let entries = http_entries(units)
  let selection = select(entries, candidates)
  use packages <- result.try(
    list.try_map(selection.packages, fn(candidate) {
      source.load(candidate.path)
      |> result.map(fn(face_units) {
        Package(
          name: candidate.name,
          path: candidate.path,
          pages: entry_pages(entries, candidate.name),
          units: face_units,
        )
      })
    }),
  )
  Ok(Discovery(packages: packages, notes: selection.notes))
}

/// 面の出力ディレクトリ名と、gleam package の name は別物である。
/// shell が無いときの title の既定値には manifest の name を使う。
pub fn package_name(path: String) -> String {
  let fallback = last_segment(path)
  case simplifile.read(path <> "/gleam.toml") {
    Error(_) -> fallback
    Ok(text) ->
      case
        text
        |> string.split("\n")
        |> list.find_map(fn(line) {
          let trimmed = string.trim(line)
          case string.starts_with(trimmed, "name = \"") {
            True ->
              case string.split(trimmed, "\"") {
                [_, value, ..] -> Ok(value)
                _ -> Error(Nil)
              }
            False -> Error(Nil)
          }
        })
      {
        Ok(value) -> value
        Error(_) -> fallback
      }
  }
}

/// filesystem を使わない発見。負例を source 文字列だけで検査する入口。
pub fn select(
  entries: List(HttpEntry),
  candidates: List(Candidate),
) -> Selection {
  let folders =
    candidates
    |> list.filter(fn(candidate) {
      candidate.has_package && candidate.has_layout
    })
  let missing =
    entries
    |> list.filter(fn(entry) {
      entry.pages == AllPages
      && !list.any(folders, fn(folder) { folder.name == entry.name })
    })
    |> list.map(fn(entry) {
      stop.Note(
        class: stop.Missing,
        text: "entry." <> entry.name <> ": フォルダの無い Http 入口",
      )
    })
  let orphans =
    folders
    |> list.filter(fn(folder) {
      !list.any(entries, fn(entry) { entry.name == folder.name })
    })
    |> list.map(fn(folder) {
      stop.Note(
        class: stop.Missing,
        text: "face." <> folder.name <> ": 入口の無いフォルダ",
      )
    })
  let packages =
    folders
    |> list.filter(fn(folder) {
      list.any(entries, fn(entry) { entry.name == folder.name })
    })
  Selection(packages: packages, notes: list.append(missing, orphans))
}

/// テストや reader が entry の宣言を再利用できるように公開する。
pub fn http_entries(units: List(source.Unit)) -> List(HttpEntry) {
  case list.find(units, fn(unit) { unit.path == "entry" }) {
    Error(_) -> []
    Ok(unit) -> {
      let module = g.in_order(unit.module)
      case public_constant(module, "entries") {
        None -> []
        Some(constant) ->
          g.list_elements(constant.value)
          |> list.filter_map(http_entry)
      }
    }
  }
}

fn http_entry(expression: glance.Expression) -> Result(HttpEntry, Nil) {
  case g.ctor_name(expression) {
    Some("Http") ->
      case g.labelled(expression, "name") {
        Some(name) ->
          case g.string_value(name) {
            Some(name) -> Ok(HttpEntry(name: name, pages: pages_of(expression)))
            None -> Error(Nil)
          }
        None -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

fn entry_pages(entries: List(HttpEntry), name: String) -> Pages {
  case list.find(entries, fn(entry) { entry.name == name }) {
    Ok(entry) -> entry.pages
    Error(_) -> UndeclaredPages
  }
}

fn pages_of(expression: glance.Expression) -> Pages {
  case g.labelled(expression, "pages") {
    None -> UndeclaredPages
    Some(value) ->
      case g.ctor_name(value) {
        Some("AllPages") -> AllPages
        Some("NoPages") -> NoPages
        _ -> UndeclaredPages
      }
  }
}

fn public_constant(
  module: glance.Module,
  name: String,
) -> Option(glance.Constant) {
  case g.find_constant(module, name) {
    Some(constant) ->
      case constant.publicity {
        glance.Public -> Some(constant)
        glance.Private -> None
      }
    None -> None
  }
}

fn candidates_in(root: String) -> List(Candidate) {
  case simplifile.read_directory(root) {
    Error(_) -> []
    Ok(entries) ->
      entries
      |> list.sort(string.compare)
      |> list.filter_map(fn(name) {
        let path = root <> "/" <> name
        case simplifile.is_directory(path) {
          Ok(True) ->
            Ok(Candidate(
              name: name,
              path: path,
              has_package: is_file(path <> "/gleam.toml"),
              has_layout: is_file(path <> "/src/layout.gleam"),
            ))
          _ -> Error(Nil)
        }
      })
  }
}

fn is_file(path: String) -> Bool {
  case simplifile.is_file(path) {
    Ok(value) -> value
    Error(_) -> False
  }
}

fn parent(path: String) -> String {
  let parts = string.split(path, "/")
  case list.length(parts) {
    0 | 1 -> "."
    length ->
      parts
      |> list.take(length - 1)
      |> string.join("/")
  }
}

fn last_segment(path: String) -> String {
  case list.last(string.split(path, "/")) {
    Ok(value) -> value
    Error(_) -> path
  }
}
