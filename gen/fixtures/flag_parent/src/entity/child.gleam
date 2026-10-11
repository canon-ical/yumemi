import entity/parent.{type Parent}
import yumemi/er.{type Held}
import yumemi/verbs

pub type Child {
  Child(id: String, parent: Held(Parent), value: String)
}

pub fn key(it: Child) -> String {
  it.id
}

pub const verbs: List(verbs.Rule(Nil)) = [
  verbs.DeleteWhere(field: "parent"),
]
