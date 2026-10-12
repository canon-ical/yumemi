//// yumemi-idem(0.13)── 再投稿で書きが二重にならない冪等キー(`Idempotency-Key`、`framework.idempotency`)。
//// 生成器は既定の SQL 4 本・表の DDL・cron の消しを足し、runtime は書きの transaction の先頭に記録を入れる。
//// ★ の書き方は変えない。題材は `gen/fixtures/notes`。

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

@external(javascript, "./yumemi_idem_test_ffi.mjs", "write")
fn write(dir: String, path: String, text: String) -> Nil

@external(javascript, "./yumemi_idem_test_ffi.mjs", "idem_check")
fn idem_check(which: String) -> String

fn generated(
  extra: List(#(String, String)),
) -> #(Int, List(#(String, String))) {
  let dir = copy_app(fixture)
  list.each(extra, fn(item) { write(dir, item.0, item.1) })
  let result = yumemi_gen.generate(dir)
  remove_app(dir)
  case result {
    Ok(#(files, notes)) -> #(
      stop.worst(notes),
      list.map(files, fn(file) { #(file.path, file.text) }),
    )
    Error(note) -> #(stop.code(note.class), [])
  }
}

fn text_of(files: List(#(String, String)), path: String) -> String {
  let assert Ok(#(_, text)) = list.find(files, fn(file) { file.0 == path })
  text
}

fn all_ok(out: String, count: Int) -> Nil {
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  string.split(out, "\n") |> list.length |> should.equal(count)
}

/// `sql.mjs` に既定の 4 本、`db/framework/idempotency.sql` に (party, key) の一意の制約、shell の scheduled に消し。
pub fn generator_adds_the_idempotency_sql_ddl_and_purge_test() {
  let #(code, files) = generated([])
  code |> should.equal(0)
  let sql = text_of(files, "src/gen/sql.mjs")
  list.each(
    [
      "\"framework/idempotency_find\": \"-- GENERATED from framework.idempotency_find — 手で編集しない\\nSELECT request_hash,result FROM framework.idempotency WHERE party=$1 AND key=$2;\\n\"",
      "\"framework/idempotency_record\": \"-- GENERATED from framework.idempotency_record — 手で編集しない\\nINSERT INTO framework.idempotency(party,key,request_hash,result,created_at) VALUES($1,$2,$3,$4::jsonb,$5::timestamptz);\\n\"",
      "\"framework/idempotency_repair\":",
      "\"framework/idempotency_sweep\": \"-- GENERATED from framework.idempotency_sweep — 手で編集しない\\nDELETE FROM framework.idempotency WHERE created_at<$1::timestamptz;\\n\"",
    ],
    fn(needle) { string.contains(sql, needle) |> should.be_true },
  )
  let ddl = text_of(files, "db/framework/idempotency.sql")
  string.contains(ddl, " [sha256:") |> should.be_true
  string.contains(ddl, "CREATE TABLE IF NOT EXISTS framework.idempotency (")
  |> should.be_true
  string.contains(ddl, "CONSTRAINT idempotency_pkey PRIMARY KEY (party, key)")
  |> should.be_true
  string.contains(ddl, "result jsonb NOT NULL") |> should.be_true
  let shell = text_of(files, "src/gen/shell.mjs")
  string.contains(
    shell,
    "import { purgeIdempotency } from '../../yumemi/yumemi/server/cron.mjs';",
  )
  |> should.be_true
  string.contains(
    shell,
    "  execution.waitUntil(purgeIdempotency({db,env,run}));\n",
  )
  |> should.be_true
}

/// app の ★(`db/queries/framework/idempotency_sweep.sql`)が既定に勝つ ── 保持の文を app が替えられる。
pub fn app_sql_wins_over_the_default_test() {
  let mine =
    "DELETE FROM framework.idempotency WHERE created_at<$1::timestamptz - interval '1 day';\n"
  let #(code, files) =
    generated([#("db/queries/framework/idempotency_sweep.sql", mine)])
  code |> should.equal(0)
  let sql = text_of(files, "src/gen/sql.mjs")
  string.contains(sql, "interval '1 day'") |> should.be_true
  string.contains(sql, "GENERATED from framework.idempotency_sweep")
  |> should.be_false
}

/// 入口と runtime(偽の取引の DB):同じキー・同じ本文は 1 行で同じ応答、違う本文は 409、キー無しは今のまま、
/// commit の後に応答を捨てた再投稿は 1 件、並んだ 2 本は一意の制約で 1 本、party で引く、断りも記録、order は後で直す、
/// ★ の db_error が走らせ直した書きも記録する。
pub fn server_replays_and_conflicts_test() {
  idem_check("server") |> all_ok(28)
}

/// client:書きの送りにキー、503・網の失敗はキーと入力を保って失敗の After に移らない、答えが出たら捨てる。
pub fn client_keeps_the_key_until_settled_test() {
  idem_check("client") |> all_ok(10)
}

/// cron:保持期間(既定 24 時間、env `IDEMPOTENCY_RETENTION_HOURS`)を過ぎた行を消す。
pub fn purge_window_test() {
  idem_check("purge") |> all_ok(3)
}
