//// Provider-independent vector value. Connector decoding validates dimensions.

pub opaque type Embedding {
  Embedding(value: List(Float))
}

pub fn parse(values: List(Float)) -> Result(Embedding, Nil) {
  case values {
    [] -> Error(Nil)
    _ -> Ok(Embedding(values))
  }
}

pub fn to_list(value: Embedding) -> List(Float) {
  value.value
}
