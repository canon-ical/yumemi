//// Opaque HMAC value for secrets stored by the application.
//// The plaintext is accepted only at this boundary and cannot be encoded back.

pub opaque type Secret {
  Secret(value: String)
}

@external(javascript, "./secret_ffi.mjs", "hmac")
pub fn hmac(value: String) -> Secret
