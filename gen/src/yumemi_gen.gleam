//// yumemi の生成器。`gleam run -m yumemi_gen -- <app dir> <out dir>`
////
//// 出すのは生成束 ── `src/gen/types/*`、`src/gen/query.gleam` と
//// `src/gen/query/{from,field}.gleam`、`src/gen/reads/*`、`src/gen/root/*`、
//// `db/queries/<service>/<name>.sql`(読み)、verb / phase、`src/gen/allow/*`(root が指す allow)。
//// 出力先が app そのものか app を含む dir(musearch なら `<root>/api` か `<root>`)なら、生成物を在るべき場所に
//// 置く ── back は app の下、面は面の package の下(`place`)。このとき `db/queries` へは既に在る
//// `-- GENERATED` の file だけを書く(生成器だけが出す SQL は `src/gen/sql.mjs` に束ねる ── `into_app`)。
//// 出力先が別の dir なら、back は `<out>/src/gen/..`、面は `<out>/<面>/..` に並べる。
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
import yumemi_gen/emit/allow as allow_emit
import yumemi_gen/emit/back
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
import yumemi_gen/reader
import yumemi_gen/reader/allow as allow_reader
import yumemi_gen/reader/front
import yumemi_gen/reader/server as server_reader
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
  faces: List(#(String, String)),
) -> List(String)

/// `inner` が `outer` そのものかその下の dir か(実体の path で比べる)。
@external(javascript, "./yumemi_gen_ffi.mjs", "holds_dir")
fn holds_dir(outer: String, inner: String) -> Bool

/// `from` から `to` への相対 path(同じ dir なら "")。
@external(javascript, "./yumemi_gen_ffi.mjs", "relative_dir")
fn relative_dir(from: String, to: String) -> String

@external(javascript, "./yumemi_gen_ffi.mjs", "sql_files")
fn sql_files(dir: String) -> List(#(String, String))

@external(javascript, "./yumemi_gen_ffi.mjs", "format_gleam")
fn format_gleam(out_dir: String, files: List(String)) -> String

/// 生成束と、止まる理由。理由が1つでもあれば呼び手は非 0 で終わる。
pub fn generate(
  app_dir: String,
) -> Result(#(List(types.File), List(Note)), Note) {
  generate_with_faces(app_dir)
  |> result.map(fn(made) { #(made.0, made.1) })
}

/// `generate` に、見つけた面の (名, package の path) を添える(`place` が面の置き場に使う)。
fn generate_with_faces(
  app_dir: String,
) -> Result(#(List(types.File), List(Note), List(#(String, String))), Note) {
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
      front.read_with_package_and_entries(
        package.name,
        face.package_name(package.path),
        package.units,
        app.services,
        app.entries,
      )
      |> result.map(fn(model) { #(package, model) })
      |> result.map_error(front_note)
    }),
  )
  let hashes = hash.of(units)
  let allow_usages = allow_reader.read(units)
  let entry_output = entry.emit(app, hashes)
  let front_notes =
    list.append(
      discovered.notes,
      list.flat_map(front_models, fn(item) {
        let #(package, model) = item
        list.flatten([
          front.notes(model, app.services),
          front_emit.route_notes(app, package.name, model, hashes),
          front_emit.gate_notes(app, units, package, model),
          front_emit.client_notes(package, model),
        ])
      }),
    )
  let front_notes =
    list.append(front_notes, front_emit.decoder_notes(app, units))
  let collision_notes =
    list.map(query.collisions(app), fn(entry) {
      let #(module, name) = entry
      Note(
        class: stop.Conflict,
        text: "名前の衝突 " <> module <> ": " <> name <> "(構成子は module ごとに1つの名前空間)",
      )
    })
  let notes =
    list.flatten([
      front_notes,
      verb.notes(app),
      reader.missing_key_notes(units),
      reader.entry_notes(app),
      server_reader.notes(app),
      collision_notes,
      root.notes(app),
      allow_emit.notes(app, allow_usages),
      sql.notes(app, hashes),
      entry_output.notes,
    ])
  let made =
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
      allow_emit.emit(app, allow_usages, units),
    ])
  let back_output =
    back.emit(app, units, hashes, sql_files(app_dir <> "/db/queries"), made)
  let notes = list.append(notes, back_output.notes)
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
    list.flatten([made, back_output.files, diagnostics]),
    notes,
    list.map(discovered.packages, fn(package) { #(package.name, package.path) }),
  ))
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
  use #(generated, notes, face_dirs) <- result.try(generate_with_faces(app_dir))
  let in_place = holds_dir(out_dir, app_dir)
  let placement = case in_place {
    True ->
      Placement(
        app: relative_dir(out_dir, app_dir),
        faces: list.map(face_dirs, fn(face) {
          #(face.0, relative_dir(out_dir, face.1))
        }),
      )
    False -> Placement(app: "", faces: [])
  }
  let faces =
    generated
    |> list.filter_map(fn(file) {
      case string.ends_with(file.path, "/priv/static/_yumemi/client.mjs") {
        True -> first_segment(file.path)
        False -> Error(Nil)
      }
    })
    |> list.unique
    |> list.map(fn(face) { #(face, face_dir(placement, face)) })
  let files =
    into_app(generated, in_place, fn(path) {
      case simplifile.read(out_dir <> "/" <> place(placement, path)) {
        Ok(text) -> string.starts_with(text, "-- GENERATED")
        Error(_) -> False
      }
    })
    |> list.map(fn(file) {
      types.File(..file, path: place(placement, file.path))
    })
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

/// 生成物の置き場。`app` は出力先から app への相対(別の dir に出すなら "")、`faces` は面の名から
/// 面の package への相対(別の dir に出すなら空 ── 面は `<out>/<面>/..`)。
pub type Placement {
  Placement(app: String, faces: List(#(String, String)))
}

/// 生成束の path(back は app からの相対、面は `<面>/..`)を、出力先からの相対に直す。
pub fn place(placement: Placement, path: String) -> String {
  case path {
    "_diagnostics.txt" -> path
    _ -> {
      let face = case string.split_once(path, "/") {
        Ok(#(first, rest)) ->
          list.key_find(placement.faces, first)
          |> result.map(fn(dir) { join(dir, rest) })
        Error(_) -> Error(Nil)
      }
      case face {
        Ok(placed) -> placed
        Error(_) -> join(placement.app, path)
      }
    }
  }
}

fn face_dir(placement: Placement, face: String) -> String {
  list.key_find(placement.faces, face) |> result.unwrap(face)
}

fn join(dir: String, path: String) -> String {
  case dir {
    "" -> path
    _ -> dir <> "/" <> path
  }
}

fn first_segment(path: String) -> Result(String, Nil) {
  case string.split(path, "/") {
    [first, ..] -> Ok(first)
    [] -> Error(Nil)
  }
}

/// 出力先が app そのもののとき、`db/queries/**` へは既に在る file だけを書く(WGy r4、鷹野の裁定 1 (c))。
/// 生成器だけが出す SQL は `src/gen/sql.mjs` に束ねてあるので、app の `db/queries` には増やさない。
/// 既に在る file のうち上書きするのは `-- GENERATED` を名乗るもの(`generated` が真)だけで、★ の手書きは
/// そのまま残す(`back` の `bundle` と同じ規則 ── app の SQL が勝つのは ★ だけ)。出力先が別の dir なら全部を書く。
pub fn into_app(
  files: List(types.File),
  app: Bool,
  generated: fn(String) -> Bool,
) -> List(types.File) {
  case app {
    False -> files
    True ->
      list.filter(files, fn(file) {
        !string.starts_with(file.path, "db/queries/") || generated(file.path)
      })
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
