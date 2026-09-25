//// GENERATED from src/entry.gleam [sha256:958bd32fabb3] — 手で編集しない

import framework/front
import gen/service

pub type Method {
  Get
  Post
}

pub type Attached {
  BlobCopy
  FixtureBrowser
  FixtureSync
}

pub type AttachedRoute {
  AttachedRoute(entry: Attached, method: Method, path: String)
}

pub const attached: List(AttachedRoute) = [
  AttachedRoute(entry: FixtureBrowser, method: Get, path: "/fixture/browser"),
  AttachedRoute(entry: FixtureSync, method: Post, path: "/fixture/sync"),
  AttachedRoute(entry: BlobCopy, method: Post, path: "/api/blobs"),
]

pub type Target =
  front.Target(service.Service, Attached)

pub type Route {
  Route(service: service.Service, method: Method, path: String)
}

pub const routes: List(Route) = [
  Route(
    service: service.ArticleCreate,
    method: Post,
    path: "/api/admin/articles",
  ),
  Route(service: service.ArticleList, method: Get, path: "/api/admin/articles"),
  Route(
    service: service.ArticlePublish,
    method: Post,
    path: "/api/admin/articles/:slug/publish",
  ),
  Route(
    service: service.ArticleRead,
    method: Get,
    path: "/api/admin/articles/:slug",
  ),
  Route(
    service: service.ArticleRetract,
    method: Post,
    path: "/api/admin/articles/:slug/retract",
  ),
  Route(service: service.WidgetList, method: Get, path: "/api/admin/widgets"),
]
