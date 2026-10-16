# results yumemi-live-2 ── Live の Block を取り直して morph で当てる(0.15 の 2 便目、面と client の側)

真壁[IM]、2026-10-17。基点 `a9a463a`(`1d85a6a` + BRIEF の commit)。branch `impl/yumemi-live-2`。証跡は `build/live2-*.txt`(git の外)。版の行・tag・Hex は触っていない。DDL 無し。

## 1〜6 の充足

| # | 中身 | 置き場 | 充足 |
|---|---|---|---|
| 1 | ★ の語:`Placement` に `Live(area:, block:, cell:, edge:)`、`Edge`(`Bottom`・`Top`・`Anywhere`)、`el.each_keyed`、`el.fresh`。停止コード 4:Layout の `Live`・Block の Service が書き・Service に root の Entity が無い(allow に Entity が無い)。足したもの:Block が Service の Out を受けない・同じ Block の `Live` が 2 つ・pc/tablet の Frame の `Live`・端の名が読めない。警告:`el.each` の要素が interactive Component を持つ・`edge: Bottom` に `el.fresh` が無い | `src/yumemi/front.gleam`、`front/el.gleam`、reader は `Fixed(.., live: Option(String))`(`gen/reader/front.gleam`)、検査は `gen/emit/front.gleam` の `live_notes`(`gen.gleam` から呼ぶ) | 済 |
| 2 | 面の shell の断片の口:`x-yumemi-block: <name>` で、その Block の読み(と 404・403 の意味を保つ root の読み)と Vars の session だけを叩き、`<style>` と `<yumemi-live>` だけを返す(`no-store`、`vary`)。門は今の道、数える印は差さない。頁でない名・403・404 は同じ status | `gen/emit/front.gleam` の `shell_block_text`・`shell_live_rows`・`page_live_text`(loader の `live_<name>`)、`gen/emit/gate.gleam` の `text_live` | 済(生成した shell を node で叩いた、21 件) |
| 3 | client の runtime:`<yumemi-live>`(`display: contents`)が札で socket、`1` で 0〜500ms の揺らぎの後に取り直して 4 規則で morph、畳み、繋ぎ直し(1 秒から倍々・上限 30 秒・繋がったら 1 回取り直す)、`visibilitychange`、札の期限の 1 分前の取り直しと張り直し、`4001`・張れないときは先に取り直す、`edge` ごとのスクロール、`el.fresh`、`:state(stale)`、断片が 200 の HTML でなければ頁ごと | `src/yumemi/front/live_block.mjs`(新規)、生成の `client.mjs` が `startLive({socket, reload})` | 済 |
| 4 | 逃げ道の口 `yumemi.block(name, {href})`:今の URL なら取り直して当て、別の URL なら規則を足した `<yumemi-live>`(document の外)を返す、断片が無ければ null | `live_block.mjs` の `block`、`interactive.mjs` の `mount(element, yumemi)`、生成の `client.mjs` が `yumemi: { block }` を渡す | 済 |
| 5 | test:Playwright(2 者・CDP の IME・details・focus・3 つの edge・断片の CSS・stale・門 302/404・JS 無し・繋ぎ直し・期限・畳み・`yumemi.block`・WebKit)、生成器の test、生成した shell の断片の口 | `test/yumemi_live2_check.mjs`(38 件)、`test/yumemi_live2_shell_check.mjs`(21 件)、`test/yumemi_live2_test.gleam`(8 件、上の 2 本を子の node で回す) | 済 |
| 6 | README の 0.15 の節を client の側まで | `README.md`(The app's three steps の後) | 済 |

## 採った形と退けた形

- **reader は `Live` を `Fixed` の欄 `live: Option(String)` で持つ。**置き場と Block の読みは `Fixed` と同じで、reader と emit の `Fixed(..)` の 30 か所ほどの照合がそのまま効く。退けた形:reader に別の構成子を足す(全部の照合に枝が要り、漏れると Live の Block が描かれない)
- **断片は loader の別の関数 `live_<name>(vars, <Block の読み>)`。**頁の `Data` は全部の読みを要るので、Block の読みと `Vars` だけの record(`LiveArticle(vars:, article_read:)`)を置き、置き場の本文は頁と同じ字(`fixed_placement_body`)を使う。断片と頁で Block の HTML が同じこと(札を除く)を shell の検査で見た。退けた形:断片でも頁の読みを全部叩いて `render` から切り出す(BRIEF の「その Block の sources だけ」に反し、Layout の読みも走る)
- **札は shell が `<yumemi-live>` の開きの tag に差す**(loader は札を知らない)。SSR は属性を名の順に並べるので、tag の中の ` name="…"` で当てて先頭に `token` を足す。最初に `<yumemi-live name="` の字で当てる形で書き、生成した shell の検査で札が付かないのを見つけて直した
- **断片の名は Block の名の snake**(`article`)。同じ Block の `Live` が 1 頁に 2 つは exit 4(名が重なる)
- **断片で読むのは Block の Service と、頁と Layout の `!optional` の読み全部(root の印)と、Vars が要れば session。**root の読みは status だけ見て本文を捨てる。Layout の `optional` の読み(widget)と givens は叩かない(r2 で訂正:r1 は「Layout の読みは叩かない」と書いていたが、Layout の `!optional` の読みも叩く。`front.gleam` の `root: !optional`)
- **門の印:**`Live` のある面の `gate.mjs` だけ `if (request.headers.has(blockHeader) || !tracksPageview(context) ||`。`Live` の無い面の `gate.mjs`・`shell.mjs` は今の字のまま(fixture の admin の shell・gate と byte で同じを見た)。束ねた `client.mjs` は `interactive.mjs` の `yumemiApi`(`mount` の 2 つ目の引数)で変わる(r2 で訂正、`gen/fixtures/{article,cms}` の `client.mjs` を r2 で生成し直した)
- **client は `<template>` に断片を入れて読む**(中の custom element は起きない)。`<style>` の規則は cssText で document の規則と比べ、無いものだけを構築した 1 枚の sheet に足す(PoC の形。2 回当てても 1 本)
- **morph の鍵:**`data-yumemi-key` → Component は tag+Args → tag。Args の替わった Component は tag+Args では当たらないので、同じ tag の Component に緩く当て(新しい側で鍵どおりに後で当たるものは使わない)、4 規則の 2 の「差し替えか stale」に回す。PoC は Component の鍵を tag だけにしていた
- **持ち物の属性:**`details`/`dialog` の `open`、focus のある control の `value`/`checked`/`selected`(と focus のある textarea の字)、`el.fresh` の `hidden`。逃げ道は「来た側の属性が全部今の側に同じ値」なら触らない ── 最初は属性の数まで比べ、逃げ道の JS が自分に足した属性(試験の `data-mounted`)で毎回 mount し直していたのを検査で見つけて直した
- **来た札で張り直さない。**取り直しのたびに札が新しくなる(api は読むたびに exp の違う札を出す)ので、来るたびに張り直すと socket が毎回切れて、その間の合図が落ちる。来た札は持つだけで、張り直すのは期限の 1 分前の timer・`4001`・張れなかったときだけ。最初は来るたびに張り直す形で書き、繋ぎ直しの検査が張り直しを 2 回数えて気付いた
- **スクロール:**追うかは当てる前に決める(端から 8px 以内)。留まるときは、見えていた先頭の節の位置を当てる前と同じに戻す(browser の scroll anchoring が効いていれば差は 0 で何もしない)。scroller は Block の祖先の `overflow-y: auto|scroll` の要素、無ければ document。`el.fresh` は morph が何かを変えたときだけ出す(変わらない取り直し・繋ぎ直しでは出さない)。`Top` も印を出す(87 は `Bottom` だけを書いていたが、頭に入る並びで読んでいる人に新着を知らせる手が他に無い)
- **`:state(stale)`** は `ElementInternals.states` に足し、無ければ `data-yumemi-state` に足す(interactive の `setStates` と同じ落ち方)。接続した時の写しは `<yumemi-live>` の接続(と morph で挿した Component)で取る
- **頁ごとの取り直し**は navigate の `reload`(route 表のある面)、無ければ `location.reload()`。断片の fetch は `redirect: "manual"` で、門の 302 を追わずに頁ごとに落とす
- **runtime の file 名は `live_block.mjs`。**`live.mjs` は Gleam の `yumemi/front/live.gleam` の出力と同じ名で、gleam が止める(Gleam module clashes with native file)
- **playwright-core 1.63.0 を devDependencies に足した**(browser は `~/.cache/ms-playwright` の chromium-1243・webkit-2359 を使う、PoC と同じ版)。Hex の tarball には入らない
- 退けた形:Block を `replaceWith` で替える(87 の (i)、送りの欄が消える)。合図の本文・差分を client で継ぎ足す(BRIEF の失敗例)。チャット専用の分岐(試験の頁もチャットの形だが runtime は Block の名と edge しか見ない)

## test の表と証拠

| # | 何を | 結果 | 証拠 |
|---|---|---|---|
| 1 | `gleam test` | **`511 passed, no failures`**(r2 の 503 + 本便の 8)、3 回(最後は畳みの検査を直した後) | `build/live2-test-final-{1,2,3}.txt` |
| 2 | `node test/yumemi_live2_check.mjs`(Chromium 153・WebKit 26.6、playwright-core 1.63.0) | **ok 38、NG 0**。畳みの検査を直した後に単独で 6 回続けて 38/0。直す前の 9 回のうち 1 回が畳みの件で NG(下の「揺れ」) | `build/live2-check-6-{1..6}.txt`、直す前は `build/live2-flake-{1..6}.txt` |
| 3 | 2 者と IME | A が「書きかけ」を打ち CDP `imeSetComposition` で「にほんご」を変換中、B が送りの Component で送る → A に `1` → 取り直し → 新しい発言が見え、値は「書きかけにほんご」のまま、focus は送りの欄、`blur`/`focusout` 無し、`insertText` の確定で「書きかけ日本語」、composition は start → … → end の 1 本、送りの Component は `kept`。B の欄も残る(Stay) | 同上 `ime:`・`send:` 8 件 |
| 4 | details・focus | 2 行目の通報を開いて理由を書き 2 回取り直しても開いたまま・理由が残る。前に 1 行入っても開いているのは同じ発言の行(鍵)。通報の欄の focus も残る | `details:`・`focus:` 3 件 |
| 5 | edge | bottom:端なら追う(残り ≤ 8px)・100px を読んでいれば留まって `el.fresh`・押すと端へ・変わらない取り直しでは印を出さない。top:読んでいれば見えている行が動かない + 印、頭なら頭のまま新しい行が先頭。anywhere:前に行が入っても見えている行が動かず印無し、`overflow-anchor: none` でも runtime が戻す | `bottom:`・`top:`・`anywhere:` 8 件 |
| 6 | 断片の CSS | 頁に無い `.c-new` の規則が足され色が効く。2 回当てても規則 1 本、Block の中に `<style>` が残らない | `css:` 2 件 |
| 7 | stale | Args の替わった素の Component は差し替え(新しい値)、打ちかけは残して `:state(stale)`(見出しは新しい値) | `stale:` 2 件 |
| 8 | 門 | 断片が 302・404 → 頁ごと取り直す(頁の GET が増える) | `gate` 2 件 |
| 9 | JS 無し | 頁は読め、`el.fresh` は出ず、取り直しのリンクがあり、socket を張らない | `no js:` 1 件 |
| 10 | 繋ぎ直し | 切れたら張り直して 1 回取り直す、来た札では張り直さない、`4001` は先に取り直して新しい札で張る(close code を頁で見た)、張れない(server が札を断る)ときは取り直して新しい札で張る、`visibilitychange` で取り直す、同じ時の合図 6 回で取り直しは 1〜2 本、期限の近い札(30 秒)は張る前に取り直して新しい札で張る | `reconnect:`・`visibilitychange:`・`coalesce:`・`expiry:` 8 件 |
| 11 | `yumemi.block` | 今の URL は当てて要素を返す、別の URL は document の外の `<yumemi-live>`、無い名は null | `yumemi.block:` 3 件 |
| 12 | WebKit | 値・focus・選択範囲 [1,2] が当てをまたいで残る | `webkit:` 1 件 |
| 13 | 生成した shell(`node test/yumemi_live2_shell_check.mjs`) | article の写しの頁を `Live` にして生成器を走らせ(停止コード 0、警告 1 = `el.fresh` 無し)、面を `gleam build`(loader の `live_article` が compile できる)、生成の `shell.mjs` を偽の APP で叩く:頁に `<yumemi-live token edge name>`・`display: contents`・数える印、断片は `<style>` と `<yumemi-live>` だけで頁と同じ HTML、読みは session と Block の Service だけ、`no-store`/`vary`・数える印無し、頁でない名 404、root 404→404・403→403、札が無ければ属性無し、札の値の escape、束ねた `client.mjs` に runtime、admin の面(Live 無し)の shell と gate は commit した fixture と byte で同じ。**ok 21、NG 0** | `build/live2-shell-3.txt`、写しは `build/live2-fx` |
| 14 | 生成器の test(gleam) | 包み・`live_<name>`・`lives` の表・断片の口・札の差し・門の印・client の起こし・端の小文字、Live の無い面は fixture と同じ字、exit 4 の 5 通り(Nil を受ける Block・root の無い Service・書きの Service・同じ Block 2 つ・Layout)、警告(関数を名で辿った `el.each` の Component・`el.fresh` 無し、`each_keyed` と `el.fresh` があれば出ない、`Top` は印の警告無し)、`each_keyed`・`fresh` の字 | `test/yumemi_live2_test.gleam`(#1 に含む) |
| 15 | mutation(`live_block.mjs` を書き換えて回し、戻した) | 下の表。8 通りすべて NG ≥ 1 | `build/live2-mut-*.txt`、`build/live2-mut-summary.txt` |
| 16 | `gleam format --check`(本便で触った gleam 7 file) | exit 0(作業木全体の check は本便の前からの未整形 8 file で 1) | このセッションの実行 |

| mutation | NG | 捕まえた件 |
|---|---|---|
| Component を Args で比べない(いつも差し替えか stale) | 2 | 送りの Component が `kept` でない(focus があるので stale に回り値は残る)・変わらない取り直しで印が出る |
| `details` の `open` を持ち物にしない | 3 | 開閉と理由・前に行が入った件・通報の欄の focus |
| 断片の `<style>` を足さない | 2 | 色が効かない・規則 0 本 |
| 繋がったときに取り直さない | 1 | 切れた後の 1 回の取り直し |
| 断片が来ないときに頁ごと取り直さない | 2 | 302・404 |
| stale の判定を外す(書きかけでも差し替え) | 1 | 打ちかけの名前が消える |
| 合図を畳まない | 1 | 6 回の合図で 6 本(検査を同じ時の合図に直した後も 2 回回して 2 回とも 6 本) |
| 見えていた行の位置を戻さない | 0 → 1 | Chromium の scroll anchoring が覆うので最初は 0。`overflow-anchor: none` の件を足して 1 |

## 確かめていないこと

- **Android の Chrome と Gboard の変換中の文字、iOS Safari の日本語入力。**母艦の CDP の IME は desktop の composition の道で、Gboard は語ごとに composition を張り直す。WebKit は Playwright の WebKit 26.6 で値・focus・選択範囲だけを見た(IME は CDP が無い)。検収の項(87 の「便の割り」、人見の電話か Android emulator)
- **実の api と面を繋いだ e2e。**client の検査の server は試験の node(shell の形の頁・手で書いた WebSocket)で、api の札・DO・socket の口(1 便目、workerd で見た)とは繋いでいない。生成した shell は偽の APP で叩いた。実の `wrangler dev` で api と面を立てて 2 者で送るのは M1(musearch)の Playwright の持ち場
- **揺れ(直した):**`gleam test` の中で 1 回 `live_runtime_in_browsers_test` が落ち、単独の 6 回の 1 回で畳みの件が 3 本(期待 ≤ 2)だった。合図を 20ms おきに 6 回送っていて、揺らぎが短いと「取りの後に来た合図」が次の取りになる ── runtime は設計どおり(取りの最中の合図だけを 1 つに畳む)で、検査の期待が強すぎた。同じ時に 6 回送る形に直し、以後 単独 6 回・`gleam test` 1 回で NG 0。落ちた行を test の失敗に出す形にもした。散らばった合図の本数の上限は見ていない
- **WebKit のスクロールと `el.fresh`**(Chromium だけで見た)、Firefox は見ていない
- **断片の CSS の `@media`・`@supports` の中の規則**(cssText で比べるので入れ子の規則は塊ごとに比べる。試験の規則は平らなものだけ)
- **`yumemi.block` の別の URL の Block を差し込んだ後**(day_swipe の形)の繋ぎ:差し込んだ `<yumemi-live>` は接続すると自分の札で socket を張る。M2 で day_swipe が乗るときに見る
- **★ の `when` で stale を出す口**(87 の「状態の名は生成器の `when` の表に 1 つ足す」)は入れていない。`:state(stale)` と `data-yumemi-state~="stale"` は立つが、★ の Component の中で `when` で出し分ける生成は無い
- **送った後の `ReloadPage` は body の差し替えのまま**(BRIEF の「しないこと」)。送った本人の頁は `ReloadPage` の取り直しと自分の合図の取り直しが重なることがある(畳みで 1〜2 回)
- 生成器の警告の `el.each` の判定は字で見る近似(`el.each(` の引数と、そこから名で呼ぶ同じ module の関数を推移的に辿り、`interactive.` を探す)。別の module の関数を辿らない
- fixture(`gen/fixtures/**`)に `Live` の頁は足していない。`Live` の生成物は test が写しで作って見る

## DDL

無し。

## r2(柏木 ゲート 2 の P2 と P1、2026-10-17)

真壁[IM]、基点 `6e4c12e`(`04d1e2d` + BRIEF r2)。指示 `briefs/BRIEF-yumemi-live-2-r2.md`。ゲート 2 は掛け直していない。証跡は `build/r2-*.txt`(git の外)。DDL 無し。

### 1〜10 の充足

| # | 中身 | 置き場 | 充足 |
|---|---|---|---|
| 1 | P2-1:断片も置き場の `cell` で包む。`page_live_cell` が Page の sp の `Live` の cell を引き、`page_live_text` が `Flow` でなくその cell で `fixed_placement_body` を描く | `gen/emit/front.gleam` | 済(`Span` の頁と断片で包みと HTML が同じ) |
| 2 | P2-2:頁に描かれた札だけ期限を見る(1 分を切れば先に取り直し、でなければ 1 分前の timer を 1 回)。取り直して来た札は期限を見ずに張り、期限は server の `4001` に任せる。繋ぎ直しの倍々の待ちは「開いて 30 秒続いた socket」で戻す(開いてすぐ閉じられる輪も倍々)。札が替わらない取り直しの輪も倍々 | `live_block.mjs` の `yumemiConnect(lookAhead)`・`yumemiReconnect`・`yumemiScheduleRetry` | 済 |
| 3 | P2-3:頁ごとは redirect(3xx・opaqueredirect)・403・404 と、200 でも断片の形でない(HTML でない・その名の `<yumemi-live>` が無い)ときだけ。5xx・その他の status・通信の失敗は `{error}` で、頁に触らず倍々(1 秒から、上限 30 秒、揺らぎつき)で取り直す。取れたら待ちを戻す | `fetchBlock`・`yumemiApply` | 済 |
| 4 | P2-4:在る規則の表を持たず、取るたびに document の今の sheet(`styleSheets` と `adoptedStyleSheets`、足した sheet も)から作り直す。足した sheet が外れていれば付け直す | `documentRules`・`adopt` | 済 |
| 5 | P2-5:当てる前に「守る節」を集める(focus のある要素、写しと値の違う・focus のある Component、Component の外の書きかけ・focus の control)。前へ探す照合で、`olds[at..found]` のうち守る節を持つ古い節が飛ばされる(か、受けられない新しい節に当たる)とき、後ろの新しい節に受けられるもの(同じ鍵で、中に同じ目印の Component / control がある)があれば、その当たりを使わず今の新しい節を新しく挿す。README:497 の言い切りは「後ろに受け手がある限り飛ばさない、新しい HTML に受け手が無いときだけ外れる」に直した | `guardsOf`・`receives`・`dropsGuarded`・`morphChildren`、`README.md` | 済 |
| 6 | P2-6:`yumemi.block` が別の URL から返した `<yumemi-live>` は取った URL(絶対)を `href` に持つ。`refresh` は `href` があればそこから取る(合図・`visibilitychange`・開いた後)。`yumemi.block(name, {href})` は `href` の合う置かれた要素があれば、それをその場で取り直す。root の属性は morph で同期しないので `href` は当てで消えない | `block`・`yumemiHref` | 済 |
| 7 | P2-7:README の断片の読み(`!optional` の読みは Layout の分も叩く)・`client.mjs` の差(`Live` の無い面も束ねた client.mjs は変わる)・r1 の results の 2 行を事実に。`gen/fixtures/{article,cms}/public/priv/static/_yumemi/client.mjs` を写しで生成し直して書き戻した(差は `yumemiApi` の 4 か所だけ) | `README.md`、本 file の r1 の節、fixture | 済 |
| 8 | P1-2・P1-3:socket が開くたび(最初も、張り直しも)に `signal()` で 0〜500ms の揺らぎの後 1 回取り直す。繋ぎ直しの待ちは待ちの半分〜全部の揺らぎ | `socket.onopen`、`jittered` | 済 |
| 9 | P1-4:警告を鍵の無い並び全体に広げた:`el.each(`・`list.map(`・`list.index_map(`・`list.flat_map(` の引数の字(と、そこから名で辿る同じ module の関数)が `interactive.` か素の `details`(`html.details`・`el.element("details"`)を持つ。広げられない形(別の module の関数、再帰・`list.fold` で組む並び、値として渡す Component・details)は README の警告の段に書いた | `unkeyed_list_with_state`・`holds_user_state`・`unkeyed_list_texts`、`README.md` | 済 |
| 10 | P1-8:1〜6 と P1-2・P1-3 を捕まえる test(柏木の probe の形を移した)。mutation で 1〜6 を戻すとどれも NG ≥ 1(下の表) | `test/yumemi_live2_check.mjs`(+10 件)、`test/yumemi_live2_shell_check.mjs`(+1 件)、`test/yumemi_live2_test.gleam`(+1 件、警告の 3 形) | 済 |

### 採った形と退けた形(r2)

- **守る節の受け手は「同じ鍵 + 中に同じ目印」。**目印は Component なら tag と `data-yumemi-island`(鍵があれば鍵)、control なら tag と `name`(無ければ `id`)。退けた形:守る節を持つ古い節をいつも残す(server が本当に消した Component が残り続ける)。受け手が後ろに無いときは今までどおり当てる ── 新しい HTML にその Component が無いなら外れる
- **頁に描かれた札の期限だけ見る。**退けた形:期限の前を見るのを全部やめる(BRIEF r1 の「札の期限の前の取り直し」が消える)。取り直して来た札にも 1 分前の timer を置く(client の時計が進んでいると timer が即時になり、輪に戻る)
- **倍々の待ちを戻すのは開いて 30 秒続いた socket が切れたとき。**r1 は開いたら戻していたので、開いてすぐ `4001` で閉じられる輪は 1 秒おきに回っていた
- **200 でも断片の形でないものは頁ごとのまま。**`x-yumemi-block` を知らない古い shell が頁を返した形で、待って取り直しても直らない。BRIEF の「頁ごとは redirect・403・404 だけ」からの差としてここに書く
- **`href` は `<yumemi-live>` の属性。**SSR の要素は持たず、`yumemi.block` が document の外の要素に足す。morph は root の属性を同期しない(札だけ替える)ので消えない
- `visibilitychange` は倍々の待ちを戻さない(待っている繋ぎ直しを今やるだけ)。r1 は 1 秒に戻していた

### test の表と証拠(r2)

| # | 何を | 結果 | 証拠 |
|---|---|---|---|
| 1 | `gleam test` | **`512 passed, no failures`**(r1 の 511 + 生成器の cell の 1 件。警告の 3 形は既存の件に足した) | `build/r2-test-2.txt` |
| 2 | `node test/yumemi_live2_check.mjs` | **ok 48、NG 0**(r1 の 38 + 10)。単独で 3 回続けて 48/0 | `build/r2-check-2.txt`、`build/r2-check-rep-{1,2,3}.txt` |
| 3 | `node test/yumemi_live2_shell_check.mjs` | **ok 22、NG 0**(頁の置き場を `Span(cols: 2, rows: 1)` にして、頁と断片の `<yumemi-live>` の中身が同じ + 包みの div が両方にある) | `build/r2-shell-1.txt`、#1 にも含む |
| 4 | P2-1 | 生成器:loader の `"grid-column: span 2; grid-row: span 1;"` が頁の helper と `live_article_view` の 2 か所 | `live_fragment_keeps_the_cell_test` |
| 5 | P2-2 | 時計を 2 時間進めた頁:socket が開き、落ち着いた後の 3 秒で断片 0 本(落ち着くまで ≤ 3 本。r1 は 3 秒で 5778 本)。開くとすぐ `4001` で閉じる server:6 秒で張り 2〜4 回 | `clock ahead (P2-2)`・`backoff (P2-2)` |
| 6 | P2-3 | 503 と通信の切断(`socket.destroy`)で:頁の読み込み 0、送りの欄の書きかけと focus が残り、server が戻ると合図無しで新しい発言が当たる | `retry (P2-3)` 2 件 |
| 7 | P2-4 | 頁の `<style>` を外した後の断片で `.c-line` の `min-height: 120px` が効く | `css (P2-4)` |
| 8 | P2-5 | 条件で出る `<p>` が前に入る(後ろに `<p class="c-foot">`)・鍵の無い同じ tag の `<div>` が前に入る、の 2 形で:送りの欄の値と focus、Component の外の `<input name="memo">` の書きかけが残り、要素も同じ物、入った節は描かれる | `morph (P2-5)` 2 件 |
| 9 | P2-6 | `?edge=anywhere` の Block を `replaceWith` で置く:`href` を持ち、合図と `visibilitychange` の取り直しはどちらも `?edge=anywhere`(頁は `?edge=bottom`)。同じ href の `yumemi.block` は置いた要素を返す | `yumemi.block (P2-6)` |
| 10 | P1-2 | socket の upgrade を 400ms 遅らせ、その間の発言が開いた後の取り直しで見える。`4001` の後も張り直して開いた後にもう 1 本 | `open (P1-2)` |
| 11 | P1-3 | `Math.random` を 0 と 0.999 にした 2 枚:繋ぎ直しは約 500ms と約 1000ms、開いた後の取り直しは 0ms と約 500ms 後 | `jitter (P1-3)` |
| 12 | P1-4 | 警告:`list.map` の並びの Component・`el.each` の行の素の `details`(関数を名で辿る)で出る、`list.map` で `el.text` だけなら出ない | `live_warnings_test` |
| 13 | r1 の件 | 時間の掛かる 2 件の待ちを延ばした(繋ぎ直しの待ちが倍々のまま続くため。`4001` 5→8 秒、張れない札 8→16 秒)。張れない札の件は開いた後の取り直しが札を出し終えるのを待ってから札を消す。期限の件は頁の札だけ 30 秒(`pageTtl`)にした ── 断片の札も 30 秒だと、r2 では期限を見ずに張るので | 同上 |
| 14 | `gleam format --check`(触った gleam 2 file) | exit 0 | このセッションの実行 |

| mutation(戻したもの) | NG | 捕まえた件 |
|---|---|---|
| M1 P2-1:断片を `Flow` で描く | 2 | 頁と断片の HTML が違う(5031 / 4973)・包みが断片に無い |
| M2a P2-2:取り直して来た札でも期限を見る | 1 | 時計 2 時間進み:socket が開かず、最初の 1 秒で 1316 本・その後の 3 秒で 2174 本 |
| M2b P2-2:開いたら倍々の待ちを戻す | 1 | 開いてすぐ閉じる輪が 6 秒で 7 回 |
| M3 P2-3:200 でなければ頁ごと | 1 | 503 で頁の読み込み 2、書きかけが消える(通信の切断の件は別の道なので通る) |
| M4 P2-4:在る規則の表を頁で持ち越す | 1 | `min-height` が 0px |
| M5 P2-5:守る節を見ない | 2 | 2 形とも送りの欄の値と focus が消える(`<p>` の形は memo も) |
| M6 P2-6:別の URL の要素に `href` を付けない | 1 | 合図・`visibilitychange` が `?edge=bottom` から取る |
| M6b P2-6:`href` を見ずに今の URL から取る | 1 | 同上 |
| M7 P1-2:開いたときに取り直さない | 3 | 切れた後の 1 回・開くまでの発言・揺らぎの件 |
| M8 P1-3:繋ぎ直しの待ちに揺らぎが無い | 1 | 2 枚とも 1001ms |
| M9 P1-3:開いた後の取り直しに揺らぎが無い | 1 | 2 枚とも開いて 1〜2ms で取る |

証拠:`build/r2-mut-*.txt`、まとめ `build/r2-mut-summary.txt`。走らせた mutation の script は作業木の外(`/tmp/claude-1000/-home-yumemism-yumemism-repo-yumemi-live-2/669a1f00-2df6-405b-ac4c-f4d4653beda8/scratchpad/mut.py`、file を書き換えて回し、元に戻す)。P1-4 の警告の mutation は回していない(gleam の件が出る形と出ない形の両方を見ている)。

### 確かめていないこと(r2)

- **P1-1(直さない):**断片の読みが 87 の「Block の Service と root の 1 本」より多い(頁と Layout の `!optional` の読みを全部叩く)。断片は `optional` の読みの 403 を見ないので、その場合だけ status が頁とずれる。README は事実に合わせて書いた
- **P1-5(直さない):**断片から足す規則は document の全 sheet の後ろに入るので、同じ詳細度の規則の勝ち負けが SSR の順と変わりうる。`@media` の塊は塊ごとに比べるので、同じ規則を重ねて足すことがある
- **P1-6(直さない):**逃げ道を当てるかの判定は来た側の属性しか見ないので、server が属性を外しても逃げ道に届かない
- **P1-7(直さない):**門の印は gate の字の `string.replace` に頼っていて、字が変わると黙って外れる
- **鍵の無い並びの素の `details` の開閉**は runtime では守らない(P1-4 は警告だけ)。守る節は focus と書きかけだけで、開いた `details` は前に行が入ると別の行へ移りうる
- **守る節の受け手の判定の粗さ:**目印は tag と `name`(か `id`)なので、同じ `name` の control が複数の行にある鍵の無い並びでは、別の行を受け手と見ることがある。鍵があれば鍵で決まる
- **時計のずれの件は進んだ時計だけ**を見た(遅れた時計は、頁の札が長く見えて 1 分前の timer が遅れるだけで、server の `4001` で張り直す道に入る。走らせていない)
- **倍々の待ちを戻す 30 秒**は試験で 30 秒続く socket を作っていないので、戻る側は走らせていない(戻らない側は `backoff (P2-2)` と M2b で見た)
- r1 の「確かめていないこと」(Android の Gboard・iOS の日本語入力、実の api と面の e2e、WebKit のスクロール、Firefox、`@media` の中の規則、day_swipe の形の実地)はそのまま残る。別の URL の Block を置いた後の取り直しは試験の server で見た(M2 の day_swipe の実地は未)
