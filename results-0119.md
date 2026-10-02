# results ── yumemi-0119(0.11.9、真壁 r1)

基点 `cd91f25`(BRIEF の commit、main 319c087 = 0.11.8 の上)。branch `impl/0119`。証跡は `build/0119-*`(git の外)。musearch の写しは `.scratch/musearch`(musearch main `251c3c217` の `git archive` に 7 面の `node_modules` を足し、独立した git に作り直した。commit しない)。

## やったこと

- 版 0.11.9(`gleam.toml`・`gen/manifest.toml` の path 依存の行)
- **(a) Layout に今の route**:`front.From` に `CurrentRoute`(値を持たない構成子)を足した
  - 名の理由:`Path(name)` のように「名で引く値」ではなく「今描いている page」そのものなので、引数を持たない構成子にして `Current` を頭に付けた。`Route` だけだと「route を名で指す」と読める
  - 値は `reader_front.route_path(page.path)`。生成の route 表のキー(`pageRoutes` / `pageSpecs` の `"/rosters/:id"`)と同じ綴りで、要求の URL の字は通らない。shell の var の行は `{ name: "route", optional: false, from: { type: "route", value: "/rosters/:id" } }`。Layout の var は page ごとの行に写るので、Layout に置いても page ごとの定数になる
  - shell の `renderPage` の `source.type === "route"` の分岐は、面のどこかの Var が `CurrentRoute` を持つときだけ出す(使わない面の shell.mjs を変えないため)
  - 型は `String`(optional でない)。`placement_var_location_notes` は Layout にも Page にも `CurrentRoute` を許す。Layout の `Path` の文言を「Layout に Path を置けない(今の page は CurrentRoute で受ける)」にした。`CurrentRoute("x")` のような値付きは `InvalidFrom`(AuthOrigin と同じ扱い)
  - 気づき:console の `api_key` の頁の綴りは route 表どおり `/api_key`。musearch の header のリンクは `/api-key` なので、比べるときは route 表の綴りを使う必要がある(musearch 側の話)
- **(b) aria-current**:`css.Interaction` に `Current`。`State(Current, styles)` → `sketch_css.selector("[aria-current]:not([aria-current=\"false\"])", ..)`、つまり `.cls[aria-current]:not([aria-current="false"])`
  - `="page"` に絞らなかった理由:WAI-ARIA では `false` 以外の値(`page`・`step`・`location`・`date`・`time`・`true`)がどれも「今いる所」を表す。状態の名を `Current` 1 つにするなら全部を拾うほうが名と合う。ナビは `aria-current="page"` を付ければそのまま効く
  - 島の shadow の `<style>` も同じ sketch の class なので、そのまま出る(経路は 0.11.4 の `island_style.mjs` から変えていない)
- **(c) Overlay の寄せ**:`css.Pin` に `AnchoredOverlay(side: Below | Above, align: AlignStart | AlignEnd)`
  - gen の reader は pin を `"Overlay"` と読み、向きは `Area.anchor: Option(OverlayAnchor)` に持つ。これで既存の Overlay の扱い(popover の要素、grid から外す、opener / closer の検査)は全部そのまま通る
  - CSS は `generated_front_css` が `[popover]::backdrop` の後に出す。`@supports (anchor-name: --yumemi) { opener に anchor-name、Area に position-anchor・position-area・position-try-fallbacks: flip-block・inset: auto・margin: 0、::backdrop は transparent }`。`AlignStart` → `span-inline-end`(ボタンの始端から伸ばす)、`AlignEnd` → `span-inline-start`
  - anchor positioning の無い browser では `@supports` の中が全部効かず、今の Overlay と同じく UA の既定で中央・backdrop も暗い
  - anchor は CSS の名前(`--yumemi-overlay-<area>`)で結んだ。同じ Area の opener が複数あると、文書順で最後の 1 つに寄る(README に書いた)。Area 名の dashed-ident に使えない字は `_` に替える
- **(d) Length**:`Var(name)` → `var(--name)`、`Env(SafeTop | SafeRight | SafeBottom | SafeLeft)` → `env(safe-area-inset-*, 0px)`、`Dvh(n)` → `<n>dvh`
  - root:`sketch_css.length_to_string` を公開にして長さの字を 1 つにした。Space・Text の size・flow の gap は sketch の `*_` の文字列版の setter に替えた(`Px`・`Rem` の字は sketch の `length.to_string` と同じ `8.0px` / `1.5rem`、出力は不変)。`front.area_flow_css` もこれを使う
  - Var の名が `[a-z0-9-]`(空でない)以外なら root は `unset` を書く。gen は Area の flow の gap(literal と `style` の定数)で `Conflict` の停止にする(`css.Var("x;}a b") の名は a-z・0-9・- だけで書く`)
  - gen の reader は `parse_length` で 3 つを読む ── `style` の定数の読み(`style_lengths`、定数から定数への辿りも)と Area の flow の gap の両方がこれを通る。emit は `framework_length` で root の型に写して root の `length_to_string` で書く(gen と root で同じ字)
- README:Style の節(0.11.9、`State(Current)` の行、Length の表)、`## framework/front ── Layout vars and Overlay (0.11.9)` の節、0.11.9 の変更点の段落

## 検収

- root `gleam test`:`Framework checks passed: 21 groups`(基線 17 + 4 ── `v0119_current_route_is_a_var_source`・`v0119_current_state_renders_aria_current_selector`・`v0119_anchored_overlay_is_a_pin`・`v0119_lengths_var_env_dvh_render_to_css`。Var に `a;b`・`a}b`・`a)b`・`a b`・空・`A`・`a_b`・改行を渡して全部 `unset`、`x;}body{color:red` を渡して `gap: unset;` で `body{` が出ないことを含む)。`build/0119-test-root.txt`
- gen `gleam test`:326 passed, no failures(基線 320 + 6 ── `front_layout_current_route_reaches_shell_var_rows_test`・`front_shell_without_current_route_has_no_route_branch_test`・`current_route_var_is_read_and_allowed_in_layout_and_page_test`・`front_emit_anchored_overlay_css_test`・`front_emit_new_lengths_reach_area_css_test`・`invalid_var_length_name_is_a_conflict_test`)。`build/0119-test-gen.txt`
- `gleam format --check`:root・gen とも 0
- **musearch の写しで差 0**:基点 319c087 の `git archive`(`.scratch/yumemi-base`)の gen で写しを再生成 → 写しと差 0(`_diagnostics.txt` が増えただけ)。続けて本作業木の gen で再生成 → `git diff --stat` 空。両方 EXIT 0・停止コード 0、診断(`[exit ..]`・`停止コード`・`書いた: 1988 ファイル`)39 行が全行一致(`build/0119-diag-base.txt`・`build/0119-diag-new.txt`)
- **写しの全面の build・test**(www・admin・console・muses・api の `gleam.toml` を `yumemi = { path = <作業木> }` に向けた。auth は Hex の yumemi 0.7 のまま):
  - `npm run build`:www・admin・console・muses・api・auth すべて EXIT 0(`build/0119-ms-build-*.txt`)
  - `npm test`:www 208/208、admin 21/21、console 52/52、muses 176/176(`build/0119-ms-test-*.txt`)
  - api:test 用の PG を写しの中で `MUSEARCH_TEST_PG_PORT=55491 bash api/test/postgres.sh` で起こした(`idp2a6` は `MUSEARCH_TEST_IDP_DB=idp2a6` でもう 1 度)。1 回目は 1433 中 1432 pass、落ちたのは `2a-6`(DB `idp2a6` が無い)。DB を足した 2 回目も 1432 pass、落ちたのは `SQL:staff_screen_rejects/given_up`(1 回目は pass)。落ちた 2 本の file(`sql-coverage.test.mjs`・`2a-6.test.mjs`)だけを回し直すと 427/427 pass(`build/0119-ms-test-api-rerun.txt`)。front の変更が届かない api の SQL なので、DB の状態の持ち越しによる揺れと見ている
  - auth:76/77。落ちた 1 本は `git show 13689259e:auth/schema.sql` が写しの git に無い(写しは履歴を持たない)ため。auth は yumemi 0.7(Hex)で、本便の変更は届かない
  - 起こした PG(55491、test が自分で起こした 55466 も写しの `build/` の下)は止めた
  - build で `{www,admin,console,muses}/priv/static/_yumemi/client.mjs` が変わる(Hex 0.11.8 → 0.11.9)。中身は sketch の `gap(to_string(px_(..)))` が `gap_(..)` の文字列版に替わった分で、出る CSS の字は同じ。musearch が 0.11.9 を取り込んだとき、この bundle の差が出る
- **使えば効く(1 回、写しの console)**:`build/0119-use-source.diff`(写しの source の差)・`build/0119-use-gen.diff`(生成の差)・`build/0119-report.json`・`build/0119-switch-1280-*.png`。測りの手は `build/0119-probe.mjs`(console の worker を node で動かし、APP を stub に。Chromium 153.0.8010.12、1280×800、`/switch`)
  - source:Layout に `Var("route", CurrentRoute)` と `Area("account", pin: css.AnchoredOverlay(side: css.Below, align: css.AlignEnd))`(中身は SiteFooter)。ConsoleHeader の Arg に `route`、リンクが `route == url` のとき `aria-current="page"`、link の Style に `State(Current, [ink, Border(BottomEdge, Px(2.0), Solid, "#7a3f8c")])`、`el.opener("account", ..)`、header に `Space(MinHeight, Dvh(10.0))` と `Space(Margin, Env(SafeTop))`
  - 生成の CSS(console の `_yumemi/style.css`):
    ```
    [popover]::backdrop { background: rgba(0, 0, 0, 0.45); }
    @supports (anchor-name: --yumemi) {
      [data-yumemi-overlay-opener][popovertarget="yumemi-overlay-account"] { anchor-name: --yumemi-overlay-account; }
      [data-yumemi-overlay][data-yumemi-area="account"] {
        position-anchor: --yumemi-overlay-account;
        position-area: block-end span-inline-start;
        position-try-fallbacks: flip-block;
        inset: auto;
        margin: 0;
      }
      [data-yumemi-overlay][data-yumemi-area="account"]::backdrop { background: transparent; }
    }
    ```
    shell.mjs:page ごとに `{ name: "route", optional: false, from: { type: "route", value: "/switch" } }`(14 頁、`/rosters/:id` などの綴り)と `} else if (source.type === "route") { value = source.value;`
  - 計算値:`aria-current="page"` の項目は 1 つ(「名義を切り替える」)で、`border-bottom: 2px solid rgb(122, 63, 140)`、color `rgb(61, 36, 25)`。他の項目は `0px none`、color `rgb(116, 102, 92)`
  - popover を開くと:ボタン `top 100.375 / bottom 125.375 / right 105`、popover `top 125.375 / right 105` ── 上端はボタンの下端に付き(差 0)、終端はボタンの終端に揃う(差 0)。`position-area: end span-start`(計算値の表記)、`::backdrop` は `rgba(0, 0, 0, 0)`
  - `min-height: 80px`(10dvh × 800px)、`margin-top: 0px`(desktop に safe area は無い)
  - anchor を支えない browser の代わり:HTML と CSS の `@supports (anchor-name: --yumemi)` を、成り立たない条件に書き換えて開くと、popover は `top 369 / bottom 431 / left 430 / right 850`(1280×800 の中央)、画面の内、`::backdrop` は `rgba(0, 0, 0, 0.45)` ── 今の Overlay と同じ
  - 図では、ボタンがページの左端にあるので、`AlignEnd` の popover はボタンの右端から左へ伸びて、幅が 105px に詰まる(`span-inline-start` の幅がそこまでしか無い)。実際の配置(アカウントのボタンは右端)なら詰まらない。`flip-inline` を足すかは使う側の配置を見て決めたい

## 残り・気づき

- 長さの字は既存どおり `float.to_string`(`100.0dvh`、`8.0px`)
- `AnchoredOverlay` の向きが構成子のリテラルでない(変数で渡す)ときは、gen は anchor を読めず中央の Overlay として出す(停止しない)
- (b) の `:popover-open` と toggle は BRIEF どおり触っていない

## DDL

無し
