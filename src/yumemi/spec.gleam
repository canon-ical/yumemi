//// Declarative value constraints. Values are wrapped by generated types.

pub type Spec {
  Uuid
  Pattern(min: Int, max: Int, regex: String)
  Text(min: Int, max: Int)
  Markdown
  MarkdownText(min: Int, max: Int)
  Range(min: Int, max: Int)
  Url
}

pub type Error {
  Invalid
}

@external(javascript, "./spec_ffi.mjs", "matches")
fn matches(raw: String, pattern: String) -> Bool

pub fn validate(raw: String, spec: Spec) -> Result(String, Error) {
  let valid = case spec {
    Uuid ->
      matches(
        raw,
        "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
      )
    Pattern(min, max, regex) -> within(raw, min, max) && matches(raw, regex)
    Text(min, max) -> within(raw, min, max)
    Markdown -> True
    MarkdownText(min, max) -> within(raw, min, max)
    Range(min, max) -> valid_integer(raw, min, max)
    Url -> valid_url(raw)
  }
  case valid {
    True -> Ok(raw)
    False -> Error(Invalid)
  }
}

fn within(raw: String, min: Int, max: Int) -> Bool {
  let length = codepoints(raw)
  length >= min && length <= max
}

@external(javascript, "./spec_ffi.mjs", "codepoints")
fn codepoints(raw: String) -> Int

@external(javascript, "./spec_ffi.mjs", "validInteger")
fn valid_integer(raw: String, min: Int, max: Int) -> Bool

@external(javascript, "./spec_ffi.mjs", "validUrl")
fn valid_url(raw: String) -> Bool
