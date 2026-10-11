# 真壁[IM]へ ── yumemi 0.12 段 C(便 yumemi-012-y6、0.12.0 の publish の前に門・数える口・器・柵の宣言と振る舞いを固める ── 読みの失敗の 503、`ToService` の受け口、数える口の検査、CSP の同じ origin、属性と書体の柵、Args の Color、README の法の注意、直書き、鷹野[PDM] 2026-10-12)

便: yumemi-012-y6(yumemi リポ、Opus 真壁の直書き、終端で柏木のゲートを便に 1 回 ── `KASHIWAGI_ROUTE=opus`)

**1 session で直に書く。細かい設計は真壁さんが決める(役員 人見 2026-10-12)。**作業木 `~/yumemism_repo/yumemi-012-y6`(branch `impl/012-y6`、基点は段 B の 3 便を merge した後の forgejo main `e57bcf2`)。記録は `briefs/results-yumemi-012-y6.md`、証跡は `build/012-y6-*`(git の外)。commit は `git-as makabe`、main に触らない。push・tag・Hex の publish は鷹野。**版の行(`0.12.0-dev`)に触らない。止め線は経過 2 時間。**

**並行の便:**同じ基点 `e57bcf2` から Y3(`briefs/BRIEF-yumemi-012-y3.md`、interactive Component・逃げ道・lock の照合・段 B の継ぎ目)が別の作業木で走る。file の持ち場は下の「持ち場」(Y3 の BRIEF と同じ字)。merge は Y3 → Y6 の順(本便が先に閉じれば先でもよい)。作業木は root で `npm ci` してから `gleam test`(80「段 A からの申し送り」)。

**親:**tech `_drafts/gleam-framework/51-front-types.v6.md` の「門」「数える口」「記録と集計の器」「ユニークの印」「CSP の宣言」「失敗の文言」「属性の型」「Css の語彙」と「生成器が止めるもの」の第 32〜40 条、`75-framework-app-boundary.v1.md`、`82-pageview-cookie-legal.v0.md` の §4 と「確認できなかったこと」。段 B の材料 ── `briefs/BRIEF-yumemi-012-y5.md`・`briefs/results-yumemi-012-y5.md`(特に「BRIEF との食い違い・判断したこと」「印の cookie」)、柏木の所見 `~/.codex-agents/runs/kashiwagi-20261012-045410-*/last-message.md`(Y5、P1-1〜7)と `kashiwagi-20261012-045019-*`(Y2、P1-4・5・10)、merge 後の確かめ(庵野)`~/yumemism_repo/yumemi/build/stageB-check/`。

**親ゴール:**0.12.0 を publish した後に直すと ★ の宣言か配った振る舞いが変わる所を、門・数える口・器・柵について publish の前に固める。使う側のアプリは `csp`・`ToService`・`Store` を宣言どおりに使え、記録が黙って消えず、Service の要件を抜けて記録されず、要らない印を焼かれない。法の義務の所在を README から読める。段 D の musearch の 5 便はこの上に書く。
- 障害:門が session の読みの 5xx(APP binding の例外を含む)を 403 `forbidden` に畳み、log も残さない。app が落ちても「権限が無い」と見え、調べられない。shell の側は 5xx のまま返すので食い違う
- 障害:`csp` に `ConnectSrc`・`ImgSrc`・`MediaSrc` を宣言すると、生成する CSP が `https://<host>` だけになり同じ origin が止まる ── 数える口の beacon が 0 件、client の遷移の fetch が止まって頁の読み込みに落ちる、同じ origin の `/media/...` の画像が error(Chromium 153、庵野の再現)
- 障害:`ToService` の受け口が Service の `requires` を見ない。Service に `Consented("analytics")` を書いても、`only` に同じ条件が無ければ同意なしで記録される。印の要らない Service でも印の cookie を焼く(データ最小化、82)
- 障害:受け口は何で落ちても log 無しで 202。DDL の当て忘れや SQL の失敗で全 event が黙って消える。`Path` の無い `Store` は全 event を `/` で記録し、`FromQuery` の name に framework の欄の名を使うと event が消えるか値が化ける
- 障害:`attr.action` に `javascript:` が通り、送信で走る。`css.Named` は字のまま `<style>` に入り、DB の値が流れると CSS を差し込める
- 障害:Args に `color.Color` を持つ Service は生成器が名指して止める。色を書く Service を app が書けない
- 障害:README に、責任の主体がアプリの運営者であることと EU の同意の入口が無く、使う側が「framework の既定だから足りる」と読む(82)

## 現在地(段 B の merge 後の main `e57bcf2`、root `gleam test` 388 本)
- 門の読みの失敗は `emit/gate.gleam` の生成 JS の `readFailure`(408 行付近):404 は `not found`、他は全部 403 `forbidden`。読みは APP binding の例外と session の path が無いときを 502 として持つ。shell の側(`emit/front.gleam` の `shell_runtime_text`)は読みの 5xx を status のまま `root read failed` / `widget read failed` で返す
- CSP は `emit/gate.gleam` の 30〜47 行付近が指令ごとに host を `https://<host>` にして並べるだけで `'self'` が無い。host の綴りの検査は `reader/gate.gleam` の `host_spelling`(615 行付近)。client の遷移の表(`emit/front.gleam` の `navigation`)は `gate_emit.csp_routes` を通して同じ字を使う。README の門の節の CSP の段(371 行付近)にも `'self'` が無い。fixture cms の public は `ConnectSrc`・`MediaSrc` ほかを宣言している
- 受け口は `src/yumemi/server/http.mjs` の `pageview`(420 行〜)。`decode`(299 行)と `judge`(338 行)は `s.pageview` なら何もしない ── `requires`・`phaseGates`・`suspended`・hook の `judge` / `write_gate` を飛ばす。印は `bc&&!s.browser` なら sink の種類に依らず焼く(446 行)。`ToService` は許す句(`anyone`・`party`)が無ければ Service を呼ばずに 202。`failure`(181 行)は `s.pageview` なら本体無しの 202 で log が無い。`Store` は `event.path??'/'`(478 行)
- `FromQuery` の name の検査は `reader/gate.gleam` の 673 行付近で `id` だけを予約する。受け口の event の欄の名は `id`・`kind`・`client_at`・`path`・`prev`・`referrer_path`・`referrer_host`
- 第 36・37 条は `reader/cms.gleam` の `counted_notes`。第 36 条は Args の欄の名と `Option` かだけを見て、型そのものは見ない。`ToService` の Args に `id` が無くても通る(Y5 は二重計数の 2・5・6 を Service の側にした ── results「BRIEF との食い違い」)。musearch の `pageview_record` の Args は `id: PageViewId`・`client_at: Datetime`・`kind: page_view.NavKind`・`path: Path`・`prev`・`referrer_path`・`referrer_host`・`source_key`(後ろ 4 つは `Option`)で、app の型で受けている
- `attr.href`・`attr.src` は `attr.gleam` の `url`・`safe_url` の柵を通る。`attr.action` は `string("action", value)` で柵の外
- `css.Named(String)` は `sketch_css.gleam` の `font_family` が字のまま出す。musearch の ★ の `Named` は 89 か所で、どれも `var(--ma-font-ui)` か `var(--ma-article-font)`
- Args の decode は `emit/http.gleam`(66 行付近で `decode を導けない` と止まる)。`Color` は Entity の Property と Out では通る(Y2)
- README の「The gate and the CMS features (0.12)」の節は、器の event の行が party を持つことを既に書いている(Y5 の柏木 P2)。82 §4 の注意の文は無い
- musearch は段 D まで 0.11 のまま

## どこまで
1. **門の session の読みの失敗。**404 は `not found`、権限の拒否は 403 `forbidden` のまま。**5xx(APP binding の例外・session の path が無いときを含む)は 403 に畳まず 503 で返し、本文は `unavailable`、元の status と原因を `console.error` に出す**(Y5 柏木 P1-1)。51 v6「失敗の文言」の本文は `forbidden`・`not found`・`unavailable` の 3 つに広がる ── 51 v6 に足す行として results に書く
2. **CSP の同じ origin。**生成器が、宣言した各指令(`ConnectSrc`・`ImgSrc`・`MediaSrc`・`FrameSrc`)にそれぞれ `'self'` を自動で足す。framework の受け口・遷移の取得・media が同じ origin にあるので、app が宣言しなくても通るのを既定にする。`'self'` を外す口は 0.12 で持たない。client の遷移の表は同じ字のまま(`csp_routes` を通す)。README の CSP の段を直す(鷹野 2026-10-12、庵野の段 B の確かめ)
3. **`ToService`。**受け口で Service の `requires` を評価する(生成器の包含の検査ではなく実行で縛る、Y5 P1-3)。Args に `id` を必須にする(P1-4)。印の cookie は Service が `Carried(.., "browser", ..)` を持つときだけ焼き、`requires` や許す句で Service に届かない event では焼かない(P1-2 の 3 つ目)。`requires` のほかに飛ばしているもの(`phaseGates`・`suspended`・hook の `judge` / `write_gate`)は今のままにし、飛ばすことを README に書く
4. **数える口の検査。**`FromQuery` の name に受け口の event の欄の名(`id`・`kind`・`client_at`・`path`・`prev`・`referrer_path`・`referrer_host`)を使えば生成器が止める(第 35 条、P1-5)。`Store` は `fields` に `Path` を必須にする(第 37 条、P1-7)。第 36 条の突き合わせを型まで見る ── event の欄の値(文字列か 3 値)から decode できる型かを見て、musearch の app の型(`PageViewId`・`Datetime`・`page_view.NavKind`・`Path`・`HostName`・`SourceKey`)は通す。受け口は応答 202 を保ったまま、想定外の失敗(SQL・Service の例外・設定の不足)を `console.error` に出す(P1-6)。bot・先読み・形の外れ・条件の外で落とすのは今どおり黙って 202
5. **柵。**`attr.action` を `attr.href`・`attr.src` と同じ scheme の柵に(Y2 P1-10)。`css.Named` の書体の名は、合わない字を `unset` にする(Y2 P1-4、`Hex`・`Token` と同じ扱い)。musearch の `var(--ma-font-ui)` の形と、引用符付きの書体の名の並び(`"Noto Sans JP", sans-serif`)は通す
6. **`emit/http.gleam` の Args の decode に `color.Color` を足す**(Y2 P1-5)。壊れた色は `invalid_argument`
7. **README の門の節。**82 §4 の英語の文案(責任はアプリの運営者、日本と EU で何が要るかの入口、第三者に送らない)を Pageview の段の末尾に入れる。器の event の行が party を持つ一文は今の README にあるので残す。82 の文案の最後の一文(`only` で利用者の操作の後に絞れる)は、本便で器の実装を確かめてから入れる ── `only: [WhenDeclared(kind)]` の面で、申告の前の event では印の cookie も行も生まれず、申告の後に数えられることを test で示せたら入れ、示せなければ外して results に理由(80「段 E」の行)。82 の「大橋に確かめてほしい点」(公表の 1 行、商号、ポリシーの文、not legal advice、EU の扱い)は README で答えを書かない
8. 足した宣言を使う fixture(fixture cms の門・back で足りなければ足す)。README の門の節の上の各段を現物に直す
9. **shell の読みの失敗。**`emit/front.gleam` の `shell_runtime_text` の読みの 5xx を 503 `unavailable` にし、元の status と原因を `console.error` に出す(鷹野の裁き 2)

## 持ち場(Y3 と Y6 の切り分け。Y3 の BRIEF と同じ字)
- **Y3 の file:**interactive Component の群(`src/yumemi/front/live.gleam`、生成の live module、`emit/front.gleam` の `live_targets`〜`quoted`・`transport_text`・`client_components`・`component_has_app`・`client_notes`・`client_text`・`client_registration`)、`src/yumemi/front/el.gleam`・`html.gleam`、`island_style.mjs`(消す)・`navigate.mjs`・client の runtime(`client.mjs` を組む所と新しい runtime の file)、`reader/front.gleam`・`gen/raw_css.gleam`・`gen/source.gleam`、`emit/front.gleam` の SSR・CSS・頁の色・`surface_notes`、`emit/back.gleam` の `consumer_of`、生成器の入口 `gen.gleam`(lock の照合・逃げ道の数えの 1 行)、`gen/scripts`、`gleam.toml` の依存と `manifest.toml`、escape と route の生成の新しい module
- **Y6 の file:**`src/yumemi/server/http.mjs`、`emit/gate.gleam`、`reader/gate.gleam`、`reader/cms.gleam`(第 36・37 条の条文の Note)、`emit/http.gleam`、`emit/pageview.gleam`(要れば)、`src/yumemi/gate.gleam`(要れば)、`front/attr.gleam` の `action` と URL の柵、`front/css.gleam` の `Named` と `front/sketch_css.gleam` の `font_family`、README の「The gate and the CMS features (0.12)」の節、Y6 の新しい test file
- **同じ file の中で割る所:**
  - `front/attr.gleam`:Y6 は `action` と URL の柵(`url`・`safe_url`)だけ。Y3 は `data` と、送り・bind の印のために足す口(`data-yumemi-send` ほかを attr に足すなら新しい関数として足し、`action`・`url`・`safe_url` の行を動かさない)
  - `front/sketch_css.gleam`:Y6 は `font_family` だけ。class 名の作り方・`sketch_css.class` の削除ほかは Y3
  - `reader/cms.gleam` の `counted_notes`:警告の Note(`逃げ道 ToService を 1 つ使っている`)は Y3(数えの 1 行へ移す)、条文の Note(第 36・37 条)は Y6
  - README:門の節の `ToService` の段の「警告を 1 行出す」の一文は Y3、門の節の他は Y6。要素の節の柵の一文(`href` / `src` の scheme)と Style の表の `Named` の行は Y6、要素・Css・遷移・逃げ道・lock の節の他は Y3
  - test:`yumemi_012_y5_test.gleam` の `ToService` の警告の期待の字は Y3、条文の test のうち Y6 の替えで落ちる所は Y6。`yumemi_012_y5_test_ffi.mjs` の門の読みの失敗の項は Y6
  - fixture:`gen/fixtures/article` の interactive Component と面は Y3、`gen/fixtures/cms` の門・back の `server.gleam`・Service は Y6
- 生成物(fixture の `src/gen/`・`priv/static/_yumemi/`・`_diagnostics.txt`・`db/`)の衝突は、merge のとき鷹野が ours で取って生成し直す。同じ関数の中の手書きの衝突は、後に merge する便の形に合わせて鷹野が解く
- 上の表に無い既存の test(`gate_test` の CSP の字ほか)は、本便の替えで落ちる所だけを直す
- `emit/front.gleam` の `shell_runtime_text` の読みの 5xx の行は Y6(鷹野の裁き 2)。同じ file のほかの関数は Y3

## しないこと
interactive Component、遷移(navigate.mjs)、client の runtime と送り手(`front/pageview.mjs`)。Y2 の Css の語彙の追加。`ToService` を外す。器の表の形を変える(ALTER が要る形にしない ── DDL は `db/framework/pageview.sql` の今の形のまま)。`'self'` を外す口、`script-src`。live module の側で Color の欄を form から bind すること(Y3)。逃げ道の数えの 1 行への統合(Y3)。82 の「大橋に確かめてほしい点」への答え。musearch の source(写しだけ)。版の行・tag・publish・push。

## 失敗例(差し戻し)
- 読みの 5xx が 403 のまま、または `console.error` に元の status と原因が無い。404 と権限の拒否の本文・status が変わる
- `csp` を宣言した面で、同じ origin の beacon・client の遷移の fetch・`/media/...` の画像が止まる。`'self'` が指令によって付いたり付かなかったりする。今の document と行き先で CSP の字が食い違い、client の遷移が頁の読み込みに落ちる
- `requires` を満たさない event が `ToService` の Service に届く。印の要らない Service や Service に届かない event で印の cookie が焼かれる
- `FromQuery` の name に `kind`・`path` ほかを書いて生成器が通る。`Path` の無い `Store` が通る
- 第 36 条の型の突き合わせで、musearch の `pageview_record` の Args(app の型で受ける形)が止まる。逆に、event の欄から decode できない型が通る
- 受け口の想定外の失敗が log 無しで消える。bot・先読みでも `console.error` が出て log が埋まる
- `attr.action("javascript:..")` が出る。`css.Named` に `;}` ほかを渡すと規則が割れる。musearch の `var(--ma-font-ui)` が `unset` になる
- Args に `Color` を持つ Service が生成器で止まる、または壊れた色が Service に届く
- README に 82 の「大橋に確かめてほしい点」の答えを書く。`only` の一文を確かめずに入れる
- 器の DDL か表の形を変える。Y3 の持ち場の file・行を触る
- 書き換えで変わった test の期待値を理由を書かずに直す。落ちた test を消して本数を合わせる

## 検収
- root `npm ci` の後に root `gleam test` が通り、本数は基点 `e57bcf2` の 388 本から減っていない(before / after と、期待値を書き換えた test の名と理由を列で)。`gleam format --check` 0
- fixture の全面を生成して停止コード 0・2 回目の差 0。足した検査(第 35 条の予約の名、第 36 条の `id` と型、第 37 条の `Path`)の 1 つずつに止まる fixture か test があり、停止コードは `stop.gleam` の分類(3 宣言の不足・4 宣言の矛盾)で results に条と値を列で
- **門(生成の `gate.mjs`、node):**読みの 404 は 404 `not found`、権限の拒否は 403 `forbidden`、読みの 500・502・APP binding の例外は 503 `unavailable` で `console.error` に元の status と原因
- **CSP(Chromium、庵野の台 `~/yumemism_repo/yumemi/build/stageB-check/` の `check.mjs`・`extra.mjs`・`serve.mjs` と面の写し `combo/` を本便の build に写してよい):**庵野が × にした 3 つの逆 ── `ConnectSrc` ほかを宣言した面で、数える口の beacon が受け口に届く、client の遷移が保たれる(頁の読み込みに落ちない)、同じ origin の `/media/...` の画像が読める。生成した CSP の各指令に `'self'` が 1 つ
- **受け口(node、test と同じ ffi):**`requires` を満たさない event は Service に届かず 202、満たす event は届く。`Carried(.., "browser", ..)` を持たない Service と、許す句か `requires` で落ちる event では `Set-Cookie` が無い。`Store` で SQL を落とすと 202 と `console.error`、bot と先読みでは `console.error` が出ない。Args の `Color` が decode され、壊れた色は `invalid_argument`
- **`only` の一文の確かめ:**`only: [WhenDeclared(kind)]` の面で、申告の前の event は `Set-Cookie` も行も無く、`Declare` の後の event は数えられる(器は使い捨ての PG、新しい port。終わったら止めて消す)
- **柵:**`attr.action` の `javascript:`・`JaVaScript:`・先頭の空白・`data:` が出ず、相対・http・https は出る。`css.Named` の `x;} body{color:red` ほかが `unset`、`var(--ma-font-ui)` と `"Noto Sans JP", sans-serif` は字のまま
- **musearch の写し:**origin/main(`~/yumemism_repo/musearch`)を `.scratch/musearch` に置き、Y5 の検収と同じ名前の置き換えと宣言の書き換えだけをして、api の package から全面を生成して停止コード 0(第 36 条の型の突き合わせで `pageview_record` が止まらない)、警告の `ToService` 1 行、www の生成の CSP に `'self'`。Hex の rate limit で落ちたら間を置いて回し直し、results に書く。写しは捨てる
- results に、51 v6 に足す行(失敗の文言が 3 つ、CSP の `'self'`、`ToService` の検査は 1・3・4 と `requires` と `id`、`FromQuery` の予約の名、`Store` の `Path`、`attr.action` と `Named` の柵、Args の `Color`)を節にまとめる。`## DDL`(表の形を変えていないことの 1 行)

## 鷹野の裁き(起動の前、2026-10-12)
1. **`'self'` は宣言した 4 指令の全部(`FrameSrc` を含む)に足す。**同じ origin の iframe が通っても失うものは無く、指令ごとに既定を変えると読み手が迷う
2. **shell の読みの失敗も本便で揃える。**`emit/front.gleam` の `shell_runtime_text` の読みの 5xx(`root read failed` / `widget read failed`)を、門と同じ 503 `unavailable` と `console.error` に替える。`shell_runtime_text` は Y3 の触らない関数なので、本便の持ち場に足す(どこまで 9)
3. **印を焼かない条件は 2 つの読みのとおり**(`Carried` を持たない Service、Service に届かない event)
4. **`ToService` で評価するのは `requires` だけ。**飛ばすものは README に書く。musearch の hook が新しい受け口に効かない件は段 D
5. **止め線は経過 2 時間。**閉じない項は results に残りを書いて閉じる

## 確認できなかったこと
1. 庵野の `build/stageB-check/` は file の並び(`check.mjs`・`extra.mjs`・`serve.mjs`・`check1.json`・`combo/`)だけを見た。×の 3 つの再現の手順と値は鷹野の伝え聞きで書いた
2. `'self'` を足した CSP の字で、musearch の 4 面の client の遷移の表が今の document の CSP と同じ字になるか(門と遷移の表が同じ関数を通るので揃う見込み)
3. 第 36 条の型の突き合わせで、app の型(`Datetime`・`page_view.NavKind` ほか)が event の欄から decode できるかを、生成器が型の宣言からどこまで辿れるか
4. 読みの 5xx を 503 にしたとき、musearch の門の Playwright の台本と CI(`.forgejo/workflows/playwright.yml`)が 403 を前提にしているか
