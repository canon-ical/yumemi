import entity/parent.{type Parent}
import framework/er.{type Held}
import framework/verbs
import gen/types/child_id.{type ChildId}
import gen/types/child_name.{type ChildName}
import gen/types/child_order.{type ChildOrder}

pub type Child {
  Child(id: ChildId, parent: Held(Parent), name: ChildName, order: ChildOrder)
}

pub fn key(it: Child) -> ChildId {
  it.id
}

pub const collection: String = "children"

pub const ordered_by: verbs.Order = verbs.Order(
  field: "order",
  within: ["parent"],
)
