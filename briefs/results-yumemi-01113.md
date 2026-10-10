# results ── yumemi-01113(0.11.13、真壁 r1)

基点 `0815e59`(BRIEF の commit、main e9401ac = 0.11.12 の上)。branch `impl/01113`。証跡は `build/01113-*`(git の外)。musearch の写しは `.scratch/musearch`(musearch origin/main `d25fa442f` の `git archive`。BRIEF を書いた時の 11ae96d7e の上に BRIEF の commit が 1 本載っていた。4 面の `node_modules` は 01112 の写しから。4 面の package.json・lock は 01112 の写しと差 0。独立した git にした。commit しない)。

## やったこと

- 版 0.11.13(`gleam.toml`・`gen/manifest.toml` の path 依存の行)
- **(1) theme を取る Service と path を生成のときに決める**(`gen/src/yumemi_gen/emit/front.gleam`)
  - Service:今の `page_theme_service` の選び方のまま(Page の source のうち、Out の型のどこかに PageTheme を持つ最初の物)
  - path:`page_theme_path` が、その Service の Out(`service` 定数の注釈の 2 つ目)から、ラベル付きの欄を glance の型でたどる(Option・1 variant の record・type alias はたどる、List には入らない、同じ型を 2 度通らない、alias は 8 段まで)。欄の型が `PageTheme` か `Option(PageTheme)` の所で止める。各段は `#(欄名, Option か)`
  - shell.mjs の theme の行:`{ theme: true, from: service.Service$<Service>$const, path: [["muse", false], ["theme", true]] }`
  - 実行時:読みの loop で decode 済みの値を Service ごとに `read` へ置き(`read.set(source.service, decoded)`)、theme の行で `pageTheme(source.path ?? [], read.get(source.from))`。`pageTheme` は path をたどり、Some は剥がし、Option の欄の None・欠けた値なら `Option$None$const`、着いたら `new Some(value)`。theme のための読みは増えない(すでに読んだ Service の値を使う)
  - **theme を取る Page の無い面は shell.mjs の字を 0.11.12 のまま**にした(`uses_page_theme` が偽なら旧の `pageTheme(definition, root)`・`let root`・`if (source.root) root = decoded;` を出す)。theme を書かない面の生成の差を出さないため
- **`theme: Some(name)` の `name` の意味**:README に書かれた意味は無かった(0.11.12 までの README に Page の theme の節が無い)。今の実装上の意味は 2 つで、(a) 生成の load の `Data` の欄名、(b) 実行時の `root[name]`(最後の root の Out の一番上の欄名)。本便では「PageTheme の値を持つ最後の欄の名」とした ── musearch の 7 Page の `Some("theme")` は `muse.theme` の `theme` に当たり、(a) はそのまま。名の合う path が無いときは一番浅い path を取る(止めない)。README の節に書いた
- **(2) 型の上で PageTheme に着けない Page**:**今どおりの出力**を選んだ。生成は止めない。load の `page.gleam` は 0.11.12 と同じ字(source に PageTheme を持つ物が無ければ `<root service>.PageTheme` を名指しし、これは compile が通らない ── 今と同じ)。shell の行は `{ theme: true }` のまま、実行時は `read.get(undefined)` で None(既定の色)
- **(4) README**:`## framework/front ── Page theme: where the colours come from (0.11.13)` の節(Service の選び・path のたどり方・`name` の意味・None の扱い・着けないとき)と 0.11.13 の段落

## 検収

- root `gleam test`:`Framework checks passed: 24 groups`(基線 24、root のコードは版の行の他に変えていない)。`build/01113-test-root.txt`
- gen `gleam test`:**339 passed, no failures**(基線 337 + 2)。`build/01113-test-gen.txt`
  - `front_emit_page_theme_follows_out_path_test`(3):fixture の ArticleRead の Out の `theme` を `look: Look`(`Look(theme: Option(PageTheme))`)へ包み直し、Feed(WidgetList)の Fixed を足す → root は 2 つ(layout の WidgetList・ArticleRead)、theme の行は `from: service.Service$ArticleRead$const, path: [["look", false], ["theme", true]]`、loop に `read.set(source.service, decoded);`。生成の `pageTheme` を JS で評価し(FFI `page_theme_from_shell`、Gleam の record の欄名の property と本物の `Some`/`Option$None$const` で値を組む)、背景 `#ccffa6` → `Some:#ccffa6`、theme が None → `None`。load の `theme_global` の `None` の腕が既定の 4 色
  - `front_emit_without_page_theme_keeps_runtime_test`:fixture の Page を `theme: None` にすると、shell.mjs に theme の行が無く、`pageTheme(definition, root)`・`if (source.root) root = decoded;` が 0.11.12 の字のまま、`read.set(` が出ない
  - root が 2 つで theme の Service が**最後の root でない**形は、fixture の Block の組では作れなかった(layout の Widget の WidgetList が先頭に並ぶため)。その形は下の musearch の写し(MuseHeader が先頭、後ろに MuseRead・ArticleRead など)で実行時に確かめた
- `gleam format --check src test`:root・gen とも 0
- **musearch の写しで**:基点 e9401ac の `git archive`(`.scratch/yumemi-base`)の gen で再生成 → 差 0(`git status` は `_diagnostics.txt` のみ)。続けて本作業木の gen で再生成 → **差は `www/src/gen/shell.mjs` の 1 本だけ**(+18 −13、`build/01113-ms-gen.diff`)。両方停止コード 0、診断 41 行が全行一致(`build/01113-diag-{base,new}.txt`)。shell.mjs の頭の sha の行は変わらない
  - 行で名指し(新の行番号):theme の行 396・414・432・492・510・530・547(7 Page:`/muse/:handle/article/:id`・`/article`・`/muse/:handle`・`/reviews`・`/schedule`・`/space/:id`・`/tweets`。どれも `from: service.Service$MuseHeader$const, path: [["muse", false], ["theme", true]]`)、`pageTheme` 1004〜1012、`const read = new Map();` 1065、`values.push(pageTheme(source.path ?? [], read.get(source.from)));` 1068、`read.set(source.service, decoded);` 1079
  - admin・console・muses・api の生成は差 0
- **写しの 4 面**(5 面の `gleam.toml` を `yumemi = { path = <作業木> }` に):`npm run build` www・admin・console・muses すべて EXIT 0(`build/01113-ms-build-*.txt`)。`npm test` www 409/409、admin 21/21、console 89/89、muses 452/452(`build/01113-ms-test-*.txt`)
- **使えば効く 1 回**(`build/01113-probe.mjs`、測った値 `build/01113-probe-use.txt`):写しの www の worker を node で動かし、APP を stub に(応答の形は `docs/pwa-1/evidence/stub-app.mjs` の型)。嬢 `iro` は `/api/muse/iro/header` と `/api/muse/iro`(muse_read)が `theme: {background: "#ccffa6", background_image: null, text: null, accent: "#ff00ff"}`、嬢 `plain` は `theme: null`。基点の shell.mjs で組んだ worker(`worker-entry-base.mjs`)と本便の worker の両方で SSR の body の CSS 変数を測った

  | | 基点 `--bg` / `--accent` | 本便 `--bg` / `--accent` | `/api/muse/*` の読み(基点 = 本便) |
  |---|---|---|---|
  | `/muse/iro` | `#FAF7F0` / `#A93632` | **`#ccffa6` / `#ff00ff`** | 4 |
  | `/muse/iro/article` | `#FAF7F0` / `#A93632` | **`#ccffa6` / `#ff00ff`** | 3 |
  | `/muse/plain` | `#FAF7F0` / `#A93632` | `#FAF7F0` / `#A93632` | 4 |
  | `/muse/plain/article` | `#FAF7F0` / `#A93632` | `#FAF7F0` / `#A93632` | 3 |

  全部 200。`--text` は theme の `text: null` なので両方とも既定の `#3D2419`。基点で staging の障害(theme を返しても既定の色)が再現し、本便で値が出る

## 確かめていないこと

- 実ブラウザ・staging での表示(SSR の HTML の文字列を測った。client 遷移は SSR の HTML を取り直す経路で同じ shell を通るが、遷移そのものは回していない)
- `background_image`(Blob)の theme が `--bg-image` に出ること(stub は null。`theme_global` は本便で変えていない)
- 欄名が JS の予約語などで Gleam が property 名を escape する欄を path が通る場合(path は Gleam の欄名をそのまま property に使う。musearch の `muse`・`theme` は該当しない)
- api・auth の build・test(BRIEF の検収の外)

## 残り・気づき

- BRIEF は「musearch の 9 Page」とあるが、origin/main の `theme: Some("theme")` は www の 7 Page だった(上の行で名指しした 7 本)
- 写しの build で 4 面と www の `manifest.toml` が path 依存の行で変わった(写しの中だけ)
- gen の fixture の生成物(`gen/fixtures/article/*/src/gen/shell.mjs`)は再生成していない(0.11.12 と同じく fixture の生成物は手で更新される物で、test は fixture の source から生成し直して見ている)
- `.scratch/` は commit していない

## DDL

無し
