# gen-1 ── 生成器 第1便の検収(真壁[IM]、2026-09-16)

発注は `tech/_drafts/gleam-framework/41-brief-gen-1.md`。仕様の正典は同ディレクトリの
`20-programming-model.md` と `40-generator-readiness.v0.md`。

## 現在地

生成器は `gen/`(package `yumemi_gen`、target javascript、`glance = "7.0.0"` 固定、
IO は simplifile)。起動は `gleam run -m yumemi_gen -- <app dir> <out dir>`。

出す ▲ は4束だけ ── `src/gen/types/*.gleam`、`src/gen/query.gleam`、`src/gen/reads/*.gleam`、
`gen/sql/queries/<service>/<name>.sql`(読みの SELECT)。`verb` / `root` / `entry` / migration /
`schema.lock.json` / openapi / mcp / er.mmd は出さない(40 の穴 1〜3)。

入力は `src/gen/` を除く `src/**/*.gleam` だけ。第1段で全ファイルを glance にかけ、
1つでも parse に失敗したら止まる。MuseArch の ★ は 84 ファイルすべて parse できた。

検収は3つ。

| 何 | どう | 結果 |
|---|---|---|
| リポ内 fixture | `gen/fixtures/article/`(20 の Article アプリ ★ 11 本を本文から機械的に写したもの)で `gleam test` | **18 passed, no failures** |
| 束ごとの diff | `python3 gen/scripts/compare.py gen/_out/musearch <musearch>/app` | 下表 |
| 実物での型検算 | `gen/scripts/probe-compile.sh` ── アプリを複製して4束だけ生成物に差し替え `gleam build` | 基準 0 error → 差し替え後 5 error → 既知2件を外して 17 error |

MuseArch のワークツリーは読むだけで、1バイトも書いていない。出力は `gen/_out/`(`.gitignore`)。
`gleam format` の折り返しは生成器が再現できないので、比べる前に出力へ `gleam format` をかけた。

再現手順。

```
cd gen
gleam test
gleam run -m yumemi_gen -- ~/yumemism_repo/musearch/app _out/musearch
gleam format _out/musearch/src/gen
cd .. && python3 gen/scripts/compare.py gen/_out/musearch ~/yumemism_repo/musearch/app
gen/scripts/probe-compile.sh ~/yumemism_repo/musearch/app gen/_out/musearch /tmp/probe
```

## 束ごとの数字

判定は2段 ── **完全一致**(バイト)と**本文一致**(先頭の `GENERATED` 行を外し、空白の詰め方を無視)。

| 束 | 両側にある | 完全一致 | 本文一致 | 不一致 | 生成器だけ | 手書きだけ |
|---|---|---|---|---|---|---|
| 1 `src/gen/types/*.gleam` | 61 | **57** | 0 | 4 | 0 | 0 |
| 2 `src/gen/query.gleam` | 1 | 0 | 0 | 1 | 0 | 0 |
| 3 `src/gen/reads/*.gleam` | 22 | 7 | 9 | 6 | 1 | 2 |
| 4 `gen/sql/queries/<service>/<name>.sql` | 29 | 0 | **14** | 15 | 9 | 2 |

束4 の完全一致が 0 なのは、**手書きの SQL 29 本すべてに `-- GENERATED` の1行が無い**から
(20:845 規約 ①)。1行目を外すと 14/29 が本文一致。束4 の射程は名前付きクエリ値の読みだけで、
`root.sql`(38 本)・`allow/`(11 本)・`framework/`(15 本)・`verb/`(44 本)は数えていない。

**束1 は 61/61 が「生成した行は全部 ▲ に在る」。**不一致の4本は ▲ 側の追記だけで、
生成した行が消えているものは1つも無い(`body` +9 行、`chunk_text` +14、`profile` +4、`query` +6)。

**束2 は手書きだけの行が 0。**生成した `query.gleam`(400 行)は手書き(277 行)の厳密な上位集合で、
差は生成器が余分に出した 122 行。型ごとの variant は次のとおり。

| 型 | 生成 | 手書き | 両方 | 生成だけ | 手書きだけ |
|---|---|---|---|---|---|
| From | 23 | 19 | 19 | 4 | 0 |
| Field | 197 | 133 | 133 | 64 | 0 |
| Arrow | 23 | 3 | 3 | 20 | 0 |
| Operand | 34 | 11 | 11 | 23 | 0 |
| Cond | 15 | 15 | 15 | 0 | 0 |
| Agg / CondAgg / Unit / Group / Order / Along / Limit / Select | 5 / 5 / 3 / 3 / 5 / 3 / 4 / 12 | 同じ | 全部 | 0 | 0 |

生成器は 20 の規則どおり「Entity 1つに From 1つ、Property 1つに列1つ、関係1つに矢印1つ、
Entity 1つに `KeyOf` 1つ」を全数出す。手書きは実際に使う所まで枝刈りしてある ── これが差の全部。
語彙の固定部分(Cond 以下の 9 型)は 1 variant も違わない。

**実物での型検算**は原因が5つに割れた。

| 段 | error | 原因 |
|---|---|---|
| 基準(手書きの ▲) | 0 | ─ |
| 4束を差し替え | 5 | ① `gen/query.gleam` の名前の衝突 1、② ★ が呼ぶ `body.blobs` / `chunk_text.split` が生成物に無い 4 |
| ①② を外して再度 | 17(16 箇所) | ③ `Max(<Order 型の列>)` の戻り 6(heaven_link / space_add / widget_add 各 2)、④ key 列と比べる穴の型 3(widget_add 2 / widget_list 1)、⑤ 手書きレコード `reads.Near` 7(article_search) |

③④⑤ はいずれも下の残差表の該当行と同じもので、新しい原因は出ていない。

## 残差の表

1件ずつ「生成器の不足」か「手書きの逸脱(★ に無い判断)」かに分ける。手書き側は直していない。

### 手書きの逸脱 ── ★ を読んでも出てこない判断

| # | 束 | 何 | 件数 |
|---|---|---|---|
| D1 | 1 | `gen/types` に ★ から導けない関数の追記(`body.blobs` / `chunk_text.split` / `profile.empty` / `query.to_chunk_text`、計 33 行)。★ が `body.blobs` と `chunk_text.split` を呼ぶので**外すと ★ が落ちる**(検算 ②) | 4 本 |
| D2 | 2 | 語彙を使用箇所まで枝刈り(From −4 / Field −64 / Arrow −20 / Operand −23)。20 は「Entity の数だけ variant が増える」 | 111 variant |
| D3 | 3 | `Max(<Order 型の列>)` の戻りを `Option(Int)` にした。20:771 は「Sum / Min / Max の型は対象 Property の Type をそのまま引き継ぐ」で `Option(Order)`。同じ形の `link_import_apply.top_tail` は `Option(Order)` ── **▲ の中で綴りが2つ** | 3 本 |
| D4 | 3 | `Eq(<Entity の key 列>, Param)` の穴を `Key(<Entity>)` で受けた(widget_list.space_visible / widget_add.space_owned / heaven_linked)。同じ形を生値で受けた ★ もある(pageview_record 3 本 / store_onboard)── **★ の中で綴りが2つ。未決 1** | 3 本 |
| D5 | 3 | `reads/article_search` に手書きレコード `Near` を置き、`from` の Chunk を行から落とした。クエリ値からは `List(#(Chunk, Article, Phase, Muse, Phase, Float))` | 1 本 |
| D6 | 3 | `GENERATED from` の綴りが不統一(`service.<svc> reads` / `.inbox/unread` / 単一 const でも名を落とす) | 7 本 |
| D7 | 3 | `reads/metrics_muse` に対応する `pub const <q>: q.Select(P)` が ★ に無い(戻りが app 側の `metrics.Metrics`) | 1 本 |
| D8 | 4 | 別名の付け方が不統一。`article_pin/slot_taken` は別名なし、`article_list/published` は別名と無印が混在 | 2 本 |
| D9 | 4 | uuid の穴に `::uuid` を付けた所と付けない所(`link_list` / `link_reorder` / `article_list_mine` / `article_pin` / `link_import_apply` は無印、`widget_*` / `space_*` は付く) | 6 本 |
| D10 | 4 | ★ が `join: []` なのに JOIN と `to_jsonb(...) AS <prop>` を足した(`heaven_link/by_shop`、`pageview_record/active_stores`)。**reads の戻りの型にも現れていない**ので ▲ の中で SQL と Gleam が食い違う | 2 本 |
| D11 | 4 | 名前付きクエリの SQL に allow の注入(`jsonb_array_elements($2::jsonb)`)を足した。allow の注入は root の読みの仕事 | 1 本(article_search/nearest) |
| D12 | 4 | 宣言した `order` を落とした(`muse_by_handle` / `store_by_handle` は `Asc(Handle)` を捨てて id だけ)。逆に `order: []` に `since ASC` を足した(`notification_fanout/subscribers`) | 3 本 |
| D13 | 4 | Option 列の ASC に `NULLS LAST` が無い(`article_release/due`)。同じ形の `article_list/published` には在る | 1 本 |
| D14 | 4 | `consent_give/current` が `<alias>.*` でなく列を並べた | 1 本 |
| D15 | 4 | `-- GENERATED` の1行が無い(規約 ①) | 29 本 |

### 生成器の不足

| # | 束 | 何 | 件数 |
|---|---|---|---|
| G1 | 4 | **向きの混じった `order` の keyset を組めない。**`article_list/published` は `slot ASC, posted_on DESC, entered_published DESC` で行比較が成立しないので、SQL を出さずに `_diagnostics.txt` へ落とした。▲ は `COALESCE` + `IS NOT DISTINCT FROM` で組んでいる | 1 本 |
| G2 | 3 | **root 相対の矢印の read を出せない。**root Entity の決め方が ★ に無い(40 の穴 2)。`reads/article_read` が丸ごと欠ける | 1 本 |
| G3 | 3・4 | **複合 key を1列として扱う。**Chunk の key は `#(article, version, seq)` だが先頭だけを key 列として使うので、tie-break と keyset の列が足りない | 1 本(article_search) |
| G4 | 2 | **From と Field の名前の衝突を解消しない。**構成子は module ごとに1つの名前空間なので、Entity `consent_version` の From と Entity Consent の `version` 列が `ConsentVersion` で衝突する。検出して報告するだけ(20 に規則が無い ── 未決 7) | 1 件 |
| G5 | 4 | `with` / `along`(Rank / Running)/ `Has` / `HasNone` / `FirstPerGroup` / `At` / `KeyOf` 固定値の SQL が未実装。MuseArch では未使用なので今回の数字には効いていない | 0 本 |
| G6 | 全 | `gleam format` の折り返しを自分で出せない。検収は出力に `gleam format` をかけてから比べた。`app gen` が整形まで持つべき(後の便) | ─ |

## 未決

**1. Entity の key 列と比べる穴の型 ── `Key(<Entity>)` か生値か。**★ の中で両方が使われている。
`widget_list` / `widget_add` は `key.free_space(...)` で `Key(FreeSpace)` を渡し、
`pageview_record` / `store_onboard` は `FreeSpaceId` / `ArticleId` / `Handle` を生で渡す。
どちらへ寄せても片方の ★ が落ちる(検算 ④ が実際に落ちた)。本便は生値で出した
(20:576「`key` 引数の型は、その Entity が `key` 関数で宣言した Type そのもの」の読み)。
**水無瀬さん(鷹野さん)に確認が必要。**

**2. `gen/types` の追加関数。**`body.blobs` と `chunk_text.split` は ★ が呼ぶので、
Spec から導く規則を作るか、`gen/` の外(手書きの module)へ移すかのどちらかが要る。
`profile.empty` と `query.to_chunk_text` は ★ からは呼ばれていない。

**3. `framework/query.gleam` に `IsTrue(field)` と `EqOrNull(field, operand)` を足した。**
★ が使うが既存の綴りで代替できない ── 真偽の列を比べる `Operand` の構成子が無く、
`Eq` は穴が NULL のとき当たらない。20:696「同じ結果に2つの綴りがあると Agent が選ぶ」には
抵触しないと読んだが、**語彙はフレームワークの所有物なので裁定が要る。**
手書きの `gen/query.gleam` はこの2つを自分で足していた(アプリが語彙を足した形 ── 20:664 に反する)。

**4. 20 の Field 一覧に to-one 関係の列と PartyId の列が無い。**20:675 の Article の例は
`ArticleSlug` / `ArticleTitle` / `ArticleBody` / `ArticlePhase` / `ArticleEntered*` /
`CategoryName` / `TagName` / `StaffName` / `StaffEmail` だけで、`ArticleCategory` と `StaffParty` が無い。
**無いと ★ の where が書けない** ── MuseArch の 39 クエリのうち **30** が関係列を使う。
本便は「to-one 関係は列、to-many は中間表なので列にしない」で出した。20 本文の訂正が要る。

**5. Lifecycle を持つ Entity の行の型。**20:763 の表は `Page(<from の Entity>)`、
手書き ▲ と本便は `Page(#(Entity, Phase))`(相は Property でなくフェーズ列なので行に添う)。20 本文の訂正が要る。

**6. 20 に規定が無くて本便が決めた3つ。**`First(1)` の戻りは `Option(R)`(`First(n>1)` は `List(R)`)、
`Max` / `Min` / `Sum` / `Avg` の戻りは `Option(...)`(空集合は NULL)、`Count` は `Int`。
どれも手書き ▲ と一致している。

**7. From と Field の名前空間の衝突(G4)。**器を割る(`gen/query/from.gleam`)か、
Field の綴りを変えるか。放っておくと Entity の増え方次第でアプリが突然ビルドできなくなる。

**8. fixture の置き場。**発注書は `gen/test/fixtures/article/` を指しているが、
Gleam は `test/` 配下の `.gleam` を全部コンパイルするので ★ をそこに置けない。
`gen/fixtures/article/` にした。
