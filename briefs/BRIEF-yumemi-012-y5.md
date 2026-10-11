# 真壁[IM]へ ── yumemi 0.12 段 B(便 yumemi-012-y5、門と業務付き CMS の機能 ── 申告・同意・数える口と器・CSP・media の variant・失敗の文言、直書き、鷹野[PDM] 2026-10-12)

便: yumemi-012-y5(yumemi リポ、Opus 真壁の直書き、終端で柏木のゲートを便に 1 回 ── `KASHIWAGI_ROUTE=opus`)

**1 session で直に書く。細かい設計は真壁さんが決める(役員 人見 2026-10-12)。**作業木 `~/yumemism_repo/yumemi-012-y5`(branch `impl/012-y5`、基点は本 BRIEF の commit = 段 A の merge 後の forgejo main `<sha:鷹野が起動時に埋める>` の上)。記録は `briefs/results-yumemi-012-y5.md`、証跡は `build/012-y5-*`(git の外)。commit は `git-as makabe`、main に触らない。push・tag・Hex の publish は鷹野。**版の行(`0.12.0-dev`)に触らない。止め線は経過 2 時間 30 分。**

**並行の便:**同じ基点から Y2(`briefs/BRIEF-yumemi-012-y2.md`、要素の木と Css)と Y4(`briefs/BRIEF-yumemi-012-y4.md`、遷移)が別の作業木で走る。file の持ち場は下の「持ち場」と tech `_drafts/gleam-framework/81-stage-b-ownership.v0.md`。merge は Y2 → Y4 → Y5 の順で、本便が最後。

**親:**tech `_drafts/gleam-framework/51-front-types.v6.md` の「門」「数える口」「記録と集計の器」「ユニークの印」「申告」「同意」「CSP の宣言」「失敗の文言」「media の variant」「入口と SSR」と「生成器が止めるもの」の第 32〜40 条、`75-framework-app-boundary.v1.md`(二重計数の 7 通り・送り手を 1 つにする・申告の一般化で musearch が書き換える所)、`70-brief-front-rethink.md` 末尾の 2 節の段 5 の行と鷹野の How。

**親ゴール:**業務の CMS ならどのアプリでも要る機能(申告・同意・PV とユニーク・CSP・画像の variant)を framework が仕組みで持ち、名と値と条件だけを app が閉じた語彙で宣言する。別のアプリの Agent が、訪問の区切りや二重計数を毎回設計しない。`adult` の綴りは framework から消える。
- 障害:framework と生成器が musearch の名を焼いている ── `Adult`・`adult_declaration_missing`・`"adult declaration required"`(主体の食い違いでも返す)。session の読みが `use`・`handling` しか返さず、門に別の同意を書くと常に落ちる。runtime に `identity` の名の分岐がある
- 障害:二重計数を避ける仕組み(再送・bot・先読み・連打・2 tab・訪問の区切り)とユニークが musearch の ★ にあり、ユニークの印が成人の申告と同じ cookie の同じ判定に乗っている
- 障害:pageview の送り手が 2 本(門の inline の script と navigate.mjs)で、欄の組み立てと鎖が 2 か所にある。inline の script のせいで `script-src` を足せない
- 障害:CSP が `frame-src` の 1 指令で、入口と門の 2 か所に書く

## 現在地(段 A の merge 後の main。置き場は `src/yumemi/` と `src/yumemi/gen/`、fixture は段 A の置き場)
- 門は `Gate(sign_in, rules, redirects, frame_src, pageview)`、検査は `SignedIn`・`Adult`・`SubjectKind`・`Consent(kind)`、条件は `WhenAdult`・`WhenSignedIn`、数える口は `Pageview(pages, endpoint, source_param, storage_key)`(`src/yumemi/gate.gleam`)
- 要件は `Adult`・`Use`・`Handling`・`Identity(from:)`(`require.gleam`)、役は `DeclareBrowser`・`NeedsBrowser`、cookie は `BrowserCookie(cookie, key_binding, max_age_days, claim)`(`server.gleam`)
- runtime は `server/http.mjs` ── 返してよい符号の表(0.11.15 の 159 行)、`needs_browser`(315)、要件の判定(320-321)、申告と browser の id の発行(329-333)、session の読み(337)
- 生成器は `emit/gate.gleam`(inline の pageview の script 274-355、client の遷移の fetch には印の meta 538-540、文言 435-441)、`reader/gate.gleam`・`reader/server.gleam`・`emit/http.gleam`・`emit/entry.gleam`(`frame_src`)、`emit/front.gleam` の `gate_file`〜`gate_notes`・403 と 404 の文言(6781・6783)・client.mjs を出す条件(島か service worker のある面だけ)
- musearch では、記録・集計・二重計数の 2〜6 は ★ にある(`api/src/service/pageview_record.gleam`、`api/db/queries/verb/pageview_*.sql`、`api/src/http_hooks.mjs:99-109`、`api/src/service/metrics_rollup.gleam`)
- 門の `Pageview` と `BrowserCookie` を宣言した fixture は無い(75 v1 の確認できなかったこと 3)

## どこまで
1. **申告 `Declared(kind)`。**門の検査・`WhenDeclared(kind)`・要件・attached の役(`Declare`・`NeedsDeclared`)の 4 か所に同じ形で書け、`BrowserCookie` は `declarations: List(Declaration(kind, claim, max_age_days))` を持つ。失敗は 403 `{"code": "declaration_missing", "declaration": "<kind>"}`、session の読みは `declared: {<kind>: true}`、cookie が有効でも申告がその期間より古ければ「申告なし」。`framework/browser` の SQL は引数に kind を足す(SQL の鍵名は替えない)。第 32・33 条
2. **同意 `Consented(kind)` と `ConsentedFor(kind, subject)`。**門の `Consent` は `Consented` に改名、session の読みは party の持つ同意を全部 `consents: {<kind>: true}` で返し、失敗は `{"code": "consent_missing", "consent": "<kind>"}`。app は `src/server.gleam` の `pub const consents: List(String)` で種類を宣言し、綴りを生成器が止める。第 40 条
3. **数える口 `Pageview(pages, only, fields, sink)`。**欄は閉じた語彙(正規表現の文字列を受けない)、event の id は framework が常に足す、`storage_key` は framework が決める、訪問の窓 30 分と browser ごとの 60 件/分は決め打ち。**送り手は client 側の 1 つ**にし、門は頁の読み込みでも client の遷移の fetch でも印の meta だけを差す(inline の script は消える)。`pageview` を宣言した面には、島が無くても client.mjs を出す。送るのは `requestIdleCallback` の後、prerender の間は activation を待つ。NavKind は `initial`・`reload`・`spa`(戻る・進むも `spa`)。client の遷移の後は、Navigation API の `navigatesuccess` の時点で今の document の印 meta を見て送る(遷移の側は Y4 が「印が今の document にある」ことを保証し、自分では送らない。約束は 81)。送り手は新しい file(例 `src/yumemi/front/pageview.mjs`)に置き、navigate.mjs に触らない。第 34・35 条
4. **記録と集計の器 `Store(resolve, rollup_by, exclude_when)`。**framework が event・訪問・印の表と、PV・ユニーク・訪問数・回遊訪問数の日・月の集計を持つ。受け口は `<prefix>/_yumemi/pageviews` で応答は常に 202。二重計数の 1〜6(送り手が 1 つ・id・bot と監視・先読み・連打・2 tab の行ロック)を framework が持ち、7(本人と運営)は app が `exclude_when` で名指す。表の DDL は生成器が ▲ として吐き、集計の仕事は生成器が cron に足す。第 37 条
5. **`ToService(service)` は名前付きの逃げ道。**入口の検査(二重計数の 1〜5)を通した event を app の Service に渡し、Args は `fields` から組む型と突き合わせ(第 36 条)、印・party・主体は root に運ぶ。使った数を exit 0 の警告で面ごとに出し、`_diagnostics.txt` にも同じ数(Y2 の生の CSS の数と別の行でよい。1 行への統合は段 C)
6. **ユニークの印は数える口が焼き、申告に縛らない。**数える条件を満たした最初の event で、印の無い browser に印だけの cookie を焼く。後で申告すると同じ印に申告の欄が足される。`Store` か印の要る `ToService` を宣言したのに `browser` の宣言が無ければ止める(第 37 条)
7. **CSP は門の `csp: List(Csp(pages, directives))`。**指令は `FrameSrc`・`ImgSrc`・`ConnectSrc`・`MediaSrc`。入口 `Http`・`HttpApi` と門の `frame_src` は消える。`script-src` は入れない。client の遷移の可否(今の document と行き先の CSP の字が同じか)はそのまま効く。第 38 条
8. **media の variant。**app の `src/server.gleam` の `Media(path, variants, theme_background)` を生成器が読み、面ごとに `src/gen/media.gleam`(Variant の enum と `url(Blob, Variant) -> String`。key を `/` で割って各節を百分率符号化し `?v=<name>`)を吐く。第 39 条。生成の code は `emit/front.gleam` に足さず別の module に置き、`emit` の file の列には 1 行足すだけにする
9. **失敗の文言。**生成の shell と門が自分で返す本文は、403 の `"forbidden"` と 404 の `"not found"` だけにする(主体の食い違いも `"forbidden"`)
10. CMS の機能を全部宣言した fixture(面と back)を足す。README の門の節と、数える口・申告・同意・media の variant の契約の節を現物に直す

## 持ち場(並行の便との切り分け。全体は 81)
- **本便の file:**`src/yumemi/gate.gleam`・`require.gleam`・`server.gleam`・`entry.gleam`・`server/*.mjs`・`front/pageview.mjs`(新)、生成器の `reader/gate.gleam`・`reader/server.gleam`・`emit/gate.gleam`・`emit/entry.gleam`・`emit/http.gleam`(申告と同意)、back の生成で要る所(`emit/sql.gleam`・`emit/runtime.gleam`・`emit/back.gleam` ほか)、media の生成の新しい module
- **`emit/front.gleam` の中で本便が持つ所:**`gate_file`〜`gate_notes`、`emit` の client.mjs を出す条件と `gen/media` の 1 行、`shell_runtime_text` の 403・404 の文言 2 行、`navigation` の CSP の行(門の型の替えに合わせる)。`navigation` の pageview の行は消すだけ(Y4 も消す)
- **触らない:**`src/yumemi/front/navigate.mjs` と、`navigation` のほかの行と `client_text` の遷移の行(Y4)。`src/yumemi/front/` の el・html・attr・css・sketch_css・theme・color、`reader/front.gleam`、`emit/codec.gleam`・`emit/typing.gleam`、`emit/front.gleam` の SSR・CSS・頁の色・面の写し・島の登録(Y2)。`live.gleam` と生成の live module(Y3)
- `emit/http.gleam` は Y2 も `Color` を値の型にする分だけ触る。関数が別なら merge で解ける
- 既存の fixture は、門(`src/gate.gleam`)と back の `server.gleam`・Service の `requires` だけを書き換える。Block・Layout・Page・style・shell・components は触らない(Y2)
- test は `gate_test`・`yumemi_s1_test` とその ffi・`yumemi_fix_0114_test` の門と pageview の部分(`navigation_keeps_counted_pages_and_passes_pageview_test` は Y4 も直すので、本便は pageview の行を消すだけ)と、本便の新しい test
- 生成物(fixture の `src/gen/`・`priv/static/_yumemi/`・`_diagnostics.txt`・`db/queries/` の既定)の衝突は、merge のとき鷹野が ours で取って生成し直す。本便は最後に merge するので、source の衝突(`navigation` の CSP の行・`shell_runtime_text` の 2 行・生成器の入口の警告の呼び出しの見込み)は merge で Y2・Y4 の形に合わせる

## しないこと
media の配信・edge cache・purge・公開の述語を framework に移すこと(別の起案)。`gen/media` の `src`(`el.Src` を返す)と、頁の色の地の画像を `gen/media` で組むこと(Y2 の型の上に乗る。段 C の継ぎ目)。`script-src`、失敗の頁(404 を app の Page で持つ)、保存期間と purge、Turnstile と回数の上限。navigate.mjs、route の照合の共有。DB の schema 名・`db/queries/framework/` の名・SQL の鍵名を替えること。app の DB に DDL を当てること(鷹野の DDL の便)。musearch の source(写しだけ)と、musearch の数字を器へ移すこと(musearch は 0.12 では `ToService` に留まる)。版の行・tag・publish・push。

## 法の読み
**利用者の操作なしに識別子の cookie を焼くこと(どこまで 6)の法の読みは、鷹野が大橋[PJM]に確かめる。実装は止めない。**真壁さんは results に `## 印の cookie` の節を置き、焼く条件・cookie の名と属性(HttpOnly・Secure・SameSite・Max-Age)・payload の中身・外へ送らないことを 1 画面で書く(大橋への材料)。

## 失敗例(差し戻し)
- framework・runtime・生成器・README に `adult` の綴りが残る(fixture と test の app の値は除く)
- session の読みが `use`・`handling` だけを返す。`identity` の名の分岐が残る
- 欄に正規表現の文字列を受ける。id を app が書ける。`storage_key` を app が選べる
- 頁に inline の pageview の script が残る。送り手が 2 つになり、頁の読み込みで 2 回送る
- 器の DDL を本便が staging・production の DB に当てる。results に `## DDL` が無い
- 403 の本文に種類が無い。宣言に無い kind が compile を通り、実行で常に落ちる
- `ToService` が数えられない
- musearch の写しで、宣言の書き換え(下の検収の列)の外の手直しが ★ に要る。配った `_mb` が読めなくなる
- Y2・Y4 の持ち場の file・行を触る

## 検収
- root `gleam test` が通り、本数は基点から減っていない(before / after を results に。期待値を書き換えた test は名と理由を列で)。`gleam format --check` 0
- 足した fixture を生成して停止コード 0・2 回目の差 0。第 32〜40 条の 1 条ずつに止まる fixture か test が 1 つ以上あり、停止コードが 51 v6 の値
- **runtime(node):**`declaration_missing` と `consent_missing` の本文、session の読みの形(申告 2 種・同意 3 種)、期間の切れた申告は「申告なし」、宣言した任意の同意の種類が門で通る
- **器(使い捨ての PG、新しい port):**生成器が吐いた DDL を当て、受け口に event を送る ── bot の UA・`cf.verifiedBotCategory`・`Sec-Purpose: prefetch` は行を作らない、同じ id の再送は 1 行、1 分に 61 件目は書かない、2 本の同時(2 tab)で訪問が 1 つ、`exclude_when` が真の event は行があり数字から除く。集計の仕事で日・月の PV・ユニーク・訪問数・回遊訪問数が期待の値。終わったら PG を止めて消す
- **送り手(Chromium、足した fixture の面):**頁の読み込みで 1 回(`initial`)、reload で 1 回(`reload`)、HTML に inline の script が無い、宣言した欄だけが載り id が付く。client の遷移の 1 回は Y4 の merge の後に鷹野が確かめる ── 本便は test の中で `navigatesuccess` の合図と印 meta を置き、1 回だけ送ることを確かめる
- **失敗の文言:**生成物を grep して `adult` と musearch の文が 0、403 は `forbidden`・404 は `not found`
- **musearch の写し:**origin/main(`~/yumemism_repo/musearch`)を `.scratch/musearch` に置き、Y1 と同じ名前の置き換えに加えて宣言の書き換えだけをする ── 門の `Adult` → `Declared("adult", ..)`・`WhenAdult` → `WhenDeclared("adult")`・`pageview` → 新しい宣言(`ToService("pageview_record")`)・`frame_src` → `csp`、`requires: [Adult]` → `[Declared("adult")]`、`[Use]`・`[Use, Handling]`・`Identity(from:)` → `Consented`・`ConsentedFor`、`DeclareBrowser`・`NeedsBrowser`・`BrowserCookie` → 新しい形(`Declaration(kind: "adult", claim: "adult_declared_at", max_age_days: 395)`)、`consents` と `media` の宣言、`api/db/queries/framework/browser.sql` の引数、`api/src/media_runtime.mjs:333` と `muses/src/worker_entry.mjs:175` の綴り。api の package から全面を生成して停止コード 0、api の `npm test`(新しい port の PG)、4 面の `npm run build`・`npm test`。書き換えた file と行数、落ちた test と理由を results に。配った形の `_mb`(payload に `adult_declared_at` を持つ)を新しい runtime が「申告 adult あり」と読む test を 1 本。auth は触らない。写しは捨てる
- results に `## DDL`(生成器が吐いた DDL の全文と、app の DB に当てる便への申し送り)と `## 印の cookie`

## 鷹野の裁き(2026-10-12)
1. 識別子の cookie の法の読みは鷹野が大橋[PJM]の側に確かめる。答えの期限は段 C の 0.12.0 の publish の前で、本便の実装は止めない
2. musearch の `pageview_record` の Args を第 36 条に合わせるための、写しでの宣言の書き換え(Args と `Carried` の合わせ)は許す。書き換えた差は results に
3. 割らずに 1 便で通す。止め線は経過 2 時間 30 分
4. 段 B の 3 便の merge 順は Y2 → Y4 → Y5(Y2 が遅れたら Y4 を先に)。どの便も単独で閉じられない継ぎ目 7 つ(`el.Src` と `gen/media.src`、地の画像の URL、route の照合の共有、逃げ道の数えの統合、`boot` を外す、共存の外し、`el.dialog`)は段 C の Y3 に「段 B の継ぎ目」として載せる。
