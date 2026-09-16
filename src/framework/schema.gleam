//// 表が載るスキーマの名。**生成器も runtime もここだけを読む** ── 20 の規約
//// 「生成器にアプリ固有の名前を焼かない」の出所を1箇所にするため。
//// 値を変えたら migration(`db/schema.sql`)と同時に変える。

/// アプリの Entity の表が載るスキーマ。
pub const app = "app"

/// フレームワークの持ち物(session / outbox / cursor)が載るスキーマ。
pub const framework = "framework"
