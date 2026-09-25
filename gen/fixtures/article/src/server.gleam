// ★ src/server.gleam ── back の宣言(framework/server)。Service でない HTTP の口と、導出規則を上書きする口。
import framework/server.{Anyone, Attached, Get, Party, Post}

pub const attached: List(server.Attached) = [
  Attached(
    name: "fixture_browser",
    method: Get,
    path: "/fixture/browser",
    who: Anyone,
  ),
  Attached(name: "fixture_sync", method: Post, path: "/fixture/sync", who: Party),
  Attached(name: "blob_copy", method: Post, path: "/api/blobs", who: Party),
]
