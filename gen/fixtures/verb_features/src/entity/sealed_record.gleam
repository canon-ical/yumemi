import framework/sealed.{type Sealed, type StaffKey}
import gen/types/sealed_record_id.{type SealedRecordId}

pub type SealedRecord {
  SealedRecord(
    id: SealedRecordId,
    body: Sealed(String, StaffKey),
    label: String,
  )
}

pub fn key(it: SealedRecord) -> SealedRecordId {
  it.id
}

pub const collection: String = "sealed_records"

