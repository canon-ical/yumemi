# BRIEF verb-1 ── yumemi:書く手の意味と語彙(2026-09-21、鷹野[PDM] → 贄川[ORC])

便: yumemi-verb-1

**親ゴール:** tech `_drafts/gleam-framework/00-goal.md` の G2「設計から Gleam 実装が一本道で導かれる」。musearch 追随 第 3 便(verb + draft)の前提 ── いま生成器に musearch を当てると、手書きと同名の verb SQL 28 本のうち **27 本が意味の違う SQL** になり、手書きの 33 本は名前すら出ない。本便は **yumemi 側だけで**、語彙で表せる形を語彙にし、表せない形に「手書き」の札を立て、残りの意味落ちを塞ぐ。

**障害:**

- 意味落ちは **compile では出ず App test でしか出ない**(`delete_roster_photo` は 318 字 → 54 字の裸 DELETE)。musearch(F3)で初めて赤くなると、生成器と ★ のどちらが悪いか切り分けられない
- 語彙を足すと既存の 4 種(`create` / `update_<prop>` / `advance` / `delete`)の出力が動き、gen-5 の route 表 82 本が退行しうる
- 手書きに残す verb の置き場と札が決まっていないと、生成 `verb.gleam` が手書きを上書きするか、手書きが「生成物」の顔で残る

## 現在地

- yumemi main `5ab4c43`(gen-5 + SQL 出力先を `db/queries/`)、Hex **0.3.0**、`cd gen && gleam test` **72**、`verify-route-table` 7 / `verify-gate2-sql` 7 / `verify-root-ffi` 8 が基線。framework の語彙は `src/framework/verbs.gleam`(`Rule` 4 種 + `Gate` / `Bump` / `Order`)、正典は tech `_drafts/gleam-framework/20-programming-model.md`:497
- musearch は **`~/yumemism_repo/musearch` の main を読むだけ**。R1(`app/`→`api/`)が走行中なので **branch は読まない**。手書き verb SQL は `app/gen/sql/queries/verb/` の **61 本**(`src/gen/sql.mjs` は 69 entry で 8 本に .sql が無い ── musearch 側のずれ、本便は 61 本だけ突き合わせる)
- 本日の実測(鷹野、musearch main `3fa2a41` に当てた clean run):生成 verb SQL **241** / 手書き 61、**両側 28・正規化一致 1・不一致 27・生成だけ 213・手書きだけ 33**。停止は exit 4 が 34 行(route 段 3、本便の対象外)、exit 1 / 3 は 0
- ★ に `verbs` の宣言は **0 本**なので、語彙を足しても musearch への出力は変わらないのが正しい(変わったら退行)
- 棚卸しは tech `_drafts/gleam-framework/56-followup-2-plan.v0.md` 節 3、順序は `_drafts/plan/58-task-dag.v0.md` の Y1(F3 の前提、前提なしで起動できる)
- rates:kimi 50 / codex 39 / claude 56、いずれも無印。通常経路(真壁 luna、ゲート 2 の P0 を直す巡だけ sol)。ゲートは 1 も 2 も便に 1 回

## 語彙で表せない 10 本 ── 水無瀬案(鷹野が検収で裁く。真壁は決めない)

| # | verb | 語彙に無い形 | 案 |
|---|---|---|---|
| 1 | `issue_roster_code` | 戻りが `Verb(Nil)` でなく `ClaimCodeIssued` | **手書き**(鷹野裁定:値は runtime の採番・digest 由来、SQL で返す形にしない。`returns:` は足さない) |
| 2 | `issue_store_api_key` | 同上(`ApiKeyIssued`) | **手書き**(同上) |
| 3 | `rollup_day` | key を取らない集計 INSERT…SELECT 90 行 | **手書き**。集計の定義そのものが業務で、宣言に写せない |
| 4 | `rollup_month` | 同上 | **手書き** |
| 5 | `purge_page_views` | 保持期間の連鎖削除(browser / visit / page_view) | **手書き** |
| 6 | `replace_chunks` | 親ロック + 旧版 delete + `jsonb_to_recordset` の create | **手書き**(2 文の形は `framework/verb.compound` に既にある) |
| 7 | `update_roster_by_external` | key でない 2 列(`store` / `external_id`)で引く | **語彙の再利用**:`upsert_key` で引く Update(鷹野裁定:新語 `by:` は足さない、Roster の自然鍵は `upsert_key` と同じ) |
| 8 | `reorder_widgets` | `within` が 2 つ、片方が Option | **語彙**:`Order(within:)` を `List(String)` へ。Option 列は `IS NOT DISTINCT FROM` |
| 9 | `create_ledger_store` | ER の外 | **手書き**(20:451 の線、gen-5 の `collection` と揃える) |
| 10 | `record_page_view` | 重複抑止とレート上限と最新 visit への従属 | **手書き** |

**手書きの札:**Entity(と ER 外 module)に `pub const handwritten_verbs: List(String)`。生成器は挙げた名を `verb.gleam` にも `db/queries/verb/` にも **出さず**、生成 `verb.gleam` のヘッダ(`sha256:` の次の行)に `handwritten: <名>, …` を書く。挙げた名が生成器の出す名と一致したときだけ抑止が効き、一致しない名は警告 1 行(exit 0)で通す。手書きの実体は **`src/verb_hand.gleam`(★、`gen/` の外)** に置く ── 生成 `verb.gleam` と module が別なので名前が衝突しない。musearch 側に書くのは F3。

## 意味が落ちる 12 本 ── 7 類、大半は語彙でなく生成器の穴

| 類 | 本 | 落ちるもの |
|---|---|---|
| A 初期フェーズ | `create_article` / `create_muse` / `create_fan` / `create_store` / `create_muse_heaven` | `phase='<edges の先頭>'` と `entered_<phase>` 欄が INSERT に出ない(20:639 の裏返し) |
| B 戻り | `create_fan` / `create_subscription` / `create_store` / `create_muse_heaven` | RETURNING が `id` だけ。手書きは `*Created` の全欄 |
| C Sealed | `create_screen_reject` | `decode($5,'hex')` と `<prop>_key_id` 欄が出ない |
| D relation 列名 | `create_store` | `ledger_store` と書く。DDL は `ledger_store_id`(**実行時に落ちる**) |
| E 名前付き Update | `update_article_body` / `update_muse_theme` | 前者は `title` / `images` が落ちる、後者は `phase='onboarded'` の gate が落ちる。どちらも `Update(name:, fields:, at:)` で表せる |
| F advance の付帯 | `advance_article` | `publish_at` の消去と、Service 名を条件にした bump 抑止(`$6='article_edit'`)。`BumpUnless` では前者も後者も書けない |
| G 親ロック delete | `delete_roster_photo` / `delete_store_schedule` | 親の `FOR UPDATE` + `phase='active'` + 複合鍵(`(roster, order)` / `(roster, date)`)が消え、`id=$1` の裸 DELETE になる |

**キャストは別扱い。**生成側は `::jsonb` / `::uuid` / `::date` / `::timestamptz` を落とす。上の 12 本はキャストを無視して数えた差なので、**キャストの欠落は 12 本の外に残る**(`images=$5` が `::jsonb` を失うのは実行時に効く)。

**12 本の外で意味が落ちているものが 2 つある(56 は「生成側が短い」で 12 を選んだので拾えていない)。**(H) `create_widget` / `create_free_space` / `create_link` / `create_links` は手書きが `framework.insert_*_guarded(…)` を呼び、親の存在確認と `order` の採番を DB 関数へ出している。生成は素の INSERT で **字数は増えるが意味は落ちる**。(I) `create_roster` は生成が 17 列(`muse_id` / `party` / `claim_code` / `claim_until` / `claimed_at` を含む)を INSERT する ── 手書きは 14 列 + phase で、**作るときに書けない欄が Draft に混ざっている**(20:639 の「Draft にフェーズの欄は無い」と同じ筋)。**H / I を本便で塞ぐかは鷹野が検収で裁く。**真壁は現状を数字で出すところまで。

## どこまで

1. `framework/verbs.gleam` に **1 語だけ** ── `Order(within: List(String))`(破壊的変更、使い手はまだ無い)。`Update` に `returns:` / `by:` は足さない(`upsert_key` で引く Update を生成器が出す)。framework の他の module は触らない
2. reader が `handwritten_verbs` を読み、上の札の規則どおりに抑止と警告とヘッダ行を出す
3. 生成 SQL の 7 類(A〜G)を塞ぐ。A〜D は宣言を増やさず生成器だけで直る。E は `verbs` の宣言があれば出る形にする。F と G は語彙で書けるところまで書き、**書けない残りは報告に残差として名指しで出す**(推測で近い SQL を出さない)。キャストは型から決まるので生成器が付ける
4. fixture を足す ── `verbs` を宣言した Entity、Sealed を持つ Entity、`within` 2 つの `ordered_by`、`handwritten_verbs` を持つ Entity、ER 外 module。`gleam test` が **72 以上**で通る
5. 突合の道具 `gen/scripts/verify-verb-sql.mjs <app dir> <out dir>` を足す。判定は 2 段 ── **段 1 = 空白だけ無視、段 2 = 空白 + キャスト無視**。合格線は **12 本が段 2 で一致**し、**10 本が生成物に出ない**こと。段 1 と段 2 の差(= キャストだけの差)は本数と名前を残差に出す
6. musearch は **読むだけ**。★ に `verbs` / `handwritten_verbs` / `upsert_key` を書くのは F3。突合に要る仮の宣言は scratchpad の写しに当てる。**DDL は書かない**
7. 検収は 3 段(fixture の `gleam test`、22 本の突合表、既存の不変)。`verify-route-table` 7 / `verify-gate2-sql` 7 / `verify-root-ffi` 8 の退行なし。musearch main に当てた **route 表 82 本と読み側 6 束(types / query / reads / 読みの SQL / root / phase)が byte 不変**であることを `diff -r` で示す
8. branch `verb-1`(main `5ab4c43` から)、真壁名義で commit、**push しない**。報告は `docs/reports/verb-1.md`(22 本の表、3 語の形、残差、**20 への記述案**)。framework が変わるので Hex は **0.4.0 の候補** ── **publish は鷹野**、便の中で publish もバージョン変更もしない。終端は承認かエスカレーション

## 失敗例

- 語彙を足して既存 4 種の生成が変わる(gen-5 の route 表 82 本が退行する)
- 手書き verb を「生成物」の札で吐く(`sha256:` を付けて `db/queries/verb/` に置く)
- 意味落ちを SQL の文字列比較で「一致」と言う。キャストも空白も落として「同じ」と書き、`::jsonb` の欠落を見逃す
- 表せない F / G を、近い SQL を推測して埋める(20:501 の「語彙で安全に書けない規則は止まる」を破る)
- musearch を書く(★ の `verbs` は F3、DDL は鷹野専管)
- 20 との差を「20 が古い」で片付ける(差は報告に書き、正典は鷹野が直す)
- 突合の相手を R1 の branch や `api/` から取る。main の写しを先に取って固定する
- 同 persona の同秒起動、`^session_id:` での終了判定、push

## 鷹野の裁定(2026-09-21、水無瀬の 9 点)

1. `issue_roster_code` / `issue_store_api_key` は**手書き**。`returns:` は足さない
2. `by:` は足さない。`update_roster_by_external` は `upsert_key` で引く Update を生成器が出す
3. `Order(within:)` は `List(String)` へ(破壊的変更を採る、`also:` は作らない)。Hex は 0.4.0
4. 手書きの札は `pub const handwritten_verbs: List(String)` の宣言 + 実体は `src/verb_hand.gleam`(★、`gen/` の外)。sha256 の有無だけの運用は採らない
5. F `advance_article` は**手書き**。`publish_at` の消去も呼び手を知る bump 抑止も語彙に足さない。musearch の仕様は変えない
6. G `delete_roster_photo` / `delete_store_schedule` は**手書き**、新語なし
7. **H / I は本便で塞ぐ。**対象は 22 → 27 本(guarded 4 本は生成器が親の存在確認と `ordered_by` の採番を出す、`create_roster` は Draft に無い欄を INSERT しない)。+1 巡は許容
8. **キャストは P0。**型から決まるので生成器が全部付ける。段 1(空白だけ無視)で一致を合格線にし、段 2 は参考値
9. Hex 0.4.0 の publish は承認直後・F3 起動前に鷹野

まとめ:語彙の追加は 1 語(`Order.within`)、手書きに残すのは 11 本(rollup 2 / purge / replace_chunks / create_ledger_store / record_page_view / issue 2 / advance_article / delete 2)、生成器の穴は A〜D + E + H + I + キャスト。20 への記述案(語彙 1 語、手書きの札、Draft の欄の規則)は報告に置く、正典は鷹野が直す。musearch `sql.mjs` の実体無し 8 本は F3 の宿題として報告に写す。
