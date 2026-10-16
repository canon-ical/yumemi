# results block-door ── 断片の口と yumemi.block を Live でない Block にも(0.14.1)

真壁[IM]、2026-10-17。基点 `cca6b4d`(`ec85d34` release 0.14.0 + BRIEF)。branch `impl/block-door`。指示 `briefs/BRIEF-block-door.md`。証跡は `build/bd-*.txt`(git の外)。push・tag・Hex は触っていない。DDL 無し。

## 1〜6 の充足

| # | 中身 | 置き場 | 充足 |
|---|---|---|---|
| 1 | 断片の口が頁の sp の `Fixed` の Block にも答える。門・宣言・同意・session・叩く読み(Block の読み + 頁と Layout の `!optional` の読み)は `Live` と同じ道(`renderBlock` を共に使う)。Layout の Block・`Widget` の Block・頁に無い名は 404(読みを叩く前)。Service を読まない Block(`In = Nil`)は Vars だけで描き、root の読みは status のために叩く | `gen/emit/front.gleam` の `page_fixed_blocks`・`front_has_door`・`fragment_function_text`(loader の `block_<name>`)・`shell_live_rows`(表 `blocks`)・`shell_block_text`、`gen/emit/gate.gleam`(数えない印を口のある面すべてに) | 済 |
| 2 | `Live` でない Block の断片は `<yumemi-block name>`(`display: contents`、札無し・socket 無し)。合図も `visibilitychange` も持たず、自分では読み直さない | loader の `block_wrap`、`src/yumemi/front/block.mjs`(新規)の `YumemiBlock` | 済 |
| 3 | `yumemi.block` を逃げ道のある面すべての `mount` の 2 つ目に渡す。`Live` の無い面は `block.mjs` だけを束ねる(札・socket・スクロールの runtime は読まない)。`Live` の Block への振る舞いは 0.14.0 と同じ(`<yumemi-live>` の分岐は字のまま移した) | `client_text`(`import { block as yumemiBlock, start as startBlock } from …/block.mjs` と `startBlock()`)、`block.mjs` の `block` | 済 |
| 4 | CSS の規則を足す道(取るたびに document の今の sheet から在る規則の表を作り直す)は `Live` と同じ関数 `adopt` | `block.mjs` へ移し、`live_block.mjs` が import | 済 |
| 5 | test(下の表) | `test/yumemi_block_door_check.mjs`(17 件)、`test/yumemi_block_door_shell_check.mjs`(18 件)、`test/yumemi_block_door_test.gleam`(6 件) | 済 |
| 6 | README の Live の節(断片の口・逃げ道・生成物の段、0.14.1 の段を足した)、`CHANGELOG.md`(新規、0.14.1)、`gleam.toml` 0.14.1、fixture の lock(`gen/fixtures/{article,cms}/{public,admin}/manifest.toml`)と生成物(shell・gate・loader・client.mjs)を写しで生成し直して書き戻した | | 済 |

## 返す要素の形

```html
<!-- x-yumemi-block: summary の応答(Fixed の Block)。cache-control: no-store、vary: x-yumemi-block -->
<style>…Block が使った class の規則…</style><yumemi-block name="summary">…頁と同じ Block の HTML(置き場の cell の包みも)…</yumemi-block>

<!-- yumemi.block("summary", { href }) が返す要素(document の外、規則は足し済み) -->
<yumemi-block name="summary" href="https://…/article/42">…</yumemi-block>
```

- 頁は `Fixed` の Block を包まない(頁の HTML は 0.14.0 と同じ)。包むのは断片だけ
- `href` は `<yumemi-block>` ならいつも(今の URL でも)付ける。client 遷移で URL が替わっても、置いた要素を取った URL で探せる。`<yumemi-live>` は 0.14.0 と同じく別の URL のときだけ
- 同じ Block を頁に 2 か所 `Fixed` で置いたら先の 1 つ(その cell)が答える。同じ名の `Live` があれば `Live` が答える
- `yumemi.block` の戻り:置いた `<yumemi-block>` を同じ URL で呼ぶと取り直して当て(`Live` と同じ 4 規則の morph)、その要素を返す。断片が来ない(redirect・403・404・断片の形でない)・5xx・通信の失敗は null で、頁も置いた要素も触らない(`yumemi-block-failed` を出す)。`Live` の要素は 0.14.0 のまま(頁ごと取り直す・待って取り直す)

## 採った形と退けた形

- **runtime を 2 つに割った。**`block.mjs` = 断片の取り(`fetchBlock`)・規則の足し(`adopt`)・当て方(`morph`、守る節)・`<yumemi-block>`・`block`。`live_block.mjs` = 札・socket・繋ぎ直し・スクロール・`el.fresh` で、`block.mjs` を import する(`adopt`・`block`・`fetchBlock`・`morph`・`remember` は再 export、`internals` も同じ鍵 + `expiry`)。退けた形:`Live` の無い面にも `live_block.mjs` を束ねる(BRIEF の失敗例)。逃げ道のある `Live` の無い面(fixture の article の public)の束ねた `client.mjs` は 35,802 → 49,894 byte。逃げ道の無い面(cms の public)は束ねない
- **`<yumemi-block>` は頁ごと取り直さない。**`Live` の要素は頁の Block そのものなので 404 で頁ごと取り直すが、`<yumemi-block>` は逃げ道が別の URL から置いたもので、その URL の 404(例:その日の板が無い)で今の頁を読み直すのは違う。null を返して逃げ道に任せる
- **`display: contents` は runtime が構築した sheet で足す。**`Live` の無い面の頁の `<style>` には `yumemi-live` の規則も無く、別の面の頁に置かれることもあるので、要素を定める `start()` が 1 本足す。inline の `style` 属性は CSP の `style-src` に掛かるので退けた
- **shell の表は `lives`(0.14.0 の字のまま)と `blocks` を分けた。**`renderPage` の札の差しは `lives` だけを回す。`renderBlock` は `lives` → `blocks` の順に引く
- **断片の口は口のある面の shell にだけ出す**(どこかの Page の sp に `Live` か `Fixed` の Block がある面)。門の数えない印も同じ条件(`gate.text_live` の引数の意味を「口がある」に広げた)
- **生成器の名:**loader の関数は `block_<snake>`、record は `Block<Pascal>`。`Live` の `live_<snake>`・`Live<Pascal>` は字のまま(関数 `fragment_function_text` を共に使う)

## test の表と証拠

| # | 何を | 結果 | 証拠 |
|---|---|---|---|
| 1 | `gleam test` | **`518 passed, no failures`**(基点の 512 + 本便の 6) | `build/bd-test5.txt`(基点は `build/bd-test0.txt`) |
| 2 | `node test/yumemi_block_door_check.mjs`(Chromium、playwright-core 1.63.0) | **ok 17、NG 0**:`Live` の無い面の逃げ道が `yumemi.block` を受け、`yumemi-live` は定まらず `live_block.mjs` を読まない/別の URL で `<yumemi-block href>`(document の外)/`replaceWith` で置くと HTML が当たり `display: contents`・Block の中に `<style>` が残らない/頁に無い規則が足され色が効く・頁に在る規則は足さない/合図が無いので server が変わっても `visibilitychange` でも取らない・upgrade 0/同じ URL で置いた要素を取り直して当て、同じ要素を返す/書きかけのメモと focus が残る/3 つ目の URL で新しい要素と規則/頁の `<style>` と足した規則を外した後(頁を移った形)取り直すと規則を足し直す/404(データ無し・頁に無い名)・門の 302・503 で null/そのとき頁は読み直さず置いた Block が残る/今の URL の `Fixed` の Block も `href` を持ち、`pushState` で URL が替わってもその `href` で探せる/`Live` の面でも `Fixed` の Block は `<yumemi-block>` で返り同じ URL で取り直せる/頁の error 0 | `build/bd-check-2.txt` |
| 3 | `node test/yumemi_block_door_shell_check.mjs`(article の写しに「`/article` は sign-in」の門を足して生成・build・偽の APP) | **ok 18、NG 0**:停止コード 0・面が compile/門の数えない印/shell に札の道具が無い/頁は Block を包まず数える印あり/`summary` の断片は `<style>` + `<yumemi-block name="summary">` だけで頁と同じ HTML、`no-store`・`vary`・数える印無し・札無し/読みは門の session 1 本と Block の Service だけ(Layout の widget を叩かない)/`notice`(`In = Nil`)は Vars で描き root を叩く/頁の root の Block(`article`)も答える/`site_header`(Layout)・`feed`(Layout の Widget)・`row_article`・`row_summary`(頁の Widget)・`nothing`・空の名は 404 で読みを 1 本も叩かない/匿名は門の 302(sign-in へ)で読み無し/root 404 → 404(`notice` でも)/root 403 → 403/別の頁(`/status`)は置いていない Block に 404/束ねた client.mjs が `yumemi-block` を定め、`yumemi-live` も `WebSocket` も無い | `build/bd-shell-2.txt`、写しは `build/block-door-fx` |
| 4 | 生成器の test(gleam、6 件) | `Live` の無い面の loader の `block_<name>`(Nil の Block は Vars だけ)・包みは断片だけ・shell の `blocks` の行(Nil は `service: null`)・頁の表に Layout と Widget の Block が無い・`renderBlock`・門の印/client.mjs の `block.mjs` と `startBlock()`・`live_block` 無し・逃げ道の無い面(cms)は束ねない/`Live` と `Fixed` が同じ頁:`lives` は 0.14.0 の字、`blocks` は他、`article` は `blocks` に出ない/同じ Block 2 か所は 1 行で先の cell/上の 2 本を子の node で回す | `test/yumemi_block_door_test.gleam`(#1 に含む) |
| 5 | 0.14.0 の `Live` の test | `node test/yumemi_live2_check.mjs` **ok 48、NG 0**(runtime を割った後、`build/bd-live2-check-1.txt`)。`node test/yumemi_live2_shell_check.mjs` **ok 22、NG 0**(`build/bd-live2-shell-1.txt`)。`gleam test` の `yumemi_live_test`(1 便目)・`yumemi_live2_test` も #1 で通る | 同左 |
| 6 | mutation(書き換えて回し、戻した) | 下の表。6 通りすべて NG ≥ 1 | `build/bd-mut-1.txt`、`build/bd-mut-root.txt` |
| 7 | `gleam format --check`(触った gleam 4 file) | exit 0 | このセッションの実行 |

| mutation | NG | 捕まえた件 |
|---|---|---|
| M1 断片の中で `yumemi-block` を探さない | 9 | 別の URL が null・置けない・CSS・取り直し・`Live` の面の件 |
| M2 `<yumemi-block>` に今の URL のとき `href` を付けない | 1 | URL が替わった後に置いた要素を探せない |
| M3 `block()` が置いた `yumemi-block` を探さない | 2 | 同じ URL で新しい要素を返す(置いた要素を取り直さない)・`Live` の面の件 |
| M4 `display: contents` を足さない | 1 | 置いた要素が `inline` |
| M5 断片の `<style>` を足さない | 4 | 色が効かない・規則 0 本・頁を移った後 |
| M6 shell の `renderBlock` が root の読みを叩かない(生成器) | 2 | `notice` の読みが 0 本・root 404 で 200 |

## 0.14.0 の test を変えたところ

- `test/yumemi_live2_test.gleam` の `faces_without_live_are_unchanged_test`:前提が「`Live` の無い面の shell と門は 0.14.0 と同じ字」だった。0.14.1 で口を開けるので、「札・socket・`<yumemi-live>`・`lives` の表が無い」と「生成の shell と門が commit した fixture と同じ」に替えた
- `test/yumemi_live2_shell_check.mjs` の 1 件:「`Live` でない Block の名(`summary`)は 404」の前提が替わった(`summary` は頁の `Fixed` の Block で 200 になる)。名を Layout の Block・Widget の Block・頁に無い名(`site_header`・`row_article`・`feed`・`nothing`)に替えた。件数は 22 のまま

## 確かめていないこと

- **実の `wrangler dev` で api と面を立てた e2e**(生成した shell は偽の APP で、client は試験の node の server で見た)。musearch の day_swipe を乗せる M2 の便の持ち場
- **musearch の `schedule_day` の頁そのもの**(root の Entity が無い読み)。断片の口は `Live` の検査(root の Entity が要る)を通らないので、読みの Service が root を持たなくても `Fixed` なら答える ── 生成器の上ではそうなっているが、musearch の ★ で生成して叩いてはいない
- `Fixed` の新規ブラウザ検証は Chromium のみ。`Live` の既存検証は Chromium と WebKit(WebKit は値・focus・選択範囲の保持)で実行済み。`Fixed` の WebKit、Firefox、Android / iOS の日本語入力は未確認(当て方は `Live` と同じ関数)
- `pc` / `tablet` の Frame の placements は口に出さない(頁が描くのは sp だけ ── `Live` と同じ扱い)。sp に無く pc だけにある Block は 404
- `yumemi.block` で取った `<yumemi-block>` の中の interactive Component・逃げ道は、接続で起きる(custom element)が、送った後の `ReloadPage` との重なりは見ていない
- 束ねた `client.mjs` が逃げ道のある `Live` の無い面で約 14KB(未圧縮)増えること。逃げ道の無い面は増えない
- fixture の `src/gen/reads/*.gleam` は基点でも今の生成器の出力と字が違う(本便の前から。本便では書き戻していない)

## DDL

無し。

## ゲート 2(柏木、2026-10-17)

柏木[CM] を `codex-kashiwagi --no-loop` で 1 回(run `kashiwagi-20261017-050831-2647200-18352`、指示は作業木の `build/gate2-block-door.md`、所見の写しは `build/gate2.md`)。

- **P0 無し。**断片の口は頁の sp の表を読みより先に引き、Layout・Widget・他頁・空の名を拒む。門は頁と共通の `gate.serve`、読みは Block の読みと頁・Layout の `!optional` の読み。`In = Nil` でも root の 403/404 を保つのを柏木が実行で確かめた
- **P1 無し。**`Live` の socket・繋ぎ直し・スクロールは基点と同一、移した morph は注記以外同一。`Live` の無い面は逃げ道がある場合だけ `block.mjs` を束ねる。`<yumemi-block>` の失敗で頁を保って null を返す判断は BRIEF に整合
- **P2 1 件(柏木が直した、柏木の commit):**「確かめていないこと」の WebKit の行 ── `Live` の既存の検査は WebKit でも回っている(値・focus・選択範囲)。実装の変更無し
- 柏木が走らせた検証:`gleam test` 518 passed・`yumemi_block_door_check` 17/0・`yumemi_block_door_shell_check` 18/0・`yumemi_live2_check` 48/0・`yumemi_live2_shell_check` 22/0。生成器を fixture の写しに走らせ、書き戻した shell・gate・loader・client.mjs・manifest の 24 file がバイトで一致

