import gen/types/handwritten_id.{type HandwrittenId}

pub type Handwritten {
  Handwritten(id: HandwrittenId, value: String)
}

pub fn key(it: Handwritten) -> HandwrittenId {
  it.id
}

pub const collection: String = "handwrittens"

pub const handwritten_verbs: List(String) = [
  "create_handwritten",
  "unknown_handwritten",
]

