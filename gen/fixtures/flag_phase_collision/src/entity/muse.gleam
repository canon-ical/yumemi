// 同じ phase 名の edge を持つ Entity 2。
pub type Muse {
  Muse(id: String, name: String)
}

pub type Phase {
  Onboarded
  Retiring
}

pub const edges: List(#(Phase, Phase)) = [#(Onboarded, Retiring)]

pub fn key(it: Muse) -> String {
  it.id
}

pub const collection: String = "muses"
