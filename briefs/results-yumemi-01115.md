# results ── yumemi-01115(0.11.15、真壁 r1)

基点 `c59ceab`(BRIEF の commit、`4fc9153` の上)。branch `impl/01115`。証跡は `build/01115-*`(git の外)。musearch の写しは `.scratch/musearch`(musearch origin/main `76182ef45` の `git archive`、独立した git、4 面の `node_modules` は 01114 の写しから hardlink ── 4 面の `package-lock.json` は 01114 の写しと差 0)。基点の yumemi は `.scratch/yumemi-base`(`4fc9153` の `git archive`)。`.scratch/` は commit に入れていない。

## やったこと

- 版 0.11.15(`gleam.toml`・`gen/manifest.toml` の path 依存の行)
- **(1) Shell の `stylesheets: List(String)`**(`gen/src/yumemi_gen/reader/front.gleam`・`emit/front.gleam`)
  - 在れば 0.11.12 の要素(manifest・theme-color・icon・apple-touch-icon)の後ろに、並びの順で `<link rel="stylesheet" href="..">`。無い・`[]` は何も出さない(既存の const の出力は変えない)
  - List の literal でない・空の String や String でない要素は exit 3「stylesheets は空でない String の List の定数で書く」
- **(2) `swap` を head の差分と stylesheet の待ちに**(`src/framework/front/navigate.mjs` の `stage`・`common`)
  - 今の head と来た head(client の script を除く)を要素の鍵(要素は `outerHTML`、text は値)の最長共通部分で突き合わせ、当たる要素は**動かさずに残す**(作り直さないので読み直しの往復が出ない)。外れる要素は外し、新しい要素は来た頁の位置(後ろの「置いてある要素」の前)へ挿す ── 並びは来た頁と同じになる
  - 新しく足す head の stylesheet と、来た body にだけある stylesheet の写し(head に `data-yumemi-hold` で置く)を `media="not all"` で先に挿し、load / error(上限 3 秒)を待つ。待つ間は古い頁のまま。待ち終えたら media を戻し、外す要素を外し、body を替える。写しは body の側の `<link>` が読み終えたら外す。待つ間に次の click が来たら(abort)先に挿したものを外す
  - 来た head にも在る href の body の stylesheet は写しを置かない
- **(3) route の表に Page ごとの CSP**(`navigate.mjs` の `table`・`policy`・`samePolicy`・`intercept`、gen の `navigation`、`emit/gate.gleam` の `csp`)
  - 生成は `startNavigation({ routes: [全 Page], boot, csp: { "<route>": "frame-src https://..", .. }, pageview })`。`csp` は門の `frame_src` の Page だけで、値は門の `after_response` が付ける header と同じ字(gate.mjs の `frameSrc` と同じ関数から出す)。CSP を持つ Page の無い面は `csp` を出さない(0.11.14 と同じ字)
  - client は `start` の時に今の document を読み込んだ Page の CSP を覚え、click(`intercept`)と `go`(戻る・進む・書いた後の取り直しも)で、行き先の表の CSP がそれと同じときだけ fetch する。応答の `content-security-policy` が表の値と同じでなければ(違う・在るはずが無い・無いはずが在る)頁の読み込み。今の「CSP の header があれば落とす」を置き換えた
  - 同じ pathname に CSP の違う行が 2 つ当たるときは表に無いものとして読み込みに落とす
  - **形の選択:**`routes` の中に `{route, csp}` を混ぜる形も書いたが、0.11.14 の `navigate.mjs` に新しい gen の `client.mjs` を組むと `route.split` で click・戻るが投げる。`csp` を別の key にすると、0.11.14 の client は `csp` を知らずに表の CSP の Page を取りにいき、応答の CSP の header で読み込みに落ちる(今の挙動のまま)ので、こちらにした
- **(4) 門の 302・pageview**:変えていない。302 は `opaqueredirect` で読み込みに落ちる(今のまま)。pageview は差し替えの前に印を読み(`counted`)、差し替えの後に `kind: spa` で 1 回送る(今のまま)
- **(5) test・README**
  - gen `yumemi_01115_test`(新規 2 本):`navigation_follows_page_csp_test`(18 件:表の組み立て、CSP の一致・不一致・在る無しをまたぐ click、今の document の CSP との比較、応答の header の一致・食い違い・欠け・余分、`common`)・`navigation_stage_keeps_head_and_waits_for_stylesheets_test`(25 件、子の node で `yumemi_01115_stage_check.mjs` を偽の DOM で:同じ stylesheet が同じ要素のまま・読み直しは新しい 1 本だけ・並びが来た頁と同じ・待つ間は title と body が古いまま・body の stylesheet の写しと外し時・取り消し・上限)
  - gen `yumemi_gen_test`:`front_emit_shell_stylesheets_render_in_head_test`・`front_shell_stylesheets_invalid_test`
  - gen `yumemi_fix_0114_test` の `navigation_skips_csp_pages_test` を `navigation_carries_csp_pages_test` に(CSP の Page は表から外れず `csp` に入る)
  - README:Shell の節に `stylesheets`、「Client navigation」の節を新設、0.11.15 の段落

## 検収

- root `gleam test`:`Framework checks passed: 25 groups`(`build/01115-test-root.txt`)
- gen `gleam test`:**344 passed, no failures**(基線 340 + 4。`build/01115-test-gen.txt`)
- `gleam format --check src test`:root・gen とも 0(`build/01115-fmt.txt`)
- **musearch の写しで差**(写しの面の `gleam.toml` は origin/main のまま)
  - 基点 `.scratch/yumemi-base` の gen で再生成 → `git status` は gen の `_diagnostics.txt` だけ(生成物の差 0)、停止コード 0(`build/01115-gen-base.txt`)
  - 本作業木の gen で再生成 → **www の `priv/static/_yumemi/client.mjs` の 1 行だけ差**(他の面・他のファイルは差 0)、停止コード 0、診断は基点と全行一致(`build/01115-diag-{base,new}.txt`)。差の中身(`build/01115-ms-gen-new.diff`):`routes` に CSP を持つ 5 頁(`/`・`/about/external`・`/for_stores/api/v1`・`/muse/:handle`・`/muse/:handle/space/:id`)が入り、`csp: { .. }` に 5 行。**下の「BRIEF との食い違い」**
  - 面が本作業木を path で引いたとき(6 面の `gleam.toml` を path 依存に)、4 面の `client.mjs` に bundle の framework の code の差(navigate.mjs 0.11.15 ほか、lock の版との差)が出る(`build/01115-ms-gen-newpath.diff`)
- **写しの 4 面**(path 依存で再生成の後):`npm run build` www・admin・console・muses すべて EXIT 0。`npm test` www 418/418(1 回目は 417/418 ── `mi-2-loading-dots` が `page.screenshot: Protocol error (Page.captureScreenshot)`、その 1 本だけ回して pass、全体を回し直して 418/418。load average 19)、admin 21/21、console 89/89、muses 473/473(`build/01115-ms-{build,test}-*.txt`)
- **使えば効く 1 回**:写しの www で `SiteHeader` の 4 本の `<link>` を Shell の `stylesheets` へ移し、門の `frame_src` を `[Prefix("/")]`、入口の www の `frame_src` に `challenges.cloudflare.com` を足した(`build/01115-ms-use.diff`)。本作業木の gen で再生成 → www `npm run build` EXIT 0。生成の表は全 Page が `frame-src https://blogparts.cityheaven.net https://challenges.cloudflare.com`
  - server:pn-1 の `serve.mjs` の写しに 104 の 4 つ(要求の header を worker へ・env・静的素材に `public, max-age=0, must-revalidate` と ETag / 304・`/media/*` に `private, no-cache` と ETag、gzip)を足し、stub を musearch main の型(`thumbnail`・`picture`・`pictures`)に追随(`build/01115-serve.mjs`)。嬢は stub の `bg`
  - probe(`build/01115-probe.mjs`):Chromium 153.0.8010.12 headless、360×780・DPR 2・`isMobile`・`hasTouch`、`tap`。CDP で RTT 150ms・下り 1.6Mbps・上り 750kbps・CPU 4 倍。前の頁を読み込み 1.5 秒待ってから `window` に印、tap、1.5 秒後に印が残るか。素の時間は rAF ごとに「文書の stylesheet の link(media の当たるもの)の href のうち、当たっている sheet の無いものが在るか」を見て、在った frame の長さの合計。104 の trace の screenshot の画素の測り方とは違う(下の「確かめていないこと」)
  - 各 3 回。after = 本作業木(`build/01115-probe-after.{json,txt}`)、before = 対照(写しの変更を戻し、6 面を基点の yumemi へ path、基点の gen で再生成・build。`build/01115-probe-before.{json,txt}`)

  | 移動 | before:遷移 | before:素の時間 | **after:遷移** | **after:素の時間** | after:差し替えまで(tap から) | after:移動中の CSS の要求 |
  |---|---|---|---|---|---|---|
  | TOP → 記事 1 件(帯の札) | 全読み込み ×3(document の要求あり) | (頁の中では測れない) | **client ×3**(`window` が残る) | **0 / 0 / 0 ms** | 1,068 / 997 / 1,084 ms | `article-mincho.css` だけ(写し 1 + body 1)。head の 4 本は 0 |
  | TOP → スケジュール(タブ) | 全読み込み ×3 | (頁の中では測れない) | **client ×3** | **0 / 0 / 0 ms** | 459 / 499 / 473 ms | 0 |
  | スケジュール → 記事(タブ同士) | client ×3 | 0 / **210** / **230** ms(4 本とも当たらない frame) | **client ×3** | **0 / 0 / 0 ms** | 332 / 391 / 948 ms | 0(before は 4 本を毎回要求) |

  - after の 9 回とも pageerror・console の error 0。移動の後の head の stylesheet は Shell の 4 本だけ(写しは外れている)、記事 1 件の body に `article-mincho.css`
  - before のタブ同士の 210・230ms は sampler が素の頁を拾える対照(1 回目が 0ms だった理由は確かめていない)
  - TOP → 記事 1 件の差し替えまでの約 1 秒は、記事の書体の CSS を読み終えるまで古い頁を出している時間(104 が見込んだ「最初の変化が遅れる」の分)。104 の全読み込みの見え終わりは 1,417〜1,467ms

## BRIEF との食い違い

- **検収の「musearch の写しで差 0」と、どこまで 3 の「CSP を持つ頁も client の遷移に入れる」が両立しない。**musearch main は今 www の 5 頁に `frame_src` を持つので、3 をそのまま入れると、新しい語を使わない musearch でも www の `client.mjs` の route の行に差が出る(5 頁が表に入り、同じ CSP の 5 頁の間 ── TOP ⇄ フリースペースなど ── が client の遷移になる。CSP の在る無しをまたぐ移動は今のまま全読み込み)。失敗例の「新しい語を使わない musearch で生成の差が出る」に字の上では当たる
  - 3 を優先して入れた。差はこの 1 行だけで、挙動の変化は「同じ CSP の頁の間だけ client で移る」ので CSP は守られる。0.11.14 の client と組んでも、`csp` を知らない client は応答の CSP の header で全読み込みに落ちる(壊れない)
  - 差 0 を取るなら、CSP を持つ Page を表に入れるのを新しい語(例:Shell か門に opt-in の印)で開く形になる。鷹野さんの判断を待つ

## 確かめていないこと

- 実機の電話・iOS Safari(WebKit)。測ったのは Chromium の emulation だけ
- 素の時間の測り方は 104(trace の screenshot の暗い画素)と違い、stylesheet の当たりを rAF で見たもの。背景画像の確かめ直しを待つ「地色だけの頁」は数えていない
- ヘブンの部品の iframe と Turnstile を、CSP を付けた頁へ client で移った後に実際に描くこと(stub に部品と Turnstile は無い)。CSP の値が同じ頁の間だけ移ることは unit test と表の値で見た
- CSP の違う頁の間の移動を Chromium で(unit test の `intercept`・`samePolicy` だけ)
- 戻る・進む、書いた後の取り直し(`reload`)を Chromium で
- `stylesheets` を使わない面で head に stylesheet の無い場合の、body の stylesheet の写しの待ち(unit test だけ)
- api・auth の build・test(検収の外)

## 残り・気づき

- musearch が 0.11.15 に上げる便で:`SiteHeader` の 4 本を Shell の `stylesheets` へ、www の全 Page に同じ `frame_src`(`challenges.cloudflare.com` を足す)。上の写しの diff がその形(`build/01115-ms-use.diff`)。musearch の spec S-4c の「この 2 つの Page は client の遷移から外れる」と、Playwright の台本の追随が要る
- pageview:CSP を持つ頁が client の遷移に入ると、その頁の pageview は `kind: spa` で数えられる(104 の「鷹野さんに確かめたいこと」の 2 つ目)
- stub(pn-1 の serve.mjs)は musearch main の型に遅れていて、`thumbnail`・`picture`・`pictures` を足した(104 と同じ追随)
- `.scratch/` は `.gitignore` に無い。commit には path を名指しで入れた

## DDL

無し
