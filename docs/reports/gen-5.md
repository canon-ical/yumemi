# gen-5 ── route 段 3: 末尾語の最長一致と ER 外 collection

## 結果

段 3 を R0〜R5 に変更した。Entity は module 名の末尾語列で候補化し、ER 外 module は `pub const collection: String` を持つトップレベル module の完全一致だけで候補化する。同じ最長長の候補、無一致、空動詞、Entity＋予約動詞の入れ子は exit 4 で止める。root の fallback と `matched = False` の動詞枝は無くした。

現物の `musearch/app` は変更していない。原状 run は 635 ファイルを書いて停止コード 4、台帳 2 (`ledger_store_add/search`) と metrics 2 (`metrics_muse/store`)を `collection` 無しの exit 4 として含む。scratchpad は app の写しだけに `ledger.gleam → ledger_store.gleam`、台帳 collection、metrics collection、参照名の機械置換を施した。

scratchpad の build 済み route 表は **87 Service 中 82 が正しく出る、5 が止まる**。route 行は 326、registry は 98 行。分類は下表の2値だけで、止まった Service は理由を名指ししている。

| Service | 分類 | 理由 |
|---|---|---|
| article_create | 正しく出る | — |
| article_edit | 正しく出る | — |
| article_list | 正しく出る | — |
| article_list_mine | 正しく出る | — |
| article_pin | 正しく出る | — |
| article_publish | 正しく出る | — |
| article_read | 正しく出る | — |
| article_retract | 正しく出る | — |
| article_revise | 正しく出る | — |
| article_search | 正しく出る | — |
| article_unpin | 正しく出る | — |
| article_unschedule | 正しく出る | — |
| consent_give | 正しく出る | — |
| fan_onboard | 正しく出る | — |
| fan_read | 正しく出る | — |
| heaven_embed_code | 正しく出る | — |
| heaven_link | 正しく出る | — |
| heaven_resolve | 正しく出る | — |
| heaven_unlink | 正しく出る | — |
| ledger_store_add | 正しく出る | — |
| ledger_store_search | 正しく出る | — |
| link_add | 正しく出る | — |
| link_import | 正しく出る | — |
| link_import_apply | 正しく出る | — |
| link_list | 正しく出る | — |
| link_remove | 正しく出る | — |
| link_reorder | 正しく出る | — |
| metrics_muse | 正しく出る | — |
| metrics_store | 正しく出る | — |
| muse_edit_profile | 正しく出る | — |
| muse_heaven_list | 正しく出る | — |
| muse_onboard | 正しく出る | — |
| muse_read | 正しく出る | — |
| muse_set_theme | 正しく出る | — |
| notification_inbox | 正しく出る | — |
| notification_mark_read | 正しく出る | — |
| pageview_record | 止まる | 対象が無い: pageview_record |
| roster_add | 正しく出る | — |
| roster_claim | 正しく出る | — |
| roster_edit | 正しく出る | — |
| roster_issue_code | 正しく出る | — |
| roster_list | 正しく出る | — |
| roster_list_mine | 正しく出る | — |
| roster_photo_delete | 正しく出る | — |
| roster_photo_put | 正しく出る | — |
| roster_read | 正しく出る | — |
| roster_remove | 正しく出る | — |
| roster_reorder | 正しく出る | — |
| roster_unclaim | 正しく出る | — |
| roster_upsert | 正しく出る | — |
| schedule_add | 止まる | 対象が曖昧: schedule_add -> 候補 muse_schedule / store_schedule |
| schedule_list | 止まる | 対象が曖昧: schedule_list -> 候補 muse_schedule / store_schedule |
| schedule_withdraw | 止まる | 対象が曖昧: schedule_withdraw -> 候補 muse_schedule / store_schedule |
| shift_target_add | 正しく出る | — |
| shift_target_list | 正しく出る | — |
| shift_target_remove | 正しく出る | — |
| space_add | 正しく出る | — |
| space_edit | 正しく出る | — |
| space_hide | 正しく出る | — |
| space_list | 正しく出る | — |
| space_remove | 正しく出る | — |
| space_reorder | 正しく出る | — |
| space_show | 正しく出る | — |
| store_api_key_issue | 正しく出る | — |
| store_api_key_revoke | 正しく出る | — |
| store_link_ledger | 正しく出る | — |
| store_list | 正しく出る | — |
| store_onboard | 正しく出る | — |
| store_read | 正しく出る | — |
| store_request_file | 正しく出る | — |
| store_request_handle | 正しく出る | — |
| store_request_list | 正しく出る | — |
| store_roster_list | 止まる | 動詞が Entity と予約動詞の入れ子: store_roster_list -> roster_list (roster) |
| store_schedule_delete | 正しく出る | — |
| store_schedule_list | 正しく出る | — |
| store_schedule_put | 正しく出る | — |
| store_verify | 正しく出る | — |
| subscription_add | 正しく出る | — |
| subscription_read | 正しく出る | — |
| subscription_remove | 正しく出る | — |
| widget_add | 正しく出る | — |
| widget_edit | 正しく出る | — |
| widget_hide | 正しく出る | — |
| widget_list | 正しく出る | — |
| widget_remove | 正しく出る | — |
| widget_reorder | 正しく出る | — |
| widget_show | 正しく出る | — |

## 突合

入力 route 表はテキスト生成物ではなく、`probe-compile.sh` が scratchpad の写しへ `src/gen/entry/http.gleam` と `src/gen/face.gleam` を差し替えて build したものを使った。

- Service 表: `gen/_out/gen-5/scratch/service-table-final.tsv`（87 行）
- registry 全行: `gen/_out/gen-5/scratch/registry-compare-final.tsv`（98 行）
- 原状生成物: `gen/_out/gen-5/original-final`
- scratchpad 生成物: `gen/_out/gen-5/scratch/generated-final2`
- build 済み route 表: `gen/_out/gen-5/scratch/probe-final2/app/src/gen/entry/http.gleam`

TSV の `registry_collection` / `registry_verb` は registry URL から読んだ値、`registry_logical_collection` / `registry_logical_verb` は Service の対象・剥がした動詞との比較値。`silent_mismatch` は全 87 Service で空、`rule_mismatch` も全行で空だった。raw URL の末尾形は **32 Service** で割れたが、これは別欄に置いた。例は `ledger_store_search` の registry が裸の list 形、`*_add` の registry が create 形、`heaven_embed_code` の `embed` と生成器の `embed_code` である。単複、prefix、root/key、folded も TSV の別欄に残した。

## gen-4 との差

gen-4 の内訳は、黙って誤り 3、対象を引けずに停止 5、正しく停止 4（台帳 2 + metrics 2）だった。本便は次の結果になった。

- 黙って誤り: **0**。fallback と module 名まるごとの動詞化を削除し、R1/R2/R4 で止めた。
- 正しく出る: **82 / 87**。末尾語で `space_add` → `free_space`、`heaven_embed_code` → `muse_heaven`、完全一致で台帳 2 + metrics 2 が出る。
- 止まる: **5 / 87**。R1 の schedule 3、R2 の `pageview_record` 1、R4 の `store_roster_list` 1。いずれも route を出さないことが規則どおり。
- gen-4 の正しく停止だった台帳 2 + metrics 2 は、main では宣言無しのまま停止し、scratchpad でだけ collection を宣言して route 化した。

## 残差

- `schedule_add/list/withdraw` の同長候補3本は、Logic や reads を読まずに候補名を出して停止する。曖昧さの裁定は別便。
- `pageview_record` は `page_view` の末尾語列に無く、ER 外 collection 宣言も無い不能1本。`pageviews` の扱いは musearch 側の module/命名便で決める。
- `store_roster_list` は R4 の入れ子停止。改名または対象を明示する仕様判断は別便。
- registry の URL 末尾形・綴り・prefix・root/key の割れは musearch 側の別便。台帳 module の改名と collection 宣言も scratchpad での検算だけで、main へは書いていない。

## 20:952 への記述案

段3を次のように改訂する。

> **段3 対象** ── 候補集合は全 Entity と、トップレベル module が宣言する ER 外 collection。Entity は module 名の末尾語列（`muse_schedule` / `schedule`、`free_space` / `space`）の各語に Service module 名が `<語>_` で始まるかを調べ、一致した語が最長の候補を採る。ER 外 module は module 名そのものとの完全一致だけを調べ、末尾語は候補にしない。候補が同じ最長長で2つ以上、候補が無い、または剥がした残りが空なら Service 名と候補を名指しして exit 4。剥がした動詞が `<他 Entity の末尾語>_<create|read|list|delete|put>` の形なら入れ子名として exit 4。動詞は選んだ語を剥がした残りであり、root Entity への fallback は行わない。ER 外 collection は `{key}` を持たず、`create` / `list` は裸の collection path、`read` / `delete` / `put` は個体レベル専用として exit 4、その他は動詞を末尾へ足す。

20 本文と canonical draft は書き換えていない。

## 検証

| 検査 | 実測 | 証拠 |
|---|---:|---|
| `cd gen && gleam test` | **72 passed, no failures** | `gen/build/gen-5-gleam-test-final.txt` |
| 原状 run | 635 files、exit 4（ledger 2 + metrics 2 も宣言無し） | `gen/build/gen-5-original-final-run.txt` |
| scratchpad run | 635 files、route 82 Service / 326 rows、exit 4 | `gen/build/gen-5-scratch-final2-run.txt` |
| `probe-compile.sh` | 基準 **0** → 差し替え **333** → requalify **129** → 既知差し替え後 **129** | `gen/build/gen-5-probe-scratch-final2.txt` |
| `verify-route-table.sh` | **PASS、7 rows** | `gen/build/gen-5-verify-route-table-final.txt` |
| `verify-gate2-sql.mjs` | **7 checks PASS** | `gen/build/gen-5-verify-gate2-sql-final.txt` |
| `verify-root-ffi.mjs` | **8 checks PASS** | `gen/build/gen-5-verify-root-ffi-final.txt` |
