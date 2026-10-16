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
- **断片で読むのは Block の Service と root(`!optional` の source)と、Vars が要れば session。**root の読みは status だけ見て本文を捨てる。Layout の widget と givens は叩かない
- **門の印:**`Live` のある面の `gate.mjs` だけ `if (request.headers.has(blockHeader) || !tracksPageview(context) ||`。`Live` の無い面の `gate.mjs`・`shell.mjs`・`client.mjs` は今の字のまま(fixture の admin の shell・gate と byte で同じを見た。fixture は生成し直していない)
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
