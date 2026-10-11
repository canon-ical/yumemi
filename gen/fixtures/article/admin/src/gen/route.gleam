//// GENERATED from admin/src/pages/**/page.gleam [sha256:a2a327ea7269] — 手で編集しない

/// 面の Page の閉じた enum(interactive Component の `live.GoTo` の行き先)。
pub type Route {
  Home
}

pub type PageRoute {
  PageRoute(route: Route, path: String)
}

pub const routes: List(PageRoute) = [
  PageRoute(route: Home, path: "/home"),
]
