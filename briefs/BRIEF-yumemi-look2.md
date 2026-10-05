# 真壁[IM]へ ── yumemi 0.11.8(便 yumemi-look2、Style と Area の見た目の欠け 4 つ、直書き、鷹野[PDM] 2026-09-29)

便: yumemi-look2

**cloud セッションの Agent として 1 session で直に書き、ゲートは受けない(終端は鷹野の検収、前面の便と同じ扱い)。**経路は Opus の真壁。作業木 `~/yumemism_repo/yumemi-look2`(branch `impl/yumemi-look2`、基点は yumemi main 5b11131 = 0.11.7 の上の本 BRIEF の commit)。記録は `results-look2.md`(リポ直下)。commit は `git-as makabe`、main に触らない、push・tag・Hex の publish は鷹野。**版は 0.11.8**(`gleam.toml`)。musearch の作業木には書かない(確かめは使い捨ての写しで、下の「検収」)。**止め線は経過 1 時間。**

**親ゴール:** MuseArch www の画面が、ブランドガイド v0.1 の寸法と間隔どおりに出る(役員 人見 2026-09-29「www の画面を実際にフロントエンドで組ませて」、割りは tech `~/canonical/tech/_drafts/musearch/75-www-front.v0.md`)。0.11.7(yumemi-look)で地の色・罫線・focus・書体は書けるようになったが、wf-1b〜wf-5d の実装で次の 4 つが書けないと分かった。各便は block ごとに仮の手当てをしている。
- 障害:`min-height: 48px` と padding を持つ入力・`<a>` のボタンが 74px になる。box-sizing が content-box で、`border-box` を書く語彙が無い(musearch `docs/wf-5d/results.md`・`docs/wf-4/results.md`)
- 障害:page の Area の `flow: css.Stack(gap: …)` が CSS に出ず、Area は `display:block` のまま。block の間が詰まる(`docs/wf-5a/results.md` ── wf-5a は block の根に透明の下の縁 12px で空けた)
- 障害:`ul`/`li` の「•」を消せない(`list-style`)。行ごとリンクの `<a>` の下線を消せない(`text-decoration`)

## どこまで

1. `Style` に 3 つを足し、`sketch_css.gleam` が CSS に写す(型の形は真壁の選択、理由を results に):
   - box-sizing(`border-box` と `content-box`)
   - 並びの印を消す(`list-style: none`、padding-left 0 は既存の Space で書ける)
   - 文字の飾り(`text-decoration: none` と `underline`)。`State(Hover|Focus, …)` の中でも使える
2. **Area の `flow` を CSS に出す。**Layout・page の Frame の Area に書いた `Stack(gap)`(ほか `Flow` の variant)が、生成される grid の CSS(`htmlWithGridCss` と `_yumemi/style.css`)で、その Area の `display:flex; flex-direction:column; gap:…` などになる。Area の中の block は幅いっぱいのまま(`align-items: stretch`)。今 Area に書いている `pin`・`style` の出力は変えない
3. 足すだけにする。既存の variant の意味と出力を変えない(2 は既存の値を CSS に出すので、musearch の生成の差は Area の CSS の行だけに出る)
4. README の Style と Area の節に足す

**しないこと:**Style の他の語彙、生成器の読み・Service・DDL の生成、`island_style.mjs` の仕組み、musearch の source、tag・publish・push。

## 失敗例(差し戻し)

既存の出力が変わる(Area の CSS 以外)。Area を flex にして block の幅が縮む。`Stack` 以外の `Flow` の variant を黙って落とす。

## 検収

- yumemi の `gleam test`(基線 Framework checks 13 groups)に 4 つの test を足して通す
- 生成器(`gen/`)の test があれば通す
- **musearch の写しで確かめる:**`git -C ~/yumemism_repo/musearch worktree add /tmp/…` はしない。`cp -r ~/yumemism_repo/musearch-wf-5a <作業木>/.scratch/musearch`(wf-5a の作業木、node_modules 込み。`.scratch/` は `.git/info/exclude` に入れてあり commit されない)に写し、写しの `www/gleam.toml` の yumemi を path 依存で本作業木へ向け(`yumemi = { path = "…/yumemi-look2" }`)、本作業木の `gen` で再生成し、`npm run build`・`npm test` を通す。生成の差が Area の CSS の行だけであることを `git diff --stat` と diff の抜粋で示す
- 同じ写しの `/me` を 390px で 1 枚撮り、block の間が空くことと、`style.input` に border-box を足した入力が 48〜50px になることを計算値で示す(写しの style.gleam に 1 行足してよい ── 写しは捨てる)
