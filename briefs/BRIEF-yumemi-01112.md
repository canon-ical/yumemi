# 真壁[IM]へ ── yumemi 0.11.12(便 yumemi-01112、head の PWA の口、直書き、鷹野[PDM] 2026-10-11)

便: yumemi-01112(yumemi リポ、直書き、ゲートなし。終端は鷹野の検収)

**1 session で直に書く。長い処理を背景に回さない。**真壁は母艦の Opus。作業木 `~/yumemism_repo/yumemi-01112`(branch `impl/01112`、基点 forgejo main 667038d = 0.11.11)。記録は `results-01112.md`(リポ直下)、証跡は `build/01112-*`(git の外)。commit は `git-as makabe`、main に触らない。push・tag・Hex の publish は鷹野。**版は 0.11.12。止め線は経過 45 分。**検収の形は `briefs/BRIEF-yumemi-01110.md` と同じ。

**親ゴール:** musearch の www と muses を電話のホーム画面に置け、全画面で開ける(役員 人見 2026-10-11「staging の muse と www を PWA 対応に」。射程はホーム画面に置けるまで、オフラインとプッシュ通知は入れない)。
- 障害:頁の head は生成器が吐き(`gen/src/yumemi_gen/emit/front.gleam` の `render_view`)、shell の const は `lang`・`title`・`theme` しか読まない。manifest・アイコン・theme-color の link を面の側から足す口が無い
- 障害:service worker の登録は JS が要り、面に手書きの script を置く口も無い。配信側で `</head>` を文字置換して逃げない(役員 人見 2026-10-01「yumemi で表せない表現は生成器の宿題」)

## どこまで

1. **shell の任意の const**:`manifest`(path)・`theme_color`・`icon`(favicon の path)・`apple_touch_icon`(path)。在れば head に `<link rel="manifest">`・`<meta name="theme-color">`・`<link rel="icon">`・`<link rel="apple-touch-icon">` を出す。無ければ 0.11.11 と出力が同じ。名と型は真壁の選択(1 つの record にまとめてもよい)、理由を results に。head を吐く所が `render_view` の他にもあれば(error 頁・shell の Response の組み立て)全部そろえる
2. **service worker の登録**:shell の任意の const `service_worker`(path)が在れば、生成の `priv/static/_yumemi/client.mjs` が読み込み時に 1 回 `navigator.serviceWorker.register(<path>)` する(`serviceWorker` が無い環境では何もしない、失敗は握って画面を壊さない)。無ければ client.mjs は 0.11.11 と同じ
3. reader で const の型違い・空文字を診断の行で止める(`title` と同じ扱い)
4. README の shell の節と 0.11.12 の変更点の段落

**しないこと:**sw.js そのもの・manifest の中身・アイコンの生成(面の静的 asset で、musearch の次の便)、既存の head の要素の順と値を変える、Service・DDL・読みの生成、musearch の source、tag・publish・push。

## 失敗例(差し戻し)

const を書かない musearch で生成の差が 0 にならない。client.mjs の既存の島・遷移の動きが変わる。SPA の client 遷移で head の link が消える・二重になる。

## 検収

- root `gleam test`・gen `gleam test` に (1)〜(3) の test を足して通す(基線の数は results に)。`gleam format --check` は root・gen とも 0
- **musearch の写しで差 0**:musearch の origin/main の写しを `<作業木>/.scratch/musearch`(commit しない)に置き、基点 667038d の gen と本作業木の gen で全面を再生成して `git diff --stat` が 0、診断の行が全行一致。写しの 4 面の `npm run build`・`npm test` が通る
- **使えば効くことを 1 回**(写しの www の shell に const を足し、空の `sw.js` と仮の manifest を置いてよい、写しは捨てる):手元の worker を Chromium 390×844 で開き、head に 4 つの要素、`navigator.serviceWorker.getRegistration()` が返る、client 遷移の後も head の要素が 1 つずつ、を results に
