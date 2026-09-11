//// Time values enter through the boundary; Logic has no clock.
pub opaque type Datetime { Datetime(value: String) }
pub opaque type Date { Date(value: String) }
pub opaque type Time { Time(value: String) }
@external(javascript, "./time_ffi.mjs", "validDatetime")
fn valid_datetime(raw: String) -> Bool
@external(javascript, "./time_ffi.mjs", "validDate")
fn valid_date(raw: String) -> Bool
@external(javascript, "./time_ffi.mjs", "validTime")
fn valid_time(raw: String) -> Bool
pub fn datetime(raw: String) -> Result(Datetime, Nil) {
  case valid_datetime(raw) { True -> Ok(Datetime(raw)) False -> Error(Nil) }
}
pub fn date(raw: String) -> Result(Date, Nil) {
  case valid_date(raw) { True -> Ok(Date(raw)) False -> Error(Nil) }
}
pub fn time(raw: String) -> Result(Time, Nil) {
  case valid_time(raw) { True -> Ok(Time(raw)) False -> Error(Nil) }
}
pub fn datetime_to_string(value: Datetime) -> String { value.value }
pub fn date_to_string(value: Date) -> String { value.value }
pub fn time_to_string(value: Time) -> String { value.value }
