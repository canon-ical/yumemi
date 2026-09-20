# gen-4 ── 入口: framework / prefix / faces / route 表 / musearch 突合

## 結果

gen-3b から入口束を2ファイル増やした。framework の `Credential` / `HttpApi` / `credential()` は musearch の写しを取り込み、`Http` / `HttpApi` に `prefix: String` を追加した。framework に `Face` は置かず、生成器が entry の name を PascalCase にして `src/gen/face.gleam` を出す。

fixture article は `public`(Anonymous / AnySubject / ReadOnly / `/api`) と `admin`(Authenticated / Subjects([Staff]) / All / `/api/admin`)を持つ。Service 5本の `faces` は書き3本が `[Admin]`、読み2本が `[Public, Admin]`。生成 route は7行。

## 束ごとの数字

| 束 | gen-3b | gen-4 | 増減 |
|---|---:|---:|---:|
| `src/gen/types/*` | 83 | 83 | 0 |
| `src/gen/query*` | 3 | 3 | 0 |
| `src/gen/reads/*` | 67 | 67 | 0 |
| `src/gen/root/*` | 92 | 92 | 0 |
| `src/gen/draft/*` | 33 | 33 | 0 |
| `src/gen/verb.gleam` / `phase.gleam` | 2 | 2 | 0 |
| `gen/sql/**/*.sql` | 348 | 352 | +4 |
| `src/gen/face.gleam` | 0 | 1 | +1 |
| `src/gen/entry/http.gleam` | 0 | 1 | +1 |
| 生成ファイル合計 | 629 | 635 | +6 |

fixture article は 53 → 55 files。`gleam test` は 59 → 61 passed(gen-4-sql merge 後。`gen/sql` の +4 は exit 1 の 4 本の SQL)。

## 検証

| 検査 | 実測 | 証拠 |
|---|---|---|
| fixture `gleam test` | 61 passed, no failures | `gen/_out/kashiwagi-gate2-test.txt` |
| route table scratch build | PASS、7 rows | `gen/_out/kashiwagi-gate2/evidence/route.txt` |
| gate 2 SQL | 7 checks PASS | `gen/_out/kashiwagi-gate2/evidence/gate2-sql.txt` |
| root FFI | 8 checks PASS | `gen/_out/kashiwagi-gate2/evidence/root-ffi.txt` |
| probe original musearch | 0 / 338 / 134 / 129 | `gen/_out/kashiwagi-gate2/evidence/probe.txt` |

上表は merge 後の木を柏木が再検証した実測。PG は `127.0.0.1:55432`、DB `postgres` の検証用スキーマを使用した。上表の既存検証だけでは、下記ゲート2の反例は検出しない。

## musearch 7a: current ★

`gleam run -m yumemi_gen -- ~/yumemism_repo/musearch/app gen/_out/final-musearch` は 631 files を書いた(gen-4-sql merge 前)。`_diagnostics.txt` の内訳は faces const 不足 **92本の exit 4**、exit 3 **1**、warning **21**、exit 1 **4**(merge 後は 635 files、exit 1 **0** ── 下の「exit 1 の4本(SQL)」節)。exit 3 の文言は `entity/ledger: key 関数が無い ── ER の外の型だけの宣言は src/types.gleam へ(src/entity/** は Entity だけ)` に更新した。

## musearch 7b: scratch の仮割当

対象は current ★の写しだけ。優先順は `method: null → faces=[] / System`、`credential: 'api_key' → [Api]`、`/api/store/ → [Store]`、`/api/staff/ → [Admin]`、残り → `[Front, Console]`。結果は Api 6 / Store 13 / Admin 5 / Front+Console 63 / System 5 = 92 Service。entry prefix は5語を明示した。生成は 631 files、route は133行。

仮割当と `who` の突合で Store 面の `who AsStaff` 6本が exit 4。対象 Entity が無い route は heaven_link(2)、heaven_resolve(2)、ledger_store_add(1)、ledger_store_search(2)、metrics_muse(2)、metrics_store(2)、schedule_add(2)、space_add(2)、space_reorder(2)の17行。これも現実装は警告ではなく exit 4 (`stop.Conflict`) とする。URL は変更していない。

## registry.mjs 98行との突合

比較時だけ registry の `:name` を `{name}` に写した。判定は route の service / method / path / credential で行い、`target` がある registry 行は target serviceへ対応付けた。

| 判定 | 行数 |
|---|---:|
| 規則で一致 | 22 |
| 割れる | 66 |
| 規則の外 | 10 |
| 合計 | 98 |

規則の外10行は unique 行数。内訳のフラグは method:null 5、folded 4（article_release は method:null と重複）、entry:'front' 1、付属の入口相当(module:null) 1。全行の機械突合は `gen/_out/musearch-gen4-scratch/route-registry-compare.tsv` に残した。

| # | registry | 対応 service | registry method/path | 判定 | 理由 |
|---:|---|---|---|---|---|
| 1 | `article_search` | `article_search` | GET /api/search | 割れる | 末尾形・単複・root/鍵の差 |
| 2 | `muse_onboard` | `muse_onboard` | POST /api/muse/onboard | 割れる | 末尾形・単複・root/鍵の差 |
| 3 | `consent_give` | `consent_give` | POST /api/consents | 割れる | 末尾形・単複・root/鍵の差 |
| 4 | `muse_edit_profile` | `muse_edit_profile` | POST /api/muse/profile | 割れる | 末尾形・単複・root/鍵の差 |
| 5 | `article_create` | `article_create` | POST /api/articles | 規則で一致 | — |
| 6 | `article_list_mine` | `article_list_mine` | GET /api/articles | 割れる | 末尾形・単複・root/鍵の差 |
| 7 | `article_edit` | `article_edit` | POST /api/articles/{id}/edit | 規則で一致 | — |
| 8 | `article_publish` | `article_publish` | POST /api/articles/{id}/publish | 規則の外 | folded |
| 9 | `article_revise` | `article_revise` | POST /api/articles/{id}/revise | 規則の外 | folded |
| 10 | `article_retract` | `article_retract` | POST /api/articles/{id}/retract | 規則で一致 | — |
| 11 | `article_pin` | `article_pin` | POST /api/articles/{id}/pin | 規則で一致 | — |
| 12 | `article_unpin` | `article_unpin` | POST /api/articles/{id}/unpin | 規則で一致 | — |
| 13 | `article_index` | `article_index` | - - | 規則の外 | method:null |
| 14 | `article_release` | `article_release` | - - | 規則の外 | method:null |
| 15 | `article_unschedule` | `article_unschedule` | POST /api/articles/{id}/unschedule | 規則で一致 | — |
| 16 | `muse_read` | `muse_read` | GET /api/muse/{handle} | 規則で一致 | — |
| 17 | `fan_onboard` | `fan_onboard` | POST /api/fan/onboard | 規則の外 | entry:'front' |
| 18 | `fan_read` | `fan_read` | GET /api/fan/{handle} | 規則で一致 | — |
| 19 | `article_list` | `article_list` | GET /api/muse/{handle}/articles | 規則で一致 | — |
| 20 | `article_read` | `article_read` | GET /api/articles/{id} | 規則で一致 | — |
| 21 | `subscription_add` | `subscription_add` | POST /api/subscriptions | 割れる | 末尾形・単複・root/鍵の差 |
| 22 | `subscription_remove` | `subscription_remove` | DELETE /api/subscriptions/{id} | 割れる | 末尾形・単複・root/鍵の差 |
| 23 | `subscription_read` | `subscription_read` | GET /api/muse/{handle}/subscription | 割れる | 末尾形・単複・root/鍵の差 |
| 24 | `notification_inbox` | `notification_inbox` | GET /api/notifications | 割れる | 末尾形・単複・root/鍵の差 |
| 25 | `notification_mark_read` | `notification_mark_read` | POST /api/notifications/{id}/read | 割れる | 末尾形・単複・root/鍵の差 |
| 26 | `pageview_record` | `pageview_record` | POST /api/pageviews | 割れる | 末尾形・単複・root/鍵の差 |
| 27 | `store_onboard` | `store_onboard` | POST /api/store/onboard | 割れる | 末尾形・単複・root/鍵の差 |
| 28 | `store_link_ledger` | `store_link_ledger` | POST /api/staff/stores/{handle}/ledger | 割れる | 末尾形・単複・root/鍵の差 |
| 29 | `schedule_add` | `schedule_add` | POST /api/muse_schedule | 割れる | 末尾形・単複・root/鍵の差 |
| 30 | `schedule_withdraw` | `schedule_withdraw` | POST /api/muse_schedule/{id}/withdraw | 割れる | 末尾形・単複・root/鍵の差 |
| 31 | `schedule_list` | `schedule_list` | GET /api/muse/{handle}/schedule | 割れる | 末尾形・単複・root/鍵の差 |
| 32 | `shift_target_add` | `shift_target_add` | POST /api/shift_targets | 割れる | 末尾形・単複・root/鍵の差 |
| 33 | `shift_target_remove` | `shift_target_remove` | DELETE /api/shift_targets/{id} | 割れる | 末尾形・単複・root/鍵の差 |
| 34 | `shift_target_list` | `shift_target_list` | GET /api/shift_targets | 規則で一致 | — |
| 35 | `ledger_store_search` | `ledger_store_search` | GET /api/ledger_stores | 割れる | 末尾形・単複・root/鍵の差 |
| 36 | `ledger_store_add` | `ledger_store_add` | POST /api/staff/ledger_stores | 割れる | 末尾形・単複・root/鍵の差 |
| 37 | `store_request_file` | `store_request_file` | POST /api/store_requests | 割れる | 末尾形・単複・root/鍵の差 |
| 38 | `store_request_list` | `store_request_list` | GET /api/staff/store_requests | 規則で一致 | — |
| 39 | `store_request_handle` | `store_request_handle` | POST /api/staff/store_requests/{id}/handle | 規則の外 | folded |
| 40 | `store_list` | `store_list` | GET /api/staff/stores | 割れる | 末尾形・単複・root/鍵の差 |
| 41 | `store_verify` | `store_verify` | POST /api/store/{handle}/verify | 割れる | 末尾形・単複・root/鍵の差 |
| 42 | `store_roster_list` | `store_roster_list` | GET /api/store/rosters | 割れる | 末尾形・単複・root/鍵の差 |
| 43 | `store_api_key_issue` | `store_api_key_issue` | POST /api/store/api_key | 割れる | 末尾形・単複・root/鍵の差 |
| 44 | `store_api_key_revoke` | `store_api_key_revoke` | DELETE /api/store/api_key | 割れる | 末尾形・単複・root/鍵の差 |
| 45 | `store_read` | `store_read` | GET /api/store/{handle} | 割れる | 末尾形・単複・root/鍵の差 |
| 46 | `roster_list` | `roster_list` | GET /api/store/{handle}/rosters | 割れる | 末尾形・単複・root/鍵の差 |
| 47 | `roster_read` | `roster_read` | GET /api/store/{handle}/rosters/{id} | 割れる | 末尾形・単複・root/鍵の差 |
| 48 | `store_schedule_list` | `store_schedule_list` | GET /api/store/{handle}/schedule | 割れる | 末尾形・単複・root/鍵の差 |
| 49 | `roster_add` | `roster_add` | POST /api/store/rosters | 割れる | 末尾形・単複・root/鍵の差 |
| 50 | `roster_edit` | `roster_edit` | POST /api/store/rosters/{id}/edit | 規則で一致 | — |
| 51 | `roster_remove` | `roster_remove` | POST /api/store/rosters/{id}/remove | 割れる | 末尾形・単複・root/鍵の差 |
| 52 | `roster_reorder` | `roster_reorder` | POST /api/store/rosters/reorder | 割れる | 末尾形・単複・root/鍵の差 |
| 53 | `roster_photo_put` | `roster_photo_put` | PUT /api/store/rosters/{id}/photos/{order} | 割れる | 末尾形・単複・root/鍵の差 |
| 54 | `roster_photo_delete` | `roster_photo_delete` | DELETE /api/store/rosters/{id}/photos/{order} | 割れる | 末尾形・単複・root/鍵の差 |
| 55 | `roster_issue_code` | `roster_issue_code` | POST /api/store/rosters/{id}/code | 割れる | 末尾形・単複・root/鍵の差 |
| 56 | `roster_claim` | `roster_claim` | POST /api/rosters/claim | 規則で一致 | — |
| 57 | `roster_unclaim` | `roster_unclaim` | POST /api/rosters/{id}/unclaim | 規則で一致 | — |
| 58 | `store_schedule_put` | `store_schedule_put` | PUT /api/store/rosters/{id}/schedule/{date} | 割れる | 末尾形・単複・root/鍵の差 |
| 59 | `store_schedule_delete` | `store_schedule_delete` | DELETE /api/store/rosters/{id}/schedule/{date} | 割れる | 末尾形・単複・root/鍵の差 |
| 60 | `roster_upsert` | `roster_upsert` | PUT /api/v1/store/rosters/{external_id} | 割れる | 末尾形・単複・root/鍵の差 |
| 61 | `store_roster_list_v1` | `store_roster_list` | GET /api/v1/store/rosters | 割れる | 末尾形・単複・root/鍵の差 |
| 62 | `roster_remove_v1` | `roster_remove` | DELETE /api/v1/store/rosters/{external_id} | 割れる | 末尾形・単複・root/鍵の差 |
| 63 | `roster_photo_put_v1` | `roster_photo_put` | PUT /api/v1/store/rosters/{external_id}/photos/{order} | 割れる | 末尾形・単複・root/鍵の差 |
| 64 | `store_schedule_put_v1` | `store_schedule_put` | PUT /api/v1/store/rosters/{external_id}/schedule/{date} | 割れる | 末尾形・単複・root/鍵の差 |
| 65 | `roster_reorder_v1` | `roster_reorder` | PUT /api/v1/store/rosters/order | 割れる | 末尾形・単複・root/鍵の差 |
| 66 | `blob_copy_v1` | `blob_copy` | POST /api/v1/store/blobs | 規則の外 | 付属の入口相当 |
| 67 | `roster_list_mine` | `roster_list_mine` | GET /api/rosters/mine | 割れる | 末尾形・単複・root/鍵の差 |
| 68 | `metrics_muse` | `metrics_muse` | GET /api/metrics/muse | 割れる | 末尾形・単複・root/鍵の差 |
| 69 | `metrics_store` | `metrics_store` | GET /api/metrics/store | 割れる | 末尾形・単複・root/鍵の差 |
| 70 | `notification_notify` | `notification_notify` | - - | 規則の外 | method:null |
| 71 | `notification_fanout` | `notification_fanout` | - - | 規則の外 | method:null |
| 72 | `metrics_rollup` | `metrics_rollup` | - - | 規則の外 | method:null |
| 73 | `link_add` | `link_add` | POST /api/links | 割れる | 末尾形・単複・root/鍵の差 |
| 74 | `link_remove` | `link_remove` | DELETE /api/links/{id} | 割れる | 末尾形・単複・root/鍵の差 |
| 75 | `link_reorder` | `link_reorder` | POST /api/links/reorder | 規則で一致 | — |
| 76 | `link_list` | `link_list` | GET /api/muse/{handle}/links | 規則で一致 | — |
| 77 | `link_import` | `link_import` | POST /api/links/import | 割れる | 末尾形・単複・root/鍵の差 |
| 78 | `link_import_apply` | `link_import_apply` | POST /api/links/import/apply | 割れる | 末尾形・単複・root/鍵の差 |
| 79 | `widget_add` | `widget_add` | POST /api/widgets | 割れる | 末尾形・単複・root/鍵の差 |
| 80 | `widget_edit` | `widget_edit` | POST /api/widgets/{id}/edit | 規則で一致 | — |
| 81 | `widget_reorder` | `widget_reorder` | POST /api/widgets/reorder | 規則で一致 | — |
| 82 | `widget_show` | `widget_show` | POST /api/widgets/{id}/show | 規則で一致 | — |
| 83 | `widget_hide` | `widget_hide` | POST /api/widgets/{id}/hide | 規則で一致 | — |
| 84 | `widget_remove` | `widget_remove` | DELETE /api/widgets/{id} | 割れる | 末尾形・単複・root/鍵の差 |
| 85 | `widget_list` | `widget_list` | GET /api/muse/{handle}/widgets | 規則で一致 | — |
| 86 | `space_add` | `space_add` | POST /api/free_spaces | 割れる | 末尾形・単複・root/鍵の差 |
| 87 | `space_edit` | `space_edit` | POST /api/free_spaces/{id}/edit | 割れる | 末尾形・単複・root/鍵の差 |
| 88 | `space_reorder` | `space_reorder` | POST /api/free_spaces/reorder | 割れる | 末尾形・単複・root/鍵の差 |
| 89 | `space_show` | `space_show` | POST /api/free_spaces/{id}/show | 割れる | 末尾形・単複・root/鍵の差 |
| 90 | `space_hide` | `space_hide` | POST /api/free_spaces/{id}/hide | 割れる | 末尾形・単複・root/鍵の差 |
| 91 | `space_remove` | `space_remove` | DELETE /api/free_spaces/{id} | 割れる | 末尾形・単複・root/鍵の差 |
| 92 | `space_list` | `space_list` | GET /api/muse/{handle}/free_spaces | 割れる | 末尾形・単複・root/鍵の差 |
| 93 | `muse_set_theme` | `muse_set_theme` | POST /api/muse/theme | 割れる | 末尾形・単複・root/鍵の差 |
| 94 | `heaven_resolve` | `heaven_resolve` | POST /api/muse_heaven/resolve | 割れる | 末尾形・単複・root/鍵の差 |
| 95 | `heaven_link` | `heaven_link` | POST /api/muse_heaven | 割れる | 末尾形・単複・root/鍵の差 |
| 96 | `heaven_unlink` | `heaven_unlink` | DELETE /api/muse_heaven/{id} | 割れる | 末尾形・単複・root/鍵の差 |
| 97 | `heaven_embed_code` | `heaven_embed_code` | GET /api/muse_heaven/{id}/embed | 割れる | 末尾形・単複・root/鍵の差 |
| 98 | `muse_heaven_list` | `muse_heaven_list` | GET /api/muse/{handle}/heaven | 割れる | 末尾形・単複・root/鍵の差 |

## 20 / 26 への記述案

- **prefix欄**: `Http` / `HttpApi` の `prefix: String` は URLの頭そのもの。`/api` の暗黙既定値は置かず、Service側に path 欄を置かない。
- **gen/face.gleam**: entry の name を PascalCase にした `pub type Face` を生成する。Face は framework の型ではない。
- **facesの規則**: 全 Service に `pub const faces: List(Face)` を必須化。未知の面名、`who: As<X>` と面の subject 集合の不一致、非Systemの `faces=[]`、System-only の面名指定は exit 4。`faces=[]` は System-only のみ許す。
- **4段の実装形**: 段1 prefix、段2 root と Args の key/path_key 型、段3 target Entity の最長 module prefix と collection、段4 verb の予約語から method / 個体変数 / suffix を決める。path_keys は実際にURLへ置いた Args欄名。3変数以上と target候補2個以上は exit 4。
- **ReadOnlyの絞り**: Entry の `All | ReadOnly` は Service の faces を上から絞り、ReadOnly面には Write route を出さない。Write Service がReadOnly面だけを名指す場合は warning(exit 0)。
- **faces=[] と System**: `allow: [system]` の Service は HTTP route 表へ入れず、System-only のため `faces=[]` を許す。
- **26 dispatch 検査2**: method + path は生成 `src/gen/entry/http.gleam` の pure route tableを引き、face名は entry name の原文、credential は Session / ApiKey の分類を持つ。

## exit 1 の4本(SQL)

`gen-4-sql` branch(真壁 `d723622`)を `gen-4` へ merge 済み。`emit/sql.gleam` に `Has` / `HasNone`(EXISTS / NOT EXISTS)と `with`(相関 `jsonb_agg` で関係先を添える)の SQL 生成を実装し、merge 後の木で **exit 1 は 4 → 0**、生成は **635 files**(≥ 629)。4 本(`store_schedule_list/{all_slots,public_slots}.sql`、`store_roster_list/mine.sql`、`roster_list/listed.sql`)が生成束に出る。手書き SQL とは意味一致で、`listed` は JOIN / GROUP BY ではなく相関サブクエリの形。fixture `relation` に `photo_filter`(Has / HasNone / with)を足して `gleam test` で SQL を固定した。`along` / `FirstPerGroup` / `At` / `KeyOf` は残差のまま触っていない。

## 未決 / 残差

- current musearch ★はprefix未追随なので7aでは空文字を読み、`/api`は補っていない。5語を足した7b scratchが明示形。
- registryの既存URLと4段規則の割れは直していない。単複、末尾形、root / 鍵の違いはmusearch側の別便で裁定する。
- scratchで `対象 Entity が無い` となるサービスは、Entity外の型置き場と route の扱いを別途決める。
- 26 検査1「同じ host に2入口で停止」と付属入口の生成は本便の射程外で未実装。

## 柏木ゲート2の反例

判定は **P0 あり(4件)**。実装は未修正。再現入力・出力・実PGのエラーは `gen/_out/kashiwagi-gate2/`、再実行は `python3 gen/_out/kashiwagi-gate2/evidence/recheck.py`。

1. entry の `prefix` を削除すると生成は exit 0 で、`article_create` の path が `/articles` になる。必須欄の不足を空文字として受け入れている。
2. entry と全 Service の faces を削除すると生成は exit 0 で、faces 不足を一件も診断せず route 表も出ない。
3. root の key が `#(Slug, Title)`、Args が `slug: Slug, title: Title, name: CategoryName` の `category_read` は root を認識せず、exit 0 で `/api/admin/categories/{name}` を出す。plan D5 の複合key照合と3変数停止を満たさない。
4. 順方向 `with: [ArticleToCategory]` は `c.category_id=a.slug`、Multi の `Has(PhotoToLabels, ...)` は `l.id=p.labels_id` を生成して exit 0。どちらも実PGで列不存在となる。本便の4クエリ以外の未対応形も成功扱いせず、正しく生成するか未実装として停止する必要がある。

P1: route の入力ハッシュは Entity を含まず、collection の変更でURLが変わっても同じ値になる。入口負例とSQL関係種別の回帰検査も必要。対象Entity無し・動詞空の警告予定に対する exit 4 は残差として記録する。

## 実行記録

- framework差分: `diff -u ~/yumemism_repo/musearch/framework/src/framework/entry.gleam src/framework/entry.gleam`。Credential / HttpApi / credential() の構造を確認し、yumemi側の差分は prefix と doc の経路調整。
- relation雛形: `src/framework/io.gleam` の `relation_rows` doc commentへ `verify-root-ffi.mjs:201-211` の JS 雛形を写した。`verify-root-ffi.mjs` 自体は変更していない。
- 生成器のJS出力: 追加した生成物は `.gleam` の `face.gleam` と `entry/http.gleam`だけ。生成器から `.mjs` は出していない。
