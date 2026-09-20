import framework/spec.{type Spec, Text}

pub const parent_a: Spec = Text(min: 1, max: 20)

pub const parent_b: Spec = Text(min: 1, max: 20)

pub const child_id: Spec = Text(min: 1, max: 20)
