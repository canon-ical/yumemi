//// yumemi-s-2(0.11.6)── outbox へ行を書いた要求は status によらず sweep する、重なった sweep は同じ行を 1 回だけ送る。

import gleam/list
import gleam/string
import gleeunit/should
import yumemi_gen

// ── fetch の口 ───────────────────────────────────────────────────────────────

@external(javascript, "./yumemi_s2_test_ffi.mjs", "fetch_sweeps")
fn fetch_sweeps() -> String

/// 手書きの SQL・生成の書きで outbox に積んだ要求は 200 / 500 / 投げても 1 回 sweep、GET・rollback・失敗した文は 0 回、
/// 202 は今のまま。
pub fn fetch_sweeps_when_outbox_is_written_test() {
  let out = fetch_sweeps()
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  string.split(out, "\n") |> list.length |> should.equal(9)
}

// ── sweep ────────────────────────────────────────────────────────────────────

@external(javascript, "./yumemi_s2_test_ffi.mjs", "concurrent_sweeps")
fn concurrent_sweeps() -> String

/// 重なった sweep は `framework/outbox_claim` で取れた行だけを送る。claim の無い 0.11.5 の形は同じ偽の DB で 2 回送る。
pub fn overlapping_sweeps_send_each_row_once_test() {
  let out = concurrent_sweeps()
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  string.split(out, "\n") |> list.length |> should.equal(7)
}

// ── 生成:claim の 1 文 ─────────────────────────────────────────────────────

@external(javascript, "./yumemi_s1_test_ffi.mjs", "copy_app")
fn copy_app(from: String) -> String

@external(javascript, "./yumemi_s1_test_ffi.mjs", "remove_app")
fn remove_app(dir: String) -> Nil

@external(javascript, "./yumemi_s2_test_ffi.mjs", "write")
fn write(dir: String, path: String, text: String) -> Nil

fn sql_of(dir: String) -> String {
  let assert Ok(#(files, _)) = yumemi_gen.generate(dir)
  let assert Ok(file) =
    list.find(files, fn(file) { file.path == "src/gen/sql.mjs" })
  file.text
}

/// app に `framework/outbox_claim` が無ければ生成の既定の 1 文を束ね、app の ★ があればそれが勝つ。
pub fn outbox_claim_default_and_app_override_test() {
  let dir = copy_app("fixtures/article")
  let default = sql_of(dir)
  write(
    dir,
    "db/queries/framework/outbox_claim.sql",
    "UPDATE framework.outbox SET sent_at=now() WHERE id=$1 AND sent_at IS NULL RETURNING id;\n",
  )
  let starred = sql_of(dir)
  remove_app(dir)
  string.contains(
    default,
    "\"framework/outbox_claim\": \"-- GENERATED from framework.outbox_claim — 手で編集しない\\nUPDATE framework.outbox SET sent_at=now() WHERE id=$1 AND done_at IS NULL\\nAND (sent_at IS NULL OR sent_at<now()-interval '1 hour') RETURNING id;\\n\"",
  )
  |> should.be_true
  string.contains(
    starred,
    "\"framework/outbox_claim\": \"UPDATE framework.outbox SET sent_at=now() WHERE id=$1 AND sent_at IS NULL RETURNING id;\\n\"",
  )
  |> should.be_true
  string.contains(starred, "GENERATED from framework.outbox_claim")
  |> should.be_false
}
