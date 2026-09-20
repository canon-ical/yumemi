//// 20 の写しではない ── 生成器の fixture として gen-3b で置いた(P0-3 / P0-5 の検算)。

// ★ src/types.gleam ── 矢印 3 形(必須 / 任意 / 複数)と、値域つき順序列の最小の ★。
import framework/spec.{type Spec, Range, Text, Uuid}

pub const album_id: Spec = Uuid

pub const album_title: Spec = Text(min: 1, max: 60)

pub const shelf_id: Spec = Uuid

pub const shelf_name: Spec = Text(min: 1, max: 40)

pub const label_id: Spec = Uuid

pub const label_name: Spec = Text(min: 1, max: 20)

pub const photo_id: Spec = Uuid

pub const photo_caption: Spec = Text(min: 0, max: 80)

/// 順序列の値域。小さい値域で「空きが足りないとき」も当てる。
pub const photo_order: Spec = Range(min: 1, max: 10)
