import framework/entry.{type Entry, All, Anonymous, AnySubject, Http}

pub type Subject {
  Guest
}

pub type Host {
  TestHost
}

pub const entries: List(Entry(Subject, Host)) = [
  Http(
    name: "test",
    hosts: [TestHost],
    prefix: "/test",
    admit: Anonymous,
    subject: AnySubject,
    services: All,
  ),
]
