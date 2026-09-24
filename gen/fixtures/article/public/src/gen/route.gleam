//// GENERATED from public/src/pages/**/page.gleam [sha256:487960d3029e] — 手で編集しない

pub type PageRoute {
  PageRoute(path: String)
}

pub const routes: List(PageRoute) = [
  PageRoute(path: "/article/:slug"),
]
