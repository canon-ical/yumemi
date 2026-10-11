//// Requirements are evaluated after argument decoding(0.12)。
////
//// 申告と同意の種類は app が名付ける。申告の種類は `src/server.gleam` の `browser.declarations`、同意の種類は
//// `consents` に無ければ生成器が exit 4 で止める(51 v6 第 32・40 条)。

pub type Requirement(args) {
  /// browser の署名 cookie の申告 `kind` が期間の内。無ければ 403 `{"code": "declaration_missing", "declaration": kind}`
  Declared(kind: String)
  /// session の party が同意 `kind` を持つ。無ければ 403 `{"code": "consent_missing", "consent": kind}`
  Consented(kind: String)
  /// party が対象 `subject(args)` についての同意 `kind` を持つ(対象を Args と突き合わせる同意)
  ConsentedFor(kind: String, subject: fn(args) -> String)
}
