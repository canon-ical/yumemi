//// Opaque request to seal plaintext at the storage boundary. No plaintext encoder.

pub type StaffKey

pub type Sealed(value, key)

@external(javascript, "./sealed_ffi.mjs", "forStaff")
pub fn for_staff(value: String) -> Sealed(String, StaffKey)
