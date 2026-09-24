//// GENERATED from public/src/pages/**/page.gleam [sha256:b0af993d9f89] — 手で編集しない

pub type PageRoute {
  PageRoute(path: String)
}

pub const routes: List(PageRoute) = [
  PageRoute(path: "/article/:slug"),
]
