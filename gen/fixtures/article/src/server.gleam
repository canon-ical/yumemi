// ★ src/server.gleam ── back の宣言(framework/server)。Service でない HTTP の口と、導出規則を上書きする口。
import framework/server.{Anyone, Attached, Get, Hook, Party, Post, ReadSession}

pub const attached: List(server.Attached) = [
  Attached(
    name: "fixture_browser",
    method: Get,
    path: "/fixture/browser",
    who: Anyone,
  ),
  Attached(
    name: "fixture_sync",
    method: Post,
    path: "/fixture/sync",
    who: Party,
  ),
  Attached(name: "blob_copy", method: Post, path: "/api/blobs", who: Party),
  Attached(
    name: "fixture_session",
    method: Get,
    path: "/fixture/session",
    who: Anyone,
  ),
]

// 機関を framework が持つ口の役。面の門(`gen/gate.mjs`)は `ReadSession` の口で session を読む
pub const attached_roles: List(server.AttachedRole) = [
  ReadSession(attached: "fixture_session"),
]

// attached の口の実装(★ の hooks.mjs、生成の http_runtime.mjs が名で引く)
pub const hooks: List(server.Hook) = [
  Hook(name: "attached_fixture_browser", module: "hooks"),
  Hook(name: "attached_fixture_sync", module: "hooks"),
  Hook(name: "attached_blob_copy", module: "hooks"),
]
