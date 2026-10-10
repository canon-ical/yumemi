# 真壁[IM]へ ── yumemi 0.11.14(便 yumemi-01114、指で押した後に焦点の枠と hover の地が残る、直書き、鷹野[PDM] 2026-10-11)

便: yumemi-01114(yumemi リポ、直書き、ゲートなし。終端は鷹野の検収)

**1 session で直に書く。長い処理を背景に回さない。**真壁は母艦の Opus。作業木 `~/yumemism_repo/yumemi-01114`(branch `impl/01114`、基点 forgejo main = 0.11.13)。記録は `briefs/results-yumemi-01114.md`、証跡は `build/01114-*`(git の外)。commit は `git-as makabe`、main に触らない。push・tag・Hex の publish は鷹野。**版は 0.11.14。止め線は経過 45 分。**検収の形は `briefs/BRIEF-yumemi-01113.md` と同じ。

**親ゴール:** 電話で指で押したボタンに、押した後の焦点の枠も hover の地も残らない。キーボードで来た人には焦点の印が出て、マウスの人には hover の地が出る(役員 人見 2026-10-11「ずれて見える」、musearch の nv-2 で鷹野が電話の絵から見つけた跡)。
- 障害(musearch nv-2 の実測、`musearch/docs/nv-2/results.md`):`css.Interaction` は `Hover`・`Focus`・`Disabled`・`Current` の 4 つで、`Focus` は `:focus` に出る。touch で押すと `:focus` が true・`:focus-visible` が false で、枠が残る。`Hover` は touch の後も `:hover` が残り、地が残る
- 障害:`:focus-visible` も `@media (hover: hover)` も Style で書けない。配信側の CSS で逃げない(役員 人見 2026-10-01)

## どこまで

1. `Interaction` に、キーボードの焦点だけに掛かる物(`:focus-visible`)と、hover が出来る端末だけに掛かる hover(`@media (hover: hover) { …:hover }`)を足す。名は真壁の選択(例 `FocusVisible`・`HoverCapable`)、理由を results に。既存の `Hover`・`Focus` の出力は変えない
2. root の `sketch_css` と gen の reader・emit の両方で通す(島の Style も Block の Style も)
3. test:2 つの新しい語の CSS の字、既存の語の字が 0.11.13 と同じ
4. README の Style の節と 0.11.14 の段落

**しないこと:**既存の語の意味を変える、他の Style の語彙、musearch の source、tag・publish・push。

## 失敗例(差し戻し)

足した語を使わない musearch で生成の差が出る。`@media` の中の規則が class の詳細度で負ける。

## 検収

- root `gleam test`・gen `gleam test`(基線 24 groups・339 passed)に足して通す。`gleam format --check` 0
- **musearch の写しで差 0**:origin/main の写しを `.scratch/musearch` に置き、基点と本作業木の gen で全面を再生成して差 0、写しの 4 面の build・test が通る
- **使えば効く 1 回**(写しの muses の `style.nav_tab` の `State(Focus, …)` と `State(Hover, …)` を新しい語へ掛け替えてよい、写しは捨てる):Chromium 360px・`hasTouch` で muses のナビのトグルを CDP の touch で 2 回押した後、outline が none・地が透明。キーボードの Tab で来たとき outline が出る。`hasTouch` 無しのマウスの hover で地が出る。computed style を表で results に
