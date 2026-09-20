pub type StoreSchedule {
  StoreSchedule(id: String)
}

pub fn key(it: StoreSchedule) -> String {
  it.id
}

pub const collection: String = "store_schedules"
