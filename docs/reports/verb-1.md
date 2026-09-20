# verb-1 巡 3 結果

対象は `verb-1` の A3。musearch の `main` は読み取り専用、宣言コピーだけに `free_space` と `link` の仮 `ordered_by` 宣言を加えた。DDL は本番・staging・production へ適用していない。

## 検証結果

| 検査 | 実測 |
|---|---|
| `cd gen && gleam test` | 76 passed, no failures (`gen/build/a3-h-gleam-test.txt`) |
| route table | 7 rows PASS (`gen/build/a3-h-route-table.txt`) |
| gate 2 SQL | 7 PASS (`gen/build/a3-h-gate2.txt`) |
| root FFI | 8 checks PASS (`gen/build/a3-h-root-ffi.txt`) |
| main clean run | 635 files / exit 4 / exit 4 診断 34 行 (`gen/build/a3-h-main-generate.txt`) |
| main と巡 2 `out-n2` | `diff -r` 差 0 (`gen/build/a3-h-main-vs-n2.txt`) |
| main と baseline | 差は `db/queries/verb/` 内だけ (`gen/build/a3-h-main-vs-baseline.txt`) |
| 突合器 self-test | 既存 2 + A3 2 の全 4 PASS (`gen/build/a3-h-verb-self-test.txt`) |

gate 2 の article fixture は `ordered_by(category)` になっているため、検証用一時 schema にだけ `category` 行を足し、create の `order` 入力を外した。これは実 DDL ではない。

## 欠落キャスト

`gen/build/a3-h-verify-main.txt` の実測は main が by-placeholder **5 本 / 7 placeholder**、by-type **4 本 / 5 cast**。内訳は次のとおり。

```text
missing casts (by placeholder): 5 (advance_muse_heaven[$5::timestamptz], advance_roster[$5::timestamptz $2::integer], delete_roster_photo[$2::integer], delete_store_schedule[$3::uuid $2::date], update_article_body[$5::jsonb])
missing casts (by type): 4 (advance_roster[$2::integer], delete_roster_photo[$2::integer], delete_store_schedule[$3::uuid $2::date], update_article_body[$5::jsonb])
```

宣言コピーは **2 本 / 3 placeholder**、by-type **1 本 / 1 cast**。

```text
missing casts (by placeholder): 2 (advance_muse_heaven[$5::timestamptz], advance_roster[$5::timestamptz $2::integer])
missing casts (by type): 1 (advance_roster[$2::integer])
```

抽出器は段 2 と同じ `quotedTokenAt` を使い、`'...'`、`"..."`、dollar-quote の内側を走査しない。by-placeholder は `(n,type)` 集合、by-type は `type` 多重集合である。self-test では手書き 2 cast に生成側の余分な date cast を許し、quoted literal 内の cast を数えないことを確認した。

## 27 本の突合表

表は巡 2 の宣言コピーで固定した 27 本の比較対象。段 2 が主、段 1 は参考。`有/有` は手書き・生成の双方に SQL があることを示す。A3 の仮宣言により、比較対象外の generated-only に `reorder_free_spaces` / `reorder_links` も増えた。

| verb | 手書き有無 | 生成有無 | 段 2 | 段 1(参考) | 欠落キャスト | 残差の理由 |
|---|---:|---:|---:|---:|---|---|
| advance_muse_heaven | 有 | 有 | — | — | `$5::timestamptz` | ★ MuseHeaven に version の入力が無く、手書きの `AND version=$2` と `version=version+1` を導けない。生成はキャストを出し忘れてはおらず、引数が 1 つ少ないためパラメータ番号が寄っている(手書き `$5::timestamptz` = 生成 `$4::timestamptz`)。型の多重集合で数えれば欠落 0。**実行時に競合を素通しする。** |
| advance_roster | 有 | 有 | — | — | `$5::timestamptz`, `$2::integer` | 同上のパラメータのずれに加え、手書きが取る `$2::integer IS NOT NULL`(version 相当のシム)が ★ に無い。型の多重集合で数えても `::integer` の欠落 1 が残る ── **本便で欠落 0 に届かない唯一の本**。**実行時に競合を素通しする。** |
| create_article | 有 | 有 | — | — | — | `*Created` 不一致。`posted_on` / `publish_at` は auto_key 相当の宣言が無く I 残差。 |
| create_consent | 有 | 有 | — | — | — | 手書き `*Created` と生成型を揃える F3 対象。 |
| create_fan | 有 | 有 | ○ | — | — | — |
| create_free_space | 有 | 有 | — | — | — | H の親 lock / inline 採番は意味一致、上限 5 は語彙外。 |
| create_link | 有 | 有 | — | — | — | H の親 lock / inline 採番は意味一致、url 重複上限は語彙外。 |
| create_muse | 有 | 有 | — | — | — | 手書き `*Created` と生成型を揃える F3 対象。 |
| create_muse_heaven | 有 | 有 | — | — | — | 手書き `*Created` と生成型を揃える F3 対象。 |
| create_roster | 有 | 有 | — | — | — | `*Created` 不一致。`claim_code` / `claim_until` / `claimed_at` は I、auto_key 宣言待ち。 |
| create_screen_reject | 有 | 有 | — | — | — | 手書き `*Created` と生成型を揃える F3 対象。 |
| create_store | 有 | 有 | ○ | — | — | — |
| create_subscription | 有 | 有 | ○ | — | — | — |
| create_widget | 有 | 有 | — | — | — | H の親 lock / inline 採番は意味一致、30 件 / image 10 件上限は語彙外。 |
| delete_free_space | 有 | 有 | ○ | ○ | — | — |
| delete_link | 有 | 有 | ○ | ○ | — | — |
| delete_subscription | 有 | 有 | ○ | — | — | — |
| delete_widget | 有 | 有 | ○ | ○ | — | — |
| reorder_widgets | 有 | 有 | — | — | — | 手書きは `RETURNING w.*` 全 17 欄、生成は id。呼び手の契約が違う。 |
| update_article_body | 有 | 有 | ○ | — | `$5::jsonb` | — |
| update_article_posted_on | 有 | 有 | — | — | — | 生成は version bump、手書きは bump しない。 |
| update_free_space_title | 有 | 有 | ○ | ○ | — | — |
| update_free_space_visible | 有 | 有 | ○ | ○ | — | — |
| update_muse_theme | 有 | 有 | — | — | — | Muse に version Property が無く `version=version+1` を導けない。 |
| update_roster_by_external | 有 | 有 | — | — | — | 生成の失敗名は `conflict`、手書きは `not_active`。 |
| update_store_verified | 有 | 有 | — | — | — | 生成は `require_rows`、手書きは素の UPDATE。 |
| update_widget_visible | 有 | 有 | ○ | ○ | — | — |

main 側だけには `advance_article`、`delete_roster_photo`、`delete_store_schedule` が追加で両側に現れる。宣言コピーでは handwritten の札により生成 SQL から消えている。

## 生成物に出てはいけない 11 本(手書きの札の効き)

裁定 1 / 3〜6 で手書きに残した 11 本。宣言コピー(`handwritten_verbs` を当てたもの)への clean run で **11 本すべてが生成 SQL から消える**ことを確かめた。固定の写し(宣言ゼロ)では札が無いので、`advance_article` / `delete_roster_photo` / `delete_store_schedule` の 3 本は依然として出る ── これが札の効きの証拠である。

| verb | 手書きに残した理由 | 固定の写し(宣言ゼロ) | 宣言コピー(札あり) |
|---|---|---|---|
| `rollup_day` | 集計 INSERT…SELECT、key を取らない | 出ない | 出ない |
| `rollup_month` | 同上 | 出ない | 出ない |
| `purge_page_views` | 保持期間の連鎖削除 | 出ない | 出ない |
| `replace_chunks` | 親ロック + 旧版 delete + `jsonb_to_recordset` | 出ない | 出ない |
| `create_ledger_store` | ER の外 | 出ない | 出ない |
| `record_page_view` | 重複抑止・レート上限・最新 visit への従属 | 出ない | 出ない |
| `issue_roster_code` | 戻りが `Verb(Nil)` でない(runtime の採番・digest 由来) | 出ない | 出ない |
| `issue_store_api_key` | 同上 | 出ない | 出ない |
| `advance_article` | `publish_at` の消去と呼び手を条件にした bump 抑止 | **出る** | **消えた** |
| `delete_roster_photo` | 親の `FOR UPDATE` + `phase='active'` + 複合鍵 | **出る** | **消えた** |
| `delete_store_schedule` | 同上 | **出る** | **消えた** |

札の名が生成候補と一致しないときは 1 名 1 行の警告で `exit 0`。宣言コピーでは 8 本が警告になった(この 8 本はもともと生成候補に無い名)。

## H 類の生成 SQL

`gen/build/a3-decl-out` で `create_widget`、`create_free_space`、`create_link` の 3 本に、親の `FOR UPDATE` と `COALESCE(max(...)+1,0)`、within 全列の `IS NOT DISTINCT FROM` が出た。`create_links` は jsonb 一括挿入を表す語彙が無いため、生成していない。guarded 関数呼び出しも生成器には残していない。

```sql
-- create_widget.sql
WITH parent_lock AS MATERIALIZED (
 SELECT 1 AS locked
 FROM app.muse
 WHERE id=$2::uuid FOR UPDATE
),
next_order AS MATERIALIZED (
 SELECT next_value.next_order
 FROM parent_lock
 CROSS JOIN LATERAL (
  SELECT COALESCE(max(existing."order")+1,0) AS next_order
  FROM app.widget AS existing
  WHERE existing.muse_id IS NOT DISTINCT FROM $2::uuid
 AND existing.space_id IS NOT DISTINCT FROM $3::uuid
 ) AS next_value
),
created AS (
 INSERT INTO app.widget(id,muse_id,space_id,kind,"order",visible,title,body,image,caption,url,heaven_id,design,num,color,fontsize,height)
 SELECT $1::uuid,$2::uuid,$3::uuid,$4,next_order.next_order,$5::boolean,$6,$7,$8,$9,$10,$11::uuid,$12::jsonb,$13,$14,$15,$16
 FROM next_order
 RETURNING id,muse_id,space_id,kind,"order",visible,title,body,image,caption,url,heaven_id,design,num,color,fontsize,height
)
SELECT id,muse_id,space_id,kind,"order",visible,title,body,image,caption,url,heaven_id,design,num,color,fontsize,height FROM created;
```

```sql
-- create_free_space.sql
WITH parent_lock AS MATERIALIZED (
 SELECT 1 AS locked
 FROM app.muse
 WHERE id=$2::uuid FOR UPDATE
),
next_order AS MATERIALIZED (
 SELECT next_value.next_order
 FROM parent_lock
 CROSS JOIN LATERAL (
  SELECT COALESCE(max(existing."order")+1,0) AS next_order
  FROM app.free_space AS existing
  WHERE existing.muse_id IS NOT DISTINCT FROM $2::uuid
 ) AS next_value
),
created AS (
 INSERT INTO app.free_space(id,muse_id,title,"order",visible)
 SELECT $1::uuid,$2::uuid,$3,next_order.next_order,$4::boolean
 FROM next_order
 RETURNING id,muse_id,title,"order",visible
)
SELECT id,muse_id,title,"order",visible FROM created;
```

```sql
-- create_link.sql
WITH parent_lock AS MATERIALIZED (
 SELECT 1 AS locked
 FROM app.muse
 WHERE id=$2::uuid FOR UPDATE
),
next_order AS MATERIALIZED (
 SELECT next_value.next_order
 FROM parent_lock
 CROSS JOIN LATERAL (
  SELECT COALESCE(max(existing."order")+1,0) AS next_order
  FROM app.link AS existing
  WHERE existing.muse_id IS NOT DISTINCT FROM $2::uuid
 ) AS next_value
),
created AS (
 INSERT INTO app.link(id,muse_id,label,url,"order")
 SELECT $1::uuid,$2::uuid,$3,$4,next_order.next_order
 FROM next_order
 RETURNING id,muse_id,label,url,"order"
)
SELECT id,muse_id,label,url,"order" FROM created;
```

上限は語彙に無いため推測で実装していない: `free_space` 5 件、`widget` 30 件、`widget` image 10 件、`link` url 重複。

## 語彙・札・Draft の記述案

`Order(within: String)` は `Order(within: List(String))` になった。破壊的変更なので、既存の `within: "muse"` は `within: ["muse"]` へ直す必要がある。影響範囲は framework の `Order` constructor、reader の `parse_order` / 検証、reorder と ordered create の SQL emitter、宣言側の `ordered_by` である。`IS NOT DISTINCT FROM` は within 全列に適用する。

手書き札は Entity / ER 外 module の `handwritten_verbs` を読み、名前が生成候補と一致した verb は `src/gen/verb.gleam` と `db/queries/verb/` から抑止する。一致しない札は 1 名 1 行の warning、exit 0。header に札を残し、手書き実体は `gen/` 外へ置く。仮宣言コピーでは 11 札のうち `advance_article`、`delete_roster_photo`、`delete_store_schedule` の 3 本が消え、残り 8 本が札の warning になった。

Draft は呼び手が作成時に与える Property だけを持つ。DB / runtime の auto_key、phase と entered timestamp、作成時に書けない claim 系欄を Draft に混ぜない。Created は生成型を錨にして RETURNING を導く。

## 残差と F3 宿題

- H/I: 上記の 4 上限、`create_links` の jsonb 一括挿入、`create_roster` の claim 系欄は語彙不足または裁定待ち。
- `advance_muse_heaven` / `advance_roster`: ★ に version の入力が無く、楽観ロック競合を実行時に素通しする。`update_muse_theme` も Muse に version Property が無い。
- `update_article_posted_on`、`update_roster_by_external`、`update_store_verified`、`reorder_widgets` は上表の契約差を残す。
- `create_article` / `create_consent` / `create_muse` / `create_muse_heaven` / `create_screen_reject` は手書き `*Created` と不一致。錨は生成型で、F3 で手書きを生成へ寄せる。
- I 類の `create_roster` (`claim_code` / `claim_until` / `claimed_at`) と `create_article` (`posted_on` / `publish_at`) は `auto_key` 相当の宣言が無く裁定待ち。

musearch `src/gen/sql.mjs` は verb 69 entry、`gen/sql/queries/verb/` は 61 本。実体無しの 8 本は `create_muse_schedule`、`advance_muse_schedule`、`create_shift_target`、`delete_shift_target`、`create_store_request`、`resolve_store_request`、`advance_store_request`、`create_ledger_store`。これは F3 の宿題であり、本便では musearch 本体を変更していない。
