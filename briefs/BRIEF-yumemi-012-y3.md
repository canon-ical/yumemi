# 真壁[IM]へ ── yumemi 0.12 段 C(便 yumemi-012-y3、interactive Component を form と custom state に移して lustre を外す、名前付きの逃げ道、lock の照合、段 B の継ぎ目、直書き、鷹野[PDM] 2026-10-12)

便: yumemi-012-y3(yumemi リポ、Opus 真壁の直書き、終端で柏木のゲートを便に 1 回 ── `KASHIWAGI_ROUTE=opus`)

**1 session で直に書く。細かい設計は真壁さんが決める(役員 人見 2026-10-12)。**作業木 `~/yumemism_repo/yumemi-012-y3`(branch `impl/012-y3`、基点は本 BRIEF の commit = 段 B の 3 便を merge した後の forgejo main `<段 B merge 後>` の上。sha は鷹野が起動時に書く)。記録は `briefs/results-yumemi-012-y3.md`、証跡は `build/012-y3-*`(git の外)。commit は `git-as makabe`、main に触らない。push・tag・Hex の publish は鷹野。**版の行(`0.12.0-dev`)に触らない。`0.12.0` への替えと tag・publish は本便の merge の後に鷹野。止め線は経過 3 時間 30 分。**

**段 C は本便 1 本で、並行の便は無い。**作業木は root で `npm ci` してから `gleam test`(80「段 A からの申し送り」)。

**親:**tech `_drafts/gleam-framework/51-front-types.v6.md` の「語」「型の一覧」「型引数」「Page の route と `Route`」「html と el」「interactive Component」「連鎖の禁止」「interactive Component の生成物」「SSR と custom element」「状態の写し」「After」「`reloads`」「読みと書き」「Out から一覧の行」「runtime」「遷移」の再起動の行、「名前付きの逃げ道」「逃げ道の数え方」「invoker commands」「interactive Component のスコープ」「media の variant」の `src`、「生成器」の lock の行と、「生成器が止めるもの」の第 4〜6・9〜22・41・43 条。`71-island-control.v0.md`(写像)、`72-authoring-surface.v1.md`(登録を生成器が吐く形・名前付き FFI の口)、`78-own-element-tree-poc.v0.md`(class 名が bundle で変わる)、`70-brief-front-rethink.md` 末尾の 2 節、`81-stage-b-ownership.v0.md`「段 C へ回す継ぎ目」、`80-baton-012.md`「段 A からの申し送り」、段 B の 3 BRIEF と results。

**親ゴール:**interactive Component は Args を受けて要素を返す view と、互いに独立した送りの `calls`・`after_send`・任意の `reloads` の宣言だけで書け、状態は form の control と `:state()` にあり、★ は update も lustre も書けない。FFI は名前付きの逃げ道としてだけ置け、生成器が数える。走る生成器と app の lock の yumemi が一致する。本便の merge で yumemi は 0.12.0 の形になり、段 D の musearch の 5 便はこの上に書く。
- 障害:★ が lustre を import して `app()` と `update` を書ける(musearch の interactive Component 129 本のうち 125 本が自前の update、71)。段 B の共存の例外がこの口を残している
- 障害:状態が lustre の model の中にあり CSS から見えない。SSR は空のタグで、JS が届くまで中身が無い。given を define の closure に焼き、遷移の後に `boot()` で起こし直す
- 障害:client での Service の連鎖(片方の戻りで片方を埋める)を ★ の update に書け、After が 2 値なので、移る先と文言を musearch が `location.assign` 13 本と sessionStorage 20 本で自作している
- 障害:0.12.0 を切った後に ★ の書き方が変わる所が残ると、段 D の後にもう一度 ★ を壊す
- 障害:0.11.15 の生成器が queue の consumer の基を名前順の先頭で選び、Service を 1 本足すと別の consumer が黙って 404 になる(musearch m012-api)

## 現在地(段 B の merge 後の main。【段 B】は段 B の結果で鷹野が確定する行)
- interactive Component は 0.11 の形 ── `pub fn app` で `lustre.component`、`view(it: State) -> Element(Event)`、`calls: List(front.Target(service, attached))` か `pub const target`、`after_send: live.After`(`Stay`・`ReloadPage`)、`reloads: List(#(Field, Service))`。`yumemi/front/live.gleam` は State 4 欄・Event 4 種・After 2 値(22 行)
- fixture の interactive Component は article の public の 4 本(`pick_tag`・`article_blob_copy`・`blob_save`・`like_button`)。`pick_tag` は given の一覧から `<option>` を作り、2 本は attached の上げ口(`Entry`)か file の control(`data-yumemi-file-input`)を持つ
- 生成器の interactive Component の群は `emit/front.gleam` の `live_targets`〜`quoted`、`transport_text`、`client_components`・`component_has_app`・`client_notes`、`client_text` の登録と `boot()`
- 【段 B】Y2 の共存 ── 第 1・2 条の例外(`pub fn app` の module と生成の live module)と、例外の数の診断の行がある。shadow root と `island_style.mjs` は、Y2 が外した枝なら無く、残した枝なら Y2 の results に食い違いの事実がある
- 【段 B】Y4 の遷移 ── 今の形のまま繋いだ枝なら、差し替えの後に client が渡した `boot` を呼び、差し替えの判定に given の条件が残る(Y4 鷹野の裁き 1)。外した枝なら無い
- 【段 B】逃げ道の数え ── Y2 の生の CSS と Y5 の `ToService` が別々の exit 0 警告と `_diagnostics.txt` の行
- 【段 B】`gen/media`(Y5)は Variant と `url` だけで `src` が無い。頁の色の地の画像は app の `media.url(.., media.W1600)` を焼く今の形。`el.img` の src は String
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
10. fixture の 4 本を新しい形に書き換え、逃げ道・`with`・`GoTo`・送り 2 つ・dialog の中の送り・`reloads` の 2 通りを使う fixture を足す。README の interactive Component・逃げ道・lock の節を現物に直す

## 段 B の継ぎ目 7 つの振り分け
**★ の書き方を変える継ぎ目は本便で全部閉じ、★ に見えない内部の重複だけを外す。0.12.0 の後に ★ を壊さないため。**
1. `el.Src` と `gen/media.src`、`el.img` の src を `Src` に、`el.static_src`(第 43 条)── どこまで。★ の `el.img` の引数の型が変わる
2. 頁の色の地の画像の URL を `gen/media` の `theme_background` で組む ── どこまで。app の `media` module の名を生成器が焼く形が残ると、別のアプリで生成物が compile しない
3. route の照合を門と遷移で 1 つの表に ── しないこと。★ に見えず、壊さずに 0.12.x で入る。本便の窓は interactive Component に使う
4. 逃げ道の数えの 1 行への統合 ── どこまで。3 つ目の数(escape)を本便が足すので、同じ手で 51 v6 の 1 行の形に揃える
5. navigate の `boot` の呼び出しを外す ── どこまで。【段 B】Y4 が残した枝なら、Component が接続のたびに自分の属性を読む形にした上で外し、差し替えの判定の given の条件も消す。外した枝なら確かめるだけ
6. 共存の外し ── どこまで。本便の芯。lustre・sketch_lustre を依存から外し、第 1・2 条の例外・一時の口・例外の数の診断の行・`el.island` を消す。【段 B】shadow root と `island_style.mjs` が残った枝なら消す(view は SSR で 1 回描くだけで client で sketch を回さないので、class 名の食い違いの元が無い)
7. `el.dialog` の 3 つと、invoker commands の無い browser の代わり ── どこまで。確認の 1 段(musearch 14 本)を interactive Component の中に書く ★ の語彙

## しないこと
route の照合の共有(継ぎ目 3)。navigate.mjs を client.mjs に畳む・改名(★ に見えない)。client で Out から一覧の行を作る型(1.0 の後)、JS の無い browser の送信と `formaction`、別の面への `GoTo`。`yumemi/new`。`@scope`・anchor・74 の 9 語の残り。門・数える口・器・media の配信(Y5 の形のまま)、取れないときの 2 回の GET。1.0 の前の起案(`yumemi/gen/*` の `internal_modules`、`glance` の固定、DB の schema 名 `framework`)。musearch の source(写しだけ)、`docs/runbook.md`(段 D)、harness-core の `docs/cloud-session.md`(publish の後に鷹野)。版の行・tag・publish・push。

## 失敗例(差し戻し)
- ★ の fixture か生成物が lustre・sketch_lustre を import する。`gleam export hex-tarball` の依存に残る
- ★ が `update`・`app()`・State・Event を書ける口が残る。`pub fn app` を持つ module が止まらない
- 片方の送りの戻りで片方の Args を埋める書き方が、★ の Gleam で通る(51 v6「連鎖の禁止」の 4 経路)
- 送り 2 つの Component で、押していない送りの `required` で止まる、Enter で別の送りが走る、別の送りの `when` の枝が出る
- SSR の Component が空のタグ。JS の無い browser で本文が読めない
- 遷移の後に Component が起きない、または 2 回起きる。`boot` か given の手当が残る
- `GoTo` が自由な URL の文字列を受ける。path の穴を Out の外(Args・今の URL)から埋める
- `@external` が ★ に残る。逃げ道の数えが面ごとに 1 行でない、`_diagnostics.txt` と数が違う
- lock の違う package を黙って通す。照合の外の package(auth の類)で止まる
- queue の consumer の基が、Service の足し引きで黙って替わる
- 書き換えで変わった test の期待値を理由を書かずに直す。落ちた test を消して本数を合わせる

## 検収
- root `npm ci` の後に root `gleam test` が通り、本数は基点から減っていない(before / after と、期待値を書き換えた test の名と理由を列で)。`gleam format --check` 0
- fixture の全面を生成して停止コード 0・2 回目の差 0。第 4〜6・9〜22・41・43 条の 1 条ずつに止まる fixture か test が 1 つ以上あり、停止コードが 51 v6 の値
- **Chromium(fixture の面):**送りの成功・失敗・Refused の枝、送りの間の fieldset と `aria-busy`、送り 2 つの制約検証と Enter の送り、`ReloadPage` と `GoTo` の文言が 1 回だけ出る、`reloads` の単一の値(前の読みの中断)と一覧(履歴を積まず scroll と focus を保つ)、dialog の中の送り、逃げ道の mount と遷移での外し、client の遷移で移った先の Component が起きている
- **落ち方:**init script で `ElementInternals.states` を消した browser で同じ見た目(属性の側の規則)、`commandForElement` を消した browser で dialog が開け閉めできる
- shadow root が 0、JS が `<style>` を出さない、Component の中の要素の class が全部文書の規則に当たる。`gleam export hex-tarball` の依存に lustre・sketch_lustre が無い
- lock の違う package を持つ fixture で第 41 条の停止、照合の外の package では止まらない。名前順の先頭に root の違う Service を足した fixture で、consumer の基が替わらない(か、名指して止まる)
- **musearch の写しで数えるだけ:**origin/main(`~/yumemism_repo/musearch`)を `.scratch/musearch` に置き、Y1 の名前の置き換えと Y5 の宣言の書き換えだけをして本作業木の生成器を当て、止まる条文ごとの件数と、逃げ道に移る FFI の file の数を results に(止まるのが期待どおり。段 D の 5 便を割る材料)。Hex の rate limit で落ちたら間を置いて回し直し、results に書く。写しは捨てる

## 鷹野に返す点
1. **上げ口と file の control(どこまで 9)は鷹野が裁いた。**51 v6 に足す行が要るなら results に書く
2. **止め線 経過 3 時間 30 分。**Y2(2 時間 30 分・8 項)より広い ── runtime の JS の書き直し・条文 22・生成物 3 種の替え・継ぎ目 6。割るなら「逃げ道と数え(どこまで 4・継ぎ目 4)」を別の便に出せるが、0.12.0 の前に 2 便とも閉じる
3. **継ぎ目 3(route の照合の共有)は 0.12.x に回す。**段 E の前のどこで入れるかは鷹野
4. **【段 B】の行**を Y2・Y4・Y5 の results で確定し、起動前に「現在地」と継ぎ目 5・6 の枝を 1 つに書き直す

## 確認できなかったこと
1. 段 B の 3 便は走っている最中で、作業木は基点 `31db577` のまま差が 0(10-12 04:22 に見た)。【段 B】の行は 3 BRIEF と 81 から書いた
2. 上げ口と file の control を 0.12 の form と `data-yumemi-args` に載せたとき、Blob を送る経路(0.11.15 の `data-yumemi-file-input`)がそのまま使えるか
3. 51 v6 の確認できなかったこと 2・3・4・7・15・16・17(状態の CSS の 2 通り、dialog の代わり、bind の literal の読み、`focusReset: "manual"`、暗黙の送信の submitter、`With` の型を辿る、`:not()` の中の `:state()`)は本便の検収で初めて当たる
4. musearch の上げ口の 8 file は grep の数で、`pub const target` と `calls` の `Entry` の内訳は数えていない
5. queue の consumer の基の決め方で ★ の宣言が増えるか
