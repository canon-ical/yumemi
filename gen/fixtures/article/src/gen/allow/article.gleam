//// GENERATED from allow.article [sha256:99fed65d7484] — 手で編集しない

import entity/article
import entity/staff
import yumemi/party.{type PartyId}

pub type Who {
  Anyone
  Staff
}

pub type At {
  AnyPhase
  Only(List(article.Phase))
}

pub type Owner {
  NoOwner
}

pub type Clause {
  Clause(who: Who, at: At, owner: Owner)
}

pub const staff: Clause = Clause(who: Staff, at: AnyPhase, owner: NoOwner)

pub type PartyActor {
  PartyActor(party: PartyId)
}

pub type SystemActor {
  SystemActor
}

pub type Actor {
  StaffActor(staff.Staff)
  AnyActor
}

pub type AnyActor =
  Actor
