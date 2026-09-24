//// GENERATED from src/entry.gleam [sha256:fceb9b379055] — 手で編集しない

import framework/front
import gen/service

pub type Method {
  Get
  Post
}

pub type Attached {
  FixtureBrowser
  FixtureSync
}

pub type AttachedRoute {
  AttachedRoute(entry: Attached, method: Method, path: String)
}

pub const attached: List(AttachedRoute) = [
  AttachedRoute(entry: FixtureBrowser, method: Get, path: "/fixture/browser"),
  AttachedRoute(entry: FixtureSync, method: Post, path: "/fixture/sync"),
]

pub type Target =
  front.Target(service.Service, Attached)

pub type Route {
  Route(service: service.Service, method: Method, path: String)
}

pub const routes: List(Route) = [
  Route(service: service.ArticleCreate, method: Post, path: "/api/articles"),
  Route(service: service.ArticleList, method: Get, path: "/api/articles"),
  Route(
    service: service.ArticlePublish,
    method: Post,
    path: "/api/articles/:slug/publish",
  ),
  Route(service: service.ArticleRead, method: Get, path: "/api/articles/:slug"),
  Route(service: service.WidgetList, method: Get, path: "/api/widgets"),
]
