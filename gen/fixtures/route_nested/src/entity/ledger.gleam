pub type Ledger {
  Ledger(id: String)
}

pub fn key(it: Ledger) -> String {
  it.id
}

pub const collection: String = "ledgers"
