//// GENERATED from public/src/pages/**/page.gleam [sha256:9eae2ad762af] — 手で編集しない

/// 面の Page の閉じた enum(interactive Component の `live.GoTo` の行き先)。
pub type Route {
  ArticleArgSlug
  Status
}

pub type PageRoute {
  PageRoute(route: Route, path: String)
}

pub const routes: List(PageRoute) = [
  PageRoute(route: ArticleArgSlug, path: "/article/:slug"),
  PageRoute(route: Status, path: "/status"),
]
