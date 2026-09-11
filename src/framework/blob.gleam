//// Opaque storage reference. Existence is checked by the storage boundary.
pub opaque type Blob { Blob(key: String) }
pub fn parse(raw: String) -> Result(Blob, Nil) {
  case raw { "" -> Error(Nil) _ -> Ok(Blob(raw)) }
}
pub fn to_string(value: Blob) -> String { value.key }
