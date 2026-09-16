# gen-2 ── 生成器 第2便の検収(真壁[IM]、2026-09-16)

発注は `tech/_drafts/gleam-framework/42-brief-gen-2.md`。仕様の正典は同ディレクトリの
`20-programming-model.md`(2026-09-16 の改訂 8 箇所)。前便は `gen-1.md`、その赤は
`gen-1-review.md`(条件付き承認、critical 0、P2 5 件)。

**新しい束は出していない。**4束(`src/gen/types/*`、`src/gen/query*`、`src/gen/reads/*`、
`gen/sql/queries/<service>/<name>.sql`)の外へは1ファイルも出ていない。
MuseArch のワークツリーは読むだけで、3段の検収の後も `git status --porcelain` は空。

## 現在地

branch `gen-2`(main `cc6d12a` から)。commit 4 本、全部 author=committer=真壁。

| 何 | どう | 結果 |
|---|---|---|
| リポ内 fixture | `gen/fixtures/article/`(20 の Article アプリ ★ 11 本)+ `gen/fixtures/flag/`(本便で追加)で `gleam test` | **33 passed, no failures**(gen-1 は 18) |
| 束ごとの diff | `python3 gen/scripts/compare.py gen/_out/musearch <musearch>/app` | 下表 |
| 実物での型検算 | `gen/scripts/probe-compile.sh` ── 複製へ4束を差し替えて `gleam build` | 0 → 162 → 22 → **17** |

再現手順。**`app gen` は musearch で exit 1 を返す**(下記 P2-2)ので、続けて走らせるときは
`|| true` を挟む。

```
cd gen
gleam test
gleam run -m yumemi_gen -- ~/yumemism_repo/musearch/app _out/musearch || true
gleam format _out/musearch/src/gen
cd .. && python3 gen/scripts/compare.py gen/_out/musearch ~/yumemism_repo/musearch/app
gen/scripts/probe-compile.sh ~/yumemism_repo/musearch/app gen/_out/musearch /tmp/probe
```

## P2 5 件の処置

| # | 柏木の条件 | 処置 | 現物 |
|---|---|---|---|
| 1 | 束4 の「生成器だけ 9 本」と束3 の `reads/article_release` が残差表に無い(D 側へ 10 件) | 足した ── **D16(1 本)と D17(9 本)**。どちらも「★ が宣言したのに ▲ に無い」手書き側の欠落 | 本報告「残差の表」 |
| 2 | 出力が不整合でも exit 0 | **非 0 で終わる。**止まる理由を 20 の exit code 表で分類する `stop.gleam` を置き、stderr と `_diagnostics.txt` に同じ1行を出す。musearch は **exit 1**。parse 失敗は 2、宣言の不足は 3、矛盾は 4。理由が複数なら人へ上げる側(6 → 5 → 4 → 3 → 2 → 1)を返す | `gen/src/yumemi_gen/stop.gleam`、`yumemi_gen.gleam` |
| 3 | スキーマ名 `app` が生成器に焼かれている | **framework の定数へ移した。**`src/framework/schema.gleam` の `pub const app` 1箇所が出所で、生成器は path 依存でそれを読む。出力は1バイトも変わらない(musearch 124 ファイルで diff 無しを確認して commit) | `src/framework/schema.gleam`、`emit/sql.gleam` |
| 4 | 20 に無かった決め2つは「決め」から外す、D4 は未決側へ | 外した。`order: []` の既定と `NULLS LAST` は 20:838 に入ったので**規定の実装**として fixture で当てる側に移り、D4 は「手書きの逸脱」から**未決**へ移した(下記) | 本報告「残差の表」「未決」 |
| 5 | 規約①の入力ハッシュが header に無い | 4束すべての header に `[sha256:<12 桁>]`。どの入力がその束を決めるかを表で固定した | `gen/src/yumemi_gen/emit/hash.gleam` |

**入力ハッシュの帰結が1つある ── 完全一致(バイト)は全束で 0 に落ちる。**手書き ▲ の header に
ハッシュが無いので、これは避けられない。**一致は本文一致で見る**(束1 は 57 が完全一致から
本文一致へ移っただけで、合計は 57 のまま)。

| 束 | 入力 |
|---|---|
| 1 `src/gen/types/*` | `src/types.gleam` |
| 2 `src/gen/query*` | `src/entity/*.gleam` 全部 |
| 3 `src/gen/reads/<svc>` | その Service + `src/types.gleam` + `src/entity/*.gleam` 全部 |
| 4 `gen/sql/queries/<svc>/*` | 束3 と同じ |

## 裁定 4 点の反映

**(1) `Cond` の `IsTrue` / `EqOrNull`** ── runtime は gen-1 で入っている。本便は**生成器が
この2つを SQL にできることを fixture で当てた**(`fixtures/flag`)。
`w.visible IS TRUE` と `w.place IS NOT DISTINCT FROM $1`、穴は `EqOrNull` の側だけ1つ
(`IsTrue` は穴を取らないので `$2` は出ない)。read 関数の穴は `Option(WidgetPlace)`。

**(2) key 列と比べる穴は生値** ── gen-1 の出力が既にこの形(20:576 の読みどおり)。変更なし。
★ の側が `key.free_space(...)` を通している 3 本は musearch の便で直る(検算 ④ として残る)。

**(3) Field / 行の型 / agg の型** ── **gen-1 の出力が既に 20 の改訂版と一致している。**
本便で変えたものは無く、fixture で当てる側に回した。7 規則すべて突き合わせた結果:
to-one 関係と PartyId は列(`ArticleCategory` / `StaffParty`)、to-many は列にしない、
Lifecycle 持ちの行は `#(Entity, Phase)`、`First(1)` は `Option(<行の型>)`、`Count` は `Int`、
`Sum` / `Min` / `Max` / `Avg` は `Option(<Property の Type>)`、`gen/types` に人の関数は足さない。
`with` だけ未実装のまま(残差 G5、MuseArch では未使用)。

**(4) From と Field は別 module** ── 束2 を 3 module に割った。

```
src/gen/query/from.gleam    pub type From { … }          28 行
src/gen/query/field.gleam   pub type Field { … }        202 行
src/gen/query.gleam         残りの語彙 + 型別名          184 行
```

`query.gleam` は `pub type From = from.From` / `pub type Field = field.Field` を持つので、
型注釈(`q.Select(P)`)と語彙の残り(`q.Eq` / `q.Param` / `q.Asc` / `q.NoLimit` …)の綴りは変わらない。
**G4(`ConsentVersion` の `Duplicate definition`)はこれで閉じた** ── probe の段1 に出なくなった。

**ただし構成子の綴りだけは変えずに済まない。**Gleam は構成子を再輸出できないので、
`import gen/query as q` のままでは `q.Article`(From)と `q.ArticleSlug`(Field)が引けない。
上書き用の module 別名も使えない ── `import gen/query/from as From` は
`I'm expecting a lowercase name here` で syntax error(実測)。だから
**★ の側の1度の書き換えが必ず要る**。本便はそれが機械で済むことを道具で示した
(`gen/scripts/requalify.py`、`q.X` → `from.X` / `field.X`)── musearch の 23 ファイルが
自動で通る。**綴りをどうするかは未決**(下記 未決 1)。musearch には書いていない
(道具は `/tmp` の複製にだけ当てる)。

## 束ごとの数字(gen-1 → gen-2)

判定は2段 ── **完全一致**(バイト)と**本文一致**(先頭の `GENERATED` 行を外し、空白の詰め方を無視)。

| 束 | 両側にある | 完全一致 | 本文一致 | 一致の合計 | 不一致 | 生成器だけ | 手書きだけ |
|---|---|---|---|---|---|---|---|
| 1 `src/gen/types/*.gleam` | 61 → 61 | 57 → **0** | 0 → **57** | 57 → 57 | 4 → 4 | 0 → 0 | 0 → 0 |
| 3 `src/gen/reads/*.gleam` | 22 → 22 | 7 → **0** | 9 → **16** | 16 → 16 | 6 → 6 | 1 → 1 | 2 → 2 |
| 4 `gen/sql/queries/…` | 29 → 29 | 0 → 0 | 14 → 14 | 14 → 14 | 15 → 15 | 9 → 9 | 2 → 2 |

増減の理由を1行ずつ。

- **束1 完全一致 57 → 0、本文一致 0 → 57** ── header に入力ハッシュが入った(P2-5)。中身は1文字も動いていない
- **束1 不一致 4、生成器だけ 0、手書きだけ 0** ── 変化なし(D1 の 4 本がそのまま残差)
- **束3 完全一致 7 → 0、本文一致 9 → 16** ── 同じ理由。合計 16 は変わらず、不一致の 6 本も同じ顔ぶれ
- **束4 は全数字が同じ** ── 手書き SQL 29 本に元から `-- GENERATED` 行が無いので(D15)、ハッシュを足しても完全一致 0 のまま動かない
- **どの束も「生成器だけ / 手書きだけ」が増えていない** ── 4束の外へ出ていないことの数字での裏

束2(1 module 対 3 module)。

| | gen-1 | gen-2 |
|---|---|---|
| 生成 | 400 行(1 module) | **414 行**(184 + 28 + 202、3 module) |
| 手書き | 277 行(1 module) | 277 行(1 module) |
| 手書きだけの行 | 0 | **1** |
| 生成だけの行 | 122 | **133** |

**増えた 11 行は全部「module が割れた分」で、語彙は1 variant も増減していない。**
内訳は header 3 本(1 → 3 module、各行にハッシュ)、`import gen/query/field` と
`import gen/query/from`、型別名と doc 6 行。**手書きだけの行 1 は旧 header そのもの**
(ハッシュが付いたので一致しない)。variant の表は gen-1 と1桁も違わない。

| 型 | 生成 | 手書き | 両方 | 生成だけ | 手書きだけ |
|---|---|---|---|---|---|
| From | 23 | 19 | 19 | 4 | 0 |
| Field | 197 | 133 | 133 | 64 | 0 |
| Arrow | 23 | 3 | 3 | 20 | 0 |
| Operand | 34 | 11 | 11 | 23 | 0 |
| Cond | 15 | 15 | 15 | 0 | 0 |
| Agg / CondAgg / Unit / Group / Order / Along / Limit / Select | 5 / 5 / 3 / 3 / 5 / 3 / 4 / 12 | 同じ | 全部 | 0 | 0 |

出力ファイル数は 124 → **126**(`query/from.gleam` と `query/field.gleam` の2本)。
`_diagnostics.txt` は 1 行 + 停止コードの 1 行。

## 実物での型検算

| 段 | gen-1 | gen-2 | 何 |
|---|---|---|---|
| 基準(手書きの ▲) | 0 | **0** | ─ |
| 段1 4束を差し替え | 5 | **162** | module 分割で ★ の `q.<From / Field>` が引けなくなった分が全部出る |
| 段2 ★ の綴りを機械で付け替え | ─ | **22** | `requalify.py` で 23 ファイル(From 23 / Field 196)。**162 − 22 = 140 が分割の代償で、1度の機械置換で消える** |
| 段3 既知の1件を外した残り | 17(16 箇所) | **17(16 箇所)** | gen-1 と同一。行番号だけ +2(付け替えが import 2 行を足すため) |

**段3 の 17 は gen-1 と同じ error・同じ箇所** ── ③ `Max(<Order 型の列>)` の戻り 6
(heaven_link / space_add / widget_add 各 2)、④ key 列と比べる穴の型 3(widget_add 2 / widget_list 1)、
⑤ 手書きレコード `reads.Near` 7(article_search)。16 箇所で error 17。新しい原因は出ていない。**gen-1 の ①(`Duplicate definition`)は消えた**(裁定 4 で閉じた)。

**gen-1 の②の実数は 4 でなく 5 だった。**`Duplicate definition` が `article_search` の検査を
止めていたので隠れていた ── ★ が呼ぶ `gen/types` の手書き関数は `body.blobs`(3 箇所)、
`chunk_text.split`(1)、**`query.to_chunk_text`(1)** の 3 関数 5 箇所で、
呼ばれていないのは `profile.empty` だけ。D1 の記述をこれで直す。

## 残差の表

1件ずつ「生成器の不足」か「手書きの逸脱(★ に無い判断)」かに分ける。手書き側は直していない。

### 手書きの逸脱 ── ★ を読んでも出てこない判断

| # | 束 | 何 | 件数 |
|---|---|---|---|
| D1 | 1 | `gen/types` に ★ から導けない関数の追記(`body.blobs` / `chunk_text.split` / `query.to_chunk_text` / `profile.empty`、計 33 行)。**前3つは ★ が 5 箇所から呼ぶので外すと ★ が落ちる**(検算の段2)。20:836 は「`gen/` の外の手書き module へ置く」── musearch の便 | 4 本 |
| D2 | 2 | 語彙を使用箇所まで枝刈り(From −4 / Field −64 / Arrow −20 / Operand −23)。20 は「Entity の数だけ variant が増える」 | 111 variant |
| D3 | 3 | `Max(<Order 型の列>)` の戻りを `Option(Int)` にした。20:771 は対象 Property の Type をそのまま引き継ぐので `Option(Order)`。同じ形の `link_import_apply.top_tail` は `Option(Order)` ── ▲ の中で綴りが2つ | 3 本 |
| D5 | 3 | `reads/article_search` に手書きレコード `Near` を置き、`from` の Chunk を行から落とした | 1 本 |
| D6 | 3 | `GENERATED from` の綴りが不統一(`service.<svc> reads` / `.inbox/unread` / 単一 const でも名を落とす) | 7 本 |
| D7 | 3 | `reads/metrics_muse` に対応する `pub const <q>: q.Select(P)` が ★ に無い(戻りが app 側の `metrics.Metrics`) | 1 本 |
| D8 | 4 | 別名の付け方が不統一(`article_pin/slot_taken` は別名なし、`article_list/published` は混在) | 2 本 |
| D9 | 4 | uuid の穴に `::uuid` を付けた所と付けない所 | 6 本 |
| D10 | 4 | ★ が `join: []` なのに JOIN と `to_jsonb(...) AS <prop>` を足した。reads の戻りの型にも現れていない | 2 本 |
| D11 | 4 | 名前付きクエリの SQL に allow の注入(`jsonb_array_elements($2::jsonb)`)を足した。allow の注入は root の読みの仕事 | 1 本 |
| D12 | 4 | 宣言した `order` を落とした(`muse_by_handle` / `store_by_handle`)。逆に `order: []` に `since ASC` を足した(`notification_fanout/subscribers`) | 3 本 |
| D13 | 4 | Option 列の ASC に `NULLS LAST` が無い(`article_release/due`)。20:838 に規定が入ったので**規定違反**になった | 1 本 |
| D14 | 4 | `consent_give/current` が `<alias>.*` でなく列を並べた | 1 本 |
| D15 | 4 | `-- GENERATED` の1行が無い(規約 ①) | 29 本 |
| **D16** | 3 | **`reads/article_release.gleam` が ▲ に無い。**★ は `due` を宣言し SQL(`article_release/due.sql`)も在るのに、型付き read 関数だけ欠けている ── Logic から呼べない(柏木 P2-1) | 1 本 |
| **D17** | 4 | **宣言した名前付きクエリ値の SQL が ▲ に無い 9 本**(`notification_inbox/{inbox,unread}`、`space_add/{count,last_order}`、`widget_add/{counts,heaven_linked,heaven_used,last_order,space_owned}`)。reads の関数は在るので、実行時に名前が引けずに落ちる ── **本便が exit 1 で止めるようにしたのと同じ不整合が ▲ に入っている**(柏木 P2-1) | 9 本 |

D4(`Eq(<key 列>, Param)` の穴を `Key(<Entity>)` で受けた 3 本)は**未決へ移した**(柏木 P2-4)。
20:576 が 2026-09-16 に「生値」で確定したので、これは手書きの逸脱ではなく
**★ の logic 3 本が `key.free_space(...)` を通している側の直し**(musearch の便)。

### 生成器の不足

| # | 束 | 何 | 件数 |
|---|---|---|---|
| G1 | 4 | **向きの混じった `order` の keyset を組めない。**`article_list/published` は `slot ASC, posted_on DESC, entered_published DESC` で行比較が成立しない。**本便から exit 1 で止まる**(SQL を落として 0 で終わらない)。▲ は `COALESCE` + `IS NOT DISTINCT FROM` で組んでいる | 1 本 |
| G2 | 3 | **root 相対の矢印の read を出せない。**root Entity の決め方が ★ に無い(40 の穴 2)── `reads/article_read` が丸ごと欠ける | 1 本 |
| G3 | 3・4 | **複合 key を1列として扱う。**Chunk の key は `#(article, version, seq)` だが先頭だけを key 列として使うので、tie-break と keyset の列が足りない | 1 本 |
| ~~G4~~ | 2 | **閉じた。**From と Field を別 module へ割った(裁定 4)。probe の `Duplicate definition` が消えた | ─ |
| G5 | 4 | `with` / `along`(Rank / Running)/ `Has` / `HasNone` / `FirstPerGroup` / `At` / `KeyOf` 固定値の SQL が未実装。MuseArch では未使用なので今回の数字には効いていない。**当たったら exit 1** | 0 本 |
| G6 | 全 | `gleam format` の折り返しを自分で出せない。検収は出力に `gleam format` をかけてから比べた。`app gen` が整形まで持つべき(後の便) | ─ |

**残差は 21 類 → 22 類**(D16 / D17 を足し、G4 を閉じ、D4 を未決へ移した)。

## 未決

**1. 割ったあとの ★ の綴り。**Gleam は構成子を再輸出できず、module 別名も大文字にできない
(`import gen/query/from as From` は syntax error ── 実測)。したがって
`q.Article` / `q.ArticleSlug` は**どう割っても引けない**。要るのは綴りの決めだけで、
本便の道具は `from.Article` / `field.ArticleSlug` を使った(musearch 23 ファイルが機械で通る)。
`import gen/query/from` の素の形(`from.Article`)は発注書が失敗例に挙げているので採らなかった。
**決着(2026-09-16 人見):`from.Article` / `field.ArticleSlug`。**`requalify.py` を同日に鷹野がこの綴りへ差し替えた。musearch の便で 1 コマンド。

**2. 未実装を exit 1 に入れた読み。**20 の表の 1 は「生成器の内部エラー / バグ、差し戻しではない」。
G1・G5 の未実装は「生成器の作者が直す」側なので 1 に寄せた ── 5(語彙の不足)に入れると
役員 人見へ上がってしまい、語彙は足りているので嘘になる。**20 の表に「未実装」の行を足すか、
1 の説明を『内部エラーと未実装』に広げるかの選択が要る。**

**3. 生成器 → framework の依存の向き。**スキーマ名の出所を1箇所にするため、生成器の
`gleam.toml` に `yumemi = { path = ".." }` を足して `framework/schema` を読んだ。
生成器が runtime の package に依存する形になったので、器として正しいか確認が要る
(代わりの案:★ の `src/app.gleam` に `pub const schema` を置かせる ── ただし 20 に規定が無く、
musearch の ★ にも無い)。

**4. G1(向きの混じった keyset)は本便でも触っていない。**発注書のとおり次便。いまは exit 1。
G2 は穴 2 の裁定待ち、G3 も据え置き。

**5. musearch 側に積んだ直しは 4 種。**本便の外だが、次の musearch の便で同時に入る:
★ の綴りの付け替え(未決 1)、`key.free_space` 3 本(D4)、`gen/types` の追加関数 3 関数 5 箇所の
移設(D1)、`reads/article_release` と SQL 9 本の欠落(D16 / D17)。

**6. gen-1 の未決 8 件のうち 7 件は閉じた。**裁定 4 点 + 20 の追記で、1(key 列の穴)・
2(`gen/types` の追加関数)・3(`IsTrue` / `EqOrNull`)・4(Field の関係列と PartyId)・
5(Lifecycle 持ちの行の型)・6(`First(1)` / agg / `Count` の型、`order: []` の既定、`NULLS LAST`)・
7(From と Field の名前空間)。8(fixture の置き場)は `gen/fixtures/` で確定
── `gen/test/` 配下に ★ は置けない(Gleam が全部コンパイルする)。
