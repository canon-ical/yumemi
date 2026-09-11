//// An IdP-issued identifier, not an application Entity or foreign key.

pub opaque type PartyId {
  PartyId(value: String)
}

pub fn parse(raw: String) -> Result(PartyId, Nil) {
  case raw {
    "" -> Error(Nil)
    _ -> Ok(PartyId(raw))
  }
}

pub fn to_string(value: PartyId) -> String {
  value.value
}
