//// 面の入口の門(0.11.1)。面 package の `src/gate.gleam` に `pub const gate: Gate` を 1 つ置くと、
//// 生成器が `src/gen/gate.mjs` を書き、生成 shell の lifecycle hook(`before_route` / `after_response`)から呼ぶ。
////
//// **Page の数だけ書かない** ── 門は `Match` で Page 群を指す。`Prefix("/me")` は `/me` と `/me/*` の全 Page、
//// `Every` は面の全 Page、`except` で除く Page を持つ。Page を足しても宣言は書き換えない。
//// path は Page の route の綴り(フォルダの木、`arg_x` は `:x`、`_` はそのまま)で書く。URL の段の `-` は
//// フォルダの `_` に対応する(生成器の規則。`/for-stores/api/v1` は `pages/for_stores/api/v1`)。
////
//// `src/gate.gleam` が無い面は、入口 `Http` の `admit: Authenticated` と `subject: Subjects([..])` から
//// 既定の門(session が読めない・主体が違えば 403 / 404)を生成器が出す。宣言を置いた面では宣言が既定に代わる。
////
//// 値の運び(route の値・session・Page の query を読みへ渡すこと)はここに置かない。門が持つのは
//// 「通すか・どこへ返すか」と、応答に足す header / script だけ。

pub type Gate {
  Gate(
    /// sign-in へ返す先。origin は env `PUBLIC_IDP_ORIGIN`、空なら `fallback_origin`。
    sign_in: SignIn,
    /// 宣言順に評価する。最初に落ちた検査の応答を返す。
    rules: List(Rule),
    /// 門を通った後の条件つきの redirect。宣言順で最初に当たったものを返す。
    redirects: List(Redirect),
    /// 入口 `Http` の `frame_src` を `Content-Security-Policy: frame-src` として付ける Page(HTML の応答だけ)。
    frame_src: List(Match),
    pageview: Pageview,
  )
}

pub type SignIn {
  SignIn(path: String, fallback_origin: String)
}

pub type Match {
  /// Page の route そのもの(`/claim/:code`)。
  Exact(path: String)
  /// その path の Page と、その下の全 Page(`/me` → `/me`, `/me/chats/:id`, ..)。
  Prefix(path: String)
  /// 面の全 Page。
  Every
}

pub type Rule {
  Rule(pages: List(Match), except: List(Match), checks: List(Check))
}

pub type Check {
  /// session が読めて anonymous でない。401 / 403 と anonymous は `fail`、他の失敗は同じ status で止める。
  SignedIn(fail: Fail)
  /// session の `adult` が true。
  Adult(fail: Fail)
  /// session の主体の種類(`subject.kind`、snake_case)がどれか。
  SubjectKind(kinds: List(String), fail: Fail)
  /// session の `consents.<kind>` が true。
  Consent(kind: String, fail: Fail)
}

pub type Fail {
  /// sign-in へ `status`(302 / 303)。`back` なら `redirect_uri` に要求の URL を付ける。
  ToSignIn(status: Int, back: Bool)
  /// `status` と本文(text/plain)で止める。
  Deny(status: Int, body: String)
  /// 302 で面の中の path へ返す。
  RedirectTo(location: String)
}

pub type Redirect {
  Redirect(pages: List(Match), when: When, to: To)
}

pub type When {
  WhenAdult
  WhenSignedIn
}

pub type To {
  /// 302 → query `param` の値。面の中の path でなければ `fallback`。
  SafeParam(param: String, fallback: String)
  /// 302 → 決まった path。
  Fixed(location: String)
}

pub type Pageview {
  NoPageview
  /// `pages` の Page が 200 の HTML を返し、session が成人なら、`</body>` の前に pageview の script を差す。
  /// script は `endpoint` へ POST し、query `source_param` の値(`[a-z0-9_]{1,16}`)を `source_key` に載せる。
  Pageview(
    pages: List(Match),
    endpoint: String,
    source_param: String,
    storage_key: String,
  )
}
