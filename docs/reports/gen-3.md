# gen-3 の検収と報告

発注は `tech/_drafts/gleam-framework/43-gen-holes.v0.md` 穴 1・2 と、gen-3 の実装指示。検収日は 2026-09-20、branch は `gen-3`。musearch は読み取りだけで、生成先は `gen/build/gen3-musearch.p5Ywux` に置いた。

gen-3 は verb / root / phase を生成束へ足した。入口(`registry` / `faces` / `prefix` / `entry.gleam`)は gen-4 の射程であり、本便では触っていない。

## 3 段の検収

実行したコマンドと証拠:

```
cd gen && gleam test
gleam run -m yumemi_gen -- ~/yumemism_repo/musearch/app build/gen3-musearch.p5Ywux
gleam format build/gen3-musearch.p5Ywux/src/gen
python3 scripts/compare.py build/gen3-musearch.p5Ywux ~/yumemism_repo/musearch/app
scripts/probe-compile.sh ~/yumemism_repo/musearch/app build/gen3-musearch.p5Ywux /tmp/yumemi-gen3-probe-3
```

ログは `gen/build/gen3-final-test-3.txt`、`gen/build/gen3-musearch-run-3.txt`、`gen/build/gen3-compare-3.txt`、`gen/build/gen3-probe-compile-3.txt`、診断は `gen/build/gen3-musearch.p5Ywux/_diagnostics.txt` にある。

| 検収 | 結果 |
|---|---|
| fixture `gleam test` | **47 passed, no failures** |
| 生成 | **522 ファイル**(診断を除く生成物 521)、終了コード 3。`entity/ledger: key 関数が無い` 1 件を notes 集約 |
| 生成物の内訳 | root 81 本、verb SQL 240 本、`src/gen/verb.gleam` 1 本、`src/gen/phase.gleam` 1 本 |
| 警告 | **17 件**。すべて module 名の `_` 前と root Entity の不一致 |
| exit 1 notes | **4 件**。`Has` / `HasNone` 2 件、`with(...)` 2 件 |
| musearch の後状態 | `?? docs/__pycache__/` だけ。その他の差分 0 |

上記の生成本数・束の比較・`*-3.txt` は初回検収の基準である。47 tests は phase 構成子修正後の値であり、初回ログの値ではない。

ゲート2で `eb76bef` と musearch `fe7c53f6660b6ae6f9ace5a9c4772579207f70a3` を再検証した実測は、生成539ファイル(診断込み)、probe基準0・段1/2/3が192/103/102、phase由来のerrorは0件だった。fan/museの生成phase moduleも隔離projectでコンパイルを確認した。以下の旧基準の31は34からphaseの3件を引いた比較値で、最新基準の再実測値ではない。

この最新基準の内訳はroot 92本、reads 67本、verb SQL 241本(create 33 / update 165 / advance 10 / delete 33)、警告21件、draft参照33本中のmodule不在13本。以下のroot 81・verb SQL 240・警告17・draft不在16という旧基準の集計と分けて扱う。

最新probe段3の102件をすべてService側の未追従とは扱えない。ログで場所を特定できる行は `src/gen/verb.gleam` 71箇所と `src/service/*` 30箇所で、生成verbにはdraft不在に加えて引数重複、import・型名衝突、型引数欠落がある。phaseの3件が消えたことだけでは生成束の成立を示さない。これらとSQL実行・FFI接続の欠陥はゲート2のP0として返す。

検証ログは `/home/yumemism/.codex-agents/runs/niekawa-20260920-015538-60185-849/evidence/gate2/` の `gleam-test.txt`、`musearch-run.txt`、`compare.txt`、`probe.txt`、`phase-build.txt`。SQL実行とFFI接続に関するゲート2の所見は同runの `gate2.md` に記録する。

### 束ごとの diff

完全一致はバイト一致、本文一致は先頭の `GENERATED` 行を外して空白を詰めた一致。束 2 は生成側が 3 module、手書き側が 1 module なので行数と variant で数えた。

| 束 | 生成 | 手書き | 両側にある | 完全一致 | 本文一致 | 不一致 | 生成器だけ | 手書きだけ |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 `src/gen/types/*.gleam` | 83 | 83 | 83 | 0 | 78 | 5 | 0 | 0 |
| 2 `src/gen/query*` | 542 行 / 3 本 | 369 行 / 1 本 | — | — | — | 3 手書き行 / 170 生成行 | — |
| 3 `src/gen/reads/*.gleam` | 63 | 37 | 35 | 0 | 0 | 35 | 28 | 2 |
| 4 `gen/sql/queries/<service>/<name>.sql` | 49 | 47 | 39 | 0 | 20 | 19 | 10 | 8 |
| 5 `src/gen/verb.gleam` | 1 | 1 | 1 | 0 | 0 | 1 | 0 | 0 |
| 6 `gen/sql/queries/verb/*.sql` | 240 | 61 | 28 | 0 | 1 | 27 | 212 | 33 |
| 7 `src/gen/root/*.gleam` | 81 | 81 | 81 | 0 | 42 | 39 | 0 | 0 |
| 8 `src/gen/phase.gleam` | 1 | 1 | 1 | 0 | 0 | 1 | 0 | 0 |

束 2 の variant は、From `33 / 29 / 28 / 5 / 1`、Field `276 / 202 / 202 / 74 / 0`、Arrow `38 / 6 / 5 / 33 / 1`、Operand `48 / 11 / 11 / 37 / 0`、Cond 以下の残り 9 型は生成・手書きが同数で手書きだけ 0。順に「生成 / 手書き / 両方 / 生成だけ / 手書きだけ」である。

### probe-compile

```
基準(手書きの ▲ そのまま)                         0
段1: 8束を生成物へ差し替え                      121
段2: from./field. へ機械置換後                   35
段3: gen/types の手書き関数を戻した後            31
```

段 3 の **31** は旧 gen-3 検収基準での比較値で、修正前の 34 行から `src/gen/phase.gleam` 由来の **3 件**(Duplicate definition 1 + Type mismatch 2)を除いた。gen-2 報告の段 3 は 17 だったため、数字は **+14**。current musearch main は後発変更を含むため、live probe の全体値はこの基準へ混ぜていない。別集計の既知分として、生成した `src/gen/verb.gleam` は key を持つ Entity 33 本から `gen/draft/*` を 33 参照し、そのうち **16 Entity の draft module が musearch に無い**。この 16 は既知の参照先欠落として数え、今回の 31 error 行へ重複加算していない(ビルドが先に到達した型エラーのため、16 本が独立した error 行としては出ていない)。

## gen-2 からの増減

| 指標 | gen-2 | gen-3 | 増減 |
|---|---:|---:|---:|
| fixture passed | 33 | **47** | **+14** |
| 生成ファイル | 126 | **522** | **+396** |
| types の両側対象 | 61 | **83** | +22 |
| query 生成行 | 414 | **542** | +128 |
| reads の両側対象 | 22 | **35** | +13 |
| 読み SQL の両側対象 | 29 | **39** | +10 |
| probe 段 1 → 段 2 → 段 3 | 162 → 22 → 17 | **121 → 35 → 31** | — → +13 → +14 |

gen-3 の増分 396 ファイルのうち、verb SQL 240、root 81、verb 1、phase 1 が新束である。残りは Entity / Service の増加と root 相対 read の追加である。

## verb SQL の本数と穴 1 の 25 本

musearch の Entity には `verbs` 宣言が無い。したがって生成器が musearch から読んだ verb SQL は、基礎 4 規則だけで出している。生成物 240 本の内訳は `create` 33、`update` 165、`advance` 9、`delete` 33。`ordered_by` / `upsert_key` / 追加 `verbs` 宣言は musearch 側に無いので、生成物側にはまだ `reorder_*` / `put_*` / 名前付き Update の束は出ていない。

手書き SQL 61 本との同名比較は 28 本が両側にあり(本文一致 1、不一致 27)、生成器だけ 212、手書きだけ 33 だった。これは「4 規則で生成できる意味上の本数」と「手書き SQL の同名」を同じ数字にしてはいけないため分けている。

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

## 警告 17 件と root 不一致 15 本

手書き root の不一致 15 本と生成器 warning 17 件の共通部分は 13 本。

- 生成器だけの 4 本: `space_edit`, `space_hide`, `space_remove`, `space_show`
- 手書き側だけの 2 本: `metrics_muse`, `link_import_apply`
- 差は `+4 - 2 = +2`。したがって手書き 15 本に対して生成器の warning は 17 件になる

共通 13 本は `article_list`, `heaven_embed_code`, `heaven_unlink`, `link_list`, `notification_fanout`, `pageview_record`, `roster_list`, `space_list`, `store_schedule_delete`, `store_schedule_put`, `subscription_add`, `subscription_read`, `widget_list`。

## 残差(閉じないもの)

- `pageview_record`: root が Entity でない `Browser`。現行の allow Entity + Args key 規則だけでは閉じない。
- `phase.gleam`: 生成側の構成子は Entity 修飾(`ArticleDraftToPublished`)で、手書き musearch の構成子(`DraftToPublished`)とは命名が異なる。意味は対応するが、文字列差分は残る。
- Root の余分な欄 3 種: `article_read` の `muse`、`article_pin` の `slot_count`、`pageview_record` の `browser`。
- `gen/draft/*`: 生成器は draft module をまだ出さない。key を持つ 33 Entity のうち 16 Entity は musearch 側にも参照先が無い。
- 入口全般: `registry` / `faces` / `prefix` / `entry.gleam` は gen-4。
- 今回の exit 1 notes 4 件: `store_schedule_list/all_slots` の `Has` / `HasNone`、`store_schedule_list/public_slots` の `Has` / `HasNone`、`store_roster_list/mine` の `with(...)`、`roster_list/listed` の `with(...)`。
- gen-2 系の残差では、複合 key の query/SQL (`G3`) と、`with` / `Has` / `HasNone` など語彙・SQL不足 (`G5`) が残る。gen-2 の From/Field module 分割 (`G4`) 自体は `from.` / `field.` の機械置換で閉じた。

## 未決

1. 穴 1 の 25 verb 名と実 SQL 61 本の対応を、関数単位で数えるのか SQL ファイル単位で数えるのか決める。
2. `Update` の NULL クリア、複数 scope の `Order`、upsert の parent/phase guard、発行結果型を追加語彙にするか、Service の Logic に残すか決める。
3. `pageview_record` と Root 余分欄 3 種を gen-3 の例外として固定するか、root 宣言を gen-4 で拡張するか決める。
4. 16 Entity の draft module を別便で補うか、verb の型参照を生成器の外へ移すか決める。

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
