# results yumemi-0147 ── client の遷移で redirect を返す GET を 2 回送らない(0.14.7)

真壁、2026-10-18。branch `impl/nav-redirect`、基点 `d5002ba`。

## 充足

| # | 内容 | 結果 |
|---|---|---|
| 1 | `swap` の fetch を `redirect: "follow"`・`mode: "same-origin"` に(他の項目はそのまま) | 済 |
| 2 | `response.redirected` なら `load(landing(url, response))`。同じ origin の最終の URL、最終に `#` が無く元に有れば元の `#`。`response.url` が空・読めない・別の origin は元の `url` | 済 |
| 3 | redirect でない応答の判定・通信失敗・中断は不変(`opaqueredirect` の検査も残した) | 済 |
| 4 | 冒頭の注記を、redirect は最終の URL を開く(理由 2 行)に | 済 |
| 5 | `yumemi_012_y4_start_check.mjs` に 7 件(init の `follow`/`same-origin`、`/a` を 1 回、元の `#x` を引き継ぐ、最終の `#y` を保つ、別 origin は元の URL、`response.url` 空は元の URL、TypeError は元の URL)。既存 19 件は不変。`yumemi_012_y4_test.gleam` の行数 19 → 26 | 済 |
| 6 | 実ブラウザの台本 `test/yumemi_0147_redirect_browser.mjs`(下表)。`gleam test` には繋いでいない | 済 |
| 7 | `gleam.toml` 0.14.7、fixture 4 面で `gleam update yumemi`(lock 0.14.7)、article・cms の public を生成し直して `client.mjs` が新しい `navigate.mjs`(`redirect: "follow"` 1 件ずつ) | 済 |
| 8 | CHANGELOG `## 0.14.7 (2026-10-18)` | 済(下の「確かめたこと 3」) |
| 9 | root の `gleam test` | `553 passed, no failures` |

## 実ブラウザの回数(Chromium 1243、`/go` のリンクを click、click 後の受信数)

台本:`node test/yumemi_0147_redirect_browser.mjs [navigate.mjs の path]`。`/` は 200 の頁、`/go` は 302 で `/`、`/out` は別の origin へ 302。

| 場面 | navigate.mjs | `/go` の受信 | `/` の受信 | 備考 |
|---|---|---|---|---|
| 同じ origin 302 | 直す前(forgejo/main) | **2**(fetch 1 + 頁の読み込み 1) | 1 | `{"main /go (fetch)":1,"main /go":1,"main /":1}` |
| 同じ origin 302 | 直した後 | **1**(fetch のみ) | 2(fetch 1 + 頁の読み込み 1) | `{"main /go (fetch)":1,"main / (fetch)":1,"main /":1}`、最終 URL は `/` |
| 別の origin 302(`/out`) | 直す前 | `/out` 2 | 別 origin 1 | |
| 別の origin 302(`/out`) | 直した後 | `/out` 2 | 別 origin 1(頁の読み込みの 1 回だけ) | `same-origin` が fetch を止め、`cors` の余計な 1 回は無い |

## 確かめたこと

1. `node test/yumemi_012_y4_start_check.mjs`:26 件が全部 `ok`(NG 0)。
2. 実ブラウザの表(上)。
3. `git grep -in "musearch\|人見" -- README.md CHANGELOG.md src` は **2 件** ── どちらも `src/yumemi/entry.gleam` の 3〜4 行目の doc コメント(人見の裁定)で、基点 `d5002ba` から有る既存。この便の差分は README・CHANGELOG に事業名・人名を入れていない。`src/` の既存の 2 行は触っていない(範囲外)。鷹野の判断を待つ。
4. root の `gleam test`:`553 passed, no failures`、`Framework checks passed: 25 groups`。

## 確かめていないこと

- WebKit・Firefox(Navigation API が無い browser は元から取らない)。
- `response.redirected` が true で `response.url` に `#` が付く場合は偽の応答でのみ確認(実ブラウザの `response.url` は fragment を含まない)。
- 生成し直した fixture のうち `src/gen/reads/*.gleam` は gleam の版による整形の差だけが出たので戻した(この便と無関係)。差分は manifest 4 件・`client.mjs` 2 件。

## 作業木の補足

root の `node_modules` は作業木に無かったので、メインの checkout のそれへ symlink を張った(`node_modules` は ignore)。fixture の面に置いた esbuild の symlink は、test が自分で張るので戻した。
