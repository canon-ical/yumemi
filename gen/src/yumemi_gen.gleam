//// yumemi の生成器。`gleam run -m yumemi_gen -- <app dir> <out dir>`
////
//// 出すのは生成束 ── `src/gen/types/*`、`src/gen/query.gleam` と
//// `src/gen/query/{from,field}.gleam`、`src/gen/reads/*`、`src/gen/root/*`、
//// `gen/sql/queries/<service>/<name>.sql`(読み)、verb / phase。
////
//// **出力が揃わなかったら 0 で終わらない。**理由は 20 の exit code 表で分類し(`stop`)、
//// stderr と `_diagnostics.txt` の両方に同じ1行で出す。ファイル自体は書いてから止まる
//// ── 何が出て何が欠けたかを、次の便が現物で見られるようにするため。

import argv
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import simplifile
import yumemi_gen/emit/hash
import yumemi_gen/emit/phase
import yumemi_gen/emit/query
import yumemi_gen/emit/reads
import yumemi_gen/emit/root
import yumemi_gen/emit/sql
import yumemi_gen/emit/types
import yumemi_gen/emit/verb
import yumemi_gen/reader
import yumemi_gen/source
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
  let hashes = hash.of(units)
  let notes =
    list.append(
      list.append(
        reader.missing_key_notes(units),
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
          root.notes(app),
        ),
      ),
      sql.notes(app, hashes),
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
      query.emit(app, hashes.entities),
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

fn read_note(error: reader.Error) -> Note {
  case error {
    reader.NoTypesModule ->
      Note(class: stop.Missing, text: "src/types.gleam が無い")
    reader.NoKeyFunction(module: module) ->
      Note(class: stop.Missing, text: module <> ": key 関数が無い")
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
  Ok(#(list.length(files), notes))
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
