# verb-1 巡 4 結果

P0-6 と鷹野裁定3の表記を反映した。固定の `musearch-main` は読み取り専用、仮宣言コピーには新しい宣言を足していない。DDL は本番・staging・production へ適用していない。

## 検証結果

| 検査 | 実測 |
|---|---|
| `cd gen && gleam test` | 77 passed, no failures (`gen/build/a4-gleam-test-final.txt`) |
| route table | 7 rows PASS (`gen/build/a4-route-table.txt`) |
| gate 2 SQL | 7 checks PASS (`gen/build/a4-gate2.txt`) |
| root FFI | 8 checks PASS (`gen/build/a4-root-ffi.txt`) |
| 固定写し clean run | 635 files / exit 4 / exit 4 診断 34 行 (`gen/build/a4-main-generate.txt`, `gen/build/a4-output-counts.txt`) |
| 固定写しと巡2 `out-n2` | `diff -r` 差 0 (`gen/build/a4-main-vs-n2.txt`) |
| 欠落キャスト突合 | 固定写し by-type 4本/5、by-placeholder 5本/7; 仮宣言 by-type 1本/1、by-placeholder 2本/3 (`gen/build/a4-verify-main.txt`, `gen/build/a4-verify-decl.txt`) |
| 段2一致 | 固定写し 10、仮宣言 11 (`gen/build/a4-verify-main.txt`, `gen/build/a4-verify-decl.txt`) |
| 突合器 self-test | 4 checks PASS (`gen/build/a4-verb-self-test.txt`) |

root FFI は固定写しのソースに、実体 build と `codec.mjs` / `runtime.mjs` が byte 一致する一時 harness を組み合わせて検証した。固定写しそのものは変更していない。

## P0-6 Draft と ordered create

`ordered_by.field` は DB が `COALESCE(max("order")+1,0)` で採番するため、`*Draft` から除外し、`*Created` には残すようにした。Draft は呼び手が作成時に与える Property だけを持つ。

`draft_fields_match_create_sql_placeholders_test` は、ordered create の有効な4 fixture (`relation`、`article`、`verb_features`、`ordered_create`) と通常 create の `flag` を対象に、Draft 欄数と create SQL の呼び手入力 placeholder 数を比較する。lifecycle の `phase` / `entered_*` は Draft 外の system 入力なので比較対象から除いている。

仮宣言コピーの実測は次のとおりで、SQL は変更せず Draft の欄だけが揃った。

| Entity | Draft | create SQL の入力 placeholder |
|---|---:|---:|
| `free_space` | 4欄 | 4 |
| `link` | 4欄 | 4 |
| `widget` | 16欄 | 16 |

`order` は3 Entityすべての `*Created` に残っている (`gen/build/a4-draft-sql-counts.txt`)。

## 欠落キャスト

型の多重集合を正典にし、placeholder 番号は参考値として両方を出す。数字と判定は変えていない。

固定写し:

```text
missing-cast(by-type, 正): 4本/5 (advance_roster[$2::integer], delete_roster_photo[$2::integer], delete_store_schedule[$3::uuid $2::date], update_article_body[$5::jsonb])
missing-cast(by-placeholder, 参考): 5本/7 (advance_muse_heaven[$5::timestamptz], advance_roster[$5::timestamptz $2::integer], delete_roster_photo[$2::integer], delete_store_schedule[$3::uuid $2::date], update_article_body[$5::jsonb])
```

仮宣言コピー:

```text
missing-cast(by-type, 正): 1本/1 (advance_roster[$2::integer])
missing-cast(by-placeholder, 参考): 2本/3 (advance_muse_heaven[$5::timestamptz], advance_roster[$5::timestamptz $2::integer])
```

型の多重集合で見ても残る唯一の欠落は `advance_roster[$2::integer]`。`advance_muse_heaven` は型の多重集合では欠落0で、番号のずれだけが参考欄に出る。

## 29本の突合表

仮宣言コピー基準で手書き・生成の両側に出る29本を全て表にした。段2一致11本、残り18本も全て類別し、未分類は0本。手書きに寄せる提案はしていない。生成側が正しい本は生成側を錨にする。

裁定3の合格線は、段1一致を参考値とし、段2一致11本 + H 類4本は意味の突合で合格、残差は全て類別して未分類0とする。H 類4本のうち3本は両側29本の表に、1本(`create_links`)は生成語彙に無い名指し残差として表の外にある。

| verb | 段2 | 類 | 判定・理由 |
|---|---:|---|---|
| `advance_muse_heaven` | — | advance | ★ に version の入力が無い。番号のずれは参考値、型の多重集合では欠落0。 |
| `advance_roster` | — | advance | ★ に version の入力が無く、`$2::integer` が型の多重集合でも残る唯一の欠落。 |
| `create_article` | — | RETURNING の手書き残差 | RETURNING は手書き `*Created` と不一致だが、錨は生成型で生成側が正しい。ただし Draft に `posted_on` / `publish_at` が残るのは I 類と同根の F3 残差。 |
| `create_consent` | — | RETURNING の手書き残差 | 手書き `*Created` と不一致。錨は生成型で、生成側が正しい。 |
| `create_fan` | ○ | — | 段2一致。 |
| `create_free_space` | — | H 類 guarded | 手書きは `framework.insert_free_space_guarded(...)`。親 `FOR UPDATE` と inline 採番は意味一致、文字一致は原理的に不可。 |
| `create_link` | — | H 類 guarded | 手書きは `framework.insert_link_guarded(...)`。親 `FOR UPDATE` と inline 採番は意味一致、文字一致は原理的に不可。 |
| `create_muse` | — | RETURNING の手書き残差 | 手書き `*Created` と不一致。錨は生成型で、生成側が正しい。 |
| `create_muse_heaven` | — | RETURNING の手書き残差 | 手書き `*Created` と不一致。錨は生成型で、生成側が正しい。 |
| `create_roster` | — | I 類 | 本便の対象から外し、F3へ移した。仮宣言の実演、`auto_key` 相当の語彙追加はしていない。 |
| `create_screen_reject` | — | RETURNING の手書き残差 | 手書き `*Created` と不一致。錨は生成型で、生成側が正しい。 |
| `create_store` | ○ | — | 段2一致。 |
| `create_subscription` | ○ | — | 段2一致。 |
| `create_widget` | — | H 類 guarded | 手書きは `framework.insert_widget_guarded(...)`。親 `FOR UPDATE` と inline 採番は意味一致、文字一致は原理的に不可。 |
| `delete_free_space` | ○ | — | 段2一致。 |
| `delete_link` | ○ | — | 段2一致。 |
| `delete_subscription` | ○ | — | 段2一致。 |
| `delete_widget` | ○ | — | 段2一致。 |
| `reorder_free_spaces` | — | 生成の方が堅い | 呼び手の契約が違う。生成側は宣言から受け取る型・戻りを導き、手書きに寄せない。 |
| `reorder_links` | — | 生成の方が堅い | 呼び手の契約が違う。生成側は宣言から受け取る型・戻りを導き、手書きに寄せない。 |
| `reorder_widgets` | — | 生成の方が堅い | 呼び手の契約が違う。生成側は宣言から受け取る型・戻りを導き、手書きに寄せない。 |
| `update_article_body` | ○ | — | 段2一致。 |
| `update_article_posted_on` | — | bump の差 | ★ の宣言側と手書きの version bump 契約が違う。 |
| `update_free_space_title` | ○ | — | 段2一致。 |
| `update_free_space_visible` | ○ | — | 段2一致。 |
| `update_muse_theme` | — | bump の差 | ★ Muse に version Property が無く、手書きの bump を導けない。 |
| `update_roster_by_external` | — | 語彙に無い失敗名 | 手書き `not_active` と生成 `conflict` の差。 |
| `update_store_verified` | — | 生成の方が堅い | 生成側は `require_rows` で更新行数を検査する。呼び手の契約が違う。 |
| `update_widget_visible` | ○ | — | 段2一致。 |

内訳は段2一致11本、残差18本( H 類 guarded 3、RETURNING の手書き残差5、語彙に無い失敗名1、生成の方が堅い4、bumpの差2、advance2、I類1 )で、11 + 18 = 29。H 類の4本目は両側に出ない `create_links` で、手書きの guarded DDL 関数呼びを生成語彙が持たない名指しの残差である。

## H 類の意味突合

仮宣言の生成 SQLには、`create_free_space`、`create_link`、`create_widget` の3本について、親の `FOR UPDATE`、within 全列の `IS NOT DISTINCT FROM`、`COALESCE(max(existing."order")+1,0)` が同じ文の CTE と INSERT に出る。これは手書きの `framework.insert_X_guarded(...)` と文字一致しないが、親 lock と ordered_by 採番の意味で合格とする。

語彙に無い上限は推測で埋めていない。名指しする上限は `free_space` 5件、`widget` 30件、`widget` の image 10件、`link` の url 重複。`create_links` の jsonb 一括 guarded 挿入も語彙に無い残差である。

## 生成物に出てはいけない 11 本(手書きの札の効き)

贄川が巡 4 の出力に対して 1 本ずつ実測した。仮宣言コピー `out-decl-n4` で **11 本すべてが生成 SQL から消えた**。
固定の写し(札の宣言が無い)では `advance_article` / `delete_roster_photo` / `delete_store_schedule` の
3 本が残る ── これが札の効きの対照になる。

| verb | 仮宣言コピー(札あり) | 固定の写し(札なし) |
|---|---|---|
| `rollup_day` | 消えた | もともと出ない |
| `rollup_month` | 消えた | もともと出ない |
| `purge_page_views` | 消えた | もともと出ない |
| `replace_chunks` | 消えた | もともと出ない |
| `create_ledger_store` | 消えた | もともと出ない |
| `record_page_view` | 消えた | もともと出ない |
| `issue_roster_code` | 消えた | もともと出ない |
| `issue_store_api_key` | 消えた | もともと出ない |
| `advance_article` | **消えた** | 出る |
| `delete_roster_photo` | **消えた** | 出る |
| `delete_store_schedule` | **消えた** | 出る |

札の名が生成候補と一致しないときは 1 名 1 行の警告で `exit 0`。仮宣言コピーでは 8 本が警告になった
(この 8 本はもともと生成候補に無い名)。

## 語彙・札・Draft

`Order(within: String)` は `Order(within: List(String))` になった。本便で足した語彙はこの 1 語だけである。破壊的変更なので、既存の `within: "muse"` は `within: ["muse"]` へ直す必要がある。影響範囲は framework の `Order` constructor、reader の `parse_order` / 検証、reorder と ordered create の SQL emitter、宣言側の `ordered_by`。`IS NOT DISTINCT FROM` は within 全列に適用する。

手書き札は Entity / ER 外 module の `handwritten_verbs` を読み、名前が生成候補と一致した verb を `src/gen/verb.gleam` と `db/queries/verb/` から抑止する。一致しない札は1名1行の warning、exit 0。header には札を残し、手書き実体は `gen/` 外に置く。

Draft は呼び手が作成時に与える Property だけを持つ。`auto_key`、DB 採番の `ordered_by.field`、phase と entered timestamp は Draft に混ぜない。Created は key と DB 採番値を含む生成型として `RETURNING` を導く。

## F3へ移した残差

- 裁定3が裁定7の I を上書きした。`create_roster` は本便で塞がず F3へ移し、`auto_key` 相当の新語彙を追加しない。仮宣言コピーにも新しい宣言を足していない。
- `create_article` の `posted_on` / `publish_at` も、作成時に呼び手が与えない欄を Draft から外す語彙が無いという I 類と同じ穴。RETURNING の生成型への整合は正しいが、Draft 入力の残差は F3 で閉じる。
- 指示書上の対象本数は `27 → 26` に直した。`create_roster` を本便の対象から外したためである。突合器の全両側一覧29本では、I類として類別を残し、未分類0を維持する。
- `advance_muse_heaven` / `advance_roster` は ★ に version の入力が無く、楽観ロック競合を導けない。`update_muse_theme` も Muse に version Property が無い。
- `create_article` / `create_consent` / `create_muse` / `create_muse_heaven` / `create_screen_reject` は手書き `*Created` と不一致だが、錨は生成型である。
- `update_article_posted_on`、`update_roster_by_external`、`update_store_verified`、`reorder_widgets` は上表の契約差を残す。

musearch `src/gen/sql.mjs` は verb 69 entry、`gen/sql/queries/verb/` は 61 本。**実体無しの 8 本**は
`create_muse_schedule`、`advance_muse_schedule`、`create_shift_target`、`delete_shift_target`、
`create_store_request`、`resolve_store_request`、`advance_store_request`、`create_ledger_store`。
これは F3 の宿題であり、本便では musearch 本体を変更していない(贄川が巡 4 に entry と .sql の差で再実測)。

## DDL

無し。migration / schema 変更は無く、staging / production へ適用していない。

## A5 P0-7 CreateMany

`CreateMany` は単体 create と同じ `create_fields` を使い、Draft の JSON からは Draft にある Property 名だけを読む。`ordered_by.field` は入力から除外し、初期 phase は literal、`entered_<phase>` は JSON と分けた `$2::timestamptz` にした。生成 Gleam も lifecycle のある CreateMany では `create_<collection>(input, at)` として `#(input, at)` を stage へ渡す。`jsonb_array_elements ... WITH ORDINALITY` で配列順を保持し、入力に現れる親を鍵順に `FOR UPDATE`、within 全列の distinct scope ごとに既存の末尾を求め、`row_number() OVER (PARTITION BY <within 全列> ORDER BY ord) - 1` を足して採番する。

SQL の要点は次のとおり。

- `input_rows`: `item->>'order'` は読まず、Draft の `slug,title,body,version,category` と `ord` を取る。
- `parent_lock`: 配列に現れる全親を `ORDER BY` してから `FOR UPDATE` する。
- `next_order`: scope の各列を `IS NOT DISTINCT FROM` で既存行と突合し、scope ごとに `COALESCE(max(existing."order")+1,0)` を出す。
- `numbered`: full scope で partition し、ordinality 順の連番を `next_order` へ足す。
- INSERT は `phase='draft'` と `$2::timestamptz` を入れ、Draft 外の system 欄を JSON から読まない。

実 PostgreSQL では、同一 scope の一括3行が `0,1,2`、親 B/C を交互に並べた一括4行が B=`0,1` / C=`0,1`、既に `0,1,2` のある親へ足した2行が `3,4` になった。初期 phase と entered timestamp も同じ検査で確認した。安全に生成できたため、A5 で新たに `exit 4` 停止へ回した形は無い。

## A5 P0-8 handwritten_verbs

Entity-local の `handwritten_verbs` は、その Entity 自身の `candidate_names(entity)` だけと照合するようにした。ER 外 module の札だけは従来どおり全 Entity の候補名へ照合する。抑止側の `emits` / `emits_reorder` は変えていないため、Entity A に Entity B の `create_feature` を書くと `handwritten: handwritten_verbs に生成名が無い: create_feature` が1行出る一方、B の function と SQL は残る。A 自身の `create_handwritten` は function と SQL の両方が消える。

## A5 検証

| 検査 | 実測 |
|---|---|
| `cd gen && gleam test` | 80 passed, no failures |
| route table | 7 rows PASS |
| gate 2 SQL | 既存7 + CreateMany 3 = 10 PASS |
| root FFI | 8 checks PASS (`MUSEARCH_APP` は指定の `musearch-ffi/app`) |
| verb SQL self-test | 4 PASS |
| 固定写し clean run | 635 files / exit 4 / exit 4 診断34行 |
| 巡4との差 | `out-n4` と `diff -r` 差0、`out-decl-n4` と `diff -rq` 差0 |
| 固定写し突合 | 段2一致10 / missing-cast by-type 4本・5 cast |
| 仮宣言突合 | 段2一致11 / missing-cast by-type 1本・1 cast |

証拠は `/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/evidence/a5-*.txt`、生成物は同 run の `out-a5-*` に置いた。固定の `musearch-main/app` と `musearch-decl/app` は読み取りだけで、framework の語彙、musearch 本体、staging、production は変更していない。
