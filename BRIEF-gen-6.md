# BRIEF gen-6 ── yumemi:front の生成(面 package を読み、51 の生成物 13 種の front 段を吐く)(2026-09-21 起草、水無瀬[PL] 草案 → 鷹野[PDM] が穴 2 つを埋めて発行)

便: yumemi-gen-6

> **草案の穴は 2 つだけ。**(a) 読む対象の musearch の基点 `96fb8cc`(段 4 の merge 後、2026-09-22 05:00)(= B3 → P1 を merge した後の main)、(b) 下の「現在地」の ★P1 申し送り(`docs/front-1/results.md` の `## Y2(gen-6)への申し送り` = **本便が再現すべき ▲ の道と名前の一覧**)。**P1 が閉じたら鷹野が埋める。**

**前提は 1 つ。**P1(`musearch-front-1`)の承認と merge(58 §3 の `P1 → Y2`)── **生成器が再現すべき手書き ▲ の現物が要る**。yumemi の基点は main **`c694180`(0.6.0、Y1c 後)**(**`yumemi-front-1d`(P5b の前提、Hex 0.7.0 ── 島の型の穴 2 つ)が先に閉じたら、鷹野がその merge 後の sha に差し替える。下の「並走」を見よ**)。作業木は `~/yumemism_repo/yumemi-gen-6`(branch `gen-6`、贄川が作る)。**musearch は読むだけ。DDL は書かない。**記録は `docs/reports/gen-6.md`、`results.md` に `## DDL`(無し)。経路は Y1c の型:贄川 = Claude opus(`claude-niekawa`)、柏木 = Codex sol(ゲート 1 / 2 は便に各 1 回)、真壁 = luna(ゲート 2 の P0 を直す巡だけ sol)。1 巡 = 1 session、真壁名義で commit、**push しない**。**merge と Hex publish は鷹野**(便の中で publish も版の変更もしない)。

**親ゴール:** tech `_drafts/gleam-framework/00-goal.md` の G2 ── 「設計を書けば、コードが生まれる」を画面に広げる。**P1 が手で置いた ▲ を、生成器が同じ道・同じ名前で吐く**(基盤 C の型:手書きが先、生成器が後)。

**障害:**

- 面を読む道が無い ── `source.load`(現物 65 行)は `<app>/src` の下だけを歩き、`src/gen/` を除いて parse する。兄弟の面 package は視界に入っていない
- 面の生成物を back の `api/src/gen/**` に吐く ── 51 §340-1 が明示的に禁じている
- back の生成が 1 file でも動く ── 面を足しても back の 597 file は動いてはならない(Y1c の実測「面を足しても back の生成は 1 file も動かない」を本便でも保つ)
- **back 側の生成器の穴を一緒に直して便が膨らむ**(§7-9(b) の 12 項)── front とは入力も出力も交わらない(裁定待ち 1 / 2)
- 手書き ▲ と生成物が「だいたい同じ」で終わる ── 差が残ると追随便が手で埋める仕事に戻り、gen-6 の意味が消える

## 現在地(yumemi main `c694180` と musearch main `da3062c` の実測。基点は上記、巡 1 の頭で測り直す)

- ★**P1 の申し送り(`docs/front-1/results.md` の `## Y2(gen-6)への申し送り`)= `<鷹野が P1 の承認後に貼る>`** ── **本便の受入条件はこの一覧の再現**
- **生成器の現物:**`gen/src` は **9,114 行**(`reader.gleam` 2,176 / `emit/verb.gleam` 2,412 / `emit/sql.gleam` 1,262 / `emit/entry.gleam` 540 / `model.gleam` 453 / `emit/reads.gleam` 325 / `emit/typing.gleam` 312 / `emit/root.gleam` 258 / `emit/query.gleam` 232 / ほか)。**`emit/front*.gleam` は 0 本**。CLI は `gleam run -m yumemi_gen -- <app dir> <out dir>` の 2 引数
- **front の素材はもう main に在る(Y1c)** ── `src/framework/front{,/css,/el,/live,/sketch_css}.gleam` **5 file 297 行**、`entry.gleam` の `pages` / `frame_src` **+23 行**、fixture の面 `gen/fixtures/article/www/` **13 file**(`layout.gleam` / `style.gleam` / `pages/article/arg_id/page.gleam` / `blocks/{article,summary}.gleam` / `components/like_button.gleam` + ffi / **手書き ▲ 4 本** = `gen/{service,blocks,widgets}.gleam` と `gen/out/article_read.gleam`)、道具 4 本(`verify-front-ssr.mjs` 67 / `verify-front-isolate.mjs` 53 / `front-harness.mjs` 128 / `front-scratch/` 146 行)
- **基線(Y1c の実測)** ── root `gleam build` 0、`cd gen && gleam test` **86**、`gleam run -m yumemi_gen -- fixtures/article <out>` が **exit 0 / 57 file**、`source.load` の units **11**、`verify-front-ssr` / `verify-front-isolate` **ALL PASS**(島は `❤ 1 → ❤ 13`、isolate 40 回で混入 0)
- **musearch 側の基線(鷹野の F3 検収)** ── 生成器を `api/` に当てて **exit 4 = 5 本 / 18 行 / 警告 29(基線 21 + 札の素通り 8)/ 597 file**。**面を足しても この数字は動かない**のが本便の検収の 1 本
- **Y1c が残した P1 2 件(本便で閉じる)** ──(a) **interactive Component の `update` が ★ の手書きのまま**(51 v5 §32 は「人は書かない」、置き場は `src/gen/live/<service>.gleam`)、(b) **`like_button` の `pub const calls` が空**で、島の通信は `like_button_ffi.mjs` の **FFI 直呼び**のまま(`calls` が Service を指し `src/gen/api.gleam` が path を持つ形が本便の仕事)
- **front-1 / Y1c が「未検証」に残した 5 件** ── Page / Layout の配置表からの描画、島の再訪問時の古い Model、1 Block に島が複数、断点ごとの非表示、WebSocket の push が `reloads` に無い(最後の 1 件は保留のまま、本便では閉じない)
- **§7-9(b) の yumemi の宿題 12 項は全部 back 側**(逆向き矢印 / 無診断 / allow 句消失 / **列名推論** / Actor の統一 / root の version と runtime の位置引数 / 札の素通り 8 本 / manifest の旧綴り / `'draft'` literal 依存 / relation 条件の語彙 / `ledger_store` 綴り / quota / theme の version)── **入力(`api/src/**`)も出力(`api/src/gen/**` と `api/db/`)も front と交わらない。本便の「しないこと」に置く**(裁定待ち 1 / 2 で 2 項だけ鷹野が裁く)
- **test の環境(musearch の api test を回すなら):**`MUSEARCH_TEST_PG_PORT=55476 MUSEARCH_TEST_APP_DB=musearchgen6 MUSEARCH_TEST_IDP_DB=idpgen6 MUSEARCH_TEST_PG_REUSE=1`。**既定 55439 は使わない**、他便の PG(B3 55471 / P1 55473 / P2 55474 / P3 55475 / P4 55477)を殺さない。**front の生成の検算に実 PG は要らない見込み**(要らなければ使わない)
- **並走:**P2 / P3 / P4(musearch の面)と P5b。**musearch とはリポが違うので file は 1 本も重ならない。**ただし**本便が読む musearch は P1 merge 直後の面 1 Page だけ**で、P2〜P4 の面は本便の視界に入らない(入れると基点が動く)── **P2〜P4 の面に生成器を当てるのは追随便**(58 §7-9(a))
- **`yumemi-front-1d` とは同じ file に当たる。**front-1d は `src/framework/front/live.gleam` の `State`(現物 3 欄 `args` / `last` / `waiting`)に島の選択肢と `reloads` の戻りの置き場を足す便で、**本便が吐く `src/gen/live/<service>.gleam` はその型に合わせて `State` を具体化する** ── **型が動いた後に吐くのが素直**(順序辺 `yumemi-front-1d → 本便` の候補、卓は鷹野)。逆順に走らせるなら本便は 0.6.0 の 3 欄の `State` に対して吐き、front-1d が出力形を直す巡を持つ

## どこまで

1. **面 package を読む道**(裁定待ち 3 の形で)── `entry.gleam` の `Http` 入口 1 本 = 面 1 つ = フォルダ 1 本 = package 1 本(56 の思想 1)から面を引き、`<面>/src` を `src/gen/` を除いて parse する。**入口の無いフォルダ、フォルダの無い `Http` 入口は exit 3 で止める**(56)
2. **reader の front 段** ── `layout.gleam` の `pub const <face>: Layout(…)`、`pages/**/page.gleam` の `pub const page: Page(…)`(フォルダの木 = URL、`arg_` の段がパス変数、literal の段の `_` は `-`、予約語の段は末尾 `_`)、`blocks/*.gleam` の `view(it: In)` と任意の `sample`、`components/*.gleam` の `calls` / `reloads` / `view(it: State)`、`style.gleam` の token
3. **emit の front 段 ── 51 §308 の 13 種のうち面に出るもの**:`src/gen/route.gleam`(Page 行だけ)、`src/gen/load/layout.gleam` と `load/<Page と同じ道>/page.gleam`(Layout の `Fixed` の source と各 `Widget` の `of` も含めて `APP` binding へ 1 つずつ **1 回だけ**投げ、Block ごとに射影。`Data` 型も)、`src/gen/blocks.gleam`、`src/gen/widgets.gleam`、**写し 3 束**(`out/<service>.gleam` / `service.gleam` / `api.gleam` ── **再輸出でなく型の写し**)、`src/gen/live/<service>.gleam`、`src/gen/shell.mjs`、`priv/static/_yumemi/client.mjs` + bundle、`priv/static/_yumemi/style.css` と SSR の `<style>`(**断点ごとの `grid-template-areas`、`pin` の貼り付けと重なり順と safe-area、その断点に居ない Block の非表示**)、`src/gen/skeleton/<block>.gleam`(初回だけ)、`build/blocks.html`
4. **Y1c の P1 2 件を閉じる** ──(a) `src/gen/live/<service>.gleam` に `Field` enum(Args の欄から)・`State` / `Event` の具体化・**`update`**・送信前検査(Args の各 Type の `Spec` から)を吐き、**fixture の `like_button.gleam` から手書きの `update` を消す**、(b) `like_button` の `pub const calls` が Service を指し、**`like_button_ffi.mjs` の FFI 直呼びを消す**(通信は生成された client が `api.gleam` の path で行う)
5. **検査**(型で止まらない分)── `attribute.class` / `attribute.style` / `element.element` の直呼び、lustre 内部 module の import、**島の中の島**、同じ断点に `Top` が 2 つ、Args に無いパス変数、**枠の名前を受けない読みを `Widget` に置く**(検査 2)、`sp:` を欠く Frame、Layout の入れ子。**落ちる符号は 20 の exit code 表のまま**(`stop`)
6. **手書き ▲ との突き合わせ** ── (a) **fixture の面**(`gen/fixtures/article/www/src/gen/` の手書き ▲ 4 本)を生成物で置き換え、**本文 diff 0**(ヘッダの sha 行だけ差が出る ── 手書き ▲ は sha を持たない、§340-2)、(b) **musearch の面**(P1 の ▲、`96fb8cc`(段 4 の merge 後、2026-09-22 05:00) の `www/src/gen/**`)に当てて**差の一覧**を出す(**musearch に書き込まない**、出力は `_out/` へ)。**差はゼロを目標にし、残ったら 1 本ずつ理由を報告に**
7. **報告** ── `docs/reports/gen-6.md`(51 §32 の型 14 対応表の「生成器 (gen-6) の置き場」列が現物になったこと、13 種のどれを出しどれを出していないか、musearch の面との差の一覧、front-1 / Y1c の未検証 5 件のうち閉じたもの)、`results.md` の `## DDL`(無し)と `## 鷹野宛`、**`## musearch 追随便への申し送り`**(P1〜P4 の手書き ▲ を生成物に差し替える手順と、差し替えで動く file の一覧)

## しないこと

**§7-9(b) の back 側の宿題 12 項**(逆向き矢印 / `with:` の無診断 / `nearest.sql` の allow 句消失 / **ER 外 module の列名推論(`ledger_store` → `ledger_store_id`)** / Actor の統一(`gen/allow` の生成)/ root の version と `runtime.mjs` の位置引数 / 札の素通り 8 本の診断 / manifest の旧綴り / `create_sql_input_placeholder_count` の `'draft'` literal 依存 / relation 条件の語彙 / quota / `update_muse_theme` の version / `update_<prop>_order` と `reorder_*` の競合)── **裁定待ち 1 / 2 で鷹野が裁いた 2 項を除き、1 項も触らない**。併せて:musearch への書き込み(読むだけ)、**P2 / P3 / P4 の面を入力にすること**(追随便)、musearch の手書き ▲ を生成物に差し替えること(追随便)、`emit/{verb,sql,reads,root,query,draft,phase,types,typing}.gleam` と back の生成物、DDL と migration、**Hex publish と版の変更**(鷹野)、PWA の生成物と `pwa` 欄、WebSocket の push を `reloads` に足すこと、fixture モードと 7 視点の後継、`main` への commit、push、`.claude/_core` `~/.codex` `~/.claude`

## 失敗例

- 面の生成物を `api/src/gen/**` に吐く、`src/gen/` 直下に 13 種以外を作る、**生成物に sha256 を付けない**(生成物は付ける ── 手書き ▲ との見分けが sha の有無)
- `route.gleam` に API の route 行を混ぜる(面の表は **Page 行だけ**、API の表は back)
- Page の URL を 4 段規則から出す(URL はフォルダの木)、`prefix` を Page に前置する
- 写し `out/<service>.gleam` を back の module の**再輸出**にする(import の連鎖で back 全部が面の bundle に入る)
- loader が「行数ぶん読みを引く」形を吐く(source は 1 つずつ 1 回だけ)、Page 単位の loader を back に生成する(一方向が崩れる)
- 島の `update` を吐かずに ★ に残す、`calls` を空のまま FFI 直呼びを温存する
- back の生成が 1 file でも動く、`gleam test` 86 を割る、musearch の基線(exit 4 = 5 本 / 警告 29 / 597 file)を動かす
- back 側の宿題を「ついでに」直す(裁定待ち 1 / 2 の外)
- 同 persona の同秒起動、`^session_id:` での終了判定、push

## 検収

- root `gleam build` **0**、`cd gen && gleam test` **86 以上**、`cd gen/fixtures/article/www && gleam build` **0**
- `gleam run -m yumemi_gen -- fixtures/article <out>` が **exit 0**、**back の 57 file が 1 本も動かない**(file 名と本文の diff 0)、front の生成物が **N file** 増える(内訳を種ごとに)
- **fixture の手書き ▲ 4 本と生成物の本文 diff 0**(差はヘッダの sha 行だけ)
- musearch `api/` + `www/`(`96fb8cc`(段 4 の merge 後、2026-09-22 05:00)、読むだけ)に当てて **exit 4 = 5 本 / 警告 29 / 597 file** が動かず、**面の生成物と P1 の手書き ▲ の差の一覧**が報告に在る
- `node gen/scripts/verify-front-ssr.mjs` と `verify-front-isolate.mjs` が **ALL PASS**、かつ **`update` と `calls` が生成物になった後も**島が Chromium で押せて表示が変わる(`❤ 1 → ❤ 13` 相当、ページ error 0)
- **`build/blocks.html`** が fixture の面で 1 枚出て、Block が全部並び `sample` の無い Block も既定値で描ける
- 検査の負例が 1 本ずつ落ちる(`attribute.class` 直呼び / 島の中の島 / 同断点の `Top` 2 つ / Args に無いパス変数 / 枠の名前を受けない読み)── **符号と 1 行の文言**を証跡に
- `docs/reports/gen-6.md` の path、`results.md` の `## DDL`(無し)・`## 鷹野宛`・`## musearch 追随便への申し送り`。終端は承認かエスカレーション

## 裁定待ち ── 起動前に鷹野が裁く

1. **ER 外 module の列名推論を gen-6 に載せるか(鷹野の指摘、B3 巡 1 で根因が確定)。**根因は 1 点 ── `gen/src/yumemi_gen/reader.gleam` の `property_column`(`:1216`)と FieldDef の組み立て(`:1099`)が **`RelProp` にだけ `<> "_id"` を効かせ、`ValueProp` は綴りをそのまま列名にする**ため、**ER 外 module(台帳 `ledger_store`)の id 型が relation と認識されず列名が `ledger_store` になる**(実列は `ledger_store_id`)。★ に列名を書く口は無い。F3 の `ledger_store` 綴り 7 本 + B3 の `create_course` + read 側(`store_onboard/existing_link.sql` ほか)が全部これ 1 点。**(a) 推奨 ── 本便に載せず、`yumemi-front-1d`(P5b の前提、framework の島の型の穴 2 つ、Hex 0.7.0)に載せる。**理由 3 つ:(i) **束が別** ── 直すのは `reader.gleam` の relation 判定と `emit/sql.gleam` の列名綴りで、本便が触る front の reader / emit を 1 行も通らない。1 便に 2 つの束を入れると柏木のゲートの射程が割れる、(ii) **直すと musearch の生成物が動く** ── 手書き札 8 本 + read 数本が生成に戻る(F3 の手書き 39 本のうち 7 本)ので **musearch 側に追随便が要り**、その追随便は `api/src/gen/**` と `db/queries/**` を書き換える ── **段 5 で走っている P2 / P3 / P4 の merge に当たる**。P5b 前提の Y 便に乗せれば、追随は P5b(`api/` を触る便)と同じ窓で裁ける、(iii) **本便はすでに大きい** ── 生成物 13 種のうち **10 種が新規**で、gen-4(巡 2 = 2:09)より束が多い(58 §2 の 3:00 / 5:00 / 8:00 はこの前提の数字)。**(b) 本便に載せる** ── Hex の publish が 1 回で済み、musearch の追随も 1 回にまとまるが、(i)(ii)(iii) を全部引き受ける。**(c) 独立の 3 本目の Y 便** ── 束は綺麗だが publish が 3 回になり、P2〜P4 の依存の窓(`>= 0.6.0 and < 0.7.0`)を跨いで版が 3 つ動く
2. **Actor の統一(`gen/allow` の生成)を gen-6 に載せるか。**09-21_07 が唯一「**gen-6 候補**」と名指しした項(生成 root の独自 `Actor` が `allow.Actor` と variant 名で衝突、★ 9 本)。**推奨 ── 載せない(裁定待ち 1 と同じ `yumemi-front-1d` へ)。**名指しは「front の生成便」でなく「次の生成器の便」の意味に読める。実体は back の root / allow の生成で、front とは束が別
3. **面の発見と出力先の契約。**`source.load` は `<app>/src` だけを歩き、CLI は `<app dir> <out dir>` の 2 引数。**(a) 推奨 ── CLI の契約は変えず、`<app dir>` の親を面の探索の根にする**(`entry.gleam` の `Http` 入口名 = 兄弟フォルダ名)。out_dir の下に **package の段**(`api/…` と `<面>/…`)を作る。既存の 86 test と `fixtures/article` の CLI 契約が動かない(Y1c 裁定 2 と同じ理由)。(b) 引数を `<repo root> <out dir>` に変える ── 56 の「生成器 1 つがリポ全体を読む」に素直だが、**86 test と musearch の呼び出し(`MUSEARCH_APP=<木>/api`)が全部動く**。(c) 面ごとに CLI を呼ぶ ── 写し 3 束が back の読み直しを要るので 2 度読みになる
4. **P4 の裁定待ち 2 が (a) に決まった場合、「生成物 14 種目」(back の静的資料を面へ写す束 ── 外部送信 6 件 / API v1 の本文)を本便に足すか。****推奨 ── 足す**(写し 3 束と同じ機構で、入力も出力も front 側。P4 が手書き ▲ で置いた道と名前をそのまま再現する)。足さないなら P4 の ▲ が生成器の外に残り、追随便で手当てが要る
5. **musearch の基線の警告 29 をこのままにするか。**基線 21 + **札の素通り 8 本**(`//// handwritten:` ヘッダが効いていない名も載る)。**推奨 ── このまま 29 を基線として使い、8 本の診断は裁定待ち 1 の Y 便へ。**本便で下げると「面を足しても musearch の数字が動かない」という検収の 1 本が使えなくなる

## 鷹野の裁定(2026-09-21 22:57)── 5 点とも How

1. **列名推論は本便に載せず Y1d の 2 束目**(BRIEF-yumemi-front-1d 裁定 4)。musearch の追随は F4
2. **Actor の統一は本便にも Y1d にも載せない。**★ 9 本の musearch 追随が付くので別便の候補(段 6 以降、§7-9(b) の山と一緒に切る)
3. **面の発見は CLI の契約を変えず `<app dir>` の親を探索の根に**、out_dir の下に package の段
4. **生成物 14 種目(back の静的資料の写し ── 外部送信 6 件 / API v1 本文)を足す**(P4 裁定 2)
5. **警告 29 はこのまま基線。**札 8 本の診断は Y1d で根因が消えれば減る
6. **前提に Y1d(0.7.0)を足す** ── `gen/live/<service>.gleam` は 4 欄の `State` と `after_send` を具体化する。順序辺 Y1d → Y2、P1 → Y2 は据え置き。実 PG は要らない見込みなので port は割り当てない(要れば 55476 の空きを確かめて使う)

## P1(`musearch-front-1`)の申し送り ── 鷹野が 2026-09-22 05:10 に埋めた穴(正本は musearch main `96fb8cc` の `docs/front-1/results.md`)

- **`## Y2(gen-6)への申し送り` が本便の仕様書。**手書き ▲ 15 file の道と名前の表(`www/src/gen/route.gleam` `PageRoute` / `routes`、`load/layout.gleam` `Data` / `load`、`load/muse/arg_handle/page.gleam` `Data` / `load` / `render` / `view` / `widget_views` / `by_kind_table` ほか、`blocks.gleam` `Block` 11 variant、`widgets.gleam` `WidgetKey`(`MuseTopMain`)、`media.gleam` `Variant`(`Thumb` / `W800` / `W1600`)/ `url` / `encode_segment`、`shell.mjs` `pageRoutes` / `pages` / `matchPage` / `readFromApp` / `pageTheme` ほか、写し 3 束 `api.gleam` `Method` / `Route` / `routes`、`service.gleam` `Service` 7 variant、`out/` 7 本の `Out` / `Row`)。**shell の fallback(route 表外を `env.SVELTE` へ元の Request のまま流す)も生成器が吐くべき形**(移行中だけ、SvelteKit を消す便で外す)
- `Frame` が断点の値を持たないので `@media 900px` と grid は P1 の手書き ▲ が定数で持つ ── gen-6 はここを 51 v5 の `sp:` / `pc:` から引く(P1 の残 P1 ③ / ⑥ `ByKind` を読む側が yumemi に無い、を本便で閉じる)
- 突き合わせの相手は musearch main **`96fb8cc`** の `www/src/gen/**`(段 5 で P2 / P3 が追記するので、突合の時点の sha を報告に書く)
- Y1d は閉じた(Hex 0.7.0、yumemi main 7fb52b2)── `gen/live/<service>.gleam` は 4 欄の `State` と `after_send`。柏木は実行経路 C(`claude-kashiwagi`、Opus xhigh)
