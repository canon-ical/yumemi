import framework/entry.{type Entry}

pub type Subject {
  Guest
}

pub type Host {
  TestHost
}

pub const entries: List(Entry(Subject, Host)) = []
