pub type MuseSchedule {
  MuseSchedule(id: String)
}

pub fn key(it: MuseSchedule) -> String {
  it.id
}

pub const collection: String = "muse_schedules"
