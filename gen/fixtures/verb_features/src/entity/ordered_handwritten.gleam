import entity/owner.{type Owner}
import framework/er.{type Held}
import framework/verbs
import gen/types/ordered_handwritten_id.{type OrderedHandwrittenId}
import gen/types/position.{type Position}

pub type OrderedHandwritten {
  OrderedHandwritten(
    id: OrderedHandwrittenId,
    owner: Held(Owner),
    position: Position,
  )
}

pub fn key(it: OrderedHandwritten) -> OrderedHandwrittenId {
  it.id
}

pub const collection: String = "ordered_handwrittens"

pub const handwritten_verbs: List(String) = ["create_ordered_handwritten"]

pub const ordered_by: verbs.Order = verbs.Order(
  field: "position",
  within: ["owner"],
)
