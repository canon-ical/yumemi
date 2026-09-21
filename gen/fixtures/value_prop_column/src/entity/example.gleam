import framework/party.{type PartyId}
import gen/types/title.{type Title}
import ledger_store.{type LedgerStoreId}

pub type Example {
  Example(ledger_store: LedgerStoreId, party: PartyId, title: Title)
}
