import framework/verbs

pub type Bulk {
  Bulk(id: String)
}

pub type Phase {
  Pending
  Done
}

pub const edges: List(#(Phase, Phase)) = [#(Pending, Done)]

pub fn key(it: Bulk) -> String {
  it.id
}

pub const verbs: List(verbs.Rule(Phase)) = [verbs.AdvanceAll]
