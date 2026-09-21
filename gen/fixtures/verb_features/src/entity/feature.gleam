import entity/owner.{type Owner}
import entity/space.{type Space}
import framework/er.{type Held}
import framework/verbs
import gen/types/feature_id.{type FeatureId}
import gen/types/position.{type Position}
import gen/types/title.{type Title}
import gleam/option.{type Option}

pub type Feature {
  Feature(
    id: FeatureId,
    owner: Held(Owner),
    space: Option(Held(Space)),
    position: Position,
    title: Title,
  )
}

pub type Phase {
  Draft
  Published
}

pub const edges: List(#(Phase, Phase)) = [#(Draft, Published)]

pub fn key(it: Feature) -> FeatureId {
  it.id
}

pub const collection: String = "features"

pub const verbs: List(verbs.Rule(Phase)) = [
  verbs.Update(name: "rename", fields: ["title"], at: verbs.Only([Draft])),
  verbs.Advance(bump: verbs.Always),
]

pub const ordered_by: verbs.Order = verbs.Order(
  field: "position",
  within: ["owner", "space"],
)
