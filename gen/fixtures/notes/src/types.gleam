// ★ src/types.gleam ── Type の正本。
import yumemi/spec.{type Spec, Text, Uuid}

pub const note_id: Spec = Uuid

pub const note_title: Spec = Text(min: 1, max: 80)

pub const note_body: Spec = Text(min: 1, max: 2000)
