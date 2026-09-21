import framework/spec.{type Spec, Range, Text, Uuid}

pub const parent_id: Spec = Uuid

pub const child_id: Spec = Uuid

pub const child_name: Spec = Text(min: 1, max: 40)

pub const child_order: Spec = Range(min: -5, max: 10)
