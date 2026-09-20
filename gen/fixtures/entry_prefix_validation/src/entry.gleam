import framework/entry.{type Entry, All, Anonymous, AnySubject, Http}

pub type Subject {
  Guest
}

pub type Host {
  ValidHost
  MissingHost
  InvalidHost
  SpacedHost
}

pub const entries: List(Entry(Subject, Host)) = [
  Http(
    name: "valid",
    hosts: [ValidHost],
    prefix: "/api/admin",
    admit: Anonymous,
    subject: AnySubject,
    services: All,
  ),
  Http(
    name: "missing",
    hosts: [MissingHost],
    admit: Anonymous,
    subject: AnySubject,
    services: All,
  ),
  Http(
    name: "invalid",
    hosts: [InvalidHost],
    prefix: "api",
    admit: Anonymous,
    subject: AnySubject,
    services: All,
  ),
  Http(
    name: "spaced",
    hosts: [SpacedHost],
    prefix: "/api admin",
    admit: Anonymous,
    subject: AnySubject,
    services: All,
  ),
]
