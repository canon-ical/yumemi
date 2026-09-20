import gen/types/parent_a.{type ParentA}
import gen/types/parent_b.{type ParentB}

pub type Parent {
  Parent(a: ParentA, b: ParentB)
}

pub fn key(it: Parent) -> #(ParentA, ParentB) {
  #(it.a, it.b)
}

pub const collection: String = "parents"
