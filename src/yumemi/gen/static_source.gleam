//// 面へ写す back 側の静的資料。面 package の Gleam 走査とは別の口で読む。

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile
import yumemi/gen/digest
import yumemi/gen/stop

pub type Error {
  Missing(path: String)
  Unreadable(path: String, detail: String)
}

pub fn note(error: Error) -> stop.Note {
  case error {
    Missing(path) -> stop.Note(class: stop.Missing, text: "静的資料が無い: " <> path)
    Unreadable(path, detail) ->
      stop.Note(class: stop.Syntax, text: "読めない: " <> path <> ": " <> detail)
  }
}

pub type Host {
  Host(
    connector: String,
    host: String,
    name: String,
    information: String,
    purpose: String,
    side: String,
  )
}

pub type Sources {
  Sources(
    app_name: String,
    hosts: List(Host),
    hosts_hash: String,
    api_v1: String,
    api_v1_hash: String,
  )
}

/// `<app>/src/external_hosts.mjs` と `<repo-root>/docs/api-v1.md` を読む。
/// .mjs は専用の狭い字句読みで宣言形を検査し、Markdown は字として保持する。
pub fn load(app_dir: String) -> Result(Sources, Error) {
  let hosts_path = app_dir <> "/src/external_hosts.mjs"
  let api_v1_path = parent(app_dir) <> "/docs/api-v1.md"
  use hosts_text <- result.try(read_required(hosts_path))
  use api_v1 <- result.try(read_required(api_v1_path))
  use hosts <- result.try(parse_external_hosts_at(hosts_path, hosts_text))
  Ok(Sources(
    app_name: last_segment(app_dir),
    hosts: hosts,
    hosts_hash: digest.short("src/external_hosts.mjs\n" <> hosts_text),
    api_v1: api_v1,
    api_v1_hash: digest.short("docs/api-v1.md\n" <> api_v1),
  ))
}

/// `load` の 2 つの file を、あるものだけ読む(0.13.1、穴 2)。無い file は `None` で、その写し
/// (`gen/external.gleam`・`gen/doc/api_v1.gleam`)を面に出さない。あっても読めない・形の違う file は
/// 今までどおり止める。両方ある app の生成物は `load` と同じ。
pub type Present {
  Present(app_name: String, hosts: Option(Hosts), api_v1: Option(ApiV1))
}

pub type Hosts {
  Hosts(hosts: List(Host), hash: String)
}

pub type ApiV1 {
  ApiV1(text: String, hash: String)
}

pub fn load_present(app_dir: String) -> Result(Present, Error) {
  let hosts_path = app_dir <> "/src/external_hosts.mjs"
  let api_v1_path = parent(app_dir) <> "/docs/api-v1.md"
  use hosts_text <- result.try(read_optional(hosts_path))
  use api_v1 <- result.try(read_optional(api_v1_path))
  use hosts <- result.try(case hosts_text {
    Some(text) ->
      parse_external_hosts_at(hosts_path, text)
      |> result.map(fn(hosts) {
        Some(Hosts(
          hosts: hosts,
          hash: digest.short("src/external_hosts.mjs\n" <> text),
        ))
      })
    None -> Ok(None)
  })
  Ok(Present(
    app_name: last_segment(app_dir),
    hosts: hosts,
    api_v1: option.map(api_v1, fn(text) {
      ApiV1(text: text, hash: digest.short("docs/api-v1.md\n" <> text))
    }),
  ))
}

fn read_optional(path: String) -> Result(Option(String), Error) {
  case read_required(path) {
    Ok(text) -> Ok(Some(text))
    Error(Missing(_)) -> Ok(None)
    Error(error) -> Error(error)
  }
}

/// JS ファイルから EXTERNAL_HOSTS の6欄だけを読む。shape が違えば Error。
pub fn external_hosts(source_text: String) -> Result(List(Host), Nil) {
  case parse_external_hosts(source_text) {
    [] -> Error(Nil)
    ["ok", ..fields] -> read_hosts(fields, [])
    [_, ..] -> Error(Nil)
  }
}

pub fn parse_external_hosts_at(
  path: String,
  source_text: String,
) -> Result(List(Host), Error) {
  external_hosts(source_text)
  |> result.map_error(fn(_) { Unreadable(path, "EXTERNAL_HOSTS の宣言形を読めない") })
}

fn read_hosts(
  fields: List(String),
  hosts: List(Host),
) -> Result(List(Host), Nil) {
  case fields {
    [] -> Ok(list.reverse(hosts))
    [connector, host, name, information, purpose, side, ..rest] ->
      case side {
        "server" | "browser" ->
          read_hosts(rest, [
            Host(connector, host, name, information, purpose, side),
            ..hosts
          ])
        _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

@external(javascript, "./static_source_ffi.mjs", "parse_external_hosts")
fn parse_external_hosts(source_text: String) -> List(String)

fn read_required(path: String) -> Result(String, Error) {
  case simplifile.read(path) {
    Ok(text) -> Ok(text)
    Error(simplifile.Enoent) -> Error(Missing(path))
    Error(error) -> Error(Unreadable(path, simplifile.describe_error(error)))
  }
}

fn parent(path: String) -> String {
  let parts = string.split(path, "/")
  case list.length(parts) {
    0 | 1 -> "."
    length -> parts |> list.take(length - 1) |> string.join("/")
  }
}

fn last_segment(path: String) -> String {
  case list.last(string.split(path, "/")) {
    Ok(value) -> value
    Error(_) -> path
  }
}
