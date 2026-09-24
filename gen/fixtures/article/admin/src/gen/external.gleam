//// GENERATED from article/src/external_hosts.mjs [sha256:967f51bb1484] — 手で編集しない

pub type Side {
  Browser
  Server
}

pub type Host {
  Host(
    connector: String,
    host: String,
    name: String,
    information: String,
    purpose: String,
    side: Side,
  )
}

pub const hosts: List(Host) = [
  Host(
    connector: "fixture-browser",
    host: "images.example.test",
    name: "Fixture Images",
    information: "公開画像の取得",
    purpose: "記事画像を表示する",
    side: Browser,
  ),
  Host(
    connector: "fixture-search",
    host: "search.example.test",
    name: "Fixture Search",
    information: "検索結果の取得",
    purpose: "記事候補を探す",
    side: Server,
  ),
  Host(
    connector: "fixture-search",
    host: "api.example.test",
    name: "Fixture Search API",
    information: "検索候補の取得",
    purpose: "候補を絞り込む",
    side: Server,
  ),
]
