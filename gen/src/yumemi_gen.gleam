//// yumemi の生成器。`gleam run -m yumemi_gen -- <app dir> <out dir>`
////
//// 出すのは4束だけ ── `src/gen/types/*`、`src/gen/query.gleam`、`src/gen/reads/*`、
//// `gen/sql/queries/<service>/<name>.sql`(読み)。verb / root / entry / migration は出さない。

import argv
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import simplifile
import yumemi_gen/emit/query
import yumemi_gen/emit/reads
import yumemi_gen/emit/sql
import yumemi_gen/emit/types
import yumemi_gen/reader
import yumemi_gen/source

pub fn main() {
  case argv.load().arguments {
    [app_dir, out_dir] ->
      case run(app_dir, out_dir) {
        Ok(count) ->
          io.println("書いた: " <> int.to_string(count) <> " ファイル -> " <> out_dir)
        Error(message) -> {
          io.println_error("停止: " <> message)
          halt(4)
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

pub fn generate(app_dir: String) -> Result(List(types.File), String) {
  use units <- result.try(
    source.load(app_dir) |> result.map_error(string.inspect),
  )
  use app <- result.try(reader.read(units) |> result.map_error(string.inspect))
  let diagnostics =
    list.append(
      list.map(query.collisions(app), fn(name) {
        "名前の衝突 gen/query.gleam: " <> name <> "(From / Field / Arrow / Operand は同じ名前空間)"
      }),
      sql.notes(app),
    )
  let notes = case diagnostics {
    [] -> []
    _ -> [
      types.File(
        path: "_diagnostics.txt",
        text: string.join(diagnostics, "\n") <> "\n",
      ),
    ]
  }
  Ok(
    list.flatten([
      types.emit(app.value_types),
      query.emit(app),
      reads.emit(app),
      sql.emit(app),
      notes,
    ]),
  )
}

fn run(app_dir: String, out_dir: String) -> Result(Int, String) {
  use files <- result.try(generate(app_dir))
  use _ <- result.try(
    simplifile.create_directory_all(out_dir)
    |> result.map_error(string.inspect),
  )
  use _ <- result.try(
    list.try_each(files, fn(file) {
      let full = out_dir <> "/" <> file.path
      let dir = parent(full)
      use _ <- result.try(simplifile.create_directory_all(dir))
      simplifile.write(full, file.text)
    })
    |> result.map_error(string.inspect),
  )
  Ok(list.length(files))
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
