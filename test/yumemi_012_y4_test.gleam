//// 0.12(Y4):Page 間の client 遷移を Navigation API に寄せる。click の横取り・履歴・scroll・focus・中断・# は
//// navigate イベントと `intercept()` に任せ、Navigation API の無い browser では何も取らない(頁の読み込み)。
//// 書いた後の取り直しは印を付けた `navigation.reload()` を取る(navigate.mjs)。

import gleam/list
import gleam/string
import gleeunit/should

@external(javascript, "./yumemi_012_y4_test_ffi.mjs", "navigation_start")
fn navigation_start() -> String

/// 取る navigate・ブラウザに任せる navigate・取れない応答の落とし方・取り直しの道・Navigation API の無い browser。
pub fn navigation_goes_through_navigation_api_test() {
  let out = navigation_start()
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  // 0.12 段 C:止まった取りの 2 通り(開き直す・新しい遷移に任せる)で 1 件増えて 19
  string.split(out, "\n") |> list.length |> should.equal(19)
}
