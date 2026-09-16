// ★ src/types.gleam ── 旗の列と「穴が NULL」を当てるための最小の ★。
//// 20 の写しではない ── 生成器の fixture として本便(gen-2)で置いた。
import framework/spec.{type Spec, Range, Text, Uuid}

pub const widget_id: Spec = Uuid
pub const widget_name: Spec = Text(min: 1, max: 60)
pub const widget_place: Spec = Range(min: 1, max: 9)
