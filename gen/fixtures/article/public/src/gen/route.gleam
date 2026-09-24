//// GENERATED from public/src/pages/**/page.gleam [sha256:82c83adc55b4] — 手で編集しない

pub type PageRoute {
  PageRoute(path: String)
}

pub const routes: List(PageRoute) = [
  PageRoute(path: "/article/:slug"),
]
