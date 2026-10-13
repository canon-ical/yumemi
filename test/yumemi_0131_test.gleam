//// yumemi-0131(0.13.1)── 文書サイトの形の app が本番の前に当たる穴。3 整数・真偽・浮動小数の列で並べた
//// Paged、2 静的資料の無い app の生成、6 一意の制約の違反の log。Markdown の Component は
//// `yumemi_0131_markdown_test.gleam`。

import glance
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import yumemi/gen as yumemi_gen
import yumemi/gen/emit/static as static_emit
import yumemi/gen/source
import yumemi/gen/static_source
import yumemi/gen/stop

const notes = "gen/fixtures/notes"

@external(javascript, "./yumemi_s1_test_ffi.mjs", "copy_app")
fn copy_app(from: String) -> String

@external(javascript, "./yumemi_s1_test_ffi.mjs", "remove_app")
fn remove_app(dir: String) -> Nil

@external(javascript, "./yumemi_s1_test_ffi.mjs", "edit")
fn edit(dir: String, path: String, from: String, to: String) -> Bool

fn generated(
  fixture: String,
  edits: List(#(String, String, String)),
) -> #(Int, List(#(String, String))) {
  let dir = copy_app(fixture)
  list.each(edits, fn(item) {
    let #(path, from, to) = item
    edit(dir, path, from, to) |> should.be_true
  })
  let assert Ok(#(files, notes)) = yumemi_gen.generate(dir)
  remove_app(dir)
  #(stop.worst(notes), list.map(files, fn(file) { #(file.path, file.text) }))
}

fn text_of(files: List(#(String, String)), path: String) -> String {
  let assert Ok(#(_, text)) = list.find(files, fn(file) { file.0 == path })
  text
}

// ── 3 Paged を整数・真偽・浮動小数の列で並べる ─────────────────────────────

/// 覚え書きに `kind` の列を足し、一覧をその列の降順で刻む。
fn ordered_by(gleam_type: String) -> List(#(String, String, String)) {
  [
    #(
      "src/entity/note.gleam",
      "created_at: Datetime)",
      "created_at: Datetime, rank: " <> gleam_type <> ")",
    ),
    #(
      "src/service/note_list.gleam",
      "order: [q.Desc(field.NoteCreatedAt)]",
      "order: [q.Desc(field.NoteRank)]",
    ),
  ]
}

/// keyset の頭の穴(`$2 IS NULL`)に型が無いと、型の無い穴を送る経路(Neon の HTTP)で PostgreSQL が穴の型を
/// 決められず(`could not determine data type of parameter $2`)、整数の列の一覧は 503 だった。
pub fn paged_by_integer_casts_the_cursor_test() {
  let #(code, files) = generated(notes, ordered_by("Int"))
  code |> should.equal(0)
  let sql = text_of(files, "src/gen/sql.mjs")
  sql |> string.contains("($2::integer IS NULL OR (") |> should.be_true
  sql |> string.contains("<($2,$3::uuid))") |> should.be_true
}

pub fn paged_by_boolean_and_float_casts_the_cursor_test() {
  let #(_, files) = generated(notes, ordered_by("Bool"))
  text_of(files, "src/gen/sql.mjs")
  |> string.contains("($2::boolean IS NULL OR (")
  |> should.be_true
  let #(_, files) = generated(notes, ordered_by("Float"))
  text_of(files, "src/gen/sql.mjs")
  |> string.contains("($2::double precision IS NULL OR (")
  |> should.be_true
}

/// text・時刻の列は今までどおり(text は型を書かない、timestamptz は書く)。
pub fn paged_by_text_and_time_is_unchanged_test() {
  let #(_, files) = generated(notes, [])
  text_of(files, "src/gen/sql.mjs")
  |> string.contains("($2::timestamptz IS NULL OR (")
  |> should.be_true
  let #(_, files) = generated(notes, ordered_by("String"))
  let sql = text_of(files, "src/gen/sql.mjs")
  sql |> string.contains("($2 IS NULL OR (") |> should.be_true
}

// ── 2 静的資料(`src/external_hosts.mjs`・`docs/api-v1.md`)の無い app ───────────────────

@external(javascript, "./yumemi_s1_test_ffi.mjs", "remove")
fn remove(dir: String, file: String) -> Nil

fn generated_without(
  fixture: String,
  files: List(String),
) -> #(Int, List(#(String, String))) {
  let dir = copy_app(fixture)
  list.each(files, remove(dir, _))
  let assert Ok(#(made, notes)) = yumemi_gen.generate(dir)
  remove_app(dir)
  #(stop.worst(notes), list.map(made, fn(file) { #(file.path, file.text) }))
}

fn has(files: List(#(String, String)), path: String) -> Bool {
  list.any(files, fn(file) { file.0 == path })
}

/// 面を置いた app は 2 つの file が無いと exit 3(「静的資料が無い」)で止まっていた。無い file の写しだけを出さない。
pub fn static_materials_are_optional_test() {
  let #(code, files) =
    generated_without("gen/fixtures/article", [
      "src/external_hosts.mjs",
      "../docs/api-v1.md",
    ])
  { code < 3 } |> should.be_true
  has(files, "public/src/gen/external.gleam") |> should.be_false
  has(files, "public/src/gen/doc/api_v1.gleam") |> should.be_false
  has(files, "public/src/gen/route.gleam") |> should.be_true

  let #(code, files) =
    generated_without("gen/fixtures/article", ["../docs/api-v1.md"])
  { code < 3 } |> should.be_true
  has(files, "public/src/gen/external.gleam") |> should.be_true
  has(files, "public/src/gen/doc/api_v1.gleam") |> should.be_false

  let #(code, files) =
    generated_without("gen/fixtures/article", ["src/external_hosts.mjs"])
  { code < 3 } |> should.be_true
  has(files, "public/src/gen/external.gleam") |> should.be_false
  has(files, "public/src/gen/doc/api_v1.gleam") |> should.be_true
}

/// あっても形の違う `external_hosts.mjs` は今までどおり止める(読めない file を黙って落とさない)。
pub fn malformed_external_hosts_still_stops_test() {
  let dir = copy_app("gen/fixtures/article")
  edit(dir, "src/external_hosts.mjs", "EXTERNAL_HOSTS", "OTHER_HOSTS")
  |> should.be_true
  let result = yumemi_gen.generate(dir)
  remove_app(dir)
  case result {
    Ok(#(_, notes)) -> stop.worst(notes) |> should.equal(2)
    Error(note) -> note.class |> should.equal(stop.Syntax)
  }
}

fn style_unit(text: String) -> source.Unit {
  let assert Ok(module) = glance.module(text)
  source.Unit(path: "style", text: text, module: module)
}

/// `gen/doc/api_v1.gleam` は面の `style.body`・`ink`・`heading` を名指しする。3 つを持たない面には class を付けない形で出す
/// (持つ面は今までと同じ字)。
pub fn api_v1_names_the_face_style_only_when_it_has_them_test() {
  let present =
    static_source.Present(
      app_name: "app",
      hosts: None,
      api_v1: Some(static_source.ApiV1(
        text: "# API\n\n本文と `code`。\n",
        hash: "h",
      )),
    )
  let full =
    style_unit(
      "pub const body = 1\npub const ink = 2\npub fn heading() { 3 }\n",
    )
  let assert [with_style] = static_emit.emit_present("www", present, [full])
  with_style.path |> should.equal("www/src/gen/doc/api_v1.gleam")
  with_style.text
  |> should.equal(static_emit.api_v1_text("# API\n\n本文と `code`。\n", "h"))
  string.contains(with_style.text, "import style\n") |> should.be_true

  let partial = style_unit("pub const body = 1\nconst ink = 2\n")
  list.each([[partial], []], fn(units) {
    let assert [plain] = static_emit.emit_present("www", present, units)
    string.contains(plain.text, "style") |> should.be_false
    string.contains(plain.text, "css.class([])") |> should.be_true
  })
}

// ── 6 一意の制約の違反の log ─────────────────────────────────────────────

@external(javascript, "./yumemi_0131_test_ffi.mjs", "check")
fn check(which: String) -> String

/// 内部の失敗は全部 log 無しの 503 unavailable に畳まれていた。畳む前に SQLSTATE と制約・表の名を 1 行出す(応答は替えない)。
pub fn unavailable_logs_the_constraint_test() {
  let out = check("unavailable")
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  string.split(out, "\n") |> list.length |> should.equal(8)
}
