//// GENERATED from public/src/pages/**/page.gleam [sha256:37acb1946f42] — 手で編集しない

pub type PageRoute {
  PageRoute(path: String)
}

pub const routes: List(PageRoute) = [
  PageRoute(path: "/article/:slug"),
]
