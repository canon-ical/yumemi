//// GENERATED from public/src/pages/**/page.gleam [sha256:91e3bdd4618c] — 手で編集しない

pub type PageRoute {
  PageRoute(path: String)
}

pub const routes: List(PageRoute) = [
  PageRoute(path: "/article/:slug"),
  PageRoute(path: "/status"),
]
