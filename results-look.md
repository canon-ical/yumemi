# yumemi-look 真壁 ── 0.11.7:Style に見た目の語彙 7 つ(2026-09-30)

証跡は `gen/build/look/`(git の外)。入力の musearch は main `c3167cbb` を `git archive` した写し(musearch には書いていない)。基点は v0.11.6(`9513d30^` = `3673fb6`、同じく `git archive`)。

## 状態

- 版 0.11.7(`gleam.toml`・`gen/manifest.toml` の path 依存の行)
- root build 0、root test 13 群(0.11.6 の 8 + 足した 5)、gen test 318 / 0、format 0(root・gen)
- musearch main を入力にした生成 ×2(基点と本便):両方 exit 0、診断は全行一致、1778 file ずつで `diff -r` は **差 0**(`ms-diff.txt` 0 byte。「package の版の行」は生成物に出なかった ── 面は yumemi を hex 依存で持ち、版は生成物に書き込まれない)

## 型の形(真壁の選択)と理由

足すだけ。既存の variant・型の意味と出力は 1 字も変えていない。

- **地の色 → 新しい variant `Background(value: String)`。**`Color` は文字の色のまま(失敗例にある通り意味を変えない)。値は文字列のまま `background-color` に渡すので `var(--ma-color-bg)` も `color-mix(...)` も書ける(test で両方見た)
- **罫線 → 新しい variant `Border(edge:, width:, style:, color:)`。**edge は新しい型 `BorderEdge { AllEdges, BottomEdge }`(`Pin` に `Bottom` が居るので constructor 名は `AllEdges` / `BottomEdge`)。`AllEdges` は `border`、`BottomEdge` は `border-bottom` に写す。太さは `Length`、線の種類は `BorderStyle { Solid, Dashed, Dotted }`、色は文字列。タブの下線 2px は `Border(BottomEdge, Px(2.0), Solid, ..)`(test あり)
- **focus の輪 → 新しい variant `Outline(width:, offset:, color:)`。**`outline-width`・`outline-offset`・`outline-color` に写す。`State(Focus, ..)` の中で使える(test で `:focus` 内に出ることを見た)
- **最小と最大の寸法 → `SpaceProperty` に `MinWidth`・`MinHeight`・`MaxWidth` を足す。**`Space(property:, value:)` の形がそのまま使え、既存の `Width` らと並ぶのが自然なので variant を新しくしなかった。`min-width`・`min-height`・`max-width` に写す
- **書体を名で指す → `FontFamily` に `Named(String)`。**`var(--ma-font-ui)` のような CSS 変数も `"Noto Sans JP", sans-serif` のような名も、そのまま `font-family` に渡す(test で両方見た)。色と同じ「値はアプリが持つ」の形
- **太さ 600 → `FontWeight` に `SemiBold`。**`font-weight: 600` に写す
- **画像の切り抜き → 新しい variant `Crop(fit:, ratio:)`。**fit は `ObjectFit { Cover, Contain, Fill, ScaleDown, FitNone }` を `object-fit` に、ratio は `Ratio(width: Float, height: Float)` を `aspect-ratio`(`16.0 / 9.0` の形)に写す

`State`・`Responsive` は `List(Style)` を包むだけなので、新しい variant はそのまま両方の中で使える。`Responsive(PC, ..)` の中の `Border`・`MaxWidth` は test あり。

## test(root `test/yumemi_test.gleam`、5 群)

- `look_background_border_and_outline_render_to_css`:地の色(CSS 変数と `color-mix`)、罫線(全周・下だけ 2px)、focus の輪(width・offset・color)が CSS の文字列に出る
- `look_min_max_named_family_and_weight_render_to_css`:`min-height`・`min-width`・`max-width`、`Named`(CSS 変数と Noto Sans JP の名)、`font-weight: 600`
- `look_crop_renders_to_css`:`object-fit: cover`・`aspect-ratio: 16.0 / 9.0`
- `look_styles_work_inside_state_and_responsive`:`State(Focus, ..)` の中の `Outline`・`Background`、`Responsive(PC, ..)` の中の `Border`・`MaxWidth`
- `look_styles_reach_island_shadow_style`:**island_style の経路**。`front_sketch_css.class` で新しい Style 4 つ(Background・Border・Outline・Crop)を class にし、FFI(`test/yumemi_look_ffi.mjs`)から `island_style.mjs` の `styled(app)` で包んだ view を node で描くと、島の `<style>` に 4 つの CSS が全部出る(gen/test の H8 と同じ形)

## musearch main の生成差(0)

- 手は `results-s-2.md` に倣う。入力は main `c3167cbb` の `git archive` の写し 2 本(`out-base`・`out-new`)。基点側は `9513d30^` の写しの `gen/`、本便側は作業木の `gen/` で、`gleam run -m yumemi_gen -- <写し>/api <写し>`(musearch の `docs/runbook.md` の手)
- 両方 exit 0、書いた file は両方 1778、診断(警告 39 行 + 停止コード 0)は全行一致。`diff -r` は差 0(`gen/build/look/ms-diff.txt` は 0 byte。`.claude` の symlink 2 本は archive に実体が無く両側同一なので除外)

## DDL

無し。

## 残り・鷹野さんへ

- `attribute.attribute("style", …)` の抜け穴を塞ぐのは別便のまま(触っていない)
- ブランドガイドの色・書体の値そのもの(CSS 変数 `--ma-*` の定義)はアプリ(www)側の仕事。yumemi には hex を焼いていない
- staging / production への適用・publish・push は鷹野さん

## r2 ── Outline に outline-style を出す(鷹野検収の差し戻し 1 点、2026-09-30)

- 障害:`Outline` が `outline-width`・`outline-offset`・`outline-color` しか出さず、`outline-style` の既定は `none` なので `State(Focus, [Outline(..)])` を書いても輪が描かれない
- 直し:`sketch_css.gleam` の `Outline` の枝に `sketch_css.outline_style("solid")` を 1 本足した。**型の形は solid 固定にした。**理由:差し戻しの要件は「`outline-style: solid` を出す」で、focus の輪の線種を変える要求はブランドガイドに無い。欄を足すと r1 の型(`Outline(width:, offset:, color:)`)を壊すので、足さない方が手戻りが少ない。線種が要るときは別便で `BorderStyle` を足せばよい
- test:`State(Focus, [Outline(..)])` の CSS に `outline-style: solid;` が出る断言を `look_styles_work_inside_state_and_responsive` に。island の shadow の test(`look_styles_reach_island_shadow_style`)にも 1 行。直接の `Outline` の test(`look_background_border_and_outline_render_to_css`)にも 1 行
- README の Style の表と 0.11.7 の節の `Outline` の記述に `outline-style: solid` を追記

### 検収(r2)

- `gleam format --check src test`:0(差分無し)
- root `gleam test`:13 群 PASS(`Framework checks passed: 13 groups`、EXIT=0、`build/r2-gleam-test-root.txt`)
- `gen/` `gleam test`:318 passed, no failures(EXIT=0、`build/r2-gleam-test-gen.txt`)
- musearch main を入力にした生成の差 0 をもう 1 回:r1 の写し(`gen/build/look/ms-input`、main `c3167cbb`)を `out-r2` にコピーし、作業木の `gen/` で `gleam run -m yumemi_gen -- build/look/out-r2/api build/look/out-r2`。EXIT=0、書いた file 1778(out-base と同じ)、診断は出力 path の行以外全行一致。`diff -r out-base out-r2` は `.claude` の symlink 2 本(r1 と同じ、archive に実体が無い)だけで**生成物の差 0**(`gen/build/look/ms-diff-r2.txt`、4 行とも symlink)

### DDL

無し。
