# BRIEF front-1d ── yumemi:島に「外から来た読み」と「書きの後」を持たせる(0.7.0)(草案、2026-09-21、水無瀬[PL] 起草 → 鷹野[PDM] が裁いて commit)

便: yumemi-front-1d

**前提:** 基点は yumemi main `c694180`(0.6.0、Y1c 後)。作業木は `~/yumemism_repo/yumemi-front-1d`(branch `front-1d`、贄川が作る)。musearch は**読むだけ**。**DDL は書かない。**経路は Y1c の型:贄川 = Claude opus(`claude-niekawa`)、柏木 = Codex sol(ゲート 1 / 2 は便に各 1 回)、真壁 = luna(ゲート 2 の P0 を直す巡だけ sol)。1 巡 = 1 session。真壁名義で commit、**push しない**。**merge と Hex publish は鷹野**(便の中で publish も版の再変更もしない)。**yumemi リポなので musearch の段 4 / 段 5 と並走できる。**

**親ゴール:** tech `_drafts/gleam-framework/00-goal.md` の G2 の front 側 ── **書きが主の画面**(musearch console の 18 画面、書き 27 本)が 51 v5 の型で成立するよう、島の型に足りない 2 つを閉じ、**P5b(`musearch-console-1b`)が Hex から引ける 0.7.0** を作る。

**障害:**

- **穴 1 ── 島の選択肢(別 Service の Out の列)に置き場が無い。**`live.State` は `args` / `last` / `waiting` の 3 欄(現物 `src/framework/front/live.gleam:3〜5`)で、ヘブンの select の候補(`muse_heaven_list` の items)はどれでもない。`el.island` は children を取らない(`front/el.gleam:32` が `[]` 固定)ので外から差すこともできず、属性 1 本に JSON を詰めるのは島の中の parse(禁則「Component の計算」)
- **同じ穴で `reloads` が実装できない。**51 v5:245 は「戻りを `last` の隣に置く」と書くが、**型に「隣」が無い**(0.6.0 の実装は 0 本 ── `grep -rn reloads --include=*.gleam` は docs と BRIEF のみ)
- **穴 3 ── 書きが成功した後に別 Block の一覧を読み直す口が無い。**島は葉で、島どうしは状態をやり取りせず、Block は純粋な view なので**島は自分の外を描き替えられない**。一覧を島に入れれば行ごとの操作が島の中の島(禁則)、`window` 直叩きも禁則。**庵野の実測 2 / 2**(`/links` の書き 7、`/heaven` の書き 4)で画面固有でないことが確定
- これを閉じないまま P5b を起こすと、便の中で framework が要ると分かって止まる(yumemi 便 + Hex publish + 鷹野の merge が便の中に入る)
- 逆に**型を広げすぎると 51 の線が消える** ── 島に 4 つ目の「好きに使える状態」を作った時点で「計算する場所がどこにも無い」という機構の担保が失われる

## 現在地(数字は yumemi main `c694180` の実測)

- **`src/framework/front/` は 5 file 297 行**(`front.gleam` 39 / `css` 76 / `el` 33 / `live` **11** / `sketch_css` 138)。本便が触るのは **`live.gleam` の 11 行だけ**(`State` 3 欄 / `Event` 3 構成子)
- **属性 → イベントの道は実物で通っている** ── fixture の島 `gen/fixtures/article/www/src/components/like_button.gleam:63〜71` が `component.on_attribute_change("count", …)` で `live.Done` を作り、Block 側 `src/blocks/article.gleam:58〜60` が `el.island("like-button", [attribute.attribute("count", …)])` で値を積む。`verify-front-ssr` の ISLAND PASS(❤ 1 → 13)がこの道の実測
- **`update` はまだ ★ の手書き**(Y1c の P1、器は gen-6 = Y2)。本便も生成器を 1 行も触らない
- `cd gen && gleam test` **86**、`gleam run -m yumemi_gen -- fixtures/article <out>` が **exit 0 / 57 file**、`source.load` の units **11**、`verify-front-ssr` / `verify-front-isolate` **ALL PASS**、依存は Hex 公開物 10 package(lustre 5.7.1 / sketch 4.2.1 / sketch_lustre 3.1.2)
- musearch main(読むだけ)の生成器基線は **exit 4 = 5 本 / 18 行 / 警告 29 / 597 file**(F3 後)。**`api/gleam.toml` は `>= 0.5.0 and < 0.6.0`、P1 の `www/gleam.toml` は `>= 0.6.0 and < 0.7.0`** ── **0.7.0 への bump は musearch 側の便(P5b)でやる。本便は musearch に 1 行も書かない**
- rates(22:4x):codex 残 18 / pace −13.89(**減りすぎ**、リセット 9-23 19:21)、claude 残り気味。**本便はゲート 2 回 ≈ 3pt** ── 起こす時期は鷹野の卓

## どこまで

1. **`live.State` に欄を 1 つ**(穴 1)── `State(args, given, last, waiting)`、型引数は `State(args, given, out, error)`。`given` は **SSR が属性で渡した読みの Out、または `reloads` が叩き直した読みの Out**。島は読むだけで、島が自分で組み立てる口は持たない
2. **`live.Event` に構成子を 1 つ**(穴 1)── `Given(given)`。`Done` と同じく **runtime だけが作る**。`update` は欄を差し替えるだけ(`Set` / `Send` / `Done` の 3 つは 1 行も変えない)
3. **書きの後の宣言を 1 本**(穴 3)── `pub type After { Stay ReloadPage }` と、島が置く `pub const after_send: After`。`ReloadPage` のとき **`Done(Ok(_))` の後に同じ URL を SSR で引き直す**(PRG の島版)。**★ は `ReloadPage` の 1 語を書くだけで、場所を移す手は生成物(`client.mjs`)の中**にある ── 禁則(生 JS / `window` / 任意の `fetch`)は ★ に効く線なので保たれる。島が別の島や別の Block を名指しする口は**作らない**(島どうしは状態をやり取りしない、が崩れる)
4. **見本の島で 3 つとも通す** ── `gen/fixtures/article/www/src/components/like_button.gleam`(または見本の島をもう 1 つ)で `given`(属性から来る候補の列を select で描く)と `after_send: ReloadPage` を使い、**`app()` の `on_attribute_change` が `Given` / `Set` を作る形**を実物にする。`calls` / `reloads` の const の形は 51 v5 のまま
5. **道具 2 本を通す** ── `verify-front-ssr`(NO-JS PASS / ISLAND PASS)と `verify-front-isolate`(40 request、混入 0)が **ALL PASS**。`ReloadPage` の再要求が 1 回で止まる(ループしない)ことを証跡に
6. **版と報告** ── `gleam.toml` を **0.7.0**(**publish は鷹野**)。報告は `docs/reports/front-1d.md`(型の差分、**51 v5 に足す文 3 つの案**、P5b と Y2 への申し送り)。**51 v5 の改訂は鷹野が本便の後に当てる**(便の中で canonical を書き換えない)

## しないこと

生成器に front の出力(route / load / blocks / widgets / live / shell / style)を足す(gen-6 = Y2)、`reader` / `emit` / `gen/src/**` の変更、`front.gleam` / `css` / `el` / `sketch_css` の型の変更(**動かすのは `live.gleam` だけ**)、`pwa` 欄と PWA の生成物、WebSocket の push の口(52 鷹野宛 10、受信箱の便まで保留)、可変長ネスト配列の Args((C)、`/links` 固有で ER に持たせる筋)、他 Block の値を参照した分岐((D)、`/settings` 実測で一本化)、musearch への書き込みと版の bump、Hex publish と版の再変更、DDL、`main` への commit、push、`.claude/_core` `~/.codex` `~/.claude`。

## 失敗例

- 島に**好きに使える 4 つ目の状態**を作る(`given` を ★ が書き換えられる、`update` に計算が入る、`Given` を ★ が作れる)── 「計算する場所がどこにも無い」という担保が消える
- 島が**別の島 / 別の Block を名指しして更新する**口を足す(`invalidate: [blocks.LinkList]` の類)── 島は葉、という線が崩れる。更新は **Page ごとの再要求 1 つだけ**
- `el.island` に children を許す、島の中で JSON を parse する、`after_send` を ★ の関数にする(const 以外にする)
- `front.gleam` / `css.gleam` / `el.gleam` / `sketch_css.gleam` を「ついでに」直す、`framework/page.gleam` の `Page` を改名する、package を割る
- Hex 以外の依存を足す、版を 0.6.x や 0.8.0 にする、便の中で publish する、musearch の `gleam.toml` を触る
- `gleam test` 86 を割る、fixture 生成 57 file / units 11 を動かす、musearch の基線(exit 4 = 5 本 / 警告 29 / 597)を動かす
- 51 v5 を便の中で書き換える(canonical は鷹野)。同 persona の同秒起動、`^session_id:` での終了判定、push

## 検収

- root `gleam build` **0**、`cd gen && gleam test` **86 以上**、`cd gen/fixtures/article/www && gleam build` **0**
- `gleam run -m yumemi_gen -- fixtures/article <out>` が **exit 0 / 57 file**、`source.load` の units **11**(**生成器は 1 file も動かない**)
- musearch main `api/`(読むだけ)への clean run が **exit 4 = 5 本 / 18 行 / 警告 29 / 597 file** で基線一致
- `verify-front-ssr` / `verify-front-isolate` **ALL PASS**、**`ReloadPage` の再要求が 1 回で止まる**証跡(request の列)
- **`src/framework/` の差分の行数**(期待:`front/live.gleam` **+10 行前後の 1 file だけ**、他の 4 module は **0**)、`gleam.toml` の版 0.7.0、依存 package 数は **10 のまま**
- 報告に **51 v5 に足す文 3 つの案**(島の args の初期値は属性で渡る / `given` は外から来た読みの置き場で `reloads` の戻りもここ / 書きの後は `after_send` の 2 値)と、`## DDL`(無し)
- 終端は承認かエスカレーション

## 申し送り(報告に必ず書く)

- **P5b(`musearch-console-1b`)へ:**島 1 つぶんの実物(`given` の受け取り方、`after_send` の置き方、`app()` の `on_attribute_change` の形)、**`muses/` は `>= 0.7.0 and < 0.8.0`、P1 が置いた `www/gleam.toml` の `< 0.7.0` も 1 行上げること**
- **Y2(gen-6)へ:**生成器が吐くべき `src/gen/live/<service>.gleam` の形(`Field` enum、`Given` の配線、`reloads` の 1 本、`after_send` の分岐)── **本便で ★ が手で書いた `update` がそのまま雛形**
- **鷹野へ:**51 v5 の改訂箇所(§243 の `reloads` の文、§236 の `State` の図、禁則の「外から起きる合図」の項が `after_send` と食い違わないか)

## 裁定待ち ── 起動前に鷹野が裁く(水無瀬の推奨つき)

1. **穴 3 の形 ── 書きの後に「Page ごとの再要求」を 1 つだけ許すか。****推奨:許す(`after_send: Stay / ReloadPage`)。**代案は (α) 一覧を島にする → 行ごとの操作が島の中の島で禁則、(β) 島が別 Block を名指しする → 島は葉が崩れる、(γ) 何もしない → 書いた画面が古いまま。**SSR が正本・front はロジックを持たない、と真正面から整合するのは再要求だけ**で、島どうしの配線も Block の純粋性も 1 つも崩れない
2. **`given` を 1 欄にするか、`reloads` の戻りと分けるか。****推奨:1 欄**(`reloads` は「外から来た読みを差し替える」手であって別の状態ではない)。分けると島の状態が 5 つになり、「3 つだけ」の線が二度と引けない
3. **起こす時期。****推奨:段 4(B3 ∥ P1)の中で今すぐ** ── yumemi リポなので musearch の 2 便と並走でき、**クリティカルパスへの足しは 0**(Y1c と同じ打ち方)、段 5 の 4 便が全部 0.7.0 で始められる。**ただし codex は減りすぎ**(残 18 / pace −13.89)で本便のゲート 2 回 ≈ 3pt が乗る ── 段 5 をリセット(9-23 19:21)後に送る話と同じ卓なので、**人見の裁定が要る 1 点**

## 鷹野の裁定(2026-09-21 22:57)── 1 / 2 は How で裁いた、3 は人見の卓

1. **穴 3 の形は「Page ごとの再要求」1 つだけ**(`after_send: Stay / ReloadPage`)。島が別の島 / Block を名指しする口は作らない
2. **`given` は 1 欄。**`reloads` の戻りも同じ欄
3. **起こす時期は役員 人見の卓。**codex が減りすぎ(残 18 / −14)でゲート 2 回 ≈ 3pt が乗る。裁定が無ければ **段 5 の頭(codex リセット 9-23 19:21 後)** ── 段 5 = Y1d → (P2 ∥ P3 ∥ P5b ∥ Y2) → P4。段 4 の中で起こすのは人見の「段 4 はそのまま回す」(22:33)の外なので鷹野は起こさない
4. **2 束目を足す ── 生成器の列名推論**(B3 巡 1 で根因確定:`gen/src/yumemi_gen/reader.gleam:1099` / `:1216` の `<> "_id"` が `RelProp` だけに効き、ER 外 module の id 型を持つ `ValueProp` は綴りのまま列名になる)。**直しは「id 型(`<Module>Id`)を持つ prop は relation と同じく `<prop>_id`」の 1 点**、`gen` の test に負例と正例を 1 本ずつ、fixture 生成 57 file の本文差を報告に。**musearch への追随(F3 の札 7 本 + B3 の `create_course` + read 側を生成に戻す)は本便でも P5b でもなく F4 の「どこまで」に 1 行足す**(鷹野が F4 の BRIEF に書く)。「しないこと」の `reader` / `emit` の変更禁止はこの 1 点だけ例外、front の reader / emit は触らない。**Actor の統一は載せない**(★ 9 本の musearch 追随が付く、別便の候補 ── 段 6 以降)
5. **束が 2 つになるので巡は 1〜2、Y1c の 1:33 に +30 分を見る。**検収に「`gen` test の増分 2 本」「musearch main への clean run で verb SQL の列名が `ledger_store_id` になった本の一覧(本文差として出るのは想定内、本数を名指し)」を足す ── 基線 597 / exit 4 = 5 / 警告 29 のうち **警告の札 8 本は根因が消えれば減ってよい**、減った本数を報告に
6. 島の器(client bundle の形)は Y1c の fixture `gen/fixtures/article/www/`(`verify-front-ssr` の ISLAND PASS の道)が正 ── 本便で `given` / `after_send` を通した見本がそのまま P5b と P3 の写す型
