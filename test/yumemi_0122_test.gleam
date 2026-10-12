//// yumemi-0122(0.12.2)── musearch の形でない最小の app が、生成→起動→一覧まで通らない 4 つの穴。★ の書き方は変えない。
//// 1 入口の host を入口の名で引く、2 `gen/verb.gleam` の FFI を生成物へ向ける、3 queue の kind・subject の Entity が
//// 無い app の import が解ける、4 `Paged(size: Param(..))` の頁を要求ごとの size で切る。
//// 題材は `gen/fixtures/notes`(Host `ApiHost` と入口 `api`、queue・subject なし、手書きの橋なし)。

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

@external(javascript, "./yumemi_0122_test_ffi.mjs", "runtime_check")
fn runtime_check(which: String) -> String

@external(javascript, "./yumemi_0122_test_ffi.mjs", "unresolved_imports")
fn unresolved_imports(
  dir: String,
  paths: List(String),
  texts: List(String),
) -> String

/// fixture の写しを `edits` で替えて生成し、(停止コード, 書いた file, 行き先の無い import)。
fn generated(
  edits: List(#(String, String, String)),
) -> #(Int, List(#(String, String)), String) {
  let dir = copy_app(fixture)
  list.each(edits, fn(item) {
    let #(path, from, to) = item
    edit(dir, path, from, to) |> should.be_true
  })
  let assert Ok(#(files, notes)) = yumemi_gen.generate(dir)
  let pairs = list.map(files, fn(file) { #(file.path, file.text) })
  let missing =
    unresolved_imports(
      dir,
      list.map(pairs, fn(pair) { pair.0 }),
      list.map(pairs, fn(pair) { pair.1 }),
    )
  remove_app(dir)
  #(stop.worst(notes), pairs, missing)
}

fn text_of(files: List(#(String, String)), path: String) -> String {
  let assert Ok(#(_, text)) = list.find(files, fn(file) { file.0 == path })
  text
}

fn has(files: List(#(String, String)), path: String) -> Bool {
  list.any(files, fn(file) { file.0 == path })
}

fn ok_lines(out: String, count: Int) -> Nil {
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  string.split(out, "\n") |> list.length |> should.equal(count)
}

// ── 1 入口の host ────────────────────────────────────────────────────────

/// 生成の `hosts` は入口の名 -> `<NAME>_HOST`。runtime はこの表を入口の名で引く。
/// Host の variant の名(`ApiHost` -> `api_host`)で引くと、入口 `api` の app は全要求が 404 だった。
/// variant を 1 つも持たない入口(`hosts: []`)は今までどおりどの host にも出ない。
pub fn entrance_host_follows_the_entry_name_test() {
  let #(code, files, _) = generated([])
  code |> should.equal(0)
  text_of(files, "src/gen/http_runtime.mjs")
  |> string.contains("const hosts={api:'API_HOST'};")
  |> should.be_true
  runtime_check("host") |> ok_lines(6)
}

// ── 2・3 生成物の import が解ける ─────────────────────────────────────────

/// `src/gen/verb.gleam` の `stage` は生成の `src/gen/operations_ffi.mjs` から取る。
/// `../operations_ffi.mjs`(src 直下の手書きの橋)を指していて、橋の無い app は bundle が止まった。
pub fn verb_stage_comes_from_the_generated_ffi_test() {
  let #(_, files, _) = generated([])
  let verb = text_of(files, "src/gen/verb.gleam")
  string.contains(
    verb,
    "@external(javascript, \"./operations_ffi.mjs\", \"stage\")",
  )
  |> should.be_true
  string.contains(verb, "../operations_ffi.mjs") |> should.be_false
  text_of(files, "src/gen/operations_ffi.mjs")
  |> string.contains("export { stage,")
  |> should.be_true
}

/// queue の kind が無い app にも `src/gen/queue_runtime.mjs`(shell が `sweep` / `consume` を import する)。
/// kind が無いので sweep は何も送らない。
pub fn no_queue_kind_still_writes_the_queue_runtime_test() {
  let #(_, files, _) = generated([])
  text_of(files, "src/gen/shell.mjs")
  |> string.contains("import { sweep,consume } from './queue_runtime.mjs';")
  |> should.be_true
  let queue = text_of(files, "src/gen/queue_runtime.mjs")
  string.contains(queue, "export const registeredKinds=[];") |> should.be_true
  string.contains(queue, "export const sweep=") |> should.be_true
  string.contains(queue, "export const consume=") |> should.be_true
  // outbox の SQL も runtime も読まない(kind の無い app に framework の outbox の表を求めない)
  string.contains(queue, "outbox.mjs") |> should.be_false
  string.contains(queue, "import") |> should.be_false
}

/// subject の Entity が無い app の `runtime.mjs` は `./subject.mjs` を import しない(`gen/subject.gleam` が無い)。
/// subject の Entity があれば今までどおり import し、`gen/subject.gleam` も吐く。
pub fn subject_import_follows_the_subject_file_test() {
  let #(_, files, _) = generated([])
  has(files, "src/gen/subject.gleam") |> should.be_false
  text_of(files, "src/gen/runtime.mjs")
  |> string.contains("subject.mjs")
  |> should.be_false
  let #(_, files, missing) =
    generated([
      #(
        "src/entity/note.gleam",
        "pub const collection",
        "pub const subject = True\n\npub const collection",
      ),
    ])
  has(files, "src/gen/subject.gleam") |> should.be_true
  text_of(files, "src/gen/runtime.mjs")
  |> string.contains("import * as subject from './subject.mjs';\n")
  |> should.be_true
  missing |> should.equal("")
}

/// 生成物の相対の import と `@external` の行き先が、生成物か app の ★ に全部ある(手書きの橋の無い app)。
pub fn every_generated_import_resolves_test() {
  let #(code, _, missing) = generated([])
  code |> should.equal(0)
  missing |> should.equal("")
}

// ── 4 Paged(size: Param(..)) ────────────────────────────────────────────

/// size が穴の頁は keyset に穴の位置(`sizeArg`、args の番号)を添え、runtime は SQL の `LIMIT $n + 1` に
/// 渡したのと同じ値で切る。固定の 20 で切っていたので、limit≠20 で limit+1 件返り next が null だった。
pub fn page_size_hole_cuts_the_page_test() {
  let #(_, files, _) = generated([])
  let runtime = text_of(files, "src/gen/runtime.mjs")
  string.contains(
    runtime,
    "'note_list/items':{key:'note_list/items',args:[['enc'],['cursor']],allow:[],out:['page',['entity','note']],keyset:{size:20,sizeArg:0,",
  )
  |> should.be_true
  text_of(files, "src/gen/sql.mjs")
  |> string.contains("LIMIT $1 + 1;")
  |> should.be_true
  runtime_check("page") |> ok_lines(10)
}

/// size が定数の頁(`Paged(size: Num(5), ..)`)は今までどおり:keyset の size で切り、`sizeArg` は無い。
pub fn constant_page_size_is_unchanged_test() {
  let #(code, files, _) =
    generated([
      #("src/service/note_list.gleam", "size: q.Param(Limit)", "size: q.Num(5)"),
    ])
  code |> should.equal(0)
  let runtime = text_of(files, "src/gen/runtime.mjs")
  string.contains(runtime, "keyset:{size:5,uniform:true,") |> should.be_true
  string.contains(runtime, "sizeArg") |> should.be_false
  text_of(files, "src/gen/sql.mjs")
  |> string.contains("LIMIT 6;")
  |> should.be_true
}
