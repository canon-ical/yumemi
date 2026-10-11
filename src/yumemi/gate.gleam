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
//// 「通すか・どこへ返すか」と、応答に足す header と数える印(`<meta name="yumemi-pageview">`)だけ(0.12)。
////
//// 申告(`Declared` / `WhenDeclared`)と同意(`Consented`)の種類は app が名付ける。申告の種類は
//// `src/server.gleam` の `browser.declarations`、同意の種類は `consents` に無ければ生成器が exit 4 で止める。

import gleam/option

pub type Gate {
  Gate(
    /// sign-in へ返す先。origin は env `PUBLIC_IDP_ORIGIN`、空なら `fallback_origin`。
    sign_in: SignIn,
    /// 宣言順に評価する。最初に落ちた検査の応答を返す。
    rules: List(Rule),
    /// 門を通った後の条件つきの redirect。宣言順で最初に当たったものを返す。
    redirects: List(Redirect),
    /// Page 群ごとの CSP の指令(HTML の応答に `Content-Security-Policy` を付ける)。0.12 で入口の `frame_src` から移した。
    csp: List(Csp),
    /// 数える口(0.12)。送り手は client.mjs 1 つで、門は印の meta だけを差す。
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
  /// session の `declared.<kind>` が true(browser の署名 cookie の申告 `kind` が期間の内)。
  Declared(kind: String, fail: Fail)
  /// session の主体の種類(`subject.kind`、snake_case)がどれか。
  SubjectKind(kinds: List(String), fail: Fail)
  /// session の `consents.<kind>` が true(party が同意 `kind` を持つ)。
  Consented(kind: String, fail: Fail)
}

pub type Fail {
  /// sign-in へ `status`(302 / 303)。`back` なら `redirect_uri` に要求の URL を付ける。
  ToSignIn(status: Int, back: Bool)
  /// `status` と本文(text/plain)で止める。
  Deny(status: Int, body: String)
  /// 302 で面の中の path へ返す。
  RedirectTo(location: String)
  /// 302 で面の中の `location` へ返し、query `param` に要求の path + search を URL 符号化して付ける
  /// (0.11.5)。`location` が既に query を持てば `&` で足す。要求の path + search が面の中の path でなければ
  /// (`SafeParam` と同じ判定)`param` を付けない ── 外の origin へ戻す値にはしない。
  /// `location` は `/` で始め、`//` で始めず、`\` も制御文字も `#` も持たない。`param` は `[A-Za-z0-9_.-]+`。
  RedirectBack(location: String, param: String)
}

pub type Redirect {
  Redirect(pages: List(Match), when: When, to: To)
}

pub type When {
  /// session の `declared.<kind>` が true。
  WhenDeclared(kind: String)
  /// session が読めて anonymous でない。
  WhenSignedIn
}

pub type To {
  /// 302 → query `param` の値。面の中の path でなければ `fallback`。
  SafeParam(param: String, fallback: String)
  /// 302 → 決まった path。
  Fixed(location: String)
  /// 302 → 決まった path に、要求の query を保って付ける(0.11.5)。`location` は `/` で始め、`//` で始めず、
  /// `\` も制御文字も `?` も `#` も持たない。
  /// hash は server に届かない ── 頁の読み込みの 302 では browser が元の URL の hash を引き継ぐ
  /// (client 遷移の fetch は redirect を取らずに頁の読み込みへ落ちるので、同じに保たれる)。
  FixedKeep(location: String)
}

/// 頁の CSP(0.12)。`pages` の Page の HTML の応答に `directives` を `Content-Security-Policy` で付ける。
/// 同じ Page に 2 つ以上の `Csp` が当たれば指令を宣言順に足し合わせる。host は `[a-z0-9.-]+`(先頭に `*.` を 1 つ許す)で、
/// `https://` を付けて出す。`script-src` は持たない。
pub type Csp {
  Csp(pages: List(Match), directives: List(Directive))
}

pub type Directive {
  FrameSrc(hosts: List(String))
  ImgSrc(hosts: List(String))
  ConnectSrc(hosts: List(String))
  MediaSrc(hosts: List(String))
}

/// 数える口(0.12)。`pages` の Page が 200 の HTML を返し、`only` を全部満たす要求に、門が
/// `<meta name="yumemi-pageview">` を差す。送るのは client.mjs(`requestIdleCallback` の後、prerender の間は
/// activation を待つ)で、宛先は app の入口の `<prefix>/_yumemi/pageviews`。event の id は framework が常に足し、
/// 前の event の鎖の鍵(`yumemi:pageview:<面の名>`)・訪問の窓 30 分・browser ごとの上限 60 件/分は framework が決める。
pub type Pageview {
  NoPageview
  Pageview(
    pages: List(Match),
    only: List(When),
    fields: List(Field),
    sink: Sink,
  )
}

/// 送る欄(閉じた語彙)。欄の名は `kind`・`client_at`・`path`・`prev`・`referrer_path` / `referrer_host`・`FromQuery` の `name`。
pub type Field {
  /// `initial` / `reload` / `spa`(戻る・進むも `spa`)
  NavKind
  /// 送った時の client の時刻(参考。訪問の区切りには使わない)
  ClientAt
  /// 数えた頁の path
  Path
  /// 同じ tab の前の event の id
  Previous
  /// 前の event が無いときだけ、同じ origin なら path(`referrer_path`)、外なら host(`referrer_host`)
  Referrer
  /// query `param` の値が `pattern` に当たるときだけ、欄 `name` に載せる
  FromQuery(name: String, param: String, pattern: QueryPattern)
}

pub type QueryPattern {
  /// `[a-z0-9_]{1,max}`(`max` は 1〜64)
  Slug(max: Int)
}

/// 送られた event の行き先。
pub type Sink {
  /// framework の器(event・訪問・印の表と、日・月の集計)。`resolve` は event の `path` を Args に受けて業務の次元を
  /// Out の欄で返す app の Service の名、`rollup_by` はその Out の欄で集計を割る名、`exclude_when` はその Out の
  /// Bool の欄で、真の event は行を作るが数字から除く。`browser` の宣言が要る
  Store(
    resolve: option.Option(String),
    rollup_by: List(String),
    exclude_when: List(String),
  )
  /// 名前付きの逃げ道。入口の検査(送り手・id・bot と監視・先読み・連打)を通した event を app の Service に渡す。
  /// Args は `fields` から組む型と突き合わせ、印・party・主体は root に運ぶ。生成器が使った数を警告で出す
  ToService(service: String)
}
