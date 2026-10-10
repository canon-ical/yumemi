# results ── yumemi-01114(0.11.14、真壁 r1)

基点 `fe76768`(BRIEF の commit、main 5d4fc4f = 0.11.13 の上)。branch `impl/01114`。証跡は `build/01114-*`(git の外)。musearch の写しは `.scratch/musearch`(musearch origin/main `a4c710f35` の `git archive`。4 面の `node_modules` は 01113 の写しから hardlink、4 面の `package-lock.json` は 01113 の写しと差 0。独立した git にした。commit しない)。基点の yumemi は `.scratch/yumemi-base`(`fe76768` の `git archive`)。

## やったこと

- 版 0.11.14(`gleam.toml`・`gen/manifest.toml` の path 依存の行)
- **(1) `css.Interaction` に 2 語**(`src/framework/front/css.gleam`・`sketch_css.gleam`)
  - `FocusVisible` → `.class:focus-visible { .. }`(sketch の `focus_visible`)
  - `HoverCapable` → `@media (hover: hover) { .class:hover { .. } }`
  - 名の理由:`FocusVisible` は CSS の `:focus-visible` と同じ名で、引いて意味が分かる。`HoverCapable` は「hover の出来る端末の hover」で、`Hover` を頭に置いて並びで隣の語と分かるようにした(`CanHover` より `Hover` の変種と読める)
  - sketch 4.2.1 の `media.Query` は opaque で `hover` の問い合わせが無い。`sketch/internals/cache/cache` の `Media(query, styles)` を字で組んだ(`css.media` が中でしているのと同じ形)。sketch の `internal_modules` だが、build・test で警告は出なかった
  - 詳細度:`@media` の中の規則は class + `:hover`(`.css-x:hover`)で、`Hover` と同じ。地の class(`.css-x { background-color: transparent }`)に勝つ。sketch は 1 class の media を class の規則と selector の後ろに書く
  - `Responsive(at, [.., State(HoverCapable, ..)])`:sketch は media の中の media を落とす(`handle_media` が中の medias を捨てる)ので、`Responsive` の中の `HoverCapable` は `@media (<幅>) and (hover: hover)` の 1 つの media にした。`HoverCapable` を含まない `Responsive` の出力は前と同じ(sketch の Style の列が同じ → class の hash も同じ)
  - 既存の `Hover`・`Focus`・`Disabled`・`Current` の枝は触っていない
- **(2) gen の reader・emit**:gen は Style を `style` の定数の名でしか読まず(`reader/front.gleam` の `parse_style`)、`Interaction` を解かない。CSS は島も Block も生成の code が実行時に root の `framework/front/sketch_css.class` を呼んで書く。**gen の source の変更は無し**。gen の test で新しい語の定数が Area の style として今と同じ経路を通ることを縛った
- **(3) test**
  - root `v01114_focus_visible_and_hover_capable_render_to_css`(25 群目):2 語の CSS の字を全文で `assert_equal`、`FocusVisible` に素の `:focus {` が無い、`Responsive` の中の `HoverCapable` が `@media (max-width: 767.0px) and (hover: hover) {`、島の shadow の `<style>` に `:focus-visible {` と `@media (hover: hover) {`。既存 4 語の字を全文で `assert_equal`(字は下で 0.11.13 の出力と突き合わせた)、`Responsive` の中の `Hover` に `(hover: hover)` が出ない
  - gen `front_emit_focus_visible_and_hover_capable_style_constant_passes_test`:fixture の style に `tab`(`State(FocusVisible, ..)`・`State(HoverCapable, ..)`)を足し、Area の style にすると style の診断が出ず、`styled_area("page", style.tab,` が出る
- **(4) README**:Style の表に 2 行、`State(..)` の語の列、`Outline` の行(焦点の輪は `FocusVisible` へ)、0.11.14 の段落

## 検収

- root `gleam test`:`Framework checks passed: 25 groups`(基線 24 + 1)。`build/01114-test-root.txt`
- gen `gleam test`:**340 passed, no failures**(基線 339 + 1)。`build/01114-test-gen.txt`
- `gleam format --check src test`:root・gen とも 0
- **既存 4 語の字が 0.11.13 と同じ**:基点 `fe76768` の `git archive` の木と本作業木で、同じ probe(`Hover`・`Focus`・`Disabled`・`Current` の 4 class を sketch で描く)の出力を `diff` → 差 0(31 行)。その字を root の test に固定した
- **musearch の写しで差 0**(写しの 5 面の `gleam.toml` は origin/main のまま = lock の yumemi 0.11.13):基点 `.scratch/yumemi-base` の gen で再生成 → `git status` 空。本作業木の gen で再生成 → `git status` 空。両方停止コード 0、診断 41 行が全行一致(`build/01114-diag-{base,new}.txt`、生のログ `build/01114-gen-{base,new}.txt`)
  - **面が yumemi 0.11.14 を引いたとき**(5 面の `gleam.toml` を path 依存に):基点の yumemi へ path → 基点 gen で再生成は `client.mjs` も差 0。本作業木へ path → 本作業木の gen で再生成すると、4 面の `priv/static/_yumemi/client.mjs` に差(admin +6、www +64 −3、console・muses +93 −3、`build/01114-ms-gen-newpath.diff`)。**中身は bundle に入る framework 自身の code だけ**(`FocusVisible`・`HoverCapable` の constructor、`sketch_css` の 2 枝と `Responsive` の `partition`、sketch の `focus_visible`)。gen の書く字(`src/gen/**`・shell・load)は差 0。framework の code を変える版はどれもこの形の差になる。musearch が lock を 0.11.14 に上げるときの client の生成し直しで出る差で、CSS の出力は変わらない
- **写しの 4 面**(5 面を本作業木へ path、上の再生成の後):`npm run build` www・admin・console・muses すべて EXIT 0。`npm test` www 409/409、admin 21/21、console 89/89、muses 464/464(`build/01114-ms-{build,test}-*.txt`)
- **使えば効く 1 回**(`build/01114-probe.mjs` = 写しの `docs/nv-2/evidence/probe-01114.mjs`、nv-2 の `stack.mjs`・stub を借りた):写しの muses `style.nav_tab` の `State(Hover, ..)` → `State(HoverCapable, ..)`、`State(Focus, ..)` → `State(FocusVisible, ..)` の 2 行だけ替え、本作業木の gen で再生成 → muses `npm run build` EXIT 0 → 手元の worker を Chromium 153.0.8010.12・360×719 で。トグル `#muse-nav-toggle`(`nav_tab` の上に `Background("transparent")` を重ねる `button_tab`)。掛け替え前(同じ写し、同じ path 依存)= `build/01114-probe-before.json`、後 = `build/01114-probe-after.json`

  | 場面 | 前 outline | 前 地 | **後 outline** | **後 地** | `:focus` / `:focus-visible` / `:hover` | `(hover: hover)` |
  |---|---|---|---|---|---|---|
  | touch(isMobile・hasTouch・DPR 3)押す前 | `none` | `rgba(0,0,0,0)` | `none` | `rgba(0,0,0,0)` | F / F / F | false |
  | touch 1 回目(開いた後) | `solid 2px rgb(61,36,25) offset 3px` | `rgb(240,227,218)` | **`none`** | **`rgba(0,0,0,0)`** | T / F / T | false |
  | touch 2 回目(閉じた後) | `solid 2px rgb(61,36,25) offset 3px` | `rgb(240,227,218)` | **`none`** | **`rgba(0,0,0,0)`** | T / F / T | false |
  | キーボード Tab 28 回目(hasTouch の頁) | `solid 2px rgb(61,36,25) offset 3px` | `rgba(0,0,0,0)` | **`solid 2px rgb(61,36,25) offset 3px`** | `rgba(0,0,0,0)` | T / T / F | false |
  | マウス(hasTouch 無し)上に来る前 | `none` | `rgba(0,0,0,0)` | `none` | `rgba(0,0,0,0)` | F / F / F | true |
  | マウスの hover | `none` | `rgb(240,227,218)` | `none` | **`rgb(240,227,218)`** | F / F / T | true |

  - touch の後も `:focus`・`:hover` は true のまま(ブラウザの状態)だが、掛け替え後は枠も地も出ない。キーボードでは枠が出て、マウスの hover では地が出る
  - マウスの hover の地 `rgb(240,227,218)` が `button_tab` の `Background("transparent")` に勝っている = `@media` の中の規則が class の詳細度で負けていない
  - pageerror はどの場面も 0。写しの変更は捨てる物(commit しない)

## 確かめていないこと

- 実機の電話・Safari(WebKit)での表示。測ったのは Chromium の `isMobile`・`hasTouch` の emulation で、`(hover: hover)` は false と出た
- muses の他の語(`nav_item`・`account_face` など、`State(Focus)`・`State(Hover)` のまま)と www・console・admin の掛け替え。本便は yumemi の語を足すまでで、musearch の source は触らない
- `HoverCapable` を `State(..)` の中や `Responsive` の 2 段目より深くに入れた形(`Responsive` の 1 段目の直下だけを 1 つの media に組む。それより深いと sketch が media の中の media を落とす)
- api・auth の build・test(BRIEF の検収の外)

## 残り・気づき

- `HoverCapable` の media は sketch の internal module(`sketch/internals/cache/cache`)の `Media` で組んだ。sketch の版を上げるとき、この型が変わっていれば compile で止まる(`sketch` の範囲は `>= 4.2.1 and < 5.0.0` のまま)
- `.scratch/` は `.gitignore` に無い。commit には入れていない(path を名指しで add した)
- Hex API の rate limit に 3 回当たった(版を上げた後の依存の解決、写しの muses の build、gen の中の Out decoder の build)。どれも間を置いて回し直して通った

## DDL

無し
