//// yumemi の生成器。`gleam run -m yumemi_gen -- <app dir> <out dir>`
////
//// 出すのは生成束 ── `src/gen/types/*`、`src/gen/query.gleam` と
//// `src/gen/query/{from,field}.gleam`、`src/gen/reads/*`、`src/gen/root/*`、
//// `db/queries/<service>/<name>.sql`(読み)、verb / phase。
////
//// **出力が揃わなかったら 0 で終わらない。**理由は 20 の exit code 表で分類し(`stop`)、
//// stderr と `_diagnostics.txt` の両方に同じ1行で出す。ファイル自体は書いてから止まる
//// ── 何が出て何が欠けたかを、次の便が現物で見られるようにするため。

import argv
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile
import yumemi_gen/emit/draft
import yumemi_gen/emit/entry
import yumemi_gen/emit/front as front_emit
import yumemi_gen/emit/hash
import yumemi_gen/emit/phase
import yumemi_gen/emit/query
import yumemi_gen/emit/reads
import yumemi_gen/emit/root
import yumemi_gen/emit/sql
import yumemi_gen/emit/static as static_emit
import yumemi_gen/emit/types
import yumemi_gen/emit/verb
import yumemi_gen/face
import yumemi_gen/model
import yumemi_gen/naming
import yumemi_gen/reader
import yumemi_gen/reader/front
import yumemi_gen/source
import yumemi_gen/static_source
import yumemi_gen/stop.{type Note, Note}

pub fn main() {
  case argv.load().arguments {
    [app_dir, out_dir] ->
      case run(app_dir, out_dir) {
        Ok(#(count, [])) ->
          io.println("書いた: " <> int.to_string(count) <> " ファイル -> " <> out_dir)
        Ok(#(count, notes)) -> {
          io.println("書いた: " <> int.to_string(count) <> " ファイル -> " <> out_dir)
          io.println_error(stop.report(notes))
          let code = stop.worst(notes)
          io.println_error("停止コード: " <> int.to_string(code))
          halt(code)
        }
        Error(note) -> {
          io.println_error(stop.line(note))
          let code = stop.code(note.class)
          io.println_error("停止コード: " <> int.to_string(code))
          halt(code)
        }
      }
    _ -> {
      io.println_error("使い方: gleam run -m yumemi_gen -- <app dir> <out dir>")
      halt(2)
    }
  }
}

@external(javascript, "./yumemi_gen_ffi.mjs", "halt")
fn halt(code: Int) -> Nil

@external(javascript, "./yumemi_gen_ffi.mjs", "bundle_front")
fn bundle_front(
  out_dir: String,
  app_dir: String,
  faces: List(String),
) -> List(String)

@external(javascript, "./yumemi_gen_ffi.mjs", "format_gleam")
fn format_gleam(out_dir: String, files: List(String)) -> String

/// 生成束と、止まる理由。理由が1つでもあれば呼び手は非 0 で終わる。
pub fn generate(
  app_dir: String,
) -> Result(#(List(types.File), List(Note)), Note) {
  use units <- result.try(
    source.load(app_dir)
    |> result.map_error(fn(error) {
      case error {
        source.ParseFailed(path: path, detail: detail) ->
          Note(class: stop.Syntax, text: path <> ": " <> detail)
        source.ReadFailed(path: path) ->
          Note(class: stop.Missing, text: "読めない: " <> path)
      }
    }),
  )
  use app <- result.try(reader.read(units) |> result.map_error(read_note))
  let app = model.App(..app, attached: attached_routes(app_dir))
  use discovered <- result.try(
    face.discover(app_dir, units)
    |> result.map_error(source_note),
  )
  use static_sources <- result.try(static_sources_for_faces(
    app_dir,
    discovered.packages,
  ))
  use front_models <- result.try(
    list.try_map(discovered.packages, fn(package) {
      front.read_with_package(
        package.name,
        face.package_name(package.path),
        package.units,
        app.services,
      )
      |> result.map(fn(model) { #(package, model) })
      |> result.map_error(front_note)
    }),
  )
  let hashes = hash.of(units)
  let entry_output = entry.emit(app, hashes)
  let front_notes =
    list.append(
      discovered.notes,
      list.flat_map(front_models, fn(item) {
        let #(package, model) = item
        list.append(
          front.notes(model, app.services),
          front_emit.route_notes(app, package.name, model, hashes),
        )
      }),
    )
  let front_notes =
    list.append(front_notes, front_emit.decoder_notes(app, units))
  let notes =
    list.append(
      front_notes,
      list.append(
        verb.notes(app),
        list.append(
          reader.missing_key_notes(units),
          list.append(
            reader.entry_notes(app),
            list.append(
              list.map(query.collisions(app), fn(entry) {
                let #(module, name) = entry
                Note(
                  class: stop.Conflict,
                  text: "名前の衝突 "
                    <> module
                    <> ": "
                    <> name
                    <> "(構成子は module ごとに1つの名前空間)",
                )
              }),
              list.append(
                list.append(root.notes(app), sql.notes(app, hashes)),
                entry_output.notes,
              ),
            ),
          ),
        ),
      ),
    )
  let diagnostics = case notes {
    [] -> []
    _ -> [
      types.File(
        path: "_diagnostics.txt",
        text: stop.report(notes)
          <> "\n停止コード: "
          <> int.to_string(stop.worst(notes))
          <> "\n",
      ),
    ]
  }
  Ok(#(
    list.flatten([
      types.emit(app.value_types, hashes.types),
      draft.emit(app, hashes),
      query.emit(app, hashes.entities),
      entry_output.files,
      list.flat_map(front_models, fn(item) {
        let #(package, model) = item
        let static_files = case static_sources {
          Some(sources) -> static_emit.emit(package.name, sources)
          None -> []
        }
        list.append(
          front_emit.emit(app, units, package, model, hashes),
          static_files,
        )
      }),
      reads.emit(app, hashes),
      sql.emit(app, hashes),
      phase.emit(app, hashes.entities),
      verb.emit(app, hashes),
      verb.sql(app, hashes),
      root.emit(app, hashes),
      diagnostics,
    ]),
    notes,
  ))
}

fn attached_routes(app_dir: String) -> List(model.AttachedRoute) {
  case simplifile.read(app_dir <> "/api/src/gen/http_runtime.mjs") {
    Ok(source_text) -> attached_routes_from_source(source_text)
    Error(_) ->
      case simplifile.read(app_dir <> "/src/gen/http_runtime.mjs") {
        Ok(source_text) -> attached_routes_from_source(source_text)
        Error(_) -> []
      }
  }
}

fn attached_routes_from_source(
  source_text: String,
) -> List(model.AttachedRoute) {
  case string.split(source_text, "const attached=[") {
    [_, rest, ..] ->
      case string.split(rest, "];") {
        [table, ..] ->
          table
          |> string.split("}")
          |> list.filter_map(parse_attached_route)
        [] -> []
      }
    _ -> []
  }
}

fn parse_attached_route(row: String) -> Result(model.AttachedRoute, Nil) {
  case
    single_quoted_field(row, "name"),
    single_quoted_field(row, "method"),
    single_quoted_field(row, "path")
  {
    Some(name), Some(method), Some(path) ->
      Ok(model.AttachedRoute(
        name: naming.pascal(name),
        method: method,
        path: path,
      ))
    _, _, _ -> Error(Nil)
  }
}

fn single_quoted_field(row: String, label: String) -> Option(String) {
  case string.split(row, label <> ":'") {
    [_, rest, ..] ->
      case string.split(rest, "'") {
        [value, ..] -> Some(value)
        [] -> None
      }
    _ -> None
  }
}

fn read_note(error: reader.Error) -> Note {
  case error {
    reader.NoTypesModule ->
      Note(class: stop.Missing, text: "src/types.gleam が無い")
    reader.NoKeyFunction(module: module) ->
      Note(
        class: stop.Missing,
        text: module
          <> ": key 関数が無い ── ER の外の型だけの宣言は src/types.gleam へ(src/entity/** は Entity だけ)",
      )
    reader.NoEntityType(module: module) ->
      Note(class: stop.Missing, text: module <> ": Entity のレコード型が読めない")
    reader.Unsupported(where: where, detail: detail) ->
      Note(class: stop.Conflict, text: where <> ": " <> detail)
    reader.Vocabulary(where: where, detail: detail) ->
      Note(class: stop.Vocabulary, text: where <> ": " <> detail)
    reader.Internal(where: where, detail: detail) ->
      Note(class: stop.NotImplemented, text: where <> ": " <> detail)
  }
}

fn source_note(error: source.Error) -> Note {
  case error {
    source.ParseFailed(path: path, detail: detail) ->
      Note(class: stop.Syntax, text: path <> ": " <> detail)
    source.ReadFailed(path: path) ->
      Note(class: stop.Missing, text: "読めない: " <> path)
  }
}

fn static_sources_for_faces(
  app_dir: String,
  packages: List(face.Package),
) -> Result(Option(static_source.Sources), Note) {
  case packages {
    [] -> Ok(None)
    _ ->
      static_source.load(app_dir)
      |> result.map(Some)
      |> result.map_error(static_source.note)
  }
}

fn front_note(error: front.Error) -> Note {
  case error {
    front.Unsupported(where: where, detail: detail) ->
      Note(class: stop.Conflict, text: where <> ": " <> detail)
  }
}

fn run(app_dir: String, out_dir: String) -> Result(#(Int, List(Note)), Note) {
  use #(files, notes) <- result.try(generate(app_dir))
  use _ <- result.try(
    simplifile.create_directory_all(out_dir)
    |> result.map_error(io_note),
  )
  use _ <- result.try(
    list.try_each(files, fn(file) {
      let full = out_dir <> "/" <> file.path
      let dir = parent(full)
      use _ <- result.try(simplifile.create_directory_all(dir))
      simplifile.write(full, file.text)
    })
    |> result.map_error(io_note),
  )
  let gleam_files =
    files
    |> list.filter_map(fn(file) {
      case string.ends_with(file.path, ".gleam") {
        True -> Ok(file.path)
        False -> Error(Nil)
      }
    })
  use _ <- result.try(case format_gleam(out_dir, gleam_files) {
    "" -> Ok(Nil)
    detail ->
      Error(Note(
        class: stop.NotImplemented,
        text: "gleam format に失敗した: " <> detail,
      ))
  })
  let faces =
    files
    |> list.filter_map(fn(file) {
      case string.ends_with(file.path, "/priv/static/_yumemi/client.mjs") {
        True -> first_segment(file.path)
        False -> Error(Nil)
      }
    })
    |> list.unique
  let bundle_errors = bundle_front(out_dir, app_dir, faces)
  let all_notes = list.append(notes, bundle_notes(bundle_errors))
  use _ <- result.try(case bundle_errors {
    [] -> Ok(Nil)
    _ ->
      simplifile.write(
        out_dir <> "/_diagnostics.txt",
        stop.report(all_notes)
          <> "\n停止コード: "
          <> int.to_string(stop.worst(all_notes))
          <> "\n",
      )
      |> result.map_error(io_note)
  })
  Ok(#(list.length(files), all_notes))
}

pub fn bundle_notes(errors: List(String)) -> List(Note) {
  list.map(errors, fn(error) {
    let class = case value_source_bundle_error(error) {
      True -> stop.ValueSource
      False -> stop.NotImplemented
    }
    Note(class: class, text: error)
  })
}

fn value_source_bundle_error(error: String) -> Bool {
  string.contains(error, "/src/gen/load/")
  && {
    string.contains(error, "view(Nil)")
    || string.contains(error, "space_title.view(it.space_list)")
  }
}

fn first_segment(path: String) -> Result(String, Nil) {
  case string.split(path, "/") {
    [first, ..] -> Ok(first)
    [] -> Error(Nil)
  }
}

fn io_note(error: simplifile.FileError) -> Note {
  Note(class: stop.NotImplemented, text: "書けない: " <> string.inspect(error))
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
