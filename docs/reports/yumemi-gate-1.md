# yumemi-gate-1(門)── 面の入口の門・rewrite・CSP・pageview・route の順・client の入口を生成器へ(真壁、2026-09-26)

基点 yumemi main `3209703`(v0.11.0 + docs)、branch `impl/yumemi-gate-1`。写しは musearch `645ec49` の `git archive`(`gen/build/gate/snap/`)。musearch には 1 file も書いていない。証跡は `gen/build/gate/`。

## 何を足したか

| 物 | 在処 | 中身 |
|---|---|---|
| 門の宣言の型(新しい module だけ) | `src/framework/gate.gleam` | `Gate(sign_in, rules, redirects, frame_src, pageview)`。Page 群は `Match` = `Exact(path)` / `Prefix(path)` / `Every` で指し、`Rule(pages, except, checks)` の `except` で除く Page を持つ。検査は `SignedIn` / `Adult` / `SubjectKind` / `Consent`、失敗の応答は `ToSignIn(status, back)` / `Deny(status, body)` / `RedirectTo(location)`。条件つきの redirect は `Redirect(pages, WhenAdult | WhenSignedIn, SafeParam(param, fallback) | Fixed(location))`。pageview は `Pageview(pages, endpoint, source_param, storage_key)` / `NoPageview`。**0.11.0 の `Page` / `Layout` / `Entry` と既存の構成子は 1 字も変えていない** |
| reader | `gen/src/yumemi_gen/reader/gate.gleam` | 面の `src/gate.gleam` の `pub const gate` を読む。無い面は入口 `Http` の `admit: Authenticated` + `subject: Subjects([..])` から既定の門(`Admitted(kinds)`)を組む。CSP の host は入口の `frame_src` 欄から読む(`model.gleam` は触らず entry の unit を直に読む)。`Exact` の Page が route に無い・`Prefix` の下に Page が無い・3xx でない `ToSignIn` などは exit 4、`gate` の const が無い file は exit 3 |
| emit | `gen/src/yumemi_gen/emit/gate.gleam` → 面の `src/gen/gate.mjs` | `before_route(request, env)` / `after_response(request, env, response)` / `serve(dispatch)`。前者は route 表で Page を引き、URL の段の `-` をフォルダの `_` に戻し、session を 1 回読み、rules → redirects の順に当てる。後者は CSP `frame-src` と pageview の script を足す。sha256 ヘッダ付き |
| 生成 shell | `emit/front.gleam` の `shell_*` | `export default gate.serve(async (request, env, before) => ..)`。門が読んだ session を `renderPage` に渡す(二度読まない)。**Page の query が空文字なら `None`**(空の検索の短絡を殻から消すための生成側の半分) |
| route 表の順 | `emit/front.gleam` の `route_text` / `route_order` | 段ごとに比べ、同じ位置で literal の段を param の段より先に。`prioritizeLiteralRoutes` は要らない |
| URL の綴り(裁定 1 (a)) | `gate.mjs` の `literalMatches` | route の literal の段 `a_b` は URL の `a-b` にも当たり、正規の綴り(`_`)に直して shell へ渡す。`/for-stores/api/v1` → `/for_stores/api/v1`、`/api-key` → `/api_key`。宣言は要らない |
| client の入口(裁定 2 (a)) | `emit/front.gleam` の `client_components` / `client_notes` | 登録の源を「`components/` のうち `pub fn app()` を持つもの全部」に直した(以前は `calls` の在る島だけで、`calls` の無い島 3 本を落としていた)。`calls` を持つのに `app()` の無い島は exit 3 で名指す |

`yumemi_gen.gleam` は front の診断の列に 2 行(`gate_notes` / `client_notes`)を足しただけ。

## 棚卸し ── 3 面の `gates.mjs` を行で割る(`gen/build/gate/inventory.tsv`、未分類 0)

| 面 | 行 | 本便 | F6(値の運び) | 名指しの残り |
|---|---|---|---|---|
| www | 407 | 285 | 122 | 0 |
| muses | 170 | 87 | 83 | 0 |
| console | 194 | 111 | 83 | 0 |

本便の行の置き場(block 単位の対応は tsv の `where` 列):`prioritizeLiteralRoutes` → route 表の順、`matchRoute` / `routeFor` / `routeParams` → `gate.mjs` の `matchRoute`、`shellPath` / `rewriteApiKeyPath` → URL の綴りの規則、`handleMe` / `handleClaim` / `gateResponse` / muses の `gate` → `Rule` と既定の `Admitted`、`safeReturn` → `SafeParam`、`withFramePageHeader` / `frameSrc` → `after_response` の CSP、`tracksPageview` / `htmlWithPageviewScript` → `Pageview`。F6 の行は `pageVars`・`queryValues`・`withPageValues`・`envWith*`・`withOwnLedger`・日付の既定・www の `entryReadNotFound`。名指しの残り(client entry の外の ★ `blob_copy*`)は `gates.mjs` の外なので表に行が無い。

## 写しで確かめたこと

写しに www / console の `src/gate.gleam`(下の「WGm への申し送り」の本文)を置き、生成器を 2 回当てた。面は写しの `src/gen` をそのまま使い、生成物の `gen/gate.mjs` と `gen/route.gleam` だけを重ねた(写しの Page は 0.11 の宣言に追随していないので、生成物の `src/gen` 全体では面が build できない ── 基線から同じ exit 1 × 3。F6 / WGm の仕事)。`gates.mjs` は F6 の射程の関数だけを原文のまま残した薄い ★ に縮めた。面は Hex の yumemi 0.9 のままなので、`framework/gate.gleam` を面の `src/framework/` に写して build した(0.11.1 を採れば要らない)。

| 検収 | 結果 | 証跡 |
|---|---|---|
| 生成器 ×2 | 2 回とも exit 4、`diff -r` は runtime build の記録の時間 1 行だけ。`_diagnostics.txt` は基線 + www の `app()` 無し 7 行(下) | `after-gen-{one,two}.log`、`after-gen-diff.txt` |
| 生成 shell と門の sha256 ヘッダ | 3 面とも `gate.mjs` / `shell.mjs` の 1 行目にヘッダ | `after-gen-one/*/src/gen/` |
| route の集合 | 3 面とも写しの `route.gleam` と同じ集合、順だけ literal-first | ― |
| `test/entry-gates.test.mjs`(門の assert) | before / after とも www 11 / muses 16 / console 18 pass | `before/test-*.txt`、`after/test-*.txt` |
| 面の node test 全部 | before / after とも www 48 pass 1 fail、muses 16、console 18。www の 1 fail は写しに `docs/api-v1.md` が無い環境要因で前後同じ test | `before/all-*.txt`、`after/all-*.txt` |
| **Workerd の status 表**(wrangler dev、www 9184 / muses 9182 / console 9183、inspector 9632〜9634、`--local-protocol https`) | **98 行で status・Location・CSP・pageview の有無・描いた Page・門の後の読みの数が前後全一致**。F5 の 23 行(`/muse/kanon/blog/article-1` は 404 のまま)、2b-7 の `/me/*` 11 Page × 3 主体、2b-8 の muses 3 Page × 4 主体・console 2 Page × 4 主体、CSP 5 行、pageview 4 行、URL の綴り 2 行、literal-first 6 行、session の失敗 3 行、route の外 2 行 | `workerd/table-{before,after}-https.tsv`、`workerd/compare.py` |
| body の sha256 | 200 の行で違うのは `/search?r=mail`(成人)の pageview の script だけ(下)。他の 15 行は 500 の Workerd のエラー頁で、stack に before / after の path が入るための差 | `workerd/bodies-*`、`workerd/pageview-script-diff.txt` |
| pageview の script | 差は追跡の判定の書き方だけ(正規表現 → route の表)。41370 path で前後の判定が選ぶ集合は同一(追跡 573、差 0) | `workerd/tracked-equiv.{mjs,txt}` |
| literal-first の 3 対 | `/articles/new`・`/page/widget/new`・`/rosters/new` と param の側が前後で同じ status・同じ Page・同じ読みの数 | table の `literal` 行 |
| 薄い ★ の残り | www 131 行 = F6 117 + dispatch の中の値の運びの呼び出し 8 + 生成物を呼ぶ口 4 + 札 2。muses 91 = 81 + 4 + 4 + 2。console 98 = 86 + 6 + 4 + 2(console の `failure` は `withOwnLedger` が使うので残した) | `thin-star.tsv`、`after/*/src/gates.mjs` |
| client の入口 | 生成器の束ねる前の `client.mjs` を写しの面の build に esbuild で束ね(`import-is-undefined` を error)、node で `customElements.define` を数えた。**muses 37 / 37 一致、console 14 / 15(差は名指しの残り `blob-copy`)**。www は 0 本(7 本とも `app()` が無い → exit 3 で名指す) | `client/{compare.py,defined.mjs,defined-*.json}` |

Workerd の APP は F5 の `yumemi-5-stub-server.mjs` の固定応答をそのまま写した stub。固定応答が今の decoder に合わない読み(11 種)の Page は、門を通った後の描画で前後とも 500 になる(`app_reads` 列が前後同じ数で、門の後まで進んだことを示す)。F5 の表で 200 だった `me_adult_pass` などがこの表では 500 なのはそのため。

## 前と変わるところ(鷹野宛)

1. **http で受けたときの `/claim` の `redirect_uri`。**前の www は `https://` + host に書き換えていたが、生成物は要求の URL のまま(console の前と同じ)。Workerd を http で起こすと `claim_anonymous` の Location が 1 行だけ `http%3A` になる(`workerd/table-*-http.tsv`)。本番の要求は https なので差は出ない。符号化も console の `encodeURIComponent` に揃えた(www の前の `URLSearchParams` とは `!'()~` と空白だけ違う)
2. **CSP を付ける Page は宣言の列挙(`frame_src: [Exact(..) ×3]`)。**前の 3 Page に合わせた。SvelteKit の頃は全 Page に meta を出していたので、`Every` にするかは鷹野の裁き
3. **muses の `adult-declare` と `article-list-actions` は送った後に reload する。**2 本とも `after_send = ReloadPage` を宣言し `yumemi-done` を出しているのに、手書きの入口が聞いていなかった。生成物は宣言どおり聞く
4. 門が session を読めなかった(例外)ときは 502 `session read failed`(前は www の `/me` が 500、他は素通り)。既定の門(`Admitted`)は主体に `handle` の文字列を求める(muses の前と同じ)
5. 空の検索:生成 shell は `?q=` を `None`(送らない)にする。`?q=%20` は前の殻が trim して短絡したが、生成物は `" "` を送る

## WGm への申し送り

- www の `src/gate.gleam`(写しで使った本文):

```gleam
import framework/gate.{
  Adult, Deny, Exact, Gate, Pageview, Prefix, Redirect, Rule, SafeParam,
  SignIn, SignedIn, ToSignIn, WhenAdult,
}

pub const gate: gate.Gate = Gate(
  sign_in: SignIn(path: "/auth/sign-in", fallback_origin: "https://auth.yumemism.dev"),
  rules: [
    Rule(pages: [Prefix("/me")], except: [], checks: [
      SignedIn(fail: ToSignIn(status: 302, back: False)),
      Adult(fail: Deny(status: 403, body: "adult declaration required")),
    ]),
    Rule(pages: [Exact("/claim/:code")], except: [], checks: [
      SignedIn(fail: ToSignIn(status: 303, back: True)),
    ]),
  ],
  redirects: [
    Redirect(pages: [Exact("/")], when: WhenAdult, to: SafeParam(param: "returnTo", fallback: "/search")),
  ],
  frame_src: [Exact("/"), Exact("/about/external"), Exact("/for_stores/api/v1")],
  pageview: Pageview(
    pages: [
      Exact("/search"), Exact("/muse/:handle"), Exact("/muse/:handle/article"),
      Exact("/muse/:handle/article/:id"), Exact("/muse/:handle/space/:id"),
      Exact("/muse/:handle/schedule"), Exact("/muse/:handle/reviews"),
      Exact("/store/:handle"), Exact("/store/:handle/cast/:id"),
    ],
    endpoint: "/api/pageviews",
    source_param: "r",
    storage_key: "musearch:last-pageview",
  ),
)
```

- console の `src/gate.gleam`:

```gleam
import framework/gate.{
  Consent, Every, Exact, Gate, NoPageview, RedirectTo, Rule, SignIn, SignedIn,
  SubjectKind, ToSignIn,
}

pub const gate: gate.Gate = Gate(
  sign_in: SignIn(path: "/auth/sign-in", fallback_origin: ""),
  rules: [
    Rule(pages: [Every], except: [], checks: [SignedIn(fail: ToSignIn(status: 302, back: True))]),
    Rule(pages: [Every], except: [Exact("/switch"), Exact("/consent")], checks: [
      SubjectKind(kinds: ["store"], fail: RedirectTo("/switch")),
      Consent(kind: "use", fail: RedirectTo("/consent")),
    ]),
  ],
  redirects: [],
  frame_src: [],
  pageview: NoPageview,
)
```

- muses は宣言を置かない(入口の `Authenticated` + `Subjects([Muse])` から既定の門)
- `gates.mjs` は F6 の後に消せる(生成 shell 0.11.1 の export default が門を持つ)。F6 の前に 0.11.1 を採るなら、写しの `after/*/src/gates.mjs` の形(`serve` の dispatch に値の運びだけ)で置ける
- www の島 7 本に `pub fn app()` を足す(muses / console と同じ形)。手書きの島 `reserve_flow_island` / `schedule_slots_island` は `components/` へ移して `app()` を持たせる。同意の 2 tag(`consent-give-use` / `-handling`)は `kind` / `version` の属性か component を 2 本に。これで ★ `client.gleam` / `client_ffi.mjs` / `web/browser_entry.mjs` は生成物の `priv/static/_yumemi/client.mjs` で置き換わる(面の build が生成物の `src/gen` で通った後)
- 空の検索:F6 r1(`75647a9`、読んだだけ)の `/search` の Page は `q` の Var をまだ宣言していない。宣言して `article_search.q: Option` が入れば、★ の `envWithSearchQuery` は消せる
- 名指しの残り:console の ★ `blob_copy*`(`roster_photo_put` の live module、Y1e 候補)

## WGy との重なり

`emit/front.gleam` で触ったのは `route_text` と `route_order`(新)、`shell_imports` の 1 行、`shell_runtime_text` の `renderPage` の頭 2 行・query の 1 行・export default、`emit` の files に 1 行(`gate_file`)、`gate_file` / `read_gate` / `gate_notes`(新、`shell_imports` の前)、`client_text` と `client_components` / `client_notes`(`island_components` を置き換え)。`yumemi_gen.gleam` は front の診断の列の 2 行。`api_routes` / `app.attached` の読み手 / `model.gleam` / `emit/entry.gleam` / back の emitter は触っていない。

## DDL

無し。

## 検証(コマンドと結果)

- root `gleam build`:exit 0、warning 1(既存の `framework/secret.gleam`)。`gen/build/gate/root-build-final.txt`
- `cd gen && gleam test`:**252 passed, no failures**(基線 241 + 新規 11、`gen/test/gate_test.gleam`)。`gen/build/gate/test-3.txt`
- `gleam format --check src test`:root / gen とも 0
- Article fixture ×2:exit 0、`diff -r` 0 行。tracked の生成物は byte 一致(本便で更新したのは `public` / `admin` の `shell.mjs` と新しい `gate.mjs`。`admin` は入口 `Authenticated` + `Subjects([Staff])` の既定の門が付く)
- 写し:上の表
