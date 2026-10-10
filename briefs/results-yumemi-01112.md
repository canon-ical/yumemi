# results ── yumemi-01112(0.11.12、真壁 r1)

基点 `c181d9e`(BRIEF の commit、main 667038d = 0.11.11 の上)。branch `impl/01112`。証跡は `build/01112-*`(git の外)。musearch の写しは `.scratch/musearch`(musearch origin/main `8118fc890` の `git archive` に 7 面の `node_modules` を足した(01110 の写しから。4 面の package.json・lock は 01110 の写しの基点 95fb3e461 から差 0、変わったのは auth と infra のみ)。独立した git に作り直した。commit しない)。

## やったこと

- 版 0.11.12(`gleam.toml`・`gen/manifest.toml` の path 依存の行)
- **(1) shell の任意の const**:`manifest`・`theme_color`・`icon`・`apple_touch_icon`、どれも `pub const <名>: String = ".."`。在れば render_view の head の `<title>` の後ろに、この順で `<link rel="manifest" href>`・`<meta name="theme-color" content>`・`<link rel="icon" href>`・`<link rel="apple-touch-icon" href>` を出す(`raw_html.link` / `raw_html.meta`)。無い const の要素は出さない。既存の head の要素(charset・viewport・title)の順と値は変えていない
  - **名と型の理由(record にしない、String の const を 1 本ずつ)**:既存の `lang`・`title` が String の const で、同じ書き方・同じ読み(`public_named_constant` + `g.string_value`)・同じ診断の形に揃う。record にすると shell.gleam に型の定義(`ThemeDefaults` の類)を書かせるか、framework に型を足して import させることになり、どれか 1 つだけ書く(theme_color だけ、など)ときも全欄を埋めるか `Option` で包む手間が出る。名は HTML の属性名を snake_case にした物(`theme-color` → `theme_color`、`apple-touch-icon` → `apple_touch_icon`)。`icon` は favicon の `rel="icon"`
  - gen の中では `reader_front.Shell` に `head: ShellHead`(5 つの `Option(String)` と `invalid: List(String)`)を足した。emit は `shell_head_text(front.shell.head)`
  - **head を吐く所の洗い出し**:頁の head は `page_render_text` の `render_view` 1 か所(全 Page の `load/**/page.gleam` がこれ)。error は `failure()` の `text/plain` で head が無い。shell の Response は `htmlWithGridCss` が SSR の文字列に `<style>` の中身と client の script を差すだけで head の要素を組まない。残る 1 か所は dev 専用の `/_blocks`(`blocks_preview.gleam` の `raw_html.head([], [])`、lang・title も出していない頁)で、ここには足していない(ホーム画面に置く頁でない)
- **(2) service worker の登録**:shell の任意の const `service_worker`(String)が在れば、生成の `priv/static/_yumemi/client.mjs` の末尾(`boot();` と `startNavigation(..)` の後ろ)に次を足す。無ければ client.mjs は 0.11.11 と同じ字
  ```js
  if (globalThis.navigator?.serviceWorker) {
    try {
      globalThis.navigator.serviceWorker.register("/sw.js").catch(() => {});
    } catch (_error) {
      // 登録できなくても画面は壊さない
    }
  }
  ```
  - 1 回:client.mjs は module で読み込みに 1 回評価され、client 遷移は client の script を keep して読み直さない(navigate.mjs の `swap`)
  - client.mjs の頭の sha は `service_worker` の値を足して取る(無いときは今と同じ入力)
  - **島の無い面**:今は島(live)が無い面に client.mjs を出さず、shell も script を差さない。`service_worker` が在るのに島が無い面では、登録だけの client.mjs(頭の行 + 上の JS)を出し、shell の `include_client` を立てて script を差す。島の client(lustre の登録・client 遷移)は起こさない ── const 1 つで遷移の動きまで変えないため。島も `service_worker` も無い面は今のまま(client.mjs 無し、script 無し)
- **(3) reader の診断**:5 つの const のどれかが在るのに空でない String の定数でない(型違い・`""`)なら、`title` と同じ「宣言の不足」(exit 3)の行 `<面>/src/shell.gleam: <名> は空でない String の定数で書く` で止める。無い const は何も言わない(任意)。`title` の扱い(無い・型違いは `title が無い`)はそのまま
- README:`## framework/front ── Shell: the home screen and the service worker (0.11.12)` の節(5 つの const の表・書き方・登録の振る舞い・遷移・診断)、0.11.12 の変更点の段落

## 検収

- root `gleam test`:`Framework checks passed: 24 groups`(基線 24、増減無し ── root のコードは版の行の他に変えていない。shell の const は gen だけが読む物で、root に型も関数も無いため、(1)〜(3) の test は gen に置いた)。`build/01112-test-root.txt`(基線 `build/01112-test-root-base.txt`)
- gen `gleam test`:337 passed, no failures(基線 332 + 5)。`build/01112-test-gen.txt`(基線 `build/01112-test-gen-base.txt`)
  - `front_emit_shell_head_consts_render_in_head_test`(1)(2):5 つ全部 → title の直後に 4 要素がこの順、client.mjs に登録が 1 回、`boot();` は残る。shell の診断は 0 行
  - `front_emit_shell_head_one_const_test`(1):`theme_color` だけ → その要素だけ、他の 3 つと登録は出ない
  - `front_emit_shell_without_head_consts_is_unchanged_test`(1)(2):const 無し → head は title の直後に閉じる、client.mjs に `serviceWorker` 無し。島の在る面では const の在る無しで shell.mjs は頭の sha の行の他は同じ
  - `front_emit_service_worker_without_islands_test`(2):components を外した面 + `service_worker` → 登録だけの client.mjs(`lustreRegister` 無し)と shell の script の差し込み。どちらも無い面 → client.mjs 無し、shell は `return rendered;`
  - `shell_head_invalid_consts_are_exit_three_test`(3):`manifest: Int = 1` と `icon: String = ""` → 2 行、どちらも exit 3、正しい `service_worker` は言わない
- `gleam format --check src test`:root・gen とも 0
- **musearch の写しで差 0**:基点 667038d の `git archive`(`.scratch/yumemi-base`)の gen で写しを再生成 → musearch main と差 0(`git status` 空)。続けて本作業木の gen で再生成 → `git status` 空(`git diff --stat` 0)。両方停止コード 0、診断(`[exit ..]`・`停止コード`・`書いた: ..`)41 行が全行一致(`build/01112-diag-base.txt`・`build/01112-diag-new.txt`、`diff` 0。生のログは `build/01112-gen-{base,new}.txt`)。`_diagnostics.txt` は消した
- **写しの 4 面の build・test**(www・admin・console・muses・api の `gleam.toml` を `yumemi = { path = <作業木> }` に向けた):
  - `npm run build`:www・admin・console・muses すべて EXIT 0(`build/01112-ms-build-*.txt`)。www は 1 回目が `gleam build` の依存解決で Hex API の rate limit(`The rate limit for the Hex API has been exceeded`)に当たって落ち、そのまま回し直して EXIT 0(ログは回し直しの方)
  - `npm test`:www 409/409、admin 21/21、console 88/88、muses 442/442(`build/01112-ms-test-*.txt`)
  - api・auth の build・test は回していない(BRIEF の検収は 4 面。auth は Hex の yumemi 0.7 で本便は届かない)
- **使えば効く(1 回、写しの www)**:`build/01112-use-source.diff`(source の差)・`build/01112-use-gen.diff`(生成の差)・`build/01112-probe-use.txt`(測った値)・`build/01112-probe.mjs`(測りの手。www の worker を node で動かし、APP を stub に。Chromium 153.0.8010.12、390×844、`http://127.0.0.1`)
  - source:www の `src/shell.gleam` に 5 つの const(`/manifest.webmanifest`・`#A93632`・`/brand/favicon.svg`・`/brand/apple-touch-icon.png`・`/sw.js`)、`priv/static/sw.js`(空)と仮の `manifest.webmanifest`
  - 生成の差:www の 37 頁の `load/**/page.gleam`(全頁) に 4 要素(各 +16 行)、`client.mjs` の末尾に登録(+7 行)、`shell.mjs` と `transport_ffi.mjs` は頭の sha の行だけ(shell.gleam が入力に入るため)。他の面は差 0
  - 測った値(`/privacy` を開き、`/terms` へ足した link を click して client 遷移):

    | | 読み込み `/privacy` | client 遷移の後 `/terms` |
    |---|---|---|
    | `link[rel=manifest]` | 1 個 `/manifest.webmanifest` | 1 個 |
    | `meta[name=theme-color]` | 1 個 `#A93632` | 1 個 |
    | `link[rel=icon]` | 1 個 `/brand/favicon.svg` | 1 個 |
    | `link[rel=apple-touch-icon]` | 1 個 `/brand/apple-touch-icon.png` | 1 個 |
    | client の script | 1 個 | 1 個 |
    | `navigator.serviceWorker.getRegistration()` | scope `http://127.0.0.1:<port>/`、script `/sw.js` | 同じ |
    | head の並び | meta・viewport・title・manifest・theme-color・icon・apple-touch-icon・script | script・(以下同じ順) |

  - client 遷移だったこと:click の前に `window.__probeMark = 'kept'` を置き、遷移の後も `kept`(文書の読み直しなら消える)。pageerror 0 件
  - 遷移の後に script が head の先頭に来るのは navigate.mjs の `swap` の今の動き(client の script を残して他を差し替える)で、本便で変えていない

## 確かめていないこと

- 実機(iPhone・Android)でホーム画面に置けること・全画面で開くこと(manifest の中身・アイコンは musearch の次の便)
- const を書かない状態の www での probe(base)は回していない。const 無しの出力が 0.11.11 と同じことは、写しの再生成の差 0 で見た
- 島の無い面の登録だけの client.mjs を実ブラウザで読み込むこと(gen の test で字だけ。musearch の 4 面はどれも島を持つ)
- dev 専用の `/_blocks` の head には足していない(上の「洗い出し」)
- api・auth の build・test(BRIEF の検収の外)

## 残り・気づき

- 写しの build で 4 面の `manifest.toml` が変わった(path 依存の行)。root のコードを変えていないので client.mjs の bundle の差は出ていない
- `.scratch/` は commit していない

## DDL

無し
