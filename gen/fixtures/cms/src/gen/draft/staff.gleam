//// GENERATED from entity.staff [sha256:1def2fe2f49f] — 手で編集しない

import yumemi/idp.{type Email, type Name}
import yumemi/party.{type PartyId}

pub type StaffDraft {
  StaffDraft(party: PartyId, name: Name, email: Email)
}

pub type StaffCreated {
  StaffCreated(party: PartyId, name: Name, email: Email)
}
