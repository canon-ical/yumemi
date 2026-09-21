//// GENERATED from src/entry.gleam [sha256:c814fd53ce44] — 手で編集しない

import gen/service

pub type Method {
  Get
}

pub type Route {
  Route(service: service.Service, method: Method, path: String)
}

pub const routes: List(Route) = [
  Route(service: service.ArticleList, method: Get, path: "/api/articles"),
  Route(service: service.ArticleRead, method: Get, path: "/api/articles/{slug}"),
  Route(service: service.WidgetList, method: Get, path: "/api/widgets"),
]
