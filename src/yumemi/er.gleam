//// Relations expose keys; only the storage decoder supplies row proofs.

import gleam/list
import gleam/option.{type Option}

pub opaque type Key(entity) {
  Key(value: String)
}

pub opaque type Has(entity) {
  Has(key: Key(entity))
}

pub opaque type Held(entity) {
  Held(key: Key(entity))
}

pub type Link(entity) =
  Option(Key(entity))

/// 多対多(中間表)。値は相手の鍵の列だけ ── 相手の中身は矢印の read で取る(20-er)。
pub opaque type Multi(entity) {
  Multi(keys: List(Key(entity)))
}

pub fn key(raw: String) -> Key(entity) {
  Key(raw)
}

pub fn of(relation: Has(entity)) -> Key(entity) {
  relation.key
}

pub fn of_held(relation: Held(entity)) -> Key(entity) {
  relation.key
}

pub fn of_multi(relation: Multi(entity)) -> List(Key(entity)) {
  relation.keys
}

pub fn to_string(key: Key(entity)) -> String {
  key.value
}

pub type Row

@external(javascript, "./er_ffi.mjs", "rowKey")
fn row_key(row: Row) -> String

pub fn from_row(row: Row) -> Has(entity) {
  Has(Key(row_key(row)))
}

pub fn held_from_row(row: Row) -> Held(entity) {
  Held(Key(row_key(row)))
}

pub fn multi_from_rows(rows: List(Row)) -> Multi(entity) {
  Multi(list.map(rows, fn(row) { Key(row_key(row)) }))
}
