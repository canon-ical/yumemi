# results ── yumemi-012-y4(段 B:遷移を Navigation API に寄せて navigate.mjs を薄くする)

基点 `31db577`(BRIEF の commit、段 A の merge `087b2d8` の上)。branch `impl/012-y4`。証跡は `build/012-y4-*`(git の外)。musearch の写しは `.scratch/musearch`(after、yumemi = 本作業木)と `.scratch/musearch-base`(before、yumemi = `087b2d8` の `git archive`)で、どちらも origin/main `1b0244412` の `git archive` に Y1 と同じ名前の置き換え(`import framework/<module>`・`"framework/<module>`・JS の `yumemi/framework/`、2238 file・5022 行、2 つの写しで同じ diff)。写しは検収の後に捨てた。

## したこと

- **navigate.mjs**(`src/yumemi/front/navigate.mjs`):click の横取り・`pushState` / `replaceState` / `popstate`・表示中の印 `shown`・`history.state` の印・scroll の当て直し・`hashTarget`・`AbortController`・pageview の送り(`counted`・`pageviewPayload`・`sendPageview`)・`yumemi-navigated` を外した。`navigation` の `navigate` イベントを `accept` で判定して `event.intercept({handler})` で取る
  - 取るもの:利用者が起こした push / replace(`userInitiated`)、traverse、`reload()` の印(`info.yumemi === "reload"`)の付いた reload。`canIntercept` が真で、`hashChange`・`downloadRequest`・`formData`(POST)・`defaultPrevented` でなく、同じ origin で、今の頁と行き先が route 表に当たり CSP が今の document の CSP と同じもの(0.11.15 の判定のまま)
  - 取らないもの:ブラウザがそのまま扱う。ただし同じ document の中の traverse で表に当たらない行き先(`stale`)は、取って頁の読み込みで開き直す(取らないと URL だけ替わり中身が前の頁のまま残る。0.11.15 の popstate の `load(url, true)` に当たる)
  - 取れない応答は `location.replace(url)`(URL は取った時点で行き先に替わっているので、履歴を積まない)。scripted な遷移なので取られない
  - Navigation API の無い browser(`navigation.addEventListener` と `NavigateEvent.prototype.intercept` の両方が要る、`supported()`)では `start` が何もしない。`reload()` は頁の読み込み
  - scroll と focus は `intercept()` の既定。**reload だけ `scroll: "manual"`**(下の「実測で見つけて直したこと」)
  - pageview の印:head の差分で `<meta name="yumemi-pageview">` を毎回「同じでない」鍵にし、前の頁の印は commit で外れ、来た頁の印が入る。`navigatesuccess` の時点で印は来た頁のものだけ
- **生成器**(`emit/front.gleam`):`navigation` から pageview の欄(`endpoint`・`source`・`key`)を外した(CSP の行は触っていない)。`client_text` は受ける変数の名を `pageview` → `options` にしただけ。import の行・`startNavigation({ routes, boot[, csp] })`・`reloadPage()` の名と引数は同じ
- **README**:「Client navigation」の節を現物に直した(0.12 の Navigation API・取るもの / 取らないもの・無い browser・scroll と focus・取り直し・pageview は印だけ・`yumemi-navigated` は無い)。0.11.4 の変更履歴の行は歴史なので残した
- fixture(`gen/fixtures/article`)は生成し直していない。回すと 74 file が変わり(Y1 の名前の替えの後に生成し直されていない分の hash と import の並び)、本便の差分が埋もれるため。merge のとき鷹野が生成し直す前提(BRIEF の持ち場)

## 実測で見つけて直したこと

- **書いた後の取り直しで scroll が頭へ飛んだ(374 → 0)。**`intercept()` の reload の既定(`after-transition`)は entry の保存位置へ戻すが、位置は entry を離れる時にしか保存されないので、離れていない取り直しでは頁の頭になる。reload だけ `scroll: "manual"` にして、差し替えの前後で位置を触らせない形にした。直した後 374 → 374(`build/012-y4-probe-after.txt` の reload-after-write)

## 73 の 16 の責務の行き先

| # | 責務 | 行き先 |
|---|---|---|
| 1 | click の横取りと行き先の判定 | Navigation API(navigate イベントの `canIntercept`・`hashChange`・`downloadRequest`・`formData`・`userInitiated`)。route と CSP の判定は framework の `accept` |
| 2 | route の照合 | framework(`matches`・`policy`。門との共有は段 C) |
| 3 | CSP の照合 | framework(`policy`・`samePolicy`、0.11.15 のまま) |
| 4 | 1 回の fetch と落とし方 | framework(`swap`)。中断は Navigation API(`event.signal`) |
| 5 | 差し替えてよいかの判定 | framework(`swappable`、given の条件も残す。Y3 で外れる) |
| 6 | head の差分 | framework(`common`・`stage`、0.11.15 のまま) |
| 7 | stylesheet の先読みと待ち | framework(`stage`、0.11.15 のまま) |
| 8 | lang と body の差し替え | framework(`stage` の `commit`) |
| 9 | 履歴と戻る・進む | Navigation API(`pushState`・`replaceState`・`popstate`・`shown`・`history.state` の印を外した)。表に当たらない同じ document の traverse だけ framework が頁の読み込みへ |
| 10 | scroll | Navigation API(`scroll` の既定)。reload だけ `manual` |
| 11 | focus | Navigation API(`focusReset` の既定) |
| 12 | 島の再起動 | framework(差し替えの後に `boot()`、今の形のまま) |
| 13 | pageview の印と送り | 印は framework(差し替えで毎回来た頁の印に替える)。送りは外した(Y5 の送り手) |
| 14 | 書いた後の取り直し | Navigation API の reload を横取り(`navigation.reload({info})` → `accept` が印を見て取る) |
| 15 | 遷移の合図 `yumemi-navigated` | 要らない(`navigatesuccess`) |
| 16 | # の扱い | Navigation API(同じ頁の # は `hashChange` でブラウザ、行き先の # は push の scroll の既定)。`hashTarget` を外した |

## 行数

- navigate.mjs:377 → 326 行。comment と空行を除くと 292 → 231 行(頭の注釈は 0.12 の形の説明で 26 → 36 行に増えた)
- 自前の履歴と scroll の処理(`pushState`・`replaceState`・`popstate`・`scrollTo`・`scrollIntoView`)は 0 個(`grep` で注釈の外に出現なし)。残したのは reload の `scroll: "manual"` の指定 1 つだけ(理由は上)

## 検収

- **root `gleam test`**:before `Framework checks passed: 25 groups`・`345 passed, no failures`(`build/012-y4-test-before.txt`)、after `25 groups`・`346 passed, no failures`(`build/012-y4-test-after.txt`)。+1 は新しい `yumemi_012_y4_test`。`gleam format --check src test` 0(`build/012-y4-fmt.txt`)
- **期待値を書き換えた test**

  | test | 変えたこと | 理由 |
  |---|---|---|
  | `yumemi_fix_0114_test.navigation_intercepts_only_routed_plain_clicks_test` | 20 → 19 項。入力を click から navigate イベントに。外した 8 項:修飾キー・中ボタン・`target=_blank`(ブラウザが別の文書で開くのでこの文書に navigate が届かない)、壊れた #・#(`hashTarget` を外した)、`counted`・payload 2 項(送りを外した)。足した 7 項:`canIntercept` 偽・scripted な push・# だけ・POST の form・traverse・印の付いた reload・印の無い reload | click の横取りを Navigation API に渡した |
  | `yumemi_fix_0114_test.navigation_keeps_counted_pages_and_passes_pageview_test` | 期待の `startNavigation(...)` から `pageview: {..}` を外した | navigate は送らない(BRIEF 8)。Y5 も同じ関数の pageview の行を消す |
  | `yumemi_01115_test.navigation_follows_page_csp_test` | 18 項のまま。`intercept(click(..))` を `accept(navigate イベント)` に | 判定の入口の形が替わった。CSP の判定の中身は同じ |
  | `yumemi_01115_test.navigation_stage_keeps_head_and_waits_for_stylesheets_test` | 25 → 28 項(印が commit まで前の頁のまま・来た頁の印に替わる・来た頁に無ければ外れる) | pageview の印の約束(BRIEF 6) |

- 新しい test `yumemi_012_y4_test.navigation_goes_through_navigation_api_test`(18 項、偽の `navigation`・`NavigateEvent`・location・fetch を子の node で):無い browser で何もしない・取り直しは頁の読み込み / 利用者の push を取る・scripted な push と表に無い push と印の無い reload は取らない / `reload()` が `navigation.reload` に印を付ける・その reload を `scroll: "manual"` で取る・push は `after-transition` / 表に当たらない同じ document の traverse は `location.replace` / 別の document の traverse は取らない / fetch に `x-yumemi-navigate: 1` と `event.signal` / redirect と通信の失敗は `location.replace` / 中断は何もしない / 表に当たらない頁の取り直しは `location.assign`

## musearch の写し

- **生成**:api の package から `gleam run -m yumemi/gen -- . ..`。before 停止コード 0・2 回目 `git status` 0 行(`build/012-y4-ms-gen-base{1,2}.txt`。1 回目は Hex の rate limit で落ち、60 秒おいて回し直し)。after 停止コード 0・2 回目 0 行。navigate.mjs を直した後に回し直し(`-new3`)、もう 1 回で 0 行(`-new4`)
- **基点との差**(`build/012-y4-ms-cmp.txt`、`.git`・`node_modules`・`build`・build の出力の `fonts` / `brand`・写しの外の `.claude` を除く):5 package の `gleam.toml` と `manifest.toml`(yumemi の path の違い)と、4 面の `priv/static/_yumemi/client.mjs` だけ。client.mjs の差は bundle の navigate.mjs の部分と `start(...)` の行の `pageview: {..}` が消えたことだけ(`build/012-y4-ms-client-www.diff`)
- **4 面 `npm run build`**:www・muses・console・admin すべて EXIT 0(`build/012-y4-ms-build-*.txt`。console・admin は 1 回目が Hex の rate limit、回し直しで 0)
- **4 面 `npm test`**:muses 475/475、console 89/89、admin 21/21、**www 427/428**(`build/012-y4-ms-test-*.txt`)
  - 落ちた 1 本:`www/test/s-4c-heaven-widget.test.mjs` の `nv-4 the generated client routes every page with one and the same CSP`。生成の client.mjs を正規表現 `boot, csp: (\{[^}]*\}),` で読んでいて、`csp` の後ろの `,`(後ろに `pageview` が続いていた)を要る。pageview の欄を外したので `csp: {..} });` になり当たらない。**pageview の欄を外したこと(BRIEF 8)による期待どおりの落ち**。写しで `,` を `[, ]` にすると 6/6 pass(`build/012-y4-ms-test-www-nv4-relaxed.txt`、写しは戻した)。musearch が 0.12 に上げる便で正規表現を直す
  - client の遷移の pageview の送りに依る test は落ちなかった(www の test は生成物の字と island を見ていて、送りを走らせるものは無い)
- api の `npm test` は回していない(api は生成の Out・SQL に差が無く、本便は front の遷移だけ)。auth は触っていない

## 実測(電話相当、Chromium headless)

- 写し:`build/012-y4-probe.mjs`・`build/012-y4-serve.mjs`(0.11.15 の `01115-probe.mjs`・`01115-serve.mjs` の写し。musearch の写しの root を env で受け、足した確かめと body の差し替えの時刻を足した)。360×780・DPR 2・`isMobile`・`hasTouch`、CDP で RTT 150ms・下り 1.6Mbps・上り 750kbps・CPU 4 倍。嬢は stub の `bg`。before = `.scratch/musearch-base`、after = `.scratch/musearch`。各 3 回
- `body` は tap から body の要素が替わるまで(MutationObserver)。`url` は tap から URL が替わるまで(rAF ごと)

  | 移動 | before:遷移 | before:素の時間 | before:body | **after:遷移** | **after:素の時間** | after:body | after:url |
  |---|---|---|---|---|---|---|---|
  | TOP → 記事 1 件 | client ×3 | 0 / 0 / 0ms | 766 / 767 / 759ms | **client ×3** | **0 / 0 / 0ms** | 769 / 765 / 748ms | 119 / 115 / 101ms |
  | TOP → スケジュール | client ×3 | 0 / 0 / 0ms | 285 / 290 / 286ms | **client ×3** | **0 / 0 / 0ms** | 292 / 283 / 290ms | 114 / 110 / 109ms |
  | スケジュール → 記事 | client ×3 | 0 / 0 / 0ms | 291 / 299 / 282ms | **client ×3** | **0 / 0 / 0ms** | 281 / 287 / 295ms | 110 / 111 / 121ms |

  after の 9 回とも pageerror・console の error 0、移動中の Document の要求 0(`build/012-y4-probe-{before,after}.{txt,json}`)
- **足した確かめ(after)**
  - `navigatesuccess` の時点:9 回とも pageview の印 meta が 1 つ、`navigation.transition.navigationType` は `push`
  - push の後の `document.activeElement`:9 回とも `body`(before も `body`)
  - Navigation API を消した browser(init script で `window.navigation` を undefined、`NavigateEvent` を delete):3 通りとも頁の読み込み(window の印が消え、Document の要求が行き先 1 本)、error 0。before は同じ条件で client の遷移のまま(before は Navigation API を使わない)
  - CSP の違う頁(serve の写しで `/muse/bg/schedule` の応答の CSP の header だけを別の値に):TOP → スケジュールは navigate の fetch 1 回の後に頁の読み込み、error 0。route の表の CSP が違う頁は musearch の www に無い(全 Page が同じ `frame_src`)ので、表で落とす枝は unit test(`navigation_follows_page_csp_test`)で見た
  - scroll して移って戻る:TOP(高さ 1047px)を 267px まで scroll、見えている link(`/muse/bg/schedule`)を tap、移った先は scrollY 0・activeElement `body`、`page.goBack()` で戻ると scrollY 267・client の遷移のまま・`navigatesuccess` の種類は `traverse`、error 0。**before も 267 に戻った**(この頁と行き先の高さでは before でも崩れない。崩れる組み合わせは見つけていない)
  - 移った先の島:9 回とも custom element は全部 define 済みで中身あり(記事 2 種 `report-file`・`nav-account`、スケジュール 3 種に `schedule-slots`、記事一覧 3 種に `article-lead-fit`)。購読のボタンは stub の session が anonymous なので頁に出ず、見ていない
  - 書いた後の取り直し:スケジュールで 374px まで scroll、`schedule-slots`(After `ReloadPage`)に `yumemi-done` を出す → navigate の fetch 1 回・body が替わる・`history.length` 2 → 2・scrollY 374 → 374・window の印が残る・`navigationType` は `reload`・印 meta 1 つ、error 0

## Y5 との約束(BRIEF 6)

- `navigatesuccess` の時点で、来た頁の `<meta name="yumemi-pageview">` が今の document にあり、前の頁の印は残らない(stage の差分で印を毎回替える。unit test 3 項と実測 9 回 + traverse + reload)
- 種類は `navigation.transition.navigationType` で見える:click は `push`、戻る・進むは `traverse`、書いた後の取り直しは `reload`(実測で 3 種とも見た)
- navigate.mjs は送らない。本便の後・Y5 の merge の前の main では client の遷移の pageview は送られない
- (柏木 ゲート 2 で追記)`navigatesuccess` は navigate.mjs が取らない同じ document の移動(頁の中の #・`history.pushState` / `replaceState`)でも出る。そのとき `navigation.transition` は null で、今の頁の印は残ったまま。送り手は `navigation.transition` が null でない時だけ数える(Chromium 153 の小さな頁で、client の遷移の後の # の移動の `navigatesuccess` が transition null・印 1 つ(来た頁のもの)、島の `pushState` の `navigatesuccess` も transition null、`build/012-y4-k-harness-after.json`)

## musearch で `yumemi-navigated` を聞いている所(段 D の材料)

- `muses/src/components/muse_nav_ffi.mjs:7-13`:`document.addEventListener("yumemi-navigated", tell)` でナビの選択中の印を付け替えている。0.12 では出ないので、`navigation.addEventListener("navigatesuccess", ..)` に替える
- ほかに `yumemi-navigated` を聞く所は musearch の 4 面の src(生成物を除く)に無い(`grep`)
- (柏木 ゲート 2 で追記)4 面の外、`docs/` の Playwright の台本 7 本が聞いている(origin/main `1b0244412`):`docs/acceptance-2b/run.mjs:404`・`docs/acceptance-2c/run.mjs:151`・`docs/acceptance-3-2/run.mjs:234`・`docs/acceptance-batch2/run.mjs:193`・`docs/acceptance-s-3/run.mjs:93`・`docs/mr-1/verify/run.mjs:124`・`docs/nv-4/evidence/probe.mjs:44`。前の 6 本は島の送りの後に `'load'` と `'yumemi-navigated'` の早い方を待つ形で、`.forgejo/workflows/playwright.yml` が path で走らせる。0.12 では書いた後の取り直しがどちらも出さないので、待ちが打ち切りまで延びる。`navigation` の `navigatesuccess` を待つ形に替える
- `www/test/s-4c-heaven-widget.test.mjs:114` の正規表現(上)

## 振る舞いが替わったところ(0.11.15 との違い)

- **URL は取った時点で替わる。**`intercept()` は navigate の時点で URL を確定させるので、body が替わるまでの間(実測で約 170〜650ms)は URL が行き先で中身が前の頁。0.11.15 は body を替えた後に `pushState` していた。その間のブラウザの読み込み中の表示は見ていない
- **利用者の GET の form も取る。**0.11.15 は click だけを取っていた。行き先が route 表に当たり CSP が同じなら link と同じ道を通る。POST の form は取らない
- **scripted な遷移(`location.assign` ほか)と `location.reload()` は今までどおり取らない**(`userInitiated` と reload の印で見る)。島の `location.assign` は頁の読み込みのまま
- 表に当たらない同じ document の traverse は頁の読み込み(0.11.15 の popstate と同じ)

## 鷹野に返す点

1. URL が先に替わる(上)。iOS の実機でアドレスバーと中身のずれが気になるかは鷹野の検収で見てほしい
2. 取れないときの 2 回の GET は直していない(実測の CSP の違う頁で navigate の fetch 1 回 + Document 1 回)。Navigation API の `precommitHandler` で URL の確定を遅らせれば 1 回目の応答を使える形は考えられるが、Baseline でないので入れていない

## 確かめたこと / 確かめていないこと

- 確かめたこと:上の root test・format・musearch の生成 2 回・4 面の build と test・電話相当の実測(before / after 各 9 回と足した確かめ)
- 確かめていないこと:
  - Firefox・Safari(Navigation API の実装の違い。実測は Chromium headless 153 だけ)、iOS の実機(BRIEF どおり撮っていない)
  - scroll が戻る・戻らないの差が before / after で出る組み合わせ(今回の頁では before も戻った)
  - focus の移り先の支援技術の読み上げ
  - given の島で差し替えを断る道(musearch の写しの頁に given の島が無い)
  - 購読のボタン(anonymous の stub では出ない)
  - api の `npm test`
