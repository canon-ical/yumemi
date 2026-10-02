# results ── yumemi-01110(0.11.10、真壁 r1)

基点 `b82b19c`(BRIEF の commit、main ac2519b = 0.11.9 の上)。branch `impl/01110`。証跡は `build/01110-*`(git の外)。musearch の写しは `.scratch/musearch`(musearch origin/main `95fb3e461` の `git archive` に 7 面の `node_modules` を足して(0119 の写しから。package.json・lock は 251c3c217 から差 0)、独立した git に作り直した。commit しない)。

## やったこと

- 版 0.11.10(`gleam.toml`・`gen/manifest.toml` の path 依存の行)
- **(1) 格子の Style**:`front.Frame` に 2 つ目の構成子 `StyledFrame(areas:, placements:, cols:, rows:, template:, style: List(css.Style))` を足した。読みの口は `front.frame_style(frame)`(`Frame` なら `[]`)
  - **置き場の理由(Frame の構成子)**:Gleam の record には欄の既定値が無い。`Frame` か `Layout` に欄を足すと、musearch の 7 面の `Frame(..)` / `Layout(..)` がどれも compile できなくなる(「足した語彙を使わない musearch で差 0」に反する)。構成子を足せば既存の `Frame(..)` はそのまま通る。他の欄は同じ名・同じ位置・同じ型なので `frame.cols` などの読みも、`resolved_cols` / `resolved_template` もそのまま効く。断点ごとに持てるのも Frame の側の利点(Layout に置くと sp・pc・tablet を分けられない)
  - 書き方は Area の style と同じく `style` の定数(`style: style.shell` か `style: [style.a, style.b]`)。それ以外(式の literal など)は gen が `Conflict` で止める(`StyledFrame の style は style の定数で書く`)── Area と同じく生成は名で `style.<名>` を引くので、literal を写せないため
  - 生成:格子の要素を `html.div(sketch_css.class(<style>), [data-yumemi-grid], ..)` にする。sp の style は全幅、pc・tablet の style は `css.Responsive(css.PC / css.Tablet, ..)` で包む(生成の格子の CSS の media と同じ幅)。例 `[css.Responsive(css.PC, style.wide), ..[style.shell, style.paper]]`。どの断点も style を持たなければ今の `html.div_` のまま(`style: []` も同じ)
  - **class の衝突を起こさない**:格子の style は格子の要素だけの sketch class で、各 Area は自分の class(`styled_area(..)`)のまま。生成の格子の CSS(列・行・template・Area の規則)は属性の selector(`[data-yumemi-grid=..]`)で、class 名を作らない
  - Page の Frame が StyledFrame なら Page の格子(`data-yumemi-grid="page:.."`)を作ってそこに掛ける(`page_has_explicit_grid` に style を足した)
  - 列・行・gap は Frame の欄(生成の CSS が `[data-yumemi-grid]` に書く)の持ち物。style で `gap` を書いても生成の `gap: 0` と同じ詳細度で、勝ち負けが読み込み順に依る ── README に「style では他の性質を書く」と書いた
- **(2) 下端に着く棒**:`css.Pin` に `BottomFlush`。生成の Area の規則は `position: sticky; bottom: 0; padding-bottom: env(safe-area-inset-bottom, 0px); z-index: 3;`。`Bottom` の規則(`bottom: env(safe-area-inset-bottom);`)は変えていない(test で断言)
  - 名の理由:`Bottom` の仲間で、下端に「面一で着く」こと。内側の余白で inset を持つので、棒の地が画面の下端まで届き、中身は iPhone の下端のバーに重ならない
  - 注意(README に書いた):Area の規則(`[grid] > [area]`、詳細度 0,2,0)が `padding-bottom` を持つので、Area の style の `Padding` の下の辺はこの inset に負ける。棒の中の余白は棒の中の block に書く
  - shell.mjs の `areaRule`(JS)は呼ばれていない死んだ文字列で、`BottomFlush` を足していない(足すと全面の shell.mjs が変わる)。効くのは static の格子の CSS(`style.css` と shell の `gridCssFromLayout` の文字列、同じ text)
- **(3) 折り返し**:`css.Style` に `Wrap(wrap: OverflowWrap)`、`OverflowWrap` は `Anywhere`・`BreakWord`・`WrapNormal` → `overflow-wrap: anywhere / break-word / normal`(root の `sketch_css` で `sketch_css.overflow_wrap`)。`State(..)` / `Responsive(..)` の中でも出る
  - `Normal` にしなかった理由:同じ module の `FontWeight.Normal` と名が衝突する
  - gen:Style の語彙は gen が読まない(Area の style も名で `style.<名>` を引くだけ、CSS は root の sketch_css が実行時に書く)ので、gen の reader・emit に足す分岐は無い。`Wrap` を持つ定数を Area の style に置いて、停止なく `styled_area("page", style.url, ..)` まで通る test を足した。`StyledFrame` の style の定数にも同じく通る
- README:Style の節(0.11.10、`Wrap` の行)、`## framework/front ── Grid style and the bottom bar (0.11.10)` の節、0.11.10 の変更点の段落

## 検収

- root `gleam test`:`Framework checks passed: 24 groups`(基線 21 + 3 ── `v01110_styled_frame_carries_grid_style`・`v01110_bottom_flush_is_a_pin`・`v01110_wrap_renders_overflow_wrap`)。`build/01110-test-root.txt`
- gen `gleam test`:332 passed, no failures(基線 326 + 6 ── `front_emit_styled_frame_grid_style_test`・`front_emit_frame_without_style_keeps_plain_grid_test`・`front_emit_page_styled_frame_makes_page_grid_test`・`invalid_frame_style_is_a_conflict_test`・`front_emit_bottom_flush_pin_css_test`・`front_emit_wrap_style_constant_passes_test`)。`build/01110-test-gen.txt`
- `gleam format --check src test`:root・gen とも 0
- **musearch の写しで差 0**:基点 ac2519b の `git archive`(`.scratch/yumemi-base`)の gen で写しを再生成 → musearch main と差 0。続けて本作業木の gen で再生成 → `git diff --stat` 空。両方 `[exit 0]`・停止コード 0、診断(`[exit ..]`・`停止コード`・`書いた: 1988 ファイル`・末尾の exit)40 行が全行一致(`build/01110-diag-base.txt`・`build/01110-diag-new.txt`、`diff` 0)。`_diagnostics.txt` は消した
- **写しの 4 面の build・test**(www・admin・console・muses・api の `gleam.toml` を `yumemi = { path = <作業木> }` に向けた):
  - `npm run build`:www・admin・console・muses すべて EXIT 0(`build/01110-ms-build-*.txt`)
  - `npm test`:www 214/214、admin 21/21、console 82/82、muses 191/191(`build/01110-ms-test-*.txt`)
  - api・auth の build・test は回していない(BRIEF の検収は 4 面。auth は Hex の yumemi 0.7 で本便は届かない)
  - 写しの git では build で `*/manifest.toml` が変わった(path 依存の行)。作業木 path に向けたあと gen を回すと、4 面の `priv/static/_yumemi/client.mjs` に `OverflowWrap`(`Anywhere`・`BreakWord`・`WrapNormal`)と `BottomFlush` の構成子の定義が増える(admin は 12 行、他は 33 行)(下の「使えば効く」の生成の差に見える。musearch が 0.11.10 を取り込むときの bundle の差で、出る CSS は変わらない)
- **使えば効く(1 回、写しの muses)**:`build/01110-use-source.diff`(source の差)・`build/01110-use-gen.diff`(生成の差)・`build/01110-probe-{base,use}.txt`・`build/01110-probe-summary.txt`・`build/01110-{base,use}-*.png`。測りの手は `build/01110-probe.mjs`(muses の worker を node で動かし、APP を stub に。Chromium 153.0.8010.12、390×844)
  - source:layout の sp を `StyledFrame(style: style.shell, rows: [Auto, Fr(1), Auto, Auto], ..)`(`style.shell = [Space(MinHeight, Dvh(100.0))]`)、nav の Area 2 つ(sp・pc)を `pin: css.BottomFlush`、`link_list` の URL の行 `url_line` を `[css.Flow(css.Scroller)]` → `[css.Wrap(css.Anywhere)]`
  - 生成の差:muses の 24 頁の `load/**/page.gleam` で格子が `html.div(sketch_css.class(style.shell), [attribute.attribute("data-yumemi-grid", "layout")], [..])`。`style.css` と shell の格子の CSS に `grid-template-rows: auto 1fr auto auto;`、nav の規則が `bottom: 0; padding-bottom: env(safe-area-inset-bottom, 0px);`
  - 比べ(base = 写しの source のまま、use = 上の 3 つを足した物。同じ probe):

    | | base | use |
    |---|---|---|
    | 短い頁 `/claim/abc`:棒の top / 下端 | 378 / **435**(本文の直後で浮く) | 787 / **844** |
    | 短い頁:格子の min-height・行 | 0px・`56 248 74 57` | 844px・`56 657 74 57`(本文の行が残りを埋める) |
    | 長い頁 `/links`(40 本):本文の top(scroll 0) | 56 | **56**(変わらない) |
    | 長い頁:末尾まで送ったときの棒の下端 | 844 | 844 |
    | 長い URL の行の scrollWidth / clientWidth | **1235 / 276**(Scroller で隠れる) | **276 / 276**(`overflow-wrap: anywhere`) |
    | 文書の scrollWidth / clientWidth | 390 / 390 | 390 / 390 |

  - 長い頁の文書の高さが 7239 → 7359 になったのは、URL の行が 1 行(Scroller)から折り返して 168px に伸びた分(40 本のうち長い URL は 1 本)。本文の上端と棒の位置は同じ
  - `padding-bottom` は desktop の Chromium では `0px`(safe area が無い)

## 確かめていないこと

- iPhone の実機・safe area を持つ端末で `env(safe-area-inset-bottom)` が棒の内側の余白になること(Chromium の desktop は 0px で、inset を作れない)。CSS の字は test と生成の差で確かめた
- pc・tablet の Frame の style(`css.Responsive` で包む経路)は生成の字の test だけで、写しの実画面では使っていない
- api・auth の build・test(BRIEF の検収の外)

## 残り・気づき

- `track.Track` に `Dvh` は足していない(BRIEF の (1) は格子の Style の `MinHeight` で表す形。行は `Fr(1)` で足りた)
- musearch の mf-dvh で「矛盾 2」として書かれた二重の inset は、`BottomFlush` を使えば棒の Area の padding が inset だけになるので起きない。棒の中の余白は block 側に書く
- `.scratch/` は commit していない

## DDL

無し
