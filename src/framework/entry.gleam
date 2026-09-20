//// Entry declarations; deployment values are resolved by the adapter.
//// 2a-4 で `credential` を足した ── 主体を運ぶ**媒体**(session cookie か `Authorization: Bearer`)の宣言で、
//// [26-dispatch](../../../../canonical/tech/_drafts/gleam-framework/26-dispatch.v0.md) 88〜113 行の起案(柏木 C1〜C3、人見の裁定 A / B / C)の実装。
//// **`admit` には触らない** ── 変えるのは「誰か」の運び方であって「未ログインを通すか」ではない(人見 2026-09-10 の 2 値は据え置き)。
////
//// **既定 `Session` を 2 つ目の constructor で表す** ── Gleam の record は既定値を持てず、`Http` に `prefix` 欄を足すと
//// 既存 3 入口の宣言が全部書き換えになる(26 の負例 (o)「既存 3 入口に `credential` を書かないまま (a)〜(j) が通る」が成立しなくなる)。
//// `Http` は `credential: Session` の略記、`HttpApi` が `credential` を明示する形。**6 欄の並びを共通にしてある**ので
//// `entry.name` / `.hosts` / `.prefix` / `.admit` / `.subject` / `.services` の accessor は両方の constructor で効き、読む側は分岐を持たない。
//// 媒体が増えても constructor は増やさない ── 足すのは `Credential` の variant(`HttpApi(.., credential: Session)` は `Http` と同値、書いてよい)。
////
//// ▲ への契約 ── 入口の媒体を読む口は `entry.credential(Entry) -> Credential` 1 本(`Http` は `Session`)。gen は各入口の宣言からこの値を吐く。
////
//// **`prefix` は URL の頭そのもの** ── `/api` や `/api/store` を書き、暗黙の `/api` は置かない。
//// ▲ への契約(検査 1)── **1 host = 1 入口**は不変(`http_runtime.mjs:294` の `find` は host だけで引く)。同じ host に 2 入口を置かない ── REST v1 は自分の host を持つ(`app/src/entry.gleam` の頭)。
//// ▲ への契約(検査 2)── **v1 の route(`/api/v1/` で始まる path)は `credential: ApiKey` の入口だけ、それ以外の route は `Session` の入口だけ**が持つ(反対側は 404)。これが「入口が媒体で割れている」の形で、負例 (k)(l)の土台。
//// ▲ への契約(検査 3)── `ApiKey` の入口では Origin を検査しない(柏木 C1 ── CSRF は cookie の媒体にだけ生じる。ツールは Origin を送らない)。
//// ▲ への契約(検査 5)── `ApiKey` の入口は ①Bearer 無し・形式不正 → **401 + `WWW-Authenticate: Bearer`**、②`per_minute` の超過 → **429**(どちらも確定の 1 文の前 ── DB を触らない)。`Session` の入口は Bearer を**見ない**(未認証として続行)。
//// ▲ への契約(検査 6・7・9・10)── 変えない。ApiKey は Bearer の HMAC で `app.store` を 1 文で引き、session の 1 文と同じ射影を返す。主体は Store なので subject の検査も allow の句も同じものが効く。

pub type Admit {
  Anonymous
  Authenticated
}

pub type Services {
  ReadOnly
  All
}

pub type Subjects(subject) {
  Subjects(List(subject))
  AnySubject
}

/// 主体を運ぶ媒体。`per_minute` は **その入口の API key 1 本あたり / 分**の上限(裁定 B ──
/// 基盤に「上限」の一般語彙を持たず、値は ★ が入口に書く)。上限の器は Cloudflare の
/// Rate Limiting binding(`app/src/entry.gleam` の頭)。鍵は Bearer の **HMAC の像**で、平文を器へ渡さない。
pub type Credential {
  Session
  ApiKey(per_minute: Int)
}

pub type Entry(subject, host) {
  Http(
    name: String,
    hosts: List(host),
    prefix: String,
    admit: Admit,
    subject: Subjects(subject),
    services: Services,
  )
  HttpApi(
    name: String,
    hosts: List(host),
    prefix: String,
    admit: Admit,
    subject: Subjects(subject),
    services: Services,
    credential: Credential,
  )
}

/// 入口の媒体。**既定は `Session`** ── `Http` の宣言を書き換えないための 1 箇所で、負例 (o) はこの関数の値で固定できる。
pub fn credential(entry: Entry(subject, host)) -> Credential {
  case entry {
    Http(..) -> Session
    HttpApi(credential: value, ..) -> value
  }
}
