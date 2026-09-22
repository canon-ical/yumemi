// ★ src/entry.gleam ── 人が来る入口の群。prefix 以外の URL は Service と Entity から生成する。
import framework/entry.{
  type Entry, All, Anonymous, AnySubject, Authenticated, Http, ReadOnly,
  Subjects,
}

pub type Subject {
  Staff
}

pub type Host {
  PublicHost
  AdminHost
}

pub const entries: List(Entry(Subject, Host)) = [
  Http(
    name: "public",
    hosts: [PublicHost],
    prefix: "/api",
    admit: Anonymous,
    subject: AnySubject,
    services: All,
  ),
  Http(
    name: "admin",
    hosts: [AdminHost],
    prefix: "/api/admin",
    admit: Authenticated,
    subject: Subjects([Staff]),
    services: All,
  ),
]
