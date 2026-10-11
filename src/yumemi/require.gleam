//// Requirements are evaluated after argument decoding.

pub type Requirement(args) {
  Adult
  Use
  Handling
  Identity(from: fn(args) -> String)
}
