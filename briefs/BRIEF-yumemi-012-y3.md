# 真壁[IM]へ ── yumemi 0.12 段 C(便 yumemi-012-y3、interactive Component を form と custom state に移して lustre を外す、名前付きの逃げ道、lock の照合、段 B の継ぎ目と柏木の P1、直書き、鷹野[PDM] 2026-10-12)

便: yumemi-012-y3(yumemi リポ、Opus 真壁の直書き、終端で柏木のゲートを便に 1 回 ── `KASHIWAGI_ROUTE=opus`)

**1 session で直に書く。細かい設計は真壁さんが決める(役員 人見 2026-10-12)。**作業木 `~/yumemism_repo/yumemi-012-y3`(branch `impl/012-y3`、基点は段 B の 3 便を merge した後の forgejo main `e57bcf2`)。記録は `briefs/results-yumemi-012-y3.md`、証跡は `build/012-y3-*`(git の外)。commit は `git-as makabe`、main に触らない。push・tag・Hex の publish は鷹野。**版の行(`0.12.0-dev`)に触らない。`0.12.0` への替えと tag・publish は Y3・Y6 の merge の後に鷹野。止め線は経過 3 時間 30 分。**

**並行の便:**同じ基点 `e57bcf2` から Y6(`briefs/BRIEF-yumemi-012-y6.md`、門の読みの失敗・`ToService` と器の受け口・数える口の検査・属性と書体の柵・Args の Color・README の法の注意)が別の作業木で走る。file の持ち場は下の「持ち場」(Y6 の BRIEF と同じ字)。merge は Y3 → Y6 の順(Y6 が先に閉じれば先でもよい)。作業木は root で `npm ci` してから `gleam test`(80「段 A からの申し送り」)。

**親:**tech `_drafts/gleam-framework/51-front-types.v6.md` の「語」「型の一覧」「型引数」「Page の route と `Route`」「html と el」「interactive Component」「連鎖の禁止」「interactive Component の生成物」「SSR と custom element」「状態の写し」「After」「`reloads`」「読みと書き」「Out から一覧の行」「runtime」「遷移」の再起動の行、「名前付きの逃げ道」「逃げ道の数え方」「invoker commands」「interactive Component のスコープ」「media の variant」の `src`、「生の CSS の逃げ道」、「生成器」の lock の行と、「生成器が止めるもの」の第 4〜6・9〜22・26・28〜31・41・43 条。`71-island-control.v0.md`(写像)、`72-authoring-surface.v1.md`(登録を生成器が吐く形・名前付き FFI の口)、`78-own-element-tree-poc.v0.md`(class 名が bundle で変わる)、`70-brief-front-rethink.md` 末尾の 2 節、`81-stage-b-ownership.v0.md`「段 C へ回す継ぎ目」、`80-baton-012.md`「段 A からの申し送り」。段 B の材料 ── results `briefs/results-yumemi-012-y2.md`(特に「島の Style を本便で外さなかった理由」「段 C(Y3)へ」)・`-y4.md`・`-y5.md`、柏木の所見 `~/.codex-agents/runs/kashiwagi-20261012-045019-*/last-message.md`(Y2)・`kashiwagi-20261012-044324-*`(Y4)・`kashiwagi-20261012-045410-*`(Y5)。

**親ゴール:**interactive Component は Args を受けて要素を返す view と、互いに独立した送りの `calls`・`after_send`・任意の `reloads` の宣言だけで書け、状態は form の control と `:state()` にあり、★ は update も lustre も書けない。FFI は名前付きの逃げ道としてだけ置け、生成器が漏れなく数える。走る生成器と app の lock の yumemi が一致する。Y3・Y6 の merge で yumemi は 0.12.0 の形になり、段 D の musearch の 5 便はこの上に書く。
- 障害:★ が lustre を import して `app()` と `update` を書ける(musearch の interactive Component 129 本のうち 125 本が自前の update、71)。段 B の共存の例外がこの口を残している
- 障害:状態が lustre の model の中にあり CSS から見えない。島は shadow root の中に JS で描き、given を define の closure に焼き、遷移の後に `boot()` で起こし直す
- 障害:client での Service の連鎖(片方の戻りで片方を埋める)を ★ の update に書け、After が 2 値なので、移る先と文言を musearch が `location.assign` 13 本と sessionStorage 20 本で自作している
- 障害:0.12.0 を切った後に ★ の書き方が変わる所が残ると、段 D の後にもう一度 ★ を壊す
- 障害:逃げ道の数えに抜け道(pipe・関数参照・`src/gen/` に手で置いた file)があり、数えが 0 のまま外の CSS や lustre が入る
- 障害:0.11.15 の生成器が queue の consumer の基を名前順の先頭で選び、Service を 1 本足すと別の consumer が黙って 404 になる(musearch m012-api)

## 現在地(段 B の merge 後の main `e57bcf2`、root `gleam test` 388 本)
- interactive Component は 0.11 の形 ── `pub fn app` で `lustre.component`、`view(it: State) -> Element(Event)`、`calls: List(front.Target(service, attached))` か `pub const target`、`after_send: live.After`(`Stay`・`ReloadPage`)、`reloads: List(#(Field, Service))`。`yumemi/front/live.gleam` は State 4 欄・Event 4 種・After 2 値
- fixture の interactive Component は article の public の 4 本(`pick_tag`・`article_blob_copy`・`blob_save`・`like_button`)で、`import sketch/lustre/element as el` の lustre のまま。`pick_tag` は given の一覧から `<option>` を作り、2 本は attached の上げ口(`Entry`)か file の control(`data-yumemi-file-input`)を持つ。fixture cms の古い形の Component 4 本は段 B の merge で外した(庵野)
- 生成器の interactive Component の群は `emit/front.gleam` の `live_targets`〜`quoted`、`transport_text`、`client_components`・`component_has_app`・`client_notes`、`client_text` の登録と `boot()`
- **共存(Y2 が残した形)。**★ の lustre の import は第 1 条で止まり、例外は `components/` で `pub fn app` を持つ module(`reader/front.gleam` の `is_legacy_component`)だけ。生成の live module は `src/gen/` の中なので検査の外(`source.gleam` が `gen/` を丸ごと除く)。例外の数は面ごとに 1 行の警告(`第 1・2 条の例外(0.11 の lustre の interactive Component、段 C の Y3 で消す): 4 module`)。Block から 0.11 の島を置く一時の口は `el.legacy_island(tag, args)`。**shadow root と `island_style.mjs` は残った** ── sketch は Style の `string.inspect` の hash で class 名を作り、lustre 入りの bundle や minify で constructor の名が替わると class 名が変わる(node・bundle・minify で 4 通りの名を実測、78 の予見どおり)。島の ★ は sketch の `sketch_css.class` と sketch_lustre の html を使う。`gleam export hex-tarball` の依存に lustre・sketch_lustre が残る
- **遷移(Y4 が今の形のまま繋いだ枝)。**navigate.mjs(326 行、Navigation API の `intercept()`)は差し替えの後に client が渡した `boot()` を呼び(`navigate.mjs:313`)、差し替えの判定に given の条件(`[data-yumemi-given]` の custom element が定義済みなら断る、114 行)が残る。柏木の P1 が 2 つ残る(下の「どこまで」11)。Y5 の送り手(`front/pageview.mjs`)は `navigatesuccess` で `navigation.transition` が null の移動を数えない
- **逃げ道の数え。**面ごとに別々の exit 0 の警告 ── 生の CSS(`emit/front.gleam` の `surface_notes`:`生の CSS の逃げ道 2 file(shell.stylesheets 1・el.static_sheet 1)、規則 4`)、`ToService`(`reader/cms.gleam` の `counted_notes`:`逃げ道 ToService を 1 つ使っている(…)`)、第 1・2 条の例外の数。`_diagnostics.txt` にも同じ行。数えには柏木の見つけた抜け道がある(下の「どこまで」12)
- **media(Y5)。**`gen/media.gleam` は `Variant`・`name`・`theme_background`(const)・`url(Blob, Variant) -> String` で、`src` は無い。頁の色の地の画像は生成器が app の `media.url(value, media.W1600)` を焼く今の形(`emit/front.gleam` の `theme_background_is_blob` の隣。Y2 が fixture article の public に app の `media.gleam` を足した)。`el.img(class, attrs)` の src は `attr.src`(String、URL の柵)
- `emit/front.gleam` の `navigation` は Y5 の `gate_emit.csp_routes` の形。route の照合は門と遷移で別々のまま
- 生成器は lock を照合しない。`gen/scripts` の 3 file(`verify-decode-roundtrip.mjs`・`verify-route-table.sh`・`y1e-prepare-f5.mjs`)が旧名 `yumemi_gen` で起こす。queue の consumer の基は `emit/back.gleam` の `consumer_of` が `sorted_services` の先頭から取る
- 51 v6 の条番号は esbuild が第 42 条、lock の照合が第 41 条(Y1 の BRIEF の「第 38・37 条」は誤りで、Y1 は 42 で実装済み)
- musearch は段 D まで 0.11 のまま

## どこまで
1. **宣言と view。**`calls`・`after_send`・任意の `reloads`・`view(<calls の順の Args>)` と任意の末尾 `with: With`。`calls` は互いに独立した送りを 1 つ以上持てる。禁じるのは client での Service の連鎖だけ(79 の段 C の「1 Service の検査」の行は古く、連鎖の検査 第 19〜22 条に替わっている)。`live.gleam` は `After(ok, error)`・`Then`(`Stay`・`ReloadPage(notice)`・`GoTo(route, notice)`)・`Reloads(read, on)` にし、State・Event・given は ★ の目から消える
2. **生成物。**Service ごとの live module(`Args`・`Field`・`Error`・`When`・`Slot` と `bind`・`bind_check`・`bind_choice`・`when`・`out`・`send`)、`gen/islands` を `gen/interactive` に改名(SSR の印 `data-yumemi-island` は残す)、Page の閉じた enum `Route`(`gen/route.gleam`、`GoTo` の行き先)。送りのボタンは `data-yumemi-send="<service>"` で、`formaction` は出さない
3. **SSR と runtime。**Component ごとに autonomous custom element を define し、中身を light DOM に SSR で全部描く。`client.mjs` の runtime は submit・制約検証・Args の組み立て・状態の付け替え(`:state()`、無い browser では `data-yumemi-state`)・`out` の結合・After・`reloads`(単一の値と一覧)・`el.notice` への 1 回の文言を持つ。lustre は client に入らない。`when` の枝を隠す規則は Y2 の `:state()` の 2 通りの出し方に揃える
4. **名前付きの逃げ道。**`src/escapes/<name>.mjs` を `gen/escapes` の関数と `yumemi-escape` 要素に写す。interactive Component の中にも置け、数えでは中の呼び出しを別に出す
5. **生成器が止めるもの。**51 v6 第 4〜6・9〜22・41・43 条(第 16 条のために `el.notice`、第 43 条のために `el.static_src` を置く)。停止コードは 51 v6 の値
6. **lock の照合(第 41 条)。**生成器が読み書きする package(api と面)の yumemi の lock が、走っている生成器の版と違えば名指して止める。生成器が触らない package(musearch の auth)は段 D まで照合の外(Y1 鷹野の裁き 2)
7. **段 B の継ぎ目のうち 6 つ**(下の節の振り分け)
8. **段 A からの申し送り。**`gen/scripts` の 3 file を `yumemi/gen` で起こす形に直す(もう使わないなら消し、results に理由)。queue の consumer の基を名前順に依らずに決める(宣言で名指すか、積む Service の root が食い違えば止めるかは真壁さんが決める。★ の宣言が増えるなら README に)
9. **上げ口と file の control を 0.12 の形に載せる。**`calls` は 0.11.15 の `Target`(`Of`・`Entry`)のまま残し、`pub const target` は `calls` に畳む。Blob の欄は live module の file の bind で写す。上げ口で写した key を Service の Args に入れるのは「上げる → key を Args」で、Service の連鎖に当たらない(鷹野 2026-10-12、80「段 A からの申し送り」の `link_import_apply` と同じ読み)
10. fixture article の 4 本を新しい形に書き換え、逃げ道・`with`・`GoTo`・送り 2 つ・dialog の中の送り・`reloads` の 2 通りを使う fixture を足す。README の interactive Component・逃げ道・lock の節を現物に直す
11. **遷移の柏木の P1 2 つ(Y4)。**
    - **取得の最中の競合で URL と中身が食い違う。**遅い頁の取得中に、まだ出ている前の頁の `#` を押すか島が `history.replaceState` すると、差し替えが signal で止まり(`navigate.mjs:311` 付近)、URL は行き先(`/slow#s`・`/slow?tab=2`)、中身は前の頁のまま残る(証跡 `~/yumemism_repo/yumemi-012-y4/build/012-y4-k-race-{after,before}.json`、台は同じ所の `012-y4-k-harness-race.mjs`。基点の 0.11.15 は揃っていた)。止まった後に新しく取った遷移が無ければ今の URL を頁の読み込みで開き直す類の直しを、navigate.mjs の中で閉じる
    - **interactive Component の `history.pushState` の後に戻ると頁ごと取り直す。**traverse として取り、fetch して body を替えるので Component の状態が消える。同じ path に積んだ後に戻ると、送り手が `spa` を 1 件数える(0.11.15 は何もしなかった。段 B の merge 後の確かめで庵野が実測)。取り直しと 1 件の数えは同じ件として扱う。0.12 の interactive Component(runtime・`reloads`・逃げ道)が pushState を使う口を持つかと合わせて真壁さんが決める。決めた形と理由を results に書き、口を持たないなら README の遷移の節にその旨を書く
12. **逃げ道の数えの抜け道(Y2 柏木 P1-1・2・3)。**数えを 1 行にまとめる継ぎ目 4 と同じ所なので、本便で閉じる。
    - `el.static_sheet` を pipe(`arg.slug |> el.static_sheet`)や関数参照(`list.map(xs, el.static_sheet)`)で書くと、第 28〜31 条と数えを抜ける(`reader/front.gleam` の `call_sites` が `glance.Call` しか見ない)
    - 実行時の `static_sheet` に柵が無く、`//host/x.css` で外の stylesheet を読む。`//`・`\`・`:` を落とす
    - 第 29 条は字面の一致だけで、括弧の中の空白(`[ data-yumemi-area ]`)・CSS の escape(`\2d`)・at-rule の前置き(`@scope ([data-yumemi-…])`)・`[class*="css-"]` を見落とす
    - 同じ file を 2 か所(`shell.stylesheets` と `static_sheet`、2 つの Block)で読むと数えが倍になる
13. **★ の検査の外と停止コード(Y2 柏木 P1-6・9)。**面の `src/gen/` に手で置いた `.gleam` が ★ の検査の外(例外が「生成の live module」より広い)。第 26 条で Shell の色が literal でないときの停止コードが 3 なのを 51 v6 の 4 に

## 段 B の継ぎ目 7 つの振り分け
**★ の書き方を変える継ぎ目は本便で全部閉じ、★ に見えない内部の重複だけを外す。0.12.0 の後に ★ を壊さないため。**
1. `el.Src` と `gen/media.src`、`el.img` の src を `Src` に、`el.static_src`(第 43 条)── どこまで。★ の `el.img` の引数の型が変わる
2. 頁の色の地の画像の URL を `gen/media` の `theme_background` で組む ── どこまで。app の `media` module の名を生成器が焼く形が残ると、別のアプリで生成物が compile しない。fixture article の public の app の `media.gleam` は要らなくなれば外す
3. route の照合を門と遷移で 1 つの表に ── しないこと。★ に見えず、壊さずに 0.12.x で入る。本便の窓は interactive Component に使う
4. 逃げ道の数えの 1 行への統合 ── どこまで。3 つ目の数(escape)を本便が足すので、同じ手で 51 v6 の 1 行の形に揃える。`ToService` の数は `reader/cms.gleam` の警告の Note から取り(下の「持ち場」)、上の 12 の抜け道を同時に閉じる
5. navigate の `boot` の呼び出しを外す ── どこまで。Component が接続のたびに自分の属性を読む形にした上で、`navigate.mjs:313` の `boot()` と、差し替えの判定の given の条件(114 行)を外す
6. 共存の外し ── どこまで。本便の芯。lustre・sketch_lustre を依存から外し、第 1・2 条の例外(`is_legacy_component`)・例外の数の診断の行・`el.legacy_island`・`sketch_css.class`(sketch の Class)を消す。**shadow root と `island_style.mjs` も消す。**SSR で描いた class 名と CSS が文書の規則に当たる形にする ── Y2 の引き継ぎどおり、class 名を constructor の名に依らない形(Style を yumemi が自分で文字列にしてから hash する類)にしてから外す。`el.legacy_island` と `attr.data("yumemi-…")` で ★ が `data-yumemi-*` の印を書ける口(Y2 柏木 P1-7)は、runtime が読む印との兼ね合いで閉じ方を真壁さんが決める
7. `el.dialog` の 3 つと、invoker commands の無い browser の代わり ── どこまで。確認の 1 段(musearch 14 本)を interactive Component の中に書く ★ の語彙

## 持ち場(Y3 と Y6 の切り分け。Y6 の BRIEF と同じ字)
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
- `emit/front.gleam` の `shell_runtime_text` の読みの 5xx の行は Y6(503 `unavailable`)。Y3 はこの関数に触らない

## しないこと
route の照合の共有(継ぎ目 3)。navigate.mjs を client.mjs に畳む・改名(★ に見えない)。client で Out から一覧の行を作る型(1.0 の後)、JS の無い browser の送信と `formaction`、別の面への `GoTo`。`yumemi/new`。`@scope`・anchor・74 の 9 語の残り。**Y6 の持ち場** ── 門の session の読みの失敗、`ToService` と器の受け口(`server/http.mjs`)、数える口の検査(`FromQuery` の名・`Store` の `Path`)、`attr.action` と `css.Named` の柵、`emit/http.gleam` の Args の Color の decode(Y2 柏木 P1-5)、README の門の節の法の注意。media の配信(Y5 の形のまま)、取れないときの 2 回の GET。1.0 の前の起案(`yumemi/gen/*` の `internal_modules`、`glance` の固定、DB の schema 名 `framework`)。musearch の source(写しだけ)、`docs/runbook.md`(段 D)、harness-core の `docs/cloud-session.md`(publish の後に鷹野)。版の行・tag・publish・push。

## 失敗例(差し戻し)
- ★ の fixture か生成物が lustre・sketch_lustre を import する。`gleam export hex-tarball` の依存に残る。面の `src/gen/` に手で置いた `.gleam` の lustre の import が止まらない
- ★ が `update`・`app()`・State・Event を書ける口が残る。`pub fn app` を持つ module が止まらない
- 片方の送りの戻りで片方の Args を埋める書き方が、★ の Gleam で通る(51 v6「連鎖の禁止」の 4 経路)
- 送り 2 つの Component で、押していない送りの `required` で止まる、Enter で別の送りが走る、別の送りの `when` の枝が出る
- SSR の Component が空のタグ。JS の無い browser で本文が読めない。shadow root が残る、Component の中の class が文書の規則に当たらない
- 遷移の後に Component が起きない、または 2 回起きる。`boot` か given の手当が残る
- 取得の最中に `#` を押す・`replaceState` すると、URL と中身が食い違ったまま残る
- interactive Component が同じ path に `pushState` した後に戻ると、頁ごと取り直して状態が消えるか `spa` が 1 件数えられる。または results に書いた決め方と振る舞いが違う
- `GoTo` が自由な URL の文字列を受ける。path の穴を Out の外(Args・今の URL)から埋める
- `@external` が ★ に残る。逃げ道の数えが面ごとに 1 行でない、`_diagnostics.txt` と数が違う。pipe・関数参照の `static_sheet` が数えと第 28〜31 条を抜ける、`static_sheet("//host/x.css")` が外を読む、同じ file を 2 回数える
- lock の違う package を黙って通す。照合の外の package(auth の類)で止まる
- queue の consumer の基が、Service の足し引きで黙って替わる
- Y6 の持ち場の file・行を触る
- 書き換えで変わった test の期待値を理由を書かずに直す。落ちた test を消して本数を合わせる

## 検収
- root `npm ci` の後に root `gleam test` が通り、本数は基点 `e57bcf2` の 388 本から減っていない(before / after と、期待値を書き換えた test の名と理由を列で)。`gleam format --check` 0
- fixture の全面を生成して停止コード 0・2 回目の差 0。第 4〜6・9〜22・26・28〜31・41・43 条の 1 条ずつに止まる fixture か test が 1 つ以上あり、停止コードが 51 v6 の値
- **Chromium(fixture の面):**送りの成功・失敗・Refused の枝、送りの間の fieldset と `aria-busy`、送り 2 つの制約検証と Enter の送り、`ReloadPage` と `GoTo` の文言が 1 回だけ出る、`reloads` の単一の値(前の読みの中断)と一覧(履歴を積まず scroll と focus を保つ)、dialog の中の送り、逃げ道の mount と遷移での外し、client の遷移で移った先の Component が起きている
- **遷移の 2 つ:**Y4 柏木の race の台(`~/yumemism_repo/yumemi-012-y4/build/012-y4-k-harness-race.mjs` を本便の build に写す)で、`#` と `replaceState` の 2 通りとも URL と中身が揃う。pushState の後に戻る振る舞いが、決めた形どおり(取り直さないなら Component の状態が残り、同じ path に積んで戻っても `spa` が 0 件)
- **落ち方:**init script で `ElementInternals.states` を消した browser で同じ見た目(属性の側の規則)、`commandForElement` を消した browser で dialog が開け閉めできる
- shadow root が 0、JS が `<style>` を出さない、Component の中の要素の class が全部文書の規則に当たる(lustre を外した bundle と minify の bundle の両方で)。`gleam export hex-tarball` の依存に lustre・sketch_lustre が無い
- **数えの抜け道:**pipe と関数参照の `static_sheet` で第 28〜31 条が効き数えに入る、`static_sheet` に `//h/x.css`・`\h`・`a:b` を渡すと出ない、第 29 条の 4 つの書き方(括弧の中の空白・escape・`@scope` の前置き・`[class*="css-"]`)で止まる、同じ file を 2 か所で読んで 1 回と数える、面の `src/gen/` に手で置いた `.gleam` の lustre の import で止まる、Shell の色が literal でないとき第 26 条で 4
- lock の違う package を持つ fixture で第 41 条の停止、照合の外の package では止まらない。名前順の先頭に root の違う Service を足した fixture で、consumer の基が替わらない(か、名指して止まる)
- **musearch の写しで数えるだけ:**origin/main(`~/yumemism_repo/musearch`)を `.scratch/musearch` に置き、Y1 の名前の置き換えと Y5 の宣言の書き換えだけをして本作業木の生成器を当て、止まる条文ごとの件数と、逃げ道に移る FFI の file の数を results に(止まるのが期待どおり。段 D の 5 便を割る材料)。Hex の rate limit で落ちたら間を置いて回し直し、results に書く。写しは捨てる

## 鷹野に返す点
1. **上げ口と file の control(どこまで 9)は鷹野が裁いた。**51 v6 に足す行が要るなら results に書く
2. **止め線 経過 3 時間 30 分。**段 B の柏木の P1(どこまで 11〜13)が足され、Y2(2 時間 30 分・8 項)より広い ── runtime の JS の書き直し・条文 26・生成物 3 種の替え・継ぎ目 6・遷移の 2 つ・数えの抜け道。門と数える口の P1 は並行の Y6 に出してある。止め線までに閉じない項は results に残りを書いて閉じ、鷹野が割り方を決める
3. **継ぎ目 3(route の照合の共有)は 0.12.x に回す。**段 E の前のどこで入れるかは鷹野
4. **interactive Component の pushState(どこまで 11 の 2 つ目)の決め方**を results に書く。口を持つ形にしたなら、Y5 の送り手が数える・数えないの振る舞いも

## 確認できなかったこと
1. 上げ口と file の control を 0.12 の form と `data-yumemi-args` に載せたとき、Blob を送る経路(0.11.15 の `data-yumemi-file-input`)がそのまま使えるか
2. 51 v6 の確認できなかったこと 2・3・4・7・15・16・17(状態の CSS の 2 通り、dialog の代わり、bind の literal の読み、`focusReset: "manual"`、暗黙の送信の submitter、`With` の型を辿る、`:not()` の中の `:state()`)は本便の検収で初めて当たる
3. musearch の上げ口の 8 file は grep の数で、`pub const target` と `calls` の `Entry` の内訳は数えていない
4. queue の consumer の基の決め方で ★ の宣言が増えるか
5. class 名を constructor の名に依らない形にしたとき、SSR の Worker(workerd)の bundle でも合うか。Y2 は node と Chromium だけで、Worker では回していない
