//// GENERATED from src/entry.gleam [sha256:95073a5c7962] — 手で編集しない

import gen/service

pub type Method {
  Get
  Post
}

pub type Route {
  Route(service: service.Service, method: Method, path: String)
}

pub const routes: List(Route) = [
  Route(service: service.ArticleCreate, method: Post, path: "/api/articles"),
  Route(service: service.ArticleList, method: Get, path: "/api/articles"),
  Route(service: service.ArticlePublish, method: Post, path: "/api/articles/:slug/publish"),
  Route(service: service.ArticleRead, method: Get, path: "/api/articles/:slug"),
  Route(service: service.WidgetList, method: Get, path: "/api/widgets"),
]
