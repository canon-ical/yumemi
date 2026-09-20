//// Interpreter capabilities supplied by the generated runtime or a test.

import gleam/list
import gleam/option.{type Option, None, Some}

pub type Context

pub type Promise(value)

@external(javascript, "./io_ffi.mjs", "resolve")
pub fn resolve(value: value) -> Promise(value)

@external(javascript, "./io_ffi.mjs", "then")
pub fn then(value: Promise(a), next: fn(a) -> Promise(b)) -> Promise(b)

@external(javascript, "./io_ffi.mjs", "commit")
pub fn commit(context: Context, carry: carry) -> Promise(Bool)

@external(javascript, "./io_ffi.mjs", "finish")
pub fn finish(context: Context) -> Promise(Nil)

@external(javascript, "./io_ffi.mjs", "reject")
pub fn reject(
  context: Context,
  stage: fn(Context) -> Promise(value),
) -> Promise(Nil)

/// 宣言された矢印 1 本。生成器が ★ から写して `gen/reads/<service>.gleam` に置く。
/// 実行側はここに書かれた名前だけで関係先を引く ── 名前を推測しない。
pub type Relation {
  Relation(
    /// Service module。"article_read"
    service: String,
    /// 生成 SQL の名。"to_muse"(`gen/sql/queries/<service>/<query>.sql`)
    query: String,
    /// 矢印の名。"ArticleToMuse"
    arrow: String,
    /// root Entity の module。"article"
    from: String,
    /// 関係 Property の名。"muse"
    prop: String,
    /// 関係先 Entity の module。"muse"
    target: String,
  )
}

/// Context の契約 ── `context.relation(relation, keys)` が、鍵の列と同じ長さ・同じ順で
/// 復号済みの関係先を返す。無い鍵は欠けさせず、実行側が失敗させる。
@external(javascript, "./io_ffi.mjs", "relation")
fn relation_rows(
  context: Context,
  relation: Relation,
  keys: List(String),
) -> Promise(List(value))

/// 必須の関係(Has / Held)。関係先が無いのは FK の破れなので、契約違反として落とす。
pub fn relation_one(
  context: Context,
  relation: Relation,
  key: String,
) -> Promise(value) {
  use rows <- then(relation_rows(context, relation, [key]))
  case rows {
    [one] -> resolve(one)
    _ -> relation_broken(relation, [key], list.length(rows))
  }
}

/// 任意の関係(Link / Option(Has) / Option(Held))。鍵が無ければ読まずに None。
pub fn relation_option(
  context: Context,
  relation: Relation,
  key: Option(String),
) -> Promise(Option(value)) {
  case key {
    None -> resolve(None)
    Some(key) -> {
      use rows <- then(relation_rows(context, relation, [key]))
      case rows {
        [one] -> resolve(Some(one))
        _ -> relation_broken(relation, [key], list.length(rows))
      }
    }
  }
}

/// 複数の関係(Multi)。鍵の順で返す。鍵が空なら読まずに空。
pub fn relation_many(
  context: Context,
  relation: Relation,
  keys: List(String),
) -> Promise(List(value)) {
  case keys {
    [] -> resolve([])
    _ -> {
      use rows <- then(relation_rows(context, relation, keys))
      case list.length(rows) == list.length(keys) {
        True -> resolve(rows)
        False -> relation_broken(relation, keys, list.length(rows))
      }
    }
  }
}

@external(javascript, "./io_ffi.mjs", "relationBroken")
fn relation_broken(
  relation: Relation,
  keys: List(String),
  found: Int,
) -> Promise(value)
