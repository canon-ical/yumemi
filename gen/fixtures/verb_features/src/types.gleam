import framework/spec.{type Spec, Range, Text, Uuid}

pub const feature_id: Spec = Uuid
pub const owner_id: Spec = Uuid
pub const space_id: Spec = Uuid
pub const position: Spec = Range(min: 0, max: 100)
pub const title: Spec = Text(min: 1, max: 80)
pub const handwritten_id: Spec = Uuid
pub const sealed_record_id: Spec = Uuid

