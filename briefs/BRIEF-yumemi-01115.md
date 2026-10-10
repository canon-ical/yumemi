# 真壁[IM]へ ── yumemi 0.11.15(便 yumemi-01115、CSP を持つ頁も client の遷移に入れ、stylesheet を head に上げて差し替えで残す、直書き、鷹野[PDM] 2026-10-11)

便: yumemi-01115(yumemi リポ、Opus 真壁の直書き、ゲートなし。終端は鷹野の検収)

**1 session で直に書く。長い処理を背景に回さない。**作業木 `~/yumemism_repo/yumemi-01115`(branch `impl/01115`、基点 forgejo main = 0.11.14 の後の `4fc9153`)。記録は `briefs/results-yumemi-01115.md`、証跡は `build/01115-*`(git の外)。commit は `git-as makabe`、main に触らない。push・tag・Hex の publish は鷹野。**版は 0.11.15。止め線は経過 1 時間 15 分。**

**親ゴール:** 嬢のページの中の移動(TOP ⇄ 記事・タブ)が、電話で「頁ごと読み直した」と見えない(役員 人見 2026-10-11「SPA じゃないっぽい挙動をする」→ 案 1 を採用「案1でよいよ」)。
- 障害(水無瀬の実測、tech `_drafts/musearch/104-www-navigation.v0.md`):CSP の header を持つ Page は client の遷移の表から外れ、全読み込みになる(白 → 素 → 地色が約 350ms)。09-28 の役員 人見の裁定「CSP を持つ頁でも SPA のまま動く形は yumemi の宿題」の残り
- 障害:stylesheet の `<link>` が body にあり、client の遷移の `swap` で body ごと替わるたびに読み直し、素の頁が 140〜380ms 出る

## どこまで
1. **Shell に stylesheet の並びを足し、`<head>` に `<link rel="stylesheet">` を出す**(名は真壁の選択、例 `stylesheets: List(String)`)。既存の Shell の const の出力は変えない
2. **`swap` は `<head>` の同じ要素(outerHTML が同じ)を残し、順を保って差分だけ足し引きする。**来た頁の body にだけある stylesheet(記事の書体の css など)は読み終えてから body を替える
3. **route の表に Page ごとの CSP を持たせ、client の遷移は「今の document を読み込んだ Page の CSP」と行き先の CSP が同じときだけ。**応答の CSP header も同じ値かを見る。今の「CSP の header があれば落とす」を置き換える。違えば全読み込み(今のまま)
4. 門の 302(未申告の `/enter` など)は今のまま全読み込みに落ちる。pageview の口(`kind: spa`)は通る
5. test(navigate の CSP の一致・不一致・header の食い違い、head の差分の足し引き、body 側の stylesheet の待ち)と README の Shell・遷移の節と 0.11.15 の段落

**しないこと:**musearch の source、View Transitions・先読み(案 2・3)、tag・publish・push。

## 失敗例(差し戻し)
- CSP の違う頁へ client で移り、ヘブンの iframe や Turnstile が CSP で落ちる
- head の stylesheet を全部消して入れ直す(素の頁が残る)
- 新しい語を使わない musearch で生成の差が出る

## 検収
- root `gleam test`・gen `gleam test` に足して通す。`gleam format --check` 0
- **musearch の写しで差 0**:origin/main(`~/yumemism_repo/musearch`)の写しを `.scratch/musearch` に置き、基点と本作業木の gen で全面を再生成して差 0、写しの 4 面の build・test が通る
- **使えば効く 1 回**(写しの www で `SiteHeader` の 4 本の `<link>` を Shell へ移し、www の全 Page に同じ CSP ── `frame-src` に `blogparts.cityheaven.net` と `challenges.cloudflare.com` ── を付けてよい、写しは捨てる):手元の worker と stub を Chromium 360px・回線 150ms・CPU 4 倍で、TOP → 記事・TOP → タブ・タブ同士の 3 通りが client の遷移(`window` が残る)で素の時間 0。測り方は 104 の「測り方」。表で results に
