//// GENERATED from public/src/pages/**/page.gleam [sha256:1601ec0a328e] — 手で編集しない

pub type PageRoute {
  PageRoute(path: String)
}

pub const routes: List(PageRoute) = [
  PageRoute(path: "/article/:slug"),
  PageRoute(path: "/status"),
]
