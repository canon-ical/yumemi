//// GENERATED from allow.note [sha256:31887c2b467d] — 手で編集しない

import yumemi/party.{type PartyId}

pub type Who {
  Anyone
}

pub type At {
  AnyPhase
}

pub type Owner {
  NoOwner
}

pub type Clause {
  Clause(who: Who, at: At, owner: Owner)
}

pub type PartyActor {
  PartyActor(party: PartyId)
}

pub type SystemActor {
  SystemActor
}

pub type Actor {
  AnyActor
}

pub type AnyActor =
  Actor
