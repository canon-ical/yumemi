//// yumemi-0122b(0.12.2)── id を DB に任せる素直な Entity(`pub const auto_key = ["id"]`)の作る Service が
//// 400 になる穴と、穴の size が 1 未満の頁が 503 になる穴。★ の書き方は変えない。
//// 題材は `gen/fixtures/notes`(Note は `auto_key` の Entity)。

import gleam/list
import gleam/string
import gleeunit/should
import yumemi/gen as yumemi_gen
import yumemi/gen/stop

const fixture = "gen/fixtures/notes"

@external(javascript, "./yumemi_s1_test_ffi.mjs", "copy_app")
fn copy_app(from: String) -> String

@external(javascript, "./yumemi_s1_test_ffi.mjs", "remove_app")
fn remove_app(dir: String) -> Nil

@external(javascript, "./yumemi_s1_test_ffi.mjs", "edit")
fn edit(dir: String, path: String, from: String, to: String) -> Bool

@external(javascript, "./yumemi_0122b_test_ffi.mjs", "runtime_check")
fn runtime_check(which: String, verb: String) -> String

/// fixture の写しを `edits` で替えて生成し、(停止コード, 止まる理由の行, 書いた file)。
fn generated(
  edits: List(#(String, String, String)),
) -> #(Int, String, List(#(String, String))) {
  generated_from(fixture, edits)
}

fn generated_from(
  from: String,
  edits: List(#(String, String, String)),
) -> #(Int, String, List(#(String, String))) {
  let dir = copy_app(from)
  list.each(edits, fn(item) {
    let #(path, from, to) = item
    edit(dir, path, from, to) |> should.be_true
  })
  let result = yumemi_gen.generate(dir)
  remove_app(dir)
  case result {
    Ok(#(files, notes)) -> #(
      stop.worst(notes),
      string.join(list.map(notes, stop.line), "\n"),
      list.map(files, fn(file) { #(file.path, file.text) }),
    )
    Error(note) -> #(stop.code(note.class), stop.line(note), [])
  }
}

fn text_of(files: List(#(String, String)), path: String) -> String {
  let assert Ok(#(_, text)) = list.find(files, fn(file) { file.0 == path })
  text
}

/// 生成の `runtime.mjs` の verb の表から `<name>:{..}` の 1 行。
fn verb_line(files: List(#(String, String)), name: String) -> String {
  let assert Ok(line) =
    text_of(files, "src/gen/runtime.mjs")
    |> string.split("\n")
    |> list.find(fn(line) { string.starts_with(line, " " <> name <> ":{key:") })
  line
}

fn ok_lines(out: String, count: Int) -> Nil {
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  string.split(out, "\n") |> list.length |> should.equal(count)
}

// ── auto_key ────────────────────────────────────────────────────────────

/// `auto_key` の key は Draft に無く、作る verb を stage すると runtime が要求の seed から採番して INSERT に渡す。
/// 作った値(`NoteCreated`)の key はその採番の値。0.12.1 は INSERT が key を DB の DEFAULT に任せたまま、
/// 作った値を commit の前に組んで `c.parse('note_id', null)` で 400(field は key)だった。
pub fn auto_key_create_stages_a_runtime_key_test() {
  let #(code, _, files) = generated([])
  code |> should.equal(0)
  text_of(files, "src/gen/draft/note.gleam")
  |> string.contains("NoteDraft(\n    title: NoteTitle,")
  |> should.be_true
  text_of(files, "src/gen/sql.mjs")
  |> string.contains(
    "INSERT INTO app.note(id,title,body,created_at)\\nVALUES($1::uuid,$2,$3,$4::timestamptz) RETURNING id,title,body,created_at;",
  )
  |> should.be_true
  runtime_check("auto", verb_line(files, "create_note")) |> ok_lines(5)
}

/// `auto_key` の key が Uuid でない(連番・文字列)と生成器で止める(採番は UUID だけ)。
pub fn auto_key_on_a_non_uuid_key_stops_test() {
  let #(code, reason, _) =
    generated([
      #(
        "src/types.gleam",
        "note_id: Spec = Uuid",
        "note_id: Spec = Text(min: 1, max: 40)",
      ),
    ])
  code |> should.equal(4)
  string.contains(reason, "entity/note: auto_key の key が Uuid でない: id")
  |> should.be_true
}

/// 複合の key の `auto_key` も止める(採番する key は 1 つ。key の一部だけを採番すると作った値の key が崩れる)。
pub fn auto_key_on_a_composite_key_stops_test() {
  let #(code, reason, _) =
    generated_from("gen/fixtures/flag", [
      #(
        "src/entity/chunk.gleam",
        "pub const collection: String = \"chunks\"",
        "pub const collection: String = \"chunks\"\n\npub const auto_key: List(String) = [\"a\"]",
      ),
    ])
  code |> should.equal(4)
  string.contains(reason, "entity/chunk: auto_key は 1 つの Property の key にだけ書ける")
  |> should.be_true
}

// ── 穴の size が 1 未満 ───────────────────────────────────────────────────

/// size が穴の頁は keyset に穴の名(`sizeField`)も添え、runtime は size が 1 未満なら SQL を流す前に
/// 400 `invalid_argument`(field は穴の名)で止める。0.12.2 の r1 は `cursorText(keyset, undefined)` の
/// TypeError で 503 `unavailable` だった。
pub fn page_size_below_one_is_invalid_argument_test() {
  let #(_, _, files) = generated([])
  text_of(files, "src/gen/runtime.mjs")
  |> string.contains(
    "keyset:{size:20,sizeArg:0,sizeField:'limit',uniform:true,",
  )
  |> should.be_true
  runtime_check("size", "") |> ok_lines(5)
}
