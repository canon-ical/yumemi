pub type Roster {
  Roster(id: String)
}

pub fn key(it: Roster) -> String {
  it.id
}

pub const collection: String = "rosters"
