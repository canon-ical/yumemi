//// Relations expose keys; only the storage decoder supplies row proofs.
import gleam/option.{type Option}
pub opaque type Key(entity) { Key(value: String) }
pub opaque type Has(entity) { Has(key: Key(entity)) }
pub opaque type Held(entity) { Held(key: Key(entity)) }
pub type Link(entity) = Option(Key(entity))
pub fn key(raw: String) -> Key(entity) { Key(raw) }
pub fn of(relation: Has(entity)) -> Key(entity) { relation.key }
pub fn of_held(relation: Held(entity)) -> Key(entity) { relation.key }
pub fn to_string(key: Key(entity)) -> String { key.value }
pub type Row
@external(javascript, "./er_ffi.mjs", "rowKey")
fn row_key(row: Row) -> String
pub fn from_row(row: Row) -> Has(entity) { Has(Key(row_key(row))) }
pub fn held_from_row(row: Row) -> Held(entity) { Held(Key(row_key(row))) }
