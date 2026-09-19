// ★ src/types.gleam ── no-key Entity を読むための最小の ★。
import framework/spec.{type Spec, Text}

pub const no_key_name: Spec = Text(min: 1, max: 60)
