# gen-3 の検収と報告

発注は `tech/_drafts/gleam-framework/43-gen-holes.v0.md` 穴 1・2 と、gen-3 の実装指示。検収日は 2026-09-20、branch は `gen-3`。musearch は読み取りだけで、生成先は `gen/build/r7-final-musearch-SmGAmt` に置いた。

gen-3 は verb / root / phase を生成束へ足した。入口(`registry` / `faces` / `prefix` / `entry.gleam`)は gen-4 の射程であり、本便では触っていない。

## 3 段の検収

実行したコマンドと証拠:

```
cd gen && gleam test
gleam run -m yumemi_gen -- ~/yumemism_repo/musearch/app build/r7-final-musearch-SmGAmt
scripts/probe-compile.sh ~/yumemism_repo/musearch/app build/r7-final-musearch-SmGAmt build/r7-final-probe3-ED75Rj
node scripts/verify-root-ffi.mjs build/r7-final-musearch-SmGAmt
PGHOST=127.0.0.1 PGPORT=55432 PGUSER=yumemism PGDATABASE=postgres node scripts/verify-gate2-sql.mjs build/r7-final-musearch-SmGAmt build/r7-final-article-5pU9D8 build/r7-final-flag-NbY0FD
```

ログは `build/gleam-test-r7-final.txt`、`build/musearch-run-r7.txt`、`build/probe-r7-final.txt`、`build/root-ffi-r7.txt`、`build/gate2-sql-r7.txt`、`build/sql-service-name-r7.txt`、診断は `gen/build/r7-final-musearch-SmGAmt/_diagnostics.txt` にある。

| 検収 | 結果 |
|---|---|
| fixture `gleam test` | **52 passed, no failures** |
| 生成 | **572 ファイル**(診断を除く生成物 571)、終了コード 3。`entity/ledger: key 関数が無い` 1 件を notes 集約 |
| 生成物の内訳 | draft 33 本、root 81 本、verb SQL 241 本、`src/gen/verb.gleam` 1 本、`src/gen/phase.gleam` 1 本 |
| 警告 | **21 件**。すべて module 名の `_` 前と root Entity の不一致 |
| exit 1 notes | **4 件**。`Has` / `HasNone` 2 件、`with(...)` 2 件 |
| musearch の後状態 | **未変更**。生成先と隔離 probe だけへ書き込み |

上記の生成本数と `r7` ログを今回の基準とする。52 tests は生成結果などを検査する Gleam test の件数である。PostgreSQL / Context の実行検査は別の Node スクリプトであり、この52件には含まれない。

今回の実測は probe 基準0・段1/2/3が **338/134/129**。段3の `src/gen/verb.gleam` / `src/gen/phase.gleam` / `src/gen/draft/*` / `src/gen/reads/*` 由来 error は **0件**で、残る129件は Service 側の未追従である。生成 verb の draft参照は33 moduleを生成し、Entity alias・同名 Kind・Property 型引数も probe の対象から消えた。root read の既存検証は実 `makeContext` に検証側で作った resolver を渡したもの。生成 read と実 Entity の検証では `Muse` の代わりに `Held(Muse)` が返り、P0-5 / G2 は未閉鎖である。

検証ログは `build/gleam-test-r7-final.txt`、`build/musearch-run-r7.txt`、`build/probe-r7-final.txt`、`build/gate2-sql-r7.txt`、`build/root-ffi-r7.txt`、`build/sql-service-name-r7.txt`。初回ゲート2の所見は `/home/yumemism/.codex-agents/runs/niekawa-20260920-015538-60185-849/evidence/gate2/gate2.md` に残し、今回の実行証拠は `build` と `gen/build` に置いた。

### 束ごとの diff

完全一致はバイト一致、本文一致は先頭の `GENERATED` 行を外して空白を詰めた一致。束 2 は生成側が 3 module、手書き側が 1 module なので行数と variant で数えた。

| 束 | 生成 | 手書き | 両側にある | 完全一致 | 本文一致 | 不一致 | 生成器だけ | 手書きだけ |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 `src/gen/types/*.gleam` | 83 | 83 | 83 | 0 | 78 | 5 | 0 | 0 |
| 2 `src/gen/query*` | 542 行 / 3 本 | 369 行 / 1 本 | — | — | — | 3 手書き行 / 170 生成行 | — |
| 3 `src/gen/reads/*.gleam` | 63 | 37 | 35 | 0 | 0 | 35 | 28 | 2 |
| 4 `gen/sql/queries/<service>/<name>.sql` | 49 | 47 | 39 | 0 | 20 | 19 | 10 | 8 |
| 5 `src/gen/verb.gleam` | 1 | 1 | 1 | 0 | 0 | 1 | 0 | 0 |
| 6 `gen/sql/queries/verb/*.sql` | 241 | 61 | 28 | 0 | 1 | 27 | 213 | 33 |
| 7 `src/gen/root/*.gleam` | 81 | 81 | 81 | 0 | 42 | 39 | 0 | 0 |
| 8 `src/gen/phase.gleam` | 1 | 1 | 1 | 0 | 0 | 1 | 0 | 0 |

束 2 の variant は、From `33 / 29 / 28 / 5 / 1`、Field `276 / 202 / 202 / 74 / 0`、Arrow `38 / 6 / 5 / 33 / 1`、Operand `48 / 11 / 11 / 37 / 0`、Cond 以下の残り 9 型は生成・手書きが同数で手書きだけ 0。順に「生成 / 手書き / 両方 / 生成だけ / 手書きだけ」である。

### probe-compile

```
基準(手書きの ▲ そのまま)                         0
段1: 8束を生成物へ差し替え                      338
段2: from./field. へ機械置換後                  134
段3: gen/types の手書き関数を戻した後           129
```

段3 の **129** は、生成束を実物へ差し替えた後に残る Service 側の未追従である。生成器は `src/gen/draft/*.gleam` を33本出し、probe は既存 draft の固有 constructor を保ったまま不足 module と Created 型を補う。`src/gen/verb.gleam` と `src/gen/phase.gleam` の error 行は 0 件で、P0-6 の対象を残差へ重複加算していない。

### ゲート2 P0 の再検証

| 対象 | 実測 |
|---|---|
| P0-1 複合 key の `version` | SQL 実行で対象行だけ更新、`version` と sibling/version 違いの行は不変 |
| P0-2 `put` | stale version は conflict、put は版を 7→8 に進め、旧版 update は conflict、key/title/phase は不変 |
| P0-3 `reorder` | 非負値の交換・Int上限・競合 rollback は通る。有効な負の Int 値では staging が一意制約違反となり未閉鎖 |
| P0-4 混在 keyset | `2147483647`、NULL、同値列のページ継続で欠落なし |
| P0-5 root FFI | 36本生成。検証側の resolver は通るが、実 Entity と生成 read は `Held` を `Muse` として返すため未閉鎖 |
| P0-7 Draft key | Draft に複合 key / slug が残る。提供 SQL 検査は手書き引数配列。追加監査ではコンパイルした ChunkDraft → 生成 verb → 検証用 PG adapter → SQL → 実 DB を確認 |

証拠は `build/gate2-sql-r7.txt` と `build/root-ffi-r7.txt`、実装は `gen/scripts/verify-gate2-sql.mjs` / `verify-root-ffi.mjs` にある。

追加監査の証拠は `build/gate2c/evidence/`。`root-real.mjs` は生成 read をコンパイルして実 `decodeArticle` / `makeContext` で再現する。`reorder-negative.mjs` は負値衝突と CHECK 違反、`reorder-concurrent.mjs` は同一 scope の2接続でロック待ちと確定値を確認する。

### 巡6 P0 修正の実装境界

- **P0-7**: `Entity.auto_key` の明示宣言を reader が読み、Draft は宣言された key だけ除外する。宣言が無い Article.slug / flag の複合 key は Draft に残る。提供スクリプトは手書き引数配列で create SQL を実行する。型付き複合 key の経路は追加監査の `build/gate2c/evidence/draft-typed.txt` で確認した。musearch runtime の追従を検証したものではない。
- **P0-5 未閉鎖**: framework `io_ffi.mjs` は relation resolver が無い場合に関係値をそのまま返す。実 Entity の Held は key だけを持つため、関係先の取得・復号が未実装。musearch は変更していない。
- **P0-2**: version-bearing put は `target.version = 入力版` を conflict 条件にし、成功時だけ `version+1`。changed が 0 行なら framework conflict として transaction を abort する。
- **P0-3**: reorder は `reorder_*_stage` で負の一時値へ退避し、続く `reorder_*` で要求値を確定する compound verb。同一 transaction の UNIQUE 衝突は rollback され、上限値への加算はしない。ただし負の一時値は有効な Int 値と衝突し、非負 CHECK がある場合も失敗するため P0-3 は未閉鎖。

今回の再測定(`7812b47`、musearch `fe7c53f`)では、既存の Created 型付き Draft を保持した probe 段3は **129**、Draft 全量置換は **162**。いずれもエラーの主位置は Service のみで、生成ファイルの主位置は0件。旧稿の全量置換140は今回の値ではない。証拠は `build/gate2c/evidence/probe.txt` と `full-draft-build.txt`。

## gen-2 からの増減

| 指標 | gen-2 | gen-3 | 増減 |
|---|---:|---:|---:|
| fixture passed | 33 | **52** | **+19** |
| 生成ファイル | 126 | **572** | **+446** |
| types の両側対象 | 61 | **83** | +22 |
| query 生成行 | 414 | **542** | +128 |
| reads の両側対象 | 22 | **35** | +13 |
| 読み SQL の両側対象 | 29 | **39** | +10 |
| probe 段 1 → 段 2 → 段 3 | 162 → 22 → 17 | **338 → 134 → 129** | — → +112 → +112 |

gen-3 の増分 446 ファイルのうち、draft 33、verb SQL 241、root 81、verb 1、phase 1 が新束である。残りは Entity / Service の増加と root 相対 read の追加である。

## verb SQL の本数と穴 1 の 25 本

musearch の Entity には `verbs` 宣言が無い。したがって生成器が musearch から読んだ verb SQL は、基礎 4 規則だけで出している。生成物 241 本の内訳は `create` 33、`update` 165、`advance` 10、`delete` 33。`ordered_by` / `upsert_key` / 追加 `verbs` 宣言は musearch 側に無いので、生成物側にはまだ `reorder_*` / `put_*` / 名前付き Update の束は出ていない。

手書き SQL 61 本との同名比較は 28 本が両側にあり(本文一致 1、不一致 27)、生成器だけ 213、手書きだけ 33 だった。これは「4 規則で生成できる意味上の本数」と「手書き SQL の同名」を同じ数字にしてはいけないため分けている。

穴 1 の一覧は verb 関数名ベースの 25 本である。`Update` の生成名は `<name>_<entity module>`、`DeleteWhere` は `delete_<entity module>_by_<field>`、`CreateMany` は `create_<collection>`、`ordered_by` は `reorder_<collection>`、`upsert_key` は `put_<entity module>` になる。

| 名前 | 出せる宣言 | 判定 |
|---|---|---|
| `pin_article` | `Update(name: "pin", fields: ["slot"], at: Only([Published]))` | 名前と phase gate は出せる。現物の `Slot` / NULL 解除との型差は残る |
| `unpin_article` | `Update(name: "unpin", fields: ["slot"], at: Only([Published]))` | 名前は出せるが、引数なしで `slot=NULL` にする規則は書けない |
| `schedule_article` | `Update(name: "schedule", fields: ["publish_at"], at: Only([Draft]))` | 名前と単一 Property 更新は出せる。現物の Option/返却契約は別 |
| `unschedule_article` | `Update(name: "unschedule", fields: ["publish_at"], at: Only([Scheduled]))` | NULL へ戻す引数なしの意味は書けない |
| `replace_chunks` | なし | 複数行 delete + insert、version、`jsonb_to_recordset` の一手は語彙外 |
| `reorder_links` | `ordered_by: Order(field: "order", within: "muse")` | 基本の並べ替えは出せる |
| `reorder_widgets` | `ordered_by: Order(field: "order", within: "muse")` | `space` も束ねる二重 scope は `Order` 1 欄では書けない |
| `reorder_free_spaces` | `ordered_by: Order(field: "order", within: "muse")` | 基本の並べ替えは出せる |
| `reorder_rosters` | `ordered_by: Order(field: "order", within: "store")` | 基本の並べ替えは出せる |
| `mark_notification_read` | `Update(name: "mark_read", fields: ["read_at"])` が近い | 出力名は `mark_read_notification` になり、現物名を出せない |
| `record_page_view` | なし | Browser/Visit の dedupe、rate limit、複数表 INSERT は語彙外 |
| `link_store_ledger` | `Update` が近い | `ledger_store` 更新は表せるが、現物名の順序・NULL guard は表せない |
| `issue_store_api_key` | `Update` が近い | 2 列更新は表せるが、現物名、発行結果、secret 境界は表せない |
| `revoke_store_api_key` | `Update` が近い | NULL クリアを引数なしで表せず、現物名も出せない |
| `issue_roster_code` | `Update` が近い | 2 列更新は表せるが、phase/期限/発行結果の契約は語彙外 |
| `claim_roster` | なし | relation 更新、claim code/期限/party の複合 guard は `Update` で書けない |
| `unclaim_roster` | なし | relation と party を NULL に戻す複合操作は書けない |
| `put_roster_photo` | `upsert_key: ["roster", "order"]` | `put_roster_photo` の基本 upsert は出せる。active roster guard は残る |
| `put_store_schedule` | `upsert_key: ["roster", "date", "starts_at"]` | 基本 upsert は出せる。既存 slot の削除と parent/phase/party guard は残る |
| `rollup_day` | なし | PageView/Visit を横断する集計 batch は語彙外 |
| `rollup_month` | なし | PageView/Visit を横断する集計 batch は語彙外 |
| `purge_page_views` | なし | Browser/Visit/PageView を横断する保全付き purge は語彙外 |
| `create_links` | `CreateMany` | `create_links` の名前と List 作成は出せる。guarded insert は残る |
| `delete_chunks` | `DeleteWhere(field: "article")` が近い | relation は現 validator が拒否し、名前も `delete_chunk_by_article` になる |
| `delete_widgets_by_heaven` | `DeleteWhere(field: "heaven")` が近い | relation の parent delete と複数形の名前は現語彙で出せない |

ここには現物との不一致がある。穴 1 の 25 名のうち `mark_notification_read` は `src/gen/verb.gleam` にはあるが `gen/sql/queries/verb/` の SQL ファイルには無い。一方、実際の SQL 61 本には `lock_store_schedule`、`pageview_browser`、`pageview_duplicate`、`pageview_visit_insert`、`pageview_visit_update`、`update_muse_profile`、`update_roster_by_external`、`update_roster_profile`、`update_widget_values` があり、穴 1 の一覧に無い。25 名と 61 SQL の対応は未決で、数字を黙って一致させていない。

## 警告 21 件と root 不一致 15 本

手書き root の不一致 15 本と生成器 warning 21 件の共通部分は 13 本。

- 生成器だけの 4 本: `space_edit`, `space_hide`, `space_remove`, `space_show`
- 手書き側だけの 2 本: `metrics_muse`, `link_import_apply`
- 差は `+8 - 2 = +6`。したがって手書き 15 本に対して生成器の warning は 21 件になる

共通 13 本は `article_list`, `heaven_embed_code`, `heaven_unlink`, `link_list`, `notification_fanout`, `pageview_record`, `roster_list`, `space_list`, `store_schedule_delete`, `store_schedule_put`, `subscription_add`, `subscription_read`, `widget_list`。

## 残差(閉じないもの)

- `pageview_record`: root が Entity でない `Browser`。現行の allow Entity + Args key 規則だけでは閉じない。
- `phase.gleam`: 生成側の構成子は Entity 修飾(`ArticleDraftToPublished`)で、手書き musearch の構成子(`DraftToPublished`)とは命名が異なる。意味は対応するが、文字列差分は残る。
- Root の余分な欄 3 種: `article_read` の `muse`、`article_pin` の `slot_count`、`pageview_record` の `browser`。
- `gen/draft/*`: 33 Entity 分を生成する。musearch の既存 draft に固有 constructor がある場合は、probe では既存束を保持しつつ不足 module / Created 型だけを補っている。
- 入口全般: `registry` / `faces` / `prefix` / `entry.gleam` は gen-4。
- 今回の exit 1 notes 4 件: `store_schedule_list/all_slots` の `Has` / `HasNone`、`store_schedule_list/public_slots` の `Has` / `HasNone`、`store_roster_list/mine` の `with(...)`、`roster_list/listed` の `with(...)`。
- gen-2 系の残差では、複合 key の query/SQL (`G3`) と、`with` / `Has` / `HasNone` など語彙・SQL不足 (`G5`) が残る。gen-2 の From/Field module 分割 (`G4`) 自体は `from.` / `field.` の機械置換で閉じた。

## 未決

1. 穴 1 の 25 verb 名と実 SQL 61 本の対応を、関数単位で数えるのか SQL ファイル単位で数えるのか決める。
2. `Update` の NULL クリア、複数 scope の `Order`、upsert の parent/phase guard、発行結果型を追加語彙にするか、Service の Logic に残すか決める。
3. `pageview_record` と Root 余分欄 3 種を gen-3 の例外として固定するか、root 宣言を gen-4 で拡張するか決める。

## 20-programming-model.md への記述案

Entity の書く操作は、Service の apply 呼び出しや SQL の名前から逆算せず、Entity の宣言を一度だけ読む。基礎の create / delete / Property の update / Lifecycle の advance は Entity の型・Property・Lifecycle から機械的に出る。個別の取り決めが基礎規則と違うときだけ、同じ Entity module に `verbs` を置く。

`Rule(phase)` は名前付きの Property 更新、Lifecycle の版更新、列を条件にした集合削除、集合作成を表す。`Update` の `at` は `AnyPhase` または `Only([Phase, ...])` で gate を指定し、`Advance` の `bump` は `Always` または `BumpUnless(From, To)` で版の増分を指定する。`DeleteWhere` は relation ではない Property に限り、`CreateMany` は Entity の collection 全体を JSON 配列から作る。`AdvanceAll` のように現在の語彙で安全に書けない規則は、近い SQL を推測せず生成器を停止させる。

並び替えと鍵による upsert は Rule の列挙ではなく、Entity の性質として宣言する。`ordered_by` は順序列と一つの所属列を、`upsert_key` は衝突判定に使う Property 列を持つ。生成器は前者から `reorder_<collection>`、後者から `put_<entity>` を出す。

```gleam
import framework/verbs

pub type Phase {
  Draft
  Scheduled
  Published
}

pub const verbs: List(verbs.Rule(Phase)) = [
  verbs.Update(
    name: "pin",
    fields: ["slot"],
    at: verbs.Only([Published]),
  ),
  verbs.Advance(bump: verbs.BumpUnless(Scheduled, Draft)),
  verbs.DeleteWhere(field: "title"),
  verbs.CreateMany,
]

pub const ordered_by: verbs.Order = verbs.Order(
  field: "order",
  within: "category",
)

pub const upsert_key: List(String) = ["category", "order"]
```

この断片で、`Update` / `Advance` / `DeleteWhere` / `CreateMany` の追加手と、`Gate` / `Bump` の条件、`ordered_by` / `upsert_key` の出力先を 20 の Entity 宣言の節に畳める。NULL クリア、複数 scope、cross-Entity batch はこの断片からは導かれず、未決のまま残す。

## 閉じ方 ── 巡 6 で止め、鷹野の検算で閉じた(役員 人見 2026-09-20)

**柏木ゲート 2 は 3 回まで。3 回目にも P0 が出たので便を止め、残りは次便の P1 にする**(役員 人見 2026-09-20 の裁定 ── ゲートが呼んだ P0 は便の中で追い続けるものではない)。巡 7 には入れていない。

鷹野[PDM]の独立検算(2026-09-20 07:20〜、HEAD `9fc36c3`):

| 検算 | 結果 |
|---|---|
| `gleam test`(gen/) | 52 passed |
| musearch への生成 | exit 3(`entity/ledger` の key 無し、既知の note)、572 ファイル、verb SQL 241 本、root 92 本 |
| 生成 SQL に Service 名 | 0(リテラル集合と Service 名 92 本の共通が空)。advance の引数は最大 `$5` |
| `verify-gate2-sql.mjs`(真壁の PG 16) | P0-1 / 2 / 3(値確定・Int 上限・rollback)/ 4 / 5(rootArrow の復号)/ 7 の 6 項目 PASS |
| 柏木 3 回目の再現 `reorder-negative.mjs` | **再現した**(P0-3 未閉鎖) |
| 柏木 3 回目の再現 `root-real.mjs` | **再現した**(P0-5 未閉鎖、G2 未閉鎖) |

**次便(gen-4)へ P1 として渡すもの:**

- P0-3 → P1: `reorder` の交換方式。負の一時値は順序列が制限なし Int のとき実値と衝突する(23505)、非負 CHECK でも落ちる(23514)。宣言の値域・制約と整合する方式に替えるか、対応不能な宣言は生成時に名指しで止める
- P0-5 → P1: root 相対 read が `Held`(key だけ)を Entity として継続関数へ渡し、関係先の取得・復号をしない。真壁の `verify-root-ffi.mjs` は検証側で作った resolve() を呼んでいて経路を外していた。framework の Context 契約として実装し、実 `makeContext` / decode で検証する
- 継続:probe 段 3 の Service 側 error 129(手書き未追従、musearch 追随便)、draft module 不在、musearch main `fe7c53f` への前進、上記「未決」3 点

## gen-3b ── 残 P0 2 件を閉じた(役員 人見 2026-09-20 の指示、鷹野[PDM] → 庵野[EXP])

**役員 人見 2026-09-20 の指示で、gen-4 へ送らず gen-3b で閉じた。**贄川も柏木のゲートも挟まず、閉じるのは鷹野の検算。branch は `gen-3b`(main `9091c02` から)、musearch は `fe7c53f` を読むだけ。作業は 2026-09-20 18:30〜、PG 16 は自前で initdb して 55432 に立て、終わったら止めた。

### 何を変えたか

| 対象 | 変更 |
|---|---|
| `src/framework/io.gleam` / `io_ffi.mjs` | `root_arrow` / `rootArrow`(名前推測 + 関係値の素通し)を消し、**Context の契約 `relation`** に置き換えた。`io.Relation`(service / query / arrow / from / prop / target)と `relation_one` / `relation_option` / `relation_many` の 3 本。JS 側は `context.relation(relation, keys)` を要求し、無ければ **`relation_contract` で名指しで落とす**(Held を Entity として渡す経路が無い)。戻りの本数が鍵の数と違えば同じ code で落とす |
| `src/framework/er.gleam` | `Multi(entity)`(`Multi(List(Key))`、20 の形)と `of_multi` / `multi_from_rows` を足した。gen-3 まで framework に無かった(40 の指摘) |
| `gen/.../emit/reads.gleam` | 矢印の read は **`const to_<prop>_relation = io.Relation(...)`** を宣言から写し、root の欄を型付きで参照して鍵を取り出す(`er.to_string(er.of_held(it.article.muse))` / `option.map(it.widget.space, fn(held) {...})` / `list.map(er.of_multi(it.article.tags), er.to_string)`)。形は Has / Held → `relation_one`、Link / Option(Has・Held) → `relation_option`、Multi → `relation_many` |
| `gen/.../emit/sql.gleam` | 矢印 1 本につき SQL 1 文 **`gen/sql/queries/<service>/to_<prop>.sql`**(鍵の jsonb 配列 → 関係先の行、鍵の順)。実行側はこれを `relation` で流す。複合 key の Entity へ向く矢印は exit 1 で止める |
| `gen/.../emit/verb.gleam` | `reorder_*_stage` の一時値を **負値から「宣言の値域の上端から下へ、範囲(scope)の現在値と確定値の帯を避けた空き値」** に替えた。範囲は `FOR UPDATE` で押さえる。`reorder_*` の確定値は値域の起点から(`Int` は 0、`Range(min:, max:)` は min) |
| `gen/.../reader.gleam` / `model.gleam` | `Range(min:, max:)` の両端を `ValueType.range` に読む(桁区切り `_`、負数も)。**`ordered_by.field` が Int / Range の必須列でない宣言は exit 4 で名指しで止める**(文字列・Option・List・値域に起点が入らない Range)。関係の `List(Has/Held/Link)` は「Multi で宣言する」で止める |
| fixtures | `relation`(photo_read:Held / Link / Multi、`order: Range(1, 10)`)、`relation_text_order` / `relation_option_order`(止まる 2 例)。既存 fixture は触っていない |
| scripts | `verify-root-ffi.mjs` を柏木の `root-real.mjs` の経路へ作り替え、`verify-gate2-sql.mjs` に P0-3 の一式と Range の列、矢印 SQL を足した。柏木の再現 4 本は `gen/scripts/gate2c/`(接続先と生成物の在処を環境変数にしただけ、`run.sh` で一括) |

### 方式の根拠

**P0-3(reorder)。**一意制約 `(within, order)` が deferrable でないとき、確定値を 1 文で入れると行ごとの検査で衝突する。だから退避が要るが、負の一時値は「順序列が制限なし `Int`」の実値と衝突し(23505)、非負 CHECK でも落ちる(23514)── 柏木 3 回目の再現。**生成器が知っている値域は宣言だけ**(`Int` なら int4 の全域、`Range` なら両端。DB の CHECK は生成器から見えない)ので、一時値は宣言の値域の中で選ぶ。上端から下へ選ぶのは、実務の CHECK が `>= 0` / `>= 1` の形で、上端側は宣言と DB で食い違いにくいから。窓は `held + 2N + 1` 個 ── 範囲の現在値が最大 `held` 個、確定値の帯 `[first, first+N)` を除いても鳩の巣で N 個以上の空きが残る。確定値の帯を除くのは、退避先が確定値と同じだと確定の 1 文で(退避中の別の行と)衝突するから(試作で実測)。**値域が窓より狭くて空きが足りないときは退避せず確定へ進む** ── UNIQUE が無ければ通り、あれば 23505 で rollback(Range(1,10) に 6 行のとき、検算に含めた)。それ以上は deferrable 制約の領分で、生成器では書けない。`FOR UPDATE` は同一 scope の同時実行を直列にし、2 本目が確定後の値で空きを選べるようにする(柏木の `reorder-concurrent` は Lock 待ちのまま PASS)。

**P0-5(root read)。**framework は表も列も復号関数も知らない(それらはアプリの codec / runtime の持ち物)ので、関係先の取得・復号は **Context の契約** として要求し、framework は (1) 宣言の名前を渡す、(2) 鍵の取り出しを型付きの生成 Gleam で行う、(3) 本数と形(One / Option / List)を検査する、(4) 契約が無ければ名指しで落とす、を持つ。名前推測(`arrowProperty`)は消えた。**musearch の runtime(`fe7c53f`)はこの契約を未実装**なので、実 `makeContext` そのままでは framework が `relation_contract` で落ちる(= 柏木の `root-real` が「再現しない」形)。復号まで通す検算は、実 `makeContext` に契約の相手側 1 関数(生成 SQL を `db.query` に流し、実 `codec.decodeMuse` 等で復号)を足して行った ── 検証側が resolve() を自作して経路を外すのではなく、契約が要求する runtime 側の最小形。musearch の runtime へ `relation` を足すのは追随便。

### 検算の数字(2026-09-20、HEAD は commit を参照)

実行したコマンド(生成先は scratchpad、PG は `127.0.0.1:55432` の自前 PG 16.15):

```
cd gen && gleam test
gleam run -m yumemi_gen -- fixtures/article <article-out>        # 53 ファイル(45 + 矢印 SQL 8)
gleam run -m yumemi_gen -- fixtures/flag <flag-out>              # 27 ファイル
gleam run -m yumemi_gen -- fixtures/relation <relation-out>      # 37 ファイル
gleam run -m yumemi_gen -- ~/yumemism_repo/musearch/app <musearch-out>
scripts/probe-compile.sh ~/yumemism_repo/musearch/app <musearch-out> <probe>
PGHOST=127.0.0.1 PGPORT=55432 PGUSER=yumemism PGDATABASE=postgres node scripts/verify-gate2-sql.mjs <musearch-out> <article-out> <flag-out> <relation-out>
PGHOST=... node scripts/verify-root-ffi.mjs <musearch-out> <relation-out> <work>
PGHOST=... scripts/gate2c/run.sh <musearch-out> <article-out> <flag-out> <relation-out> <work>
```

| 検算 | 結果 |
|---|---|
| `gleam test` | **59 passed, no failures**(52 + 7:矢印 SQL、Relation 契約、3 形、Int 値域、Range 値域、止まる 2 例、Range の読み) |
| musearch への生成 | **629 ファイル**(572 + 矢印 SQL 57)、exit 3(`entity/ledger` の key 無し、既知)、警告 21、exit 1 の notes 4(gen-3 と同じ)。verb SQL 241、root 92、reads 67(矢印を持つ module 36)、draft 33 |
| 生成 SQL に Service 名 | verb SQL のリテラル ∩ Service 名 92 = **0**。全 SQL 本文(ヘッダ行を除く)でも 0。advance の引数は最大 `$5` |
| probe-compile | 基準 0、段 1/2/3 **338 / 134 / 129**(gen-3 と同じ)、生成ファイル起点の error **0** |
| `verify-gate2-sql.mjs` | **7 行 PASS**:P0-1 / P0-7 / P0-2 / **P0-3(交換・Int 上限・負値・両端値(int4 下限と上限が同居)・上端に詰まった scope・別 scope 不変・不明 id は 'conflict' で rollback・部分並べ替えの UNIQUE 衝突は 23505 で rollback・非負 CHECK・同一 scope 同時実行は Lock 待ちで最終値一致)** / **P0-3 Range(1,10)(逆順・上端詰まり・5/10 行・6/10 行の飽和は UNIQUE ありで 23505 rollback、無しで通る)** / P0-5(矢印 SQL:uuid / text の鍵、鍵の順、無い鍵は 0 行)/ P0-4 |
| `verify-root-ffi.mjs` | **8 checks PASS**:(a) 契約の無い実 makeContext → `relation_contract` で拒否、継続関数 0 回、db 0 回、(b) Held(Muse) → 実 `decodeMuse` → `Muse` が `fn(Muse)` に届く(db 1 回、key `article_read/to_muse`、params は鍵 1 個の jsonb)、(c) 行の無い Held → `expected 1 target row(s), found 0` で拒否、(d) 実 `decodeWidget` の `Option(Held)` Some → `Some(FreeSpace)` / `Some(MuseHeaven)`、(e) None → None で db 0 回、(f) fixture:Held → Album、Link → Some(Shelf)、Multi → List(Label) が鍵の順(L22,L21,L23)、(g) Link None / 空 Multi は読まずに None / []、(h) Multi の欠けは拒否 |
| 柏木の再現 `reorder-negative.mjs` | **再現しない**:`a=-1,b=-2` に `[b,a]` → 退避 → 確定 → **`b=0, a=1` で COMMIT**(要求値そのもの)。script の `assert.equal(code,'23505')` が落ちて exit 1 |
| 柏木の再現 `root-real.mjs` | **再現しない**:実 `decodeArticle` + 実 `makeContext` で `interpret` が `relation_contract`「Context does not implement relation(relation, keys)」で reject、`REPRODUCED` の行は出ない、exit 1 |
| 柏木の `reorder-concurrent.mjs` / `draft-typed.mjs` | どちらも PASS(2 本目の Lock 待ちと最終値 `a=0,b=1`、`(11,7,1)` の保存) |
| musearch の後状態 | `git status --short` は前後とも `?? docs/__pycache__/` のみ |
| `git diff --check` | 指摘なし |

### 残るもの(gen-3b で閉じない)

- musearch の runtime に `relation(relation, keys)` を足す(生成 SQL `to_<prop>` を `SQL[service/query]` で引き、`target` の復号関数で復号する 1 関数)── musearch 追随便。手書き `reads/article_read.gleam` の `then(it.muse)` と Root の余分な欄 `muse` は、それまで手書きのまま
- 値域が飽和した scope の reorder(空きが N 個無いとき)は、UNIQUE ありなら 23505。deferrable 制約でしか閉じない
- 宣言の値域より狭い DB の CHECK(★ と DDL の食い違い)は生成器から見えない。DDL 生成が入るまでは運用で合わせる

### 20 への記述案

矢印の read は「root の個体から ER の矢印を辿る」の生成関数(`reads.to_category(it)`)で、**関係値には鍵しか無いので、関係先の取得と復号は実行側の Context が契約 `relation` として担う。**生成器は矢印ごとに `io.Relation`(Service・SQL 名・矢印名・元 Entity・Property・先 Entity)を宣言から写し、鍵の取り出しを型付きで書く(`er.of` / `er.of_held` / `er.of_multi`)。出力の形は宣言から決まる ── `Has` / `Held` は `Entity`、`Link` と `Option(Has/Held)` は `Option(Entity)`、`Multi` は `List(Entity)`。framework は契約が無ければ名指しで落とし、鍵と行の本数が違えば落とす。関係先の行は矢印ごとの生成 SQL(`gen/sql/queries/<service>/to_<prop>.sql`、鍵の配列 → 鍵の順の行)で引く。

`ordered_by` の並べ替えは 2 文の compound(退避 → 確定)で、退避の一時値は**宣言の値域の上端から下へ、範囲の現在値と確定値の帯を避けた空き値**、確定値は値域の起点から詰める。順序列は必須の `Int` か `Range` に限り、それ以外の宣言は生成器が止める。一意制約が deferrable でない前提の設計で、値域が飽和した範囲では退避できず、UNIQUE があれば衝突で rollback する。
