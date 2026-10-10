//// 0.11.15:CSP を持つ頁も client の遷移に入れ(今の document の CSP と同じ行き先だけ)、head の同じ要素を残して
//// 差分だけ足し引きし、来た stylesheet を読み終えてから body を替える(navigate.mjs)。

import gleam/list
import gleam/string
import gleeunit/should

@external(javascript, "./yumemi_01115_test_ffi.mjs", "navigation_csp")
fn navigation_csp() -> String

@external(javascript, "./yumemi_01115_test_ffi.mjs", "navigation_stage")
fn navigation_stage() -> String

/// route 表の CSP の一致・不一致、応答の header の食い違い。
pub fn navigation_follows_page_csp_test() {
  let out = navigation_csp()
  string.contains(out, "NG ") |> should.be_false
  string.split(out, "\n") |> list.length |> should.equal(18)
}

/// head の差分の足し引き、body の側の stylesheet の待ち、取り消し、上限。
pub fn navigation_stage_keeps_head_and_waits_for_stylesheets_test() {
  let out = navigation_stage()
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  string.split(out, "\n") |> list.length |> should.equal(25)
}
