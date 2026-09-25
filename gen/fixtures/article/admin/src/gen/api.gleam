//// GENERATED from src/entry.gleam [sha256:7a3c0e1de776] — 手で編集しない

import framework/front
import gen/service

pub type Method {
  Get
  Post
}

pub type Attached {
  BlobCopy
  FixtureBrowser
  FixtureSession
  FixtureSync
}

pub type AttachedRoute {
  AttachedRoute(entry: Attached, method: Method, path: String)
}

pub const attached: List(AttachedRoute) = [
  AttachedRoute(entry: FixtureBrowser, method: Get, path: "/fixture/browser"),
  AttachedRoute(entry: FixtureSync, method: Post, path: "/fixture/sync"),
  AttachedRoute(entry: BlobCopy, method: Post, path: "/api/blobs"),
  AttachedRoute(entry: FixtureSession, method: Get, path: "/fixture/session"),
]

pub type Target =
  front.Target(service.Service, Attached)

pub type Route {
  Route(service: service.Service, method: Method, path: String)
}

pub const routes: List(Route) = []
