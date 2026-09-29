# results ── yumemi-look2(0.11.8、真壁 r1)

基点 `706ca10`(BRIEF の commit、main 5b11131 = 0.11.7 の上)。branch `impl/yumemi-look2`。前の真壁が container の再起動で止まり(checkpoint 56559d5・0bdb669)、続きを引き継いで閉じた。証跡は `build/look2-*`(git の外)。musearch の写しは `.scratch/musearch`(wf-5a の作業木 ccba485c のコピー、`.git` の gitfile を消して独立した git に作り直した ── 元の musearch の worktree の index を触らないため)。

## やったこと

- 版 0.11.8(`gleam.toml`・`gen/manifest.toml` の path 依存の行)
- **1. Style に 3 つ**(`src/framework/front/css.gleam`・`sketch_css.gleam`):
  - `Sizing(box: BorderBox | ContentBox)` → `box-sizing`
  - `Marker(marker: NoMarker)` → `list-style: none`
  - `Decoration(line: NoDecoration | Underline)` → `text-decoration`
  - 型の形の理由:既存の `Crop(fit: ObjectFit, ..)`・`Border(style: BorderStyle, ..)` と同じ「Style の variant 1 つ + 値の閉じた型」にした。値を文字列にしないのは、Color 以外の語彙が全部閉じた型で、書けない値(`list-style: square` 等)を型で止めるため。`ListMarker` は今 `NoMarker` だけだが、印の種類を足すときに variant を足すだけで済む形にした。`State(..)`・`Responsive(..)` の中は既存の経路(`to_sketch` の再帰)でそのまま通る
- **2. Area の flow を grid の CSS に**:
  - `framework/front.area_flow_css(flow)` が `css.Flow` を宣言の列にする。`Stack` → `display:flex; flex-direction:column; align-items:stretch; gap`、`Row` → `flex-direction:row; flex-wrap; gap`、`Grid` → `display:grid; repeat(n, minmax(0,1fr)); gap`、`Scroller` → `flex row; overflow-x:auto`。各 variant が向きまで書き切るので、pc・tablet の Frame で別の flow に替えても sp の向きが残らない
  - gen:reader が Area の flow を `AreaFlow` で読む(gap は literal か `style` の定数を読む)。`static_area_rule` がその Area の規則の `grid-area` の後に出す。`GridTracks` は既存の `grid_tracks` の出力のまま(重ねない)。`pin: Overlay` の Area は flow を出さない(overlay の表示の扱いを変えないため)。hidden の Area は flow の後の `display:none` が勝つ。media で表示に戻す規則は、flow があれば `display:block` を足さない(flow の display が効く)
  - gap が literal でも `style` の定数でもなく読めない Area は、flow の行を出さない(従来どおり)。variant は落としていない ── 読めない gap の Area だけが従来の出力のまま
  - `htmlWithGridCss` の `gridCssFromLayout` と `_yumemi/style.css` は同じ grid の CSS の文字列から作られ、両方に出る(musearch の 4 face で、shell.mjs の文字列が style.css に含まれることを node で確かめた)
- **3. 足すだけ**:既存の variant の意味・出力は不変。musearch の生成の差は Area の規則の行だけ(下)
- **4. README**:Style の表に 3 行、`## framework/front ── Area flow (0.11.8)` の節、0.11.8 の変更点の段落

## 検収

- root `gleam test`:`Framework checks passed: 17 groups`(基線 13 + 足した 4 ── `look2_box_sizing_renders_to_css`・`look2_list_marker_renders_to_css`・`look2_text_decoration_renders_to_css_and_inside_state`・`look2_area_flow_renders_to_area_css`)。`build/look2-test-root.txt`
- gen `gleam test`:320 passed, no failures(基線 318 + 2 ── `front_emit_area_flow_reaches_grid_css_test`・`front_emit_area_flow_variants_and_grid_tracks_test`)。`build/look2-test-gen.txt`
- `gleam format --check`:root・gen とも 0
- **musearch の写しで生成の差**:同じ写しを基点 706ca10 の `git archive`(`.scratch/yumemi-base`)の gen で再生成 → 写しのファイルと差 0(`_diagnostics.txt` が増えただけ)。続けて本作業木の gen で再生成。両方 停止コード 0、診断(`[exit ..]` と停止コードの行)は全行一致(`build/look2-gen-base.txt`・`build/look2-gen-new.txt`)
  - `git diff --stat`:8 files, +396 / -5。`{www,admin,console,muses}/priv/static/_yumemi/style.css` と同じ 4 face の `src/gen/shell.mjs`(`gridCssFromLayout` の文字列 1 行ずつ)だけ
  - style.css の差の行を全部数えると `+display: flex` 98・`+flex-direction: column` 98・`+align-items: stretch` 98・`+gap: 8.0px` 87・`+gap: 0.0px` 9・`+gap: 4.0px` 2・`-display: block` 1。Area の規則の行以外の差は無い(musearch は Stack だけを使っている)
  - 抜粋(www、pc の media の規則で表示に戻す aside):`[data-yumemi-grid="layout"] > [data-yumemi-area="aside"] { grid-area: aside; -display: block; +display: flex; +flex-direction: column; +align-items: stretch; +gap: 4.0px; }`
- 写しの `www/gleam.toml` を `yumemi = { path = "/root/yumemism_repo/yumemi-look2" }` に向け、`npm run build` EXIT 0、`npm test` tests 123 / pass 123 / fail 0(`build/look2-ms-build.txt`・`build/look2-ms-test.txt`)。style.input に border-box を足した後も同じ(`build/look2-ms-*-after.txt`)
- **390px の /me**(wf-5a の `docs/wf-5a/evidence/serve.mjs` の stub server。写しの serve.mjs に `YUMEMI_DEV: "1"` を足して `/_blocks` も出す。撮りと計算値は `.scratch/evidence/look2-shots.mjs`):
  - `build/me-390-after.png`(before も同梱)。page の Frame の Area `page`(`Stack(gap: style.s2)`)の計算値は `display:flex`・`flex-direction:column`・`align-items:stretch`・`gap:8px`。4 block の間の空きは 8 / 8 / 8px、block の幅は 4 つとも 342px(Area の中身の幅いっぱい、縮んでいない)。scrollWidth 390 = innerWidth
  - 見た目の間は 20px(gap 8px + wf-5a が block の根に付けた透明の下の縁 12px。写しの wf-5a の仮の手当ては外していない)
  - **入力**:`style.input` は /me に無く、`/search` は stub が検索の API を持たず 503。`/_blocks` の `search_form` の入力で測った。写しの `www/src/style.gleam` の `input` に `css.Sizing(box: css.BorderBox)` を 1 行足す前は `box-sizing: content-box`・min-height 48px・padding 12px で **74px**、足した後は `border-box` で **50px**(48〜50 の内)。`build/report-before.json`・`build/report-after.json`

## 残り・気づき

- 長さは `float.to_string` のまま出るので `gap: 8.0px`(既存の `length_css` と同じ形、CSS としては有効)
- `Row` の `flex-wrap` の既定は BRIEF に無いので `wrap` の Bool をそのまま出した
- musearch の wf-5a の透明の下の縁 12px は、0.11.8 を取り込んだ後に外せる(外すかは musearch の便の判断)

## DDL

無し
