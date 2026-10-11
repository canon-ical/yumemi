//// GENERATED from src/entry.gleam [sha256:c6be46c30a92] — 手で編集しない

import gen/service
import yumemi/front

pub type Method {
  Get
  Post
}

pub type Attached {
  BlobCopy
  FixtureBrowser
  FixtureDeclare
  FixtureMedia
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
  AttachedRoute(entry: FixtureDeclare, method: Post, path: "/fixture/declare"),
  AttachedRoute(entry: FixtureMedia, method: Get, path: "/media/:key"),
]

pub type Target =
  front.Target(service.Service, Attached)

pub type Route {
  Route(service: service.Service, method: Method, path: String)
}

pub const routes: List(Route) = [
  Route(service: service.ArticleRead, method: Get, path: "/api/articles/:slug"),
  Route(service: service.WidgetList, method: Get, path: "/api/widgets"),
]
