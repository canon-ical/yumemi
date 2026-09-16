// ★ src/types.gleam ── Type の正本。制約は Property でなく Type が持つ(手順1)。
////                     ここに書くのは仕様だけ。型の値・検証・復号は生成物。
import framework/spec.{type Spec, Markdown, Pattern, Text}

pub const slug: Spec = Pattern(min: 1, max: 64, regex: "^[a-z0-9]+(-[a-z0-9]+)*$")
pub const title: Spec = Text(min: 1, max: 120)
pub const body: Spec = Markdown
pub const category_name: Spec = Text(min: 1, max: 40)
pub const tag_name: Spec = Text(min: 1, max: 20)
