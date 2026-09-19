// ★ src/entity/no_key.gleam ── key の無い Entity。
pub type NoKey {
  NoKey(name: String, value: Int)
}

pub type Phase {
  Draft
  Published
}

pub const edges: List(#(Phase, Phase)) = [#(Draft, Published)]

pub const collection: String = "no_keys"
