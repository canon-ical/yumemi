# 真壁[IM]へ ── yumemi 0.11.10(便 yumemi-01110、格子の Style・下端に着く棒・折り返し、直書き、鷹野[PDM] 2026-10-03)

便: yumemi-01110(yumemi リポ、直書き、ゲートなし。終端は鷹野の検収)

**1 session で直に書く。長い処理を背景に回さない。**真壁は母艦の Opus。作業木 `~/yumemism_repo/yumemi-01110`(branch `impl/01110`、基点 forgejo main ac2519b = 0.11.9)。記録は `results-01110.md`(リポ直下)、証跡は `build/01110-*`(git の外)。commit は `git-as makabe`、main に触らない。push・tag・Hex の publish は鷹野。**版は 0.11.10。止め線は経過 45 分。**手本は 0.11.9 の `BRIEF-yumemi-0119.md`・`results-0119.md`(検収の形をそのまま使う)。

**親ゴール:** musearch の muses の下端のナビが、どの頁でも画面の下端に着き、iPhone の下端のバーに重ならない。長い URL が行の中で折り返す。どれも配信側の CSS を足さずに Style で書ける(役員 人見 2026-10-01「yumemi で表せない表現は生成器の宿題、配信側 CSS で逃げない」)。
- 障害:`Layout`・`Frame` は格子そのものの Style を持たず、格子の高さを viewport に合わせられない(musearch `docs/mf-dvh/results.md` の矛盾 1、`track.Track` に `Dvh` も無い)
- 障害:`Pin.Bottom` は `bottom: env(safe-area-inset-bottom)` で浮いて止まり、内側の余白を足すと inset が二重になる(同 矛盾 2)
- 障害:Style に `overflow-wrap` が無く、長い URL が行の外へはみ出す(musearch `docs/mf-10/results.md`)

## どこまで

1. **格子の Style**:`Frame`(sp・pc・tablet ごと)に格子の要素へ掛ける `style: List(Style)` を足す(既定は空、空なら出力は 0.11.9 と同じ)。`Space(MinHeight, Dvh(100.0))` を書けば格子の要素の `min-height: 100.0dvh`。`Frame.rows` の `Fr(1)` と組めば本文の行が残りを埋める。名と置き場(Frame か Layout か)は真壁の選択、理由を results に
2. **下端に着く棒**:`Pin` に、`bottom: 0` で留まり内側の下に `env(safe-area-inset-bottom, 0px)` の余白を持つ構成子を足す(例 `BottomFlush`。名は真壁の選択)。既存の `Bottom` の出力は変えない
3. **折り返し**:Style に `overflow-wrap: anywhere` を書ける語彙を 1 つ(`Wrap(Anywhere | BreakWord | Normal)` の類。名は真壁の選択)。root の `sketch_css` と gen の reader・emit の両方で通す
4. README の該当の節と 0.11.10 の変更点の段落

**しないこと:**既存の構成子の意味と出力を変える、`Path`・`Query`・`Session` を Layout に、popover の toggle、Style の他の語彙、Service・DDL・読みの生成、musearch の source、tag・publish・push。

## 失敗例(差し戻し)

足した語彙を使わない musearch で生成の差が 0 にならない。`Bottom` の出力が変わる。格子の Style が Area の Style と同じ class の衝突を起こす。

## 検収

- root `gleam test`(基線 21 groups)・gen `gleam test`(基線 326 passed)に (1)〜(3) の test を足して通す。`gleam format --check` は root・gen とも 0
- **musearch の写しで差 0**:musearch の origin/main の写しを `<作業木>/.scratch/musearch`(commit しない)に置き、基点 ac2519b の gen と本作業木の gen で全面を再生成して `git diff --stat` が 0、診断の行が全行一致。写しの 4 面の `npm run build`・`npm test` が通る
- **使えば効くことを 1 回**(写しの muses の source に足してよい、写しは捨てる):Frame に `Space(MinHeight, Dvh(100.0))` と `rows` の `Fr(1)`、nav の Area を (2) に、URL の行に (3)。Chromium 390×844 で、短い頁の棒の下端 = 844、長い頁で本文の位置が変わらない、長い URL の行の scrollWidth = clientWidth を results に
