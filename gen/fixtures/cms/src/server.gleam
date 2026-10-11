// ★ src/server.gleam ── back の宣言(yumemi/server)。Service でない HTTP の口と、導出規則を上書きする口。
import gleam/option.{None, Some}
import yumemi/server.{
  Anyone, Attached, BrowserCookie, Contain, Cover, Declaration, Declare, Get,
  Hook, ImageVariant, Media, NeedsDeclared, Party, Post, ReadSession, ScaleDown,
}

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
  Attached(
    name: "fixture_declare",
    method: Post,
    path: "/fixture/declare",
    who: Anyone,
  ),
  Attached(name: "fixture_media", method: Get, path: "/media/:key", who: Anyone),
]

// 機関を framework が持つ口の役。面の門(`gen/gate.mjs`)は `ReadSession` の口で session を読む
pub const attached_roles: List(server.AttachedRole) = [
  ReadSession(attached: "fixture_session"),
  Declare(attached: "fixture_declare", kind: "adult"),
  NeedsDeclared(attached: "fixture_media", kind: "adult"),
]

// browser の署名 cookie(0.12)── payload の id がユニークの印、申告は種類ごとの欄
pub const browser: server.BrowserCookie = BrowserCookie(
  cookie: "_fx",
  key_binding: "FIXTURE_BROWSER_KEY",
  max_age_days: 400,
  declarations: [
    Declaration(kind: "adult", claim: "adult_declared_at", max_age_days: 395),
    Declaration(kind: "region", claim: "region_declared_at", max_age_days: 30),
  ],
)

// 同意の種類(0.12)── 要件と門の Consented / ConsentedFor の綴りを生成器が止める
pub const consents: List(String) = ["use", "handling", "identity"]

// 画像の variant(0.12)── 生成器が面ごとに src/gen/media.gleam を書く
pub const media: server.Media = Media(
  path: "/media",
  theme_background: "w1600",
  variants: [
    ImageVariant(name: "thumb", width: 400, height: Some(400), fit: Cover),
    ImageVariant(name: "w800", width: 800, height: None, fit: ScaleDown),
    ImageVariant(name: "w1600", width: 1600, height: None, fit: Contain),
  ],
)

// attached の口の実装(★ の hooks.mjs、生成の http_runtime.mjs が名で引く)
pub const hooks: List(server.Hook) = [
  Hook(name: "attached_fixture_browser", module: "hooks"),
  Hook(name: "attached_fixture_sync", module: "hooks"),
  Hook(name: "attached_blob_copy", module: "hooks"),
  Hook(name: "attached_fixture_media", module: "hooks"),
]
