//// 型と import の書き出し。entity module は「戻りの型に出る module は修飾、
//// Key の中身や穴の型だけの module は非修飾」で綴る。

import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import yumemi_gen/emit/typing.{type Ty, TyApp, TyRef, TyTuple}

pub type Style {
  /// 修飾して綴る module の道(`entity/muse` など)。
  Style(qualified: List(String))
}

fn last_segment(path: String) -> String {
  case list.last(string.split(path, "/")) {
    Ok(segment) -> segment
    Error(_) -> path
  }
}

pub fn ty(style: Style, value: Ty) -> String {
  case value {
    TyRef(module: None, name: name) -> name
    TyRef(module: Some(path), name: name) ->
      case list.contains(style.qualified, path) {
        True -> last_segment(path) <> "." <> name
        False -> name
      }
    TyApp(head: head, args: args) ->
      ty(style, head)
      <> "("
      <> string.join(list.map(args, ty(style, _)), ", ")
      <> ")"
    TyTuple(items) ->
      "#(" <> string.join(list.map(items, ty(style, _)), ", ") <> ")"
  }
}

/// 型の木から import 行を起こす。extra は型に現れない import(framework/step など)。
pub fn imports(style: Style, values: List(Ty), extra: List(#(String, List(String)))) -> String {
  let from_types =
    list.fold(values, dict.new(), fn(acc, value) { walk(style, value, acc) })
  let all =
    list.fold(extra, from_types, fn(acc, entry) {
      let #(path, names) = entry
      add(acc, path, names)
    })
  all
  |> dict.to_list
  |> list.sort(fn(left, right) { string.compare(left.0, right.0) })
  |> list.map(fn(entry) {
    let #(path, names) = entry
    case list.sort(list.unique(names), string.compare) {
      [] -> "import " <> path
      sorted ->
        "import "
        <> path
        <> ".{"
        <> string.join(list.map(sorted, fn(name) { "type " <> name }), ", ")
        <> "}"
    }
  })
  |> string.join("\n")
}

fn add(
  acc: Dict(String, List(String)),
  path: String,
  names: List(String),
) -> Dict(String, List(String)) {
  case dict.get(acc, path) {
    Ok(existing) -> dict.insert(acc, path, list.append(existing, names))
    Error(_) -> dict.insert(acc, path, names)
  }
}

fn walk(
  style: Style,
  value: Ty,
  acc: Dict(String, List(String)),
) -> Dict(String, List(String)) {
  case value {
    TyRef(module: None, ..) -> acc
    TyRef(module: Some(path), name: name) ->
      case list.contains(style.qualified, path) {
        True -> add(acc, path, [])
        False -> add(acc, path, [name])
      }
    TyApp(head: head, args: args) ->
      list.fold(args, walk(style, head, acc), fn(inner, item) {
        walk(style, item, inner)
      })
    TyTuple(items) ->
      list.fold(items, acc, fn(inner, item) { walk(style, item, inner) })
  }
}
