pub type MuseHeaven {
  MuseHeaven(id: String)
}

pub fn key(it: MuseHeaven) -> String {
  it.id
}

pub const collection: String = "muse_heavens"
