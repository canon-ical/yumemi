// 同じ phase 名の edge を持つ Entity 1。
pub type Fan {
  Fan(id: String, name: String)
}

pub type Phase {
  Onboarded
  Retiring
}

pub const edges: List(#(Phase, Phase)) = [#(Onboarded, Retiring)]

pub fn key(it: Fan) -> String {
  it.id
}

pub const collection: String = "fans"
