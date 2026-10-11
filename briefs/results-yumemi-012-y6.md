# results ── yumemi-012-y6(0.12 段 C、門・数える口・器・柵を publish の前に固める、真壁 r1、Opus 直書き)

基点 `e57bcf2`(段 B の 3 便を merge した main、BRIEF の commit `f7994b4` の上)。branch `impl/012-y6`。証跡は `build/012-y6-*`(git の外)。止め線(2 時間)の内に閉じた。版の行(`0.12.0-dev`)は触っていない。

## やったこと

1. **門の session の読みの失敗**(`emit/gate.gleam` の生成 JS):404 は `404 not found`、401 / 403 ほか 4xx は `403 forbidden`(今のまま)、**5xx・APP binding の例外・session の path が無いときは `503 unavailable`**。`readSession` が `cause`(`session read returned <status>` / 例外 / `session path is missing`)を持ち、`readFailure` が `console.error("yumemi gate: session read error", status, cause)` を出す
2. **CSP の `'self'`**(`emit/gate.gleam` の `csp_for`):宣言した各指令(`FrameSrc`・`ImgSrc`・`ConnectSrc`・`MediaSrc`)の先頭に `'self'` を 1 つ。外す口は無い。client の遷移の表は `csp_routes` を通るので同じ字(fixture `yumemi_fix_0114_test` の `startNavigation({.. csp: {..}})` も `'self'` 付きで揃う)
3. **`ToService`**(`server/http.mjs`):
   - Service の `requires` を受け口で評価する。`judge` の要件の評価を `unmetRequirement(s, module, args)` に切り出し、`judge` と受け口の両方が同じ関数を呼ぶ(`judge` の振る舞いは同じ)
   - 印の cookie は **句(`anyone` / `party`)と `requires` を通って Service に届く event で、かつ Service が `Carried(.., "browser", ..)` を持つとき**だけ焼く。生成の `http_runtime.mjs` の `pageviews` の sink に `browser: true|false` を足した(`emit/http.gleam` の `carries_browser`、`reader/cms` の同名の関数はこちらへ寄せた)
   - `phaseGates`・`suspended`・hook の `judge` / `write_gate` は今どおり見ない。README に書いた
4. **数える口の検査**:
   - 第 35 条:`FromQuery` の name に受け口の event の欄の名(`id`・`kind`・`client_at`・`path`・`prev`・`referrer_path`・`referrer_host`、`reader/gate.event_names`)を使うと exit 4
   - 第 36 条:`ToService` の Args に `id` が無ければ exit 3。欄の型を `emit/http` の decode の語彙で見て、event の値(文字列、`kind` は 3 値)から decode できなければ exit 4。通すのは `String`・値型(`['scalar',..]`)・hook(`arg_*`)、`client_at` は加えて `Datetime`、`kind` は加えて `initial`・`reload`・`spa` を全部持つ payload の無い列挙。`Option` は中身を見る。型から decode を導けない欄は既存の `decode を導けない` が止めるので二重に出さない
   - 第 37 条:`Store` の `fields` に `Path` が無ければ exit 3。受け口の `event.path??'/'` は外した
   - 受け口の想定外の失敗(SQL・Service の例外・設定の不足)は 202 のまま `console.error("yumemi pageview: event dropped", 面, error)`。黙るのは `fail` の status を持つ拒否(検査の段・Args の `invalid_argument`)と PostgreSQL の RAISE(`P0001`、Service の業務の失敗)。bot・先読み・形の外れ・`only` の外は今どおり黙って 202
5. **柵**:`attr.action` を `href` / `src` と同じ `url` の柵に。`css.Named` は `sketch_css.valid_font_family` を通らなければ `unset`。項(`,` 区切り)ごとに `var(--<[a-z0-9-]+>)`・引用符で囲んだ名(引用符・`\`・`;`・`{}`・`<>`・`()`・`/`・`*`・制御文字を持たない)・引用符の無い語(`[A-Za-z0-9_-]` を空白 1 つで繋ぐ)のどれか。`font_family` を `pub` にした(test が Y3 の消す `sketch_css.class` を通らずに見られるように)
6. **Args の `color.Color`**:`emit/http.gleam` の `shape_type` に `yumemi/front/color.Color` → `['color']`、`http.mjs` の `decodeArg` に `case 'color'`(`color.parse`、壊れた色は 400 `invalid_argument` と欄の名)。`http.mjs` は `../front/color.mjs` を直に import(生成の codec の export は触っていない)
7. **README の門の節**:失敗の文言 3 つ、CSP の `'self'`、第 35 条の予約の名、受け口の log、印の条件(`Store` / `ToService`)、第 37 条の `Path`、`ToService` の要件・句・飛ばすもの・第 36 条の `id` と型、82 §4 の英語の文案(「Who is responsible.」、最後の `only` の一文を含む ── 下の検収で確かめた)、`Colours in Args.`。要素の節の柵の一文に `action`、Style の表の `Named` の行に柵。`ToService` の段の「警告を 1 行出す」の一文(Y3)は触っていない
8. **shell の読みの失敗**(`emit/front.gleam` の `shell_runtime_text` の読みの行だけ):Page の読みの 5xx と `readFromApp` の例外は `503 unavailable`、`console.error("yumemi shell: root read error" | "widget read error", status, 本文 | error)`。403・404・他の 4xx は今どおり
9. fixture:`gen/fixtures/cms` と `gen/fixtures/article` を生成し直しただけ(門と shell の 8 file)。宣言は足していない ── 足した検査は fixture cms の写しを壊す test で、`Color` の Args も写しで見た(下)

## 検収

- **root `gleam test`**:before `388 passed`(`build/012-y6-test-before.txt`)→ after **`400 passed, no failures`**(`build/012-y6-test-after.txt`)。`gleam format --check src test` 0。`npm ci` は root で(`build/012-y6-npmci.txt`、esbuild の postinstall の allow-scripts の警告で exit 1 だが `added 2 packages`、test は通る)
- **期待値を書き換えた test**

| test | 理由 |
|---|---|
| `gate_test.gate_mjs_carries_rules_csp_and_expanded_pageview_routes_test` | CSP の字に `'self'`(どこまで 2) |
| `yumemi_fix_0114_test.navigation_carries_csp_pages_test` | client の遷移の表の CSP の字に `'self'`(同じ字を保つ) |
| `yumemi_012_y5_test.to_service_is_counted_as_escape_with_warning_test` | 写しの Args に `id: String` を足した(第 36 条で `id` 必須)。警告の期待の字(Y3)は触っていない |
| `yumemi_012_y5_test.generated_gate_has_no_inline_script_and_two_texts_test` | `readFailure` の 1 行の三項の字 → 404・503・403 の 3 行の字 |
| `yumemi_012_y5_test_ffi.mjs` の `gate_checks` | CSP 2 項に `'self'`、読みの 500 は `403 forbidden` → `503 unavailable`(console.error を捕まえて STDERR に出さない)。項の数 7 のまま |

- **新しい test** `test/yumemi_012_y6_test.gleam`(12 本)と `yumemi_012_y6_test_ffi.mjs`
- **fixture の生成**:cms・article を生成して停止コード 0、2 回目 停止コード 0・`git status` の差 0(`build/012-y6-gen-{cms,article}-{1,2}.txt`)。article の警告は基点からの 2 行(第 1・2 条の例外・生の CSS)だけ
- **足した検査の停止コード**(fixture cms の写しを壊す。`yumemi_012_y6_test`)

| 条 | 壊し方 | 停止コード | 文 |
|---|---|---|---|
| 35 | fields から `NavKind` / `ClientAt` / `Previous` / `Referrer` を外し、`FromQuery` の name を `kind` / `client_at` / `prev` / `referrer_host` に | 4(宣言の矛盾) | `FromQuery の name \`kind\` は [a-z][a-z0-9_]* で、受け口の event の欄の名(id・kind・…)でない`(「2 つある」は出ない) |
| 36 | `ToService` の Args に `id` が無い | 3(宣言の不足) | `ToService("page_resolve"): Args に欄 \`id\` が無い(event の id で再送を見分ける)` |
| 36 | Args の `kind: Int` / `kind: Bool` / `client_at: time.Date` / `path: Int` / `source_key: option.Option(Int)`、`kind` の列挙が `Initial | Reload` だけ | 4 | `Args の欄 \`kind\` の型を event の値から decode できない(…)` |
| 36(通す) | musearch の形:`id`・`path` を値型、`client_at: time.Datetime`、`kind: NavKind`(3 値の列挙)、`prev`・`referrer_*`・`source_key` を `Option(値型)` / `Option(String)` | 0 | 警告の `ToService` 1 行だけ |
| 37 | `Store` の fields から `Path` を外す | 3 | `public/gate: pageview の Store の fields に Path が無い(器は path ごとに数える)` |
| Color | `article_create` の Args に `accent: color.Color` | 0 | 生成の `http_runtime.mjs` に `['accent',['color']]` |

- **門(fixture cms の生成 `gate.mjs`、node、`gate_checks` 8 項)**:読みの 404 → `404 not found`(log 0)、`/status` の申告の rule で読みの 401 → `403 forbidden`(log 0)、500 → `503 unavailable` と log `yumemi gate: session read error 500 session read returned 500`、502 → 503、APP の例外 → 503 と log に ` 502 ` と `binding exploded`、session の path が無い門 → 503 と `session path is missing`、`/article/a` と `/status` の CSP の字(各指令に `'self'` 1 つ)
- **CSP(Chromium 153.0.8010.12、庵野の台を `build/012-y6-check/` に写し、combo を本便の生成器で生成し直して public を `gleam build`)**:`build/012-y6-csp.txt`(script `build/012-y6-check/csp.mjs`)8 項 ok ── `/status`(`connect-src 'self' https://api.example; media-src 'self' https://media.example`)で beacon が受け口に届く(`initial` 1 件)、`#to-status` の click で document の読み込み無し・`x-yumemi-navigate` の fetch・`window.__s` 保持・`spa` の beacon、`/article/a?theme=img`(`img-src 'self' https://img.example`)で `/media/w1600/blob-key` が `loaded`、`/article/a` → `/article/b` の client の遷移が保たれる、console に CSP の違反 0。`/status` の `<video src="/media/clip">` は受け口まで届いた(server の log に `/media/clip`、PNG を返すので `MEDIA_ERR_SRC_NOT_SUPPORTED`)
  - **同じ script を庵野の基点の combo に当てると 7 項 NG**(`build/012-y6-csp-before.txt`):beacon 0、`/status` は document の読み込みに落ちる、`/media/...` は `blocked/error`、console に `violates the following Content Security Policy directive: "connect-src https://api.example"`。× の 3 つの再現と逆を同じ台で見た
- **shell(combo の生成 `shell.mjs`、node)**:`build/012-y6-shell503.txt` 5 項 ok ── root の読みの 500 → 503 `unavailable` と log `yumemi shell: root read error 500 db down`、502 → 503、APP の例外 → 503 と log、403 → `forbidden`(log 0)、404 → `not found`(log 0)
- **受け口(node、`receiver_checks` 13 項)**:`requires: [Consented("analytics")]` の Service は同意の無い party と匿名で届かず `Set-Cookie` 無し、同意のある party で届き印を焼く。`requires: [Declared("adult")]` は申告が無ければ届かず cookie 無し。`browser: false` の Service は届くが `Set-Cookie` 無し・`s.browser` null。`browser: true` は届いて印。`party` の句だけの Service に匿名は届かず cookie 無し。`Store` の SQL が落ちる(`42P01`)と 202 と log 1、bot の UA・`Sec-Purpose: prefetch`・形の外れは log 0。Service の例外は 202 と log 1。`kind: 1` の event は log 0。Args の `Color` は `#AABBCC` → `#aabbcc`、`red` は 400 `{"code":"invalid_argument","field":"accent"}` で Service に届かない
- **`only` の一文の確かめ**(使い捨ての PG 16、port 55591、`build/012-y6-only.txt`、script `build/012-y6-only.mjs`):fixture cms の生成 DDL を当て(`build/012-y6-ddl-apply.txt`)、`only: [WhenDeclared("adult")]` の `Store` の受け口に、申告の前に 2 回送って 202・`Set-Cookie` 0・`pageview_mark` 0 行・`pageview_event` 0 行。`Declare`(`/api/declare/adult`)で cookie、その cookie で送って 202・event 1 行(mark は申告の印)・mark 1・visit 1。PG は止めて data を消した。→ README に 82 の最後の一文を入れた
- **柵**:`attr.action` の `javascript:alert(1)`・`JaVaScript:`・先頭の空白・先頭のタブ・`data:text/html,x` は `<form></form>`、`/search`・`search?q=a`・`http://`・`https://` は字のまま。`css.Named` の `x;} body{color:red`・`x;}`・`a</style><script>`・`"Noto Sans JP"; color: red`・`var(--x);}`・`var(--X)`・`"a\"b"`・`url(x)`・`a /* c */`・空・`a,,b` は `unset`、`var(--ma-font-ui)`・`var(--ma-article-font)`・`"Noto Sans JP", sans-serif`・`'Hiragino Sans', system-ui`・`"ヒラギノ角ゴ ProN", serif`・`Noto Sans JP` は字のまま(既存の `yumemi_test` の 2 つの `Named` も通る)
- **musearch の写し**(origin/main `1b0244412` の `git archive` を `.scratch/musearch`、Y1 の名前の置き換え 2238 file、Y5 の宣言の書き換え `yumemi-012-y5/build/012-y5-ms-star.diff` を `patch -p0` でそのまま、5 package を本作業木への path 依存、node_modules は手元への symlink)。api の package から全面を生成:
  - **停止コード 4**(`build/012-y6-ms-gen1.txt`)。止めているのは段 B の Y2 の条(第 1 条 312・第 27 条 7・第 28 条 7・第 29 条 8 ── musearch の ★ が 0.11 の lustre のまま)と、path 依存の一時 package の build の失敗(exit 1、4 面)。**基点 `e57bcf2` の生成器で同じ写しを回しても停止コード 4 で、診断の行は exit 1 の 4 行(基点は Hex の rate limit、本便は一時 package に simplifile が無い)を除いて同じ**(`build/012-y6-ms-gen-base.txt`、差 `build/012-y6-ms-notes-diff.txt`)。本便の替えが足した診断は 0
  - 第 36 条の型の突き合わせで `pageview_record`(`id: PageViewId`・`client_at: Datetime`・`kind: page_view.NavKind`・`path: Path`・`Option` 4 つ)は止まらない(第 35〜37 条と `decode を導けない` の行は 0)。生成の `http_runtime.mjs` の sink は `{type:'service',service:'pageview_record',browser:true}`
  - 警告の `www: 逃げ道 ToService を 1 つ使っている(…)` 1 行
  - www の生成 `gate.mjs` の CSP 37 route の全部が `frame-src 'self' https://blogparts.cityheaven.net https://challenges.cloudflare.com`
  - 写し・基点の archive は捨てた(`.scratch/` は空)

## 51 v6 に足す行

- **失敗の文言**(r2 で全部並べる形に直した):門と生成の shell が自分で返す本文はこれで全部(`Fail` の `RedirectBack`・`ToSignIn`・`Deny` の本文は app の字)
  - 503 `unavailable`:session の読み(門・shell)と Page の読み(shell)の 5xx・APP binding の例外・session の本文が JSON でない・門に session の path が無い。401・403・匿名の頁に畳まない。元の status と原因は `console.error`。門は rule も redirect も当たらない頁で読めなかったら「読んでいない」として渡し、session を要る頁では shell が読み直す
  - 401 `unauthorized`(shell):`Option` でない session の欄に主体が無い(匿名、または読みが 4xx)。`Option` の欄は `None` で頁を返す
  - 403 `forbidden`:門の権限の拒否(主体の不一致、check の上で読みが 404 以外の 4xx。`signed-in` の 401・403 は `Fail` へ)、Page の読みの 403
  - 404 `not found`:check の上で門の読みが 404、root の Page の読みの 404、頁が当たらず `SVELTE` も無い(widget の 404 は `None`)
  - `<status>` `root read failed` / `widget read failed`(shell):Page の読みのほかの 4xx。status は読みの status
  - 500 `PUBLIC_<NAME>_ORIGIN` / `PUBLIC_IDP_ORIGIN`(shell):頁が読む origin の変数が無いか空。本文は変数の名
  - 500 `invalid variable source`(shell):shell の知らない変数の出どころ(生成器の誤り)
- **CSP の宣言**:生成器が宣言した各指令(`FrameSrc`・`ImgSrc`・`ConnectSrc`・`MediaSrc`)の先頭に `'self'` を 1 つ足す。外す口は 0.12 で持たない。client の遷移の表も同じ字
- **数える口(`ToService`)**:受け口の検査は 1(欄)・3(bot と監視)・4(先読み)と `only`、句(`anyone` / `party`)、**Service の `requires`**。`phaseGates`・`suspended`・hook の `judge` / `write_gate` は見ない。印の cookie は Service が `Carried(.., "browser", ..)` を持ち、event が句と `requires` を通って Service に届くときだけ
- **第 36 条**:`ToService` の Args は `id` を持つ(無ければ 3)。欄の型は event の値から decode できる(`String`・値型・`arg_*` hook、`client_at` は `Datetime` も、`kind` は 3 値を全部持つ列挙も。`Option` は中身。外れれば 4)。Service の `allow` に `Anyone` か `Party` の句が要る(無ければ 3。受け口はこの 2 つの句でしか event を通さない、r2)
- **第 35 条**:`FromQuery` の name は受け口の event の欄の名(`id`・`kind`・`client_at`・`path`・`prev`・`referrer_path`・`referrer_host`)でない(外れれば 4)
- **第 37 条**:`Store` の `fields` は `Path` を持つ(無ければ 3)
- **受け口の失敗**:応答は常に 202。想定外の失敗(SQL・Service の例外・設定の不足)は `console.error`、bot・先読み・形の外れ・条件の外・`fail` の拒否・Service の RAISE(P0001)は黙る
- **属性の型**:`attr.action` は `href` / `src` と同じ scheme の柵(http・https・mailto・tel・相対)
- **Css の語彙**:`Named` の書体の名は項ごとに `var(--name)`・引用符の名・引用符の無い語のどれか。合わなければ `unset`(`Hex`・`Token` と同じ)
- **Service の Args**:`color.Color`(と `Option(Color)`)を decode する(`color.parse`)。壊れた色は 400 `invalid_argument`

## BRIEF との食い違い・判断したこと

- **musearch の写しの停止コード 0 は出せなかった**。止めるのは段 B の Y2 の第 1・27・28・29 条で、基点の生成器でも同じ診断(上)。musearch の ★ が 0.12 の要素の木に移るのは段 D。本便の確かめは「本便が足した診断が 0、`pageview_record` が第 36 条を通る、警告 1 行、CSP の `'self'`」までにした。4 面の `npm run build`・`npm test` は回していない
- **第 36 条の型の判定は emit/http の decode の語彙の字を読む**(`decodes_from_event`)。語彙を構造の型に組み直すと `shape_type` の全体に手が入るので、同じ module の中で字の頭を見る形にした。値型(`['scalar',..]`)は値型の parse の綴りまでは見ない(`kind` を値型で受けて `initial` を通さない綴りでも生成器は通す。実行で `invalid_argument` → 黙って 202)
- **受け口の黙る / 出すの線**:`fail(...)` の status を持つ error は検査の段の拒否として黙る。Args の decode の `invalid_argument` は「形の外れ」として黙る。Service の RAISE(P0001)は Service の業務の失敗(再送の検出を Service が RAISE で書く app で log が埋まらないように)として黙る
- **log の文**:元の本文 `session read failed` / `root read failed` は 0.11 の応答の本文で、Y5 の test が「生成物に無い」ことを見ている。log は `... read error` と別の綴りにした。shell の 5xx 以外の 4xx(401・422 ほか)の本文 `root read failed` / `widget read failed` は今のまま(本便は 5xx だけ)
- **shell の APP の例外**も 503 にした(BRIEF は 5xx だけ書くが、門は APP binding の例外を 503 にするので揃えた)。log の status は 502 と書く(門の `readSession` と同じ数)
- **`Store` の受け口で印の後に `browser` が無いとき**(`browser` の宣言が無い)は今まで黙って 202、本便から「設定の不足」として log。生成器が第 37 条で止める形なので実際には出ない
- 第 35 条の検査は今の `name == "id"` の分岐を表(`event_names`)に替えた。文言は「id でない」→「受け口の event の欄の名(…)でない」
- `sketch_css.font_family` を `pub` にした(test のため。名は変えていない)

## 確認できなかったこと

- musearch の 4 面の `npm run build`・`npm test`、api の `npm test`(写しの生成が停止コード 4 で止まるため。上)。musearch の門の Playwright の台本と CI(`.forgejo/workflows/playwright.yml`)は回していない。www の test の stub を grep した範囲(`status: 500` は「想定外の request」の既定の応答だけ)では、読みの 5xx を 403 と期待する test・`root read failed` を期待する test は見当たらなかった
- Cloudflare の本物の Worker での `console.error` の出方(node で見ただけ)
- `ToService` の受け口を本物の api の Worker と DB で通すこと(偽の spec の node で見た)
- 写しの path 依存の一時 package に simplifile が無いと出る exit 1(基点では Hex の rate limit で同じ段が落ちた)。Hex の版の yumemi に依存する面では起きない見込みだが、見ていない
- `MediaSrc` の `'self'` は `<video>` の request が server に届くこと(CSP で止まらないこと)まで。再生できる media は置いていない

## DDL

無し。器の表と関数(`db/framework/pageview.sql`)の字は変えていない(fixture cms の生成物に差 0)。確かめに使い捨ての PG(port 55591)へ当てただけで、staging・production には当てていない。

## r2(柏木の P1 2 件、真壁 Opus 直書き)

### やったこと

1. **P1-1 shell が自分で session を読む道**(`emit/front.gleam` の shell の読みの行):5xx は 503 `unavailable` と `console.error("yumemi shell: session read error", <status>, <本文>)`、APP binding の例外と本文が JSON でないのは 503 と `console.error(.., 502, <原因>)`。4xx と匿名は今どおり(必須の欄は 401 `unauthorized`、`Option` の欄は匿名の頁)
2. **P1-1 門の受け渡し**(`emit/gate.gleam`):読みの 5xx(例外・path 無しを含む)は shell へ `session: undefined`(読んでいない)で渡し、`null`(匿名)にしない。session を要る頁では shell が読み直し、それも読めなければ 503。redirect の当たる頁で読めなかったら門が 503(redirect の判断ができないので、匿名として redirect を飛ばさない)。読みの本文が JSON でないのも読めなかった方へ(`.catch(() => null)` を外した)
3. **P1-2 第 36 条**(`reader/cms.gleam`):`ToService` の Service の `allow` に `Anyone` か `Party` の句が無ければ exit 3。停止コードは第 36 条の `id` 無し(3、宣言の不足)に揃えた。読めない句(`UnreadClause`、別に exit 4)があるときは足さない
4. README:「Failure texts」を本文の一覧(503・401・403・404・`<status> root/widget read failed`・500 `PUBLIC_*_ORIGIN`・500 `invalid variable source`)に。第 36 条の文に句の 1 行。results の「51 v6 に足す行」も同じ形に
5. fixture cms・article を生成し直した(門と shell の 8 file)

### 503 に替えた道(生成物 `gen/fixtures/cms/public/src/gen/` の行)

| 道 | 生成器 | 生成物 |
|---|---|---|
| shell の session 読みの例外・本文が JSON でない(前は匿名) | `src/yumemi/gen/emit/front.gleam:6686` | `shell.mjs:228` |
| shell の session 読みの 5xx(前は匿名、必須の欄なら 401) | `src/yumemi/gen/emit/front.gleam:6690` | `shell.mjs:232` |
| 門の読みの 5xx を rule の無い頁へ渡すとき(前は `null` = 匿名) | `src/yumemi/gen/emit/gate.gleam:463` | `gate.mjs:181-182` |
| 門の redirect の当たる頁で読みの 5xx(前は redirect を飛ばして頁) | `src/yumemi/gen/emit/gate.gleam:474` | `gate.mjs:192` |
| 門の読みの本文が JSON でない(前は匿名で check、403 や `Fail`) | `src/yumemi/gen/emit/gate.gleam:379` | `gate.mjs:88` |

### 検収

- root `gleam test`:before 400 passed(柏木の `build/kashiwagi-gate2-test.txt`)→ after **402 passed, no failures**(`build/r2-test-final.txt`)。足したのは `shell_session_read_5xx_is_unavailable_test`(11 項)と `to_service_needs_anyone_or_party_clause_test`(`Staff` だけの句で exit 3、`Party` で exit 0)
- **期待値を書き換えた test**:`gate_read_failures_are_not_found_forbidden_or_unavailable_test` の ok の数 8 → 12。足した 4 項(rule の無い頁の 5xx は `undefined` を渡す、4xx は `null` を渡す、本文が JSON でないのは 503、redirect だけの頁の 5xx は 503)の分。既存 8 項の判定の字は変えていない
- `gleam format --check src test`:exit 0
- fixture cms・article の生成を 4 回(r2 の 1・2 回目で門と shell の 8 file が替わり、checkpoint の後の 3・4 回目は停止コード 0、`git status` の差 0)。`build/r2-gen-*-{1..4}.txt`
- musearch の `pageview_record` の句は `allow.Anyone`(`musearch-3-8g/api/src/service/pageview_record.gleam:225`)なので新しい第 36 条には当たらない(字で見ただけ、生成はしていない)

### 判断したこと

- 門の読みの 5xx を rule も redirect も当たらない頁で 503 にはしなかった。その頁が session を要らなければ頁は返せる。要るなら shell が読み直して 503 になるので、「読めなかった」が匿名や 401 に化ける道は無い。読み直しで 1 回余分に APP を叩くのは失敗のときだけ
- 本文が JSON でない session の読み(200)は 5xx でも例外の外でもない形だが、shell は try の中で例外になるので 503 にし、門も同じに揃えた(匿名に畳まない)。門のこの 1 行は `readSession` の中で、BRIEF の「受け渡しの行だけ」を少し越える
- 句の検査の停止コードは 3。Service の Args に `id` が無いのと同じく「受け口が要る物を Service が持たない」の不足と読んだ

### しなかったこと

- 柏木の P2 の「後でよい」5 件、Y3 の file、README の「Who is responsible.」の段落の移動
