# verb-1b ── ordered create の3穴

## 状態

`ordered_create_sql` と `ordered_create_many_sql` を、親版を別文で進めてから create 本体を実行する形へ直した。`sql_files` は、親 Entity を解決できる ordered_by について、単体と一括を別々の条件で lock file にする。

- `create_<module>_lock.sql`: `emits(app, entity, "create_" <> entity.module)` が真のときだけ出す。親1行の no-op `UPDATE` で、引数は親鍵の `$1` だけ。
- `create_<collection>_lock.sql`: `entity.verbs` に `CreateManyRule` があり、かつ `emits(app, entity, "create_" <> entity.collection)` が真のときだけ出す。Draft jsonb 配列に現れる親鍵を distinct にして、親鍵順の `FOR UPDATE` 後に no-op `UPDATE` する。引数は配列の `$1` だけ。

単体と一括の条件は同じ `case` でまとめず、各 create 本体の出力条件をそのまま lock の門に使う。CreateMany を宣言していない `ordered_by` Entity では単体 lock だけが出て、手書き札で create 本体を消した Entity では単体 lock も出ない。

一括 lock は `WITH locked AS (...)` の中で親表を `ORDER BY <親鍵> FOR UPDATE` で先に行ロックし、その結果を後段の `UPDATE <親表> SET <鍵>=<鍵> WHERE <鍵> IN (SELECT <鍵> FROM locked)` に渡す2段構成にした。no-op `UPDATE` は親行の版を進めるため残している。

create 本体の親 CTE は `FOR UPDATE NOWAIT` にし、単体は `parent_gate` の `count(*)`、一括は scope ごとの二重 `NOT EXISTS` を `framework.require_rows(...,'conflict')` へ渡す。開始値は `order_span` の `first` (`int.max(lo, 0)`) を使う。`verify-gate2-sql.mjs` は第5引数に負の下端 fixture 出力を必須で受け、無いと usage を出して exit 2 で止める。DDL、`src/framework/`、musearch 本体、staging、production は変更していない。

## P0-9 ── 採番の競合

### 変更前の SQL

単体は親を同じ文でロックし、同じ文の snapshot で末尾を読む形だった。

```sql
WITH parent_lock AS MATERIALIZED (
 SELECT 1 AS locked
 FROM app.album
 WHERE id=$2::uuid FOR UPDATE
),
next_order AS MATERIALIZED (
 SELECT next_value.next_order
 FROM parent_lock
 CROSS JOIN LATERAL (
  SELECT COALESCE(max(existing."order")+1,0) AS next_order
  FROM app.photo AS existing
  WHERE existing.album_id IS NOT DISTINCT FROM $2::uuid
 ) AS next_value
),
created AS (...)
SELECT ... FROM created;
```

一括も `parent_lock` と採番を同じ文に置き、scope の採番側を親へ INNER JOIN していた。

```sql
parent_lock AS MATERIALIZED (
 SELECT parent.id AS album_id
 FROM app.album AS parent
 WHERE EXISTS (...)
 ORDER BY parent.id
 FOR UPDATE
),
next_order AS MATERIALIZED (
 SELECT scope.album_id,COALESCE(max(existing."order")+1,0) AS next_order
 FROM scopes AS scope
 JOIN parent_lock AS parent
   ON parent.album_id IS NOT DISTINCT FROM scope.album_id
 LEFT JOIN app.photo AS existing ON ...
 GROUP BY scope.album_id
)
```

READ COMMITTED では、後続文のロック待ちが解けても同じ文の snapshot が更新されず、後続が古い末尾を読む。

### 変更後の SQL

生成物の lock file は次の実物になった。

```sql
-- GENERATED from entity.photo [sha256:5a39571d3975] — 手で編集しない
-- 呼び手は create_photo と同じ transaction でこれを先に 1 回打つ。$1 は album の鍵ひとつ。親行の版を進める。
UPDATE app.album SET id=id WHERE id=$1::uuid;
```

```sql
-- GENERATED from entity.article [sha256:cbd1f2e465d8] — 手で編集しない
-- 呼び手は create_articles と同じ transaction でこれを先に 1 回打つ。$1 は Draft の jsonb 配列。親行の版を進める。
WITH locked AS (
 SELECT name
 FROM app.category
 WHERE name IN (
 SELECT DISTINCT (item->>'category')
 FROM jsonb_array_elements($1::jsonb) AS items(item)
 )
 ORDER BY name
 FOR UPDATE
)
UPDATE app.category SET name=name WHERE name IN (SELECT name FROM locked);
```

単体 create 本体は `parent_gate` を常に1行の CTE として置き、親 lock の後に末尾を読む。

```sql
WITH parent_lock AS MATERIALIZED (
 SELECT 1 AS locked
 FROM app.album
 WHERE id=$2::uuid FOR UPDATE NOWAIT
),
parent_gate AS MATERIALIZED (
 SELECT framework.require_rows((SELECT count(*) FROM parent_lock),'conflict') AS ok
),
next_order AS MATERIALIZED (
 SELECT next_value.next_order
 FROM parent_gate
 CROSS JOIN LATERAL (
  SELECT COALESCE(max(existing."order")+1,1) AS next_order
  FROM app.photo AS existing
  WHERE existing.album_id IS NOT DISTINCT FROM $2::uuid
 ) AS next_value
)
```

一括 create 本体は親への INNER JOIN を持たず、全 scope を `parent_gate` で検査する。

```sql
parent_gate AS MATERIALIZED (
 SELECT framework.require_rows(CASE WHEN NOT EXISTS (
  SELECT 1 FROM scopes AS scope
  WHERE NOT EXISTS (
   SELECT 1 FROM parent_lock AS p
   WHERE p.category_id IS NOT DISTINCT FROM scope.category_id
  )
 ) THEN 1 ELSE 0 END,'conflict') AS ok
),
next_order AS MATERIALIZED (
 SELECT scope.category_id,
        COALESCE(max(existing."order")+1,0) AS next_order
 FROM scopes AS scope
 CROSS JOIN parent_gate
 LEFT JOIN app.article AS existing
  ON existing.category_id IS NOT DISTINCT FROM scope.category_id
 GROUP BY scope.category_id
)
```

`create_<module>_lock.sql` / `create_<collection>_lock.sql` を同じ transaction の先頭で実行すれば、READ COMMITTED の後続は `0,1` となった。REPEATABLE READ と SERIALIZABLE では待っていた①が `40001` で失敗し、重複を保存しない。①を省略した場合は create 本体の `NOWAIT` が競合中に `55P03` で止まる。

## P0-10 ── 開始値

### 変更前の SQL

単体・一括とも次の固定値だった。

```sql
COALESCE(max(existing."order")+1,0)
```

### 変更後の SQL

`order_span(entity, app, ordered)` の `first` を両方の emitter で使う。

```text
Range(min: 1, max: 10)       -> COALESCE(max(existing."order")+1,1)
宣言無し(Int)                -> COALESCE(max(existing."order")+1,0)
Range(min: -5, max: 10)      -> COALESCE(max(existing."order")+1,0)
```

実物は `fx-relation/db/queries/verb/create_photo.sql`、`fx-article/db/queries/verb/create_article.sql` / `create_articles.sql`、`fx-ordered_create_negative/db/queries/verb/create_child.sql` に出ている。`hi` 超過時の飽和は本便では扱っていない。

## P0-11 ── 親欠落

### 変更前の SQL

一括は次の INNER JOIN で親の無い scope を `next_order` へ入れる前に消していた。

```sql
FROM scopes AS scope
JOIN parent_lock AS parent
  ON parent.category_id IS NOT DISTINCT FROM scope.category_id
LEFT JOIN app.article AS existing ON ...
```

単体も `parent_lock` が0行になると、片側の空結果に依存する形で create の評価を止めていた。

### 変更後の SQL

単体は次の門で `0` を必ず `P0001/conflict` にする。

```sql
parent_gate AS MATERIALIZED (
 SELECT framework.require_rows((SELECT count(*) FROM parent_lock),'conflict') AS ok
),
next_order AS MATERIALIZED (
 SELECT next_value.next_order
 FROM parent_gate
 CROSS JOIN LATERAL (...)
)
```

一括は scope 件数比較を使わず、親の無い scope が1つでもあれば門を落とす。

```sql
parent_gate AS MATERIALIZED (
 SELECT framework.require_rows(CASE WHEN NOT EXISTS (
  SELECT 1 FROM scopes AS scope
  WHERE NOT EXISTS (
   SELECT 1 FROM parent_lock AS p
   WHERE p.category_id IS NOT DISTINCT FROM scope.category_id
  )
 ) THEN 1 ELSE 0 END,'conflict') AS ok
)
```

`within: ["owner", "space"]` のように1親へ複数 scope が付く形を壊さないため、`count(scopes)=count(parent_lock)` にはしていない。

## T1 の実測表

全36箱(①あり/なし × 単体×単体・一括×一括・単体×一括 × 3 isolation × UNIQUEあり/なし)と、A rollback の1箱を実行した。UNIQUE の有無は各行の2箱が同じ結果だった。

| ① | 組 | isolation | UNIQUEあり / UNIQUEなし | 実測結果 |
|---|---|---|---|---|
| あり | 単体×単体 | READ COMMITTED | `ok:0,1` / `ok:0,1` | 後続は先行+1 |
| あり | 一括×一括 | READ COMMITTED | `ok:0,1` / `ok:0,1` | 後続は先行+1 |
| あり | 単体×一括 | READ COMMITTED | `ok:0,1` / `ok:0,1` | 後続は先行+1 |
| あり | 単体×単体 | REPEATABLE READ | `40001:0` / `40001:0` | B①で失敗 |
| あり | 一括×一括 | REPEATABLE READ | `40001:0` / `40001:0` | B①で失敗 |
| あり | 単体×一括 | REPEATABLE READ | `40001:0` / `40001:0` | B①で失敗 |
| あり | 単体×単体 | SERIALIZABLE | `40001:0` / `40001:0` | B①で失敗 |
| あり | 一括×一括 | SERIALIZABLE | `40001:0` / `40001:0` | B①で失敗 |
| あり | 単体×一括 | SERIALIZABLE | `40001:0` / `40001:0` | B①で失敗 |
| なし | 単体×単体 | READ COMMITTED | `55P03:0` / `55P03:0` | B②で失敗 |
| なし | 一括×一括 | READ COMMITTED | `55P03:0` / `55P03:0` | B②で失敗 |
| なし | 単体×一括 | READ COMMITTED | `55P03:0` / `55P03:0` | B②で失敗 |
| なし | 単体×単体 | REPEATABLE READ | `55P03:0` / `55P03:0` | B②で失敗 |
| なし | 一括×一括 | REPEATABLE READ | `55P03:0` / `55P03:0` | B②で失敗 |
| なし | 単体×一括 | REPEATABLE READ | `55P03:0` / `55P03:0` | B②で失敗 |
| なし | 単体×単体 | SERIALIZABLE | `55P03:0` / `55P03:0` | B②で失敗 |
| なし | 一括×一括 | SERIALIZABLE | `55P03:0` / `55P03:0` | B②で失敗 |
| なし | 単体×一括 | SERIALIZABLE | `55P03:0` / `55P03:0` | B②で失敗 |
| あり | 単体×単体 | READ COMMITTED / A rollback | `ok:0` | Bが先行の番を取得 |

全箱で同じ scope に同じ `order` の2行は0件だった。stdout の全行は `a1/evidence/gate2-final.txt` に残した。

## 検証結果

| 検査 | 実測 |
|---|---|
| `cd gen && gleam test` | **83 passed, no failures** |
| `verify-gate2-sql.mjs` | 既存10行 + T1 37行 + T2 4行 + T3 4行、status 0。T1重複0。 |
| T2 | Range(1,10) 単体 `1`、宣言無し単体 `0`、CreateMany `0,1,2`、負の下端 `0` |
| T3 | 正常入力通過。混在・全件親無し・単体親無しが全て `P0001/conflict` + 0行。FK無しDDL。 |
| route table | `PASS (7 rows, face/http scratch build)` |
| `verify-verb-sql --self-test` | 4 checks PASS |
| 仮宣言 `verify-verb-sql` | stage2 `11`、missing-cast(by-type) `1本/1` |
| root FFI | `8 checks PASS` |
| main clean run | exit 4、exit 4診断34行、警告21行。基線との差0。 |
| decl clean run | exit 4。基線との差は ordered create の既存3本と lock SQL 6本だけ。 |
| astra ordered-create | `P0-9 ... no reproduction = PASS` |
| astra order-range | `P0-10 ... no reproduction = PASS` |
| `git diff --check` | 出力なし |

`verify-gate2-sql.mjs` は第 5 引数に**負の下端 fixture の出力**を必須で取る(省略すると usage + exit 2)。T1 / T2 / T3 を回すときの呼び方は次のとおり。

```
PGHOST=127.0.0.1 PGPORT=55432 PGUSER=yumemism PGDATABASE=postgres \
  node gen/scripts/verify-gate2-sql.mjs <main-out> <article-out> <flag-out> <relation-out> <ordered_create_negative-out>
```

証拠は `/home/yumemism/.codex-agents/runs/niekawa-20260921-131116-1974475-16200/a1/evidence/`、生成物は同 run の `a1/fx-*` / `a1/main-out` / `a1/decl-out` にある。

## F3 への申し送り

呼び手は `create_<name>_lock.sql` を create 本体と同じ transaction で先に1回打つ。READ COMMITTED では後続が先行+1になる。REPEATABLE READ 以上では①が `40001` を返すので、呼び手は transaction 単位で再試行する。①を飛ばす呼び手は、②だけでは RR 以上の安全を得られず、競合が重なる場合だけ `55P03` で止まる。

## B2 ── lock 出力条件・一括行ロック順・第5引数

巡2では lock の出力条件を create 本体と一致させた。単体は `emits(app, entity, "create_" <> entity.module)` の門を通し、一括は `CreateManyRule` の宣言と `emits(app, entity, "create_" <> entity.collection)` の両方を要求する。したがって、`CreateMany` 無しの `ordered_by` Entity は単体 lock のみ、手書き札で create が消える Entity は対応する lock も無しになる。

一括 lock の実物は次の順序である。

```sql
WITH locked AS (
 SELECT <親鍵>
 FROM <親表>
 WHERE <親鍵> IN (SELECT DISTINCT ... FROM jsonb_array_elements($1::jsonb) ...)
 ORDER BY <親鍵>
 FOR UPDATE
)
UPDATE <親表> SET <親鍵>=<親鍵>
WHERE <親鍵> IN (SELECT <親鍵> FROM locked);
```

`FOR UPDATE` は鍵順の行ロック取得用、後段の no-op `UPDATE` は親行の版を進める用で、後者は残している。`verify-gate2-sql.mjs` は第5引数を省略すると path 推測せず usage + exit 2 になる。

巡2の実測は次のとおり。

| 検査 | 実測 |
|---|---|
| `gleam test` | 86 passed, no failures |
| `verify-gate2-sql.mjs` | 19 PASS、status 0。T1 は37行、`no duplicate scope/order`。 |
| main / decl 差分 | main 差0。decl は `create_free_space` / `create_link` / `create_widget` と各 lock の6行だけ。 |
| `verify-verb-sql` | self-test 4 PASS。decl は stage2=11、missing-cast-ty=1。 |
| route / root | route 7 rows、root FFI 8 checks PASS。 |
| main generator | exit 4、exit 3=0、exit4=34行/9 service、警告21行。 |
| 第5引数無し | usage のみ、exit 2、stack trace なし。 |

証拠は `/home/yumemism/.codex-agents/runs/niekawa-20260921-131116-1974475-16200/a1/evidence/` にある。

## 残差

- `hi` 超過時の飽和の綴りは本便の語彙に無い。
- ①を飛ばした RR 以上の呼び手は、②だけでは救えない。`55P03` は競合が重なったときだけである。
- 親 Entity が引けない `ordered_by`（`within` 先頭が関係でない形）には lock 文が出ない。
- 親欠落の失敗コードは汎用の `'conflict'`。専用名は語彙が要る。
- 負の下端は BRIEF の括弧書き(`lo`)とは異なる。reader の受理条件と起点は `int.max(lo, 0)` が正典である。
- `within` 先頭が optional の形では NULL scope を親検査・親 lock から外す実装にしたが、専用 fixture と実 PG の独立箱は本便では置いていない。
