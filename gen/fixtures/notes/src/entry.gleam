// ★ src/entry.gleam ── 入口は 1 つ。Host の variant の名(`ApiHost`)は入口の名(`api`)と違う。
import yumemi/entry.{type Entry, All, Anonymous, AnySubject, Http, NoPages}

pub type Subject {
  Guest
}

pub type Host {
  ApiHost
}

pub const entries: List(Entry(Subject, Host)) = [
  Http(
    name: "api",
    hosts: [ApiHost],
    prefix: "/api",
    admit: Anonymous,
    subject: AnySubject,
    services: All,
    pages: NoPages,
  ),
]
