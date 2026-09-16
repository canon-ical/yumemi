//// 入力ハッシュ。20 の規約① 「全ファイル先頭に `GENERATED from <入力>` と入力ハッシュを置く」。
//// **どの入力がその束を決めるかを束ごとに固定する** ── `app gen --check` が「入力が変われば
//// ハッシュが変わる / 変わらなければ変わらない」で判定できるようにするため。
////
//// | 束 | 入力 |
//// |---|---|
//// | 1 `src/gen/types/*` | `src/types.gleam` |
//// | 2 `src/gen/query*` | `src/entity/*.gleam` 全部 |
//// | 3 `src/gen/reads/<svc>` | その Service + `src/types.gleam` + `src/entity/*.gleam` 全部 |
//// | 4 `gen/sql/queries/<svc>/*` | 束3 と同じ |

import gleam/list
import gleam/string
import yumemi_gen/digest
import yumemi_gen/source.{type Unit}

pub type Hashes {
  Hashes(
    types: String,
    entities: String,
    /// Service module 名 -> ハッシュ
    services: List(#(String, String)),
  )
}

pub fn of(units: List(Unit)) -> Hashes {
  let type_units = list.filter(units, fn(unit) { unit.path == "types" })
  let entity_units =
    list.filter(units, fn(unit) { string.starts_with(unit.path, "entity/") })
  let base = list.append(type_units, entity_units)
  Hashes(
    types: over(type_units),
    entities: over(entity_units),
    services: units
      |> list.filter(fn(unit) { string.starts_with(unit.path, "service/") })
      |> list.map(fn(unit) { #(last_segment(unit.path), over([unit, ..base])) }),
  )
}

/// Service 1つを決める入力のハッシュ。無い Service は Entity の分で代用する。
pub fn service(hashes: Hashes, module: String) -> String {
  case list.key_find(hashes.services, module) {
    Ok(value) -> value
    Error(_) -> hashes.entities
  }
}

fn over(units: List(Unit)) -> String {
  units
  |> list.sort(fn(left, right) { string.compare(left.path, right.path) })
  |> list.map(fn(unit) { unit.path <> "\n" <> unit.text })
  |> string.join("\n")
  |> digest.short
}

fn last_segment(path: String) -> String {
  case list.last(string.split(path, "/")) {
    Ok(segment) -> segment
    Error(_) -> path
  }
}
