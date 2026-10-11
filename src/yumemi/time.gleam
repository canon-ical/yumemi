//// Time values enter through the boundary; Logic has no clock.

pub opaque type Datetime {
  Datetime(value: String)
}

pub opaque type Date {
  Date(value: String)
}

pub opaque type Time {
  Time(value: String)
}

@external(javascript, "./time_ffi.mjs", "validDatetime")
fn valid_datetime(raw: String) -> Bool

@external(javascript, "./time_ffi.mjs", "validDate")
fn valid_date(raw: String) -> Bool

@external(javascript, "./time_ffi.mjs", "validTime")
fn valid_time(raw: String) -> Bool

pub fn datetime(raw: String) -> Result(Datetime, Nil) {
  case valid_datetime(raw) {
    True -> Ok(Datetime(raw))
    False -> Error(Nil)
  }
}

pub fn date(raw: String) -> Result(Date, Nil) {
  case valid_date(raw) {
    True -> Ok(Date(raw))
    False -> Error(Nil)
  }
}

pub fn time(raw: String) -> Result(Time, Nil) {
  case valid_time(raw) {
    True -> Ok(Time(raw))
    False -> Error(Nil)
  }
}

pub fn datetime_to_string(value: Datetime) -> String {
  value.value
}

pub fn date_to_string(value: Date) -> String {
  value.value
}

pub fn time_to_string(value: Time) -> String {
  value.value
}

@external(javascript, "./time_ffi.mjs", "addDays")
fn add_days_raw(value: String, days: Int) -> String

pub fn add_days(value: Datetime, days: Int) -> Datetime {
  Datetime(add_days_raw(value.value, days))
}

@external(javascript, "./time_ffi.mjs", "toDate")
fn to_date_raw(value: String) -> String

/// Convert an instant to the calendar date observed in Asia/Tokyo.
pub fn to_date(value: Datetime) -> Date {
  Date(to_date_raw(value.value))
}

@external(javascript, "./time_ffi.mjs", "dateLe")
fn date_le_raw(left: String, right: String) -> Bool

pub fn date_le(left: Date, right: Date) -> Bool {
  date_le_raw(left.value, right.value)
}

@external(javascript, "./time_ffi.mjs", "datetimeLt")
fn datetime_lt_raw(left: String, right: String) -> Bool

pub fn datetime_lt(left: Datetime, right: Datetime) -> Bool {
  datetime_lt_raw(left.value, right.value)
}

@external(javascript, "./time_ffi.mjs", "datetimeLe")
fn datetime_le_raw(left: String, right: String) -> Bool

pub fn datetime_le(left: Datetime, right: Datetime) -> Bool {
  datetime_le_raw(left.value, right.value)
}

@external(javascript, "./time_ffi.mjs", "quarterAligned")
fn quarter_aligned_raw(value: String) -> Bool

/// True only on an absolute 15-minute boundary with zero seconds.
pub fn quarter_aligned(value: Datetime) -> Bool {
  quarter_aligned_raw(value.value)
}
