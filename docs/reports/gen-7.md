# gen-7 ── musearch の面を生成物で差し替えるために閉じる生成器の穴

## DDL

無し。`git diff --stat 0c59f35 -- db/ gen/fixtures/article/db/` は空。DB / migration / schema は変更していない。

## 鷹野宛

- **束 D の名指し例外は exit 3 × 1(www のみ)に訂正**。plan v2 は「musearch snapshot の3面に `shell.gleam` が無い」を前提にしていたが、実物では www にのみ無く、muses / console には存在した。yumemi-5 が www に `shell.gleam` を置くまで exit 3 が1本出るのは仕様。
- **3面とも本物の bundle という前報は誤り**。旧手順は生成された `src/gen` を一時 package に重ねず、入力側の古い `src/gen` を bundle に含めていた。巡9で生成物を重ね、`import-is-undefined` を esbuild の error にした。fixture は生成物由来の bundle が通る。snapshot `9c2b0bd` は生成物を使う runtime build で www / muses / console が各 exit 1 × 1となり、3面とも `client.mjs` を残さない。前報の byte 数は入力側を組んだ値で、生成物の bundle 成功を示さない。
- **client 由来 exit 1 の名指し例外は www 1 / muses 1 / console 1**。www は生成 `api.gleam` の `front.Target` が snapshot 面の依存する yumemi 0.7.0 に無いなどの型エラー。muses は生成 `unclaim_confirm.view(Nil)` が `In` を要求し、console は `session_switch.view(Nil)` が `In` を要求する。www の ★ component 5本は `view` のみで `app` が無いことも確認したが、今回は runtime build が先に止まり、esbuild の import 検査までは到達していない。これらの整合は追随便に渡す。
- **musearch で URL が動いたのは add 9 / edit 7 / remove 6**。BRIEF 見込みの10/7/6から add が1減った。`schedule_add` は既存の target ambiguity (exit 4)で前後とも route が無い。face 展開後は36/28/25。
- **registry との method/path 一致は47 → 53**。BRIEF の「採用済み290一致」は `c99c107` snapshot の値であり、基点 `9c2b0bd` とは直接比較できない。
- **Hex 0.8.0 の publish は鷹野**(承認後、yumemi-5 の前)。

## 追随便への申し送り

- **P1-G1-1: 束 B が yumemi-5 に強いる書き換え**。musearch snapshot の3面で Page 39・Layout 3・Frame 57・Fixed 69 の const 構築と `calls` 46本が書き換え対象。Gleam の record に欄の既定値がないため、新しい欄 `reads: []` / `cell: Flow` / `cols: []` / `rows: []` / `template: []` を明示する必要がある。
- **P1-G1-2: 14種目の付属入口表の源が生成物の中**(`api/src/gen/http_runtime.mjs:413`、GENERATED header)。back の世代を揃える便で、この源は消えるか移る。
- **P1-E-1: route registry 監査の固定値**。`gen/scripts/audit-route-registry.mjs` の非 system service 数87は snapshot `9c2b0bd` の103と合わない。snapshot で registry 監査を回す便で直す。
- **decoder 由来 exit 1 = 2** (`metrics_muse` / `metrics_store`: `entity/visit.Source` の複数 variant を判別不能)。束 A1 の「判別不能 union は停止する」検査が musearch 実物で2件発火した。基線では黙って先頭 variant に落として生成されており、BRIEF の障害そのものが表面化した。yumemi-5 で `visit.Source` に共通欄 `kind` を宣言するか、判別規則を決める。
- **`transport_ffi.mjs` の sha256 は入力不変でも一度動く**。hash 入力は `hash.entry <> string.inspect(front.components)`。束 B' の reader model 変更で inspect 文字列が変わったため。規約「入力が変われば hash が変わる」の逆向きが model 変更で一次的に崩れる点を注記する。
- **minify (gen-6 P1-6、`client.mjs` 181,827 B)は未着手**。申し送り列の最後尾。
- **per-element given (gen-6 P1-13)は Lustre 待ち**。
- gen-6 P1-4 (面 package の direct dependency sketch / `sketch_lustre` notice)は残る。yumemi-5 で面を差し替えるとき対応する。
- gen-6 P1-9 (`framework/page` を import する写し3 file)は残る。
- gen-6 P1-11 (穴を持たない名前付きクエリの P enum)は残る。

## 閉じた穴と残した穴

gen-6 P1 13件と本便の追加分をすべて分類した。**未分類は0件**。

| 項目 | 分類 | 根拠 / 行き先 |
|---|---|---|
| gen-6 P1-1 custom decoder の複数 variant | 閉 | 束 A1 |
| gen-6 P1-2 Block preview の Layout 欠落 | 閉 | 束 F / P1-2 |
| gen-6 P1-3 opaque decoder の placeholder assert | 閉 | 束 F / P1-3、`new_primitive_decoder` |
| gen-6 P1-4 面 package の direct dependency / `sketch_lustre` notice | 残 | yumemi-5 で面差し替え時 |
| gen-6 P1-5 `--bg-image` の `url()` 包み | 閉 | 束 F / P1-5 |
| gen-6 P1-6 `client.mjs` minify | 残 | 申し送り列の最後尾 |
| gen-6 P1-7 validate 文言 | 閉 | 束 F / P1-7、制約別文言 |
| gen-6 P1-8 `gleam format` | 閉 | 束 A3 |
| gen-6 P1-9 `framework/page` import の写し3 file | 残 | 追随便 |
| gen-6 P1-10 `widget_list` Summary | 閉 | 束 F / P1-10、logic から構成 |
| gen-6 P1-11 P enum | 残 | 追随便 |
| gen-6 P1-12 `fallbackClient` | 閉 | 束 A4 + 巡9。生成物を重ねて bundle し、未定義 import を error にして素の entry を削除。面別 exit 1 を記録。fixture で bundle 成功、snapshot 3面は追随待ち |
| gen-6 P1-13 per-element given | 残 | Lustre 待ち |
| 末尾カンマ | 閉 | 束 A2、glexer token 置換 |
| 動詞対応表 | 閉 | 束 E |
| grid | 閉 | 束 B + B' |
| `reads`・`Target`・0.8.0 | 閉 | 束 B。publish は鷹野 |
| 14種目 | 閉 | 束 C |
| `shell.gleam` | 閉 | 束 D + P1-G2-1。file 不在と、file 内の `lang` / `title` / `theme` または theme 欄の不足を Missing(3) |

## 基線と最終値

| 指標 | 基線(巡1、基点 `0c59f35`) | 巡9の実測 |
|---|---|---|
| root `gleam build` | exit 0、warning 1 (既存) | exit 0、warning 1 不変 |
| `cd gen && gleam test` | 128 passed | 159 passed、failures なし |
| fixture 生成 | exit 0 / 86 file | exit 0 / 88 file (`external.gleam`・`doc/api_v1.gleam` が追加) |
| snapshot 生成 | exit 4 = 21行 / warning 30 / 1175 file / exit 2 = 0 / exit 3 = 0 | exit 4 = 20行 / warning 29 / 1181 file を生成・失敗後の実体1178 file / exit 2 = 0 / exit 3 = 1 (www shell) / exit 1 = 5 (metrics 2 + client 3) |
| fixture face build / SSR / isolate / given / Block preview | exit 0 / ALL PASS | exit 0 / ALL PASS (isolate 2228 不変) |
| sha256 header | 欠け0 | 欠け0 |
| 生成物 `gleam format --check` | 未適用 | 0 |

## musearch snapshot 再走

- 巡9の最終値: exit 2 = 0 / exit 3 = 1 (www shell) / exit 4 = 20行 / exit 1 = 5 (decoder 2、client の www / muses / console 各1) / warning 29。生成器は1181 file と報告し、失敗した3面の素の `client.mjs` を消した後の実体は1178 file。run_dir 内の `out-gen7-g2-f` と `out-gen7-g2-g` の再走 diff は空。
- 診断集合の推移: exit 4 は21 → 20 (束 B' で reader が `Entry` を読めるようになり `未知の Service variant: Entry` の誤診断が消えた)。warning は30 → 29 (束 D で shell 既定値 warning が消えた)。exit 3 × 1 は束 D の名指し例外。exit 1 は既存の decoder 2件に、生成物の runtime build で表面化した client 3件が加わった。各面の診断は `_diagnostics.txt` と stderr に別行で残る。

## 51 v5 追記文

> `Frame` に `cols: List(Track)`、`rows: List(Track)`、`template: List(List(String))` を追加する。空の `cols` は framework の `default_sp_cols` = `[Fr(1)]`(SP)/ `default_wide_cols` = `[Fr(1), Minmax(min: RemSize(12.0), max: RemSize(20.0))]`(PC / Tablet)に解決する。ただし生成器が空の `cols` に吐く CSS は旧 runtime と同じ `minmax(0, 1fr)`(SP)/ `minmax(0, 1fr) minmax(12rem, 20rem)`(PC / Tablet)で、先頭 track は `1fr` ではない(`Fr(1)` を明示すると `1fr` を吐く)。空の `rows` は自動行、空の `template` は SP で area ごとの行積み、PC / Tablet で SP の area 配置を基に追加 area を右列へ置く。`Track`(`framework/front/track`)は `Fr(Int) | Rem(Float) | Px(Float) | Minmax(min: TrackSize, max: TrackSize)`、`TrackSize` は `FrSize(Int) | RemSize(Float) | PxSize(Float)`。`Cell` は `Flow | Span(cols: Int, rows: Int) | At(col: Int, row: Int, span: CellSpan)`、`CellSpan` は `CellSpan(cols: Int, rows: Int)`。`Fixed` は `cell: Cell` を持ち、流し込みは `Flow` を明示する。`Span` は wrapper に `grid-column: span <cols>; grid-row: span <rows>`、`At` は `grid-column: <col> / <col + cols>; grid-row: <row> / <row + rows>` を吐く。既存の `Grid(cols: Int, gap)` を維持し、`GridTracks(cols: List(Track), gap)` を追加する。`Page` と `Layout` に `reads: List(service)` を足し、`Target(service, attached)` = `Of(service) | Entry(attached)` を `framework/front` に置く。

## 動詞と method/path の対応

| 動詞 | 変更前 | 変更後 |
|---|---|---|
| create | POST `/<plural>` | POST `/<plural>` |
| read | GET `/<plural>/:id` | GET `/<plural>/:id` |
| list | GET `/<plural>` | GET `/<plural>` |
| delete | DELETE `/<plural>/:id` | DELETE `/<plural>/:id` |
| put | PUT `/<plural>/:id` | PUT `/<plural>/:id` |
| add | POST `/<plural>/add` or `/<plural>/:id/add` when a key matches | POST `/<plural>` |
| edit | POST `/<plural>/:id/edit` | PUT `/<plural>/:id` |
| remove | POST `/<plural>/:id/remove` | DELETE `/<plural>/:id` |

変更前の add は key 引数がある場合に `/:id` を含み、無ければ collection に `/add` が付いた。変更後は key 引数を path に載せない。edit は key 引数の無い `setting_edit` で `PUT /api/muse_settings` になった。`schedule_add` は既存の target ambiguity で前後とも route が無い。snapshot route は390件で不変、add / edit / remove の URL 変更は service 単位で9/7/6、face 展開後で36/28/25。`roster_remove` は `/api/v1/store/...` の別 prefix を持つため、unique method/path template の remove は7件。新設した重なり検査は同一 face 内の method と path 形の衝突を exit 4 にし、`{id}` と `{slug}` も同じ path 形として扱う。

registry method/path の直接一致は47 → 53。BRIEF にある「採用済み一致」290は `c99c107` snapshot の値であり、今回の入力 `9c2b0bd` と直接比較できない。route registry checker は非 system service 数87を固定しているが、このsnapshotは103のため同checkerでは再計測できない。

## 検証

- `git diff --stat 0c59f35 -- db/ gen/fixtures/article/db/`: 空。
- `cd gen && gleam test`: 159 passed、failures なし。`gen/build/gen7-g2-test-final.txt`。
- fixture は88 fileを2回生成し、出力間および tracked `public/src/gen` / `priv`・untracked `src/gen` / `db` との差分は空。面 build は exit 0 / warning 0。SSR / isolate / given / Block preview は全 PASS。
- snapshot は run_dir の入力を読み、同 run_dir 内の出力へ2回生成した。診断内の一時パスを固定表記にし、`diff -rq` は空。`gen/build/gen7-g2-snapshot-f.txt`、`gen/build/gen7-g2-snapshot-g.txt`、`gen/build/gen7-g2-snapshot-final-diff.txt`。
- 生成物の `gleam format --check` は fixture 52 file、snapshot 816 file で exit 0。生成ファイルの sha256 先頭ヘッダ欠けは fixture / snapshot とも0。
- 最終 untracked: `gen/fixtures/article/db/` と `gen/fixtures/article/src/gen/` の2本。commit 対象外。
