# front-1c 真壁 道具の向き直しと報告

## 状態

- branch: `front-1c`。道具と verify の checkpoint は 1 本(`0a5cb99`)へ squash 済み。
  便全体は 真壁 3 本(framework / 面 package / 道具と報告)と 贄川 の P2 2 本。
- `gen/scripts/` の front 4 本だけを backup 枝から写し、面の `www/src` を scratch の
  `src/` へコピーする形にした。`www/src/gen/**` も同時にコピーする。
- `docs/reports/front-1c.md` に 14 型表、v4 → v5、56 差分、数字、P1 / Y2 の申し送りを
  記録した。
- root、gen、musearch の本体・staging・production・push は変更していない。

## DDL

無し。migration / schema 変更は無く、staging / production へ適用していない。

## 検証証拠

- `gleam build`: compile 完了。`build/root-gleam-build-front-1c.txt`
- `cd gen && gleam test`: **86 passed, no failures**。
  `build/gen-gleam-test-front-1c.txt`
- `gleam run -m yumemi_gen -- fixtures/article _out/front-1c-report`:
  **57 files / input units 11**。`build/generate-front-1c.txt`
- `node gen/scripts/verify-front-ssr.mjs`: **ALL PASS**、JS 無し本文、style 1 本・body
  先頭、島 `❤ 1 -> ❤ 13`、browser error 0。
  `build/verify-front-ssr.txt`
- `node gen/scripts/verify-front-isolate.mjs`: **ALL PASS**、40 回、style 長 first 322 /
  second 191、marker 混入 0。`build/verify-front-isolate.txt`

# gen-5 真壁 route 段3 作業結果

## 状態

- branch: `gen-5`。段3をR0〜R5へ変更した。Entityは末尾語の最長一致、ER外moduleは`collection`宣言の完全一致だけで対象を引く。
- scratchpadの87 Serviceは正しく出る82、止まる5。停止は`schedule_add/list/withdraw`の曖昧、`pageview_record`の無一致、`store_roster_list`のR4入れ子。
- mainのmusearchは変更していない。台帳2 + metrics2のcollection宣言、`ledger`改名、参照書換は写しだけに行った。
- route registry突合は`gen/_out/gen-5/scratch/service-table-final.tsv`（87行）と`registry-compare-final.tsv`（98行）。検証器の`silent_mismatch`集計は0、raw URLの末尾形差は別欄。検証器の未知collectionを一致扱いするP1があり、0だけを完全な検出保証とは扱わない（`docs/reports/gen-5.md`）。

## DDL

無し。migration / schema変更は無く、staging / productionへ適用していない。

## 検証証拠

- `gen/build/gen-5-gleam-test-final.txt`: `gleam test` 72 passed, no failures。
- `gen/build/gen-5-probe-scratch-final2.txt`: probe 0 → 333 → 129 → 129。
- `gen/build/gen-5-verify-route-table-final.txt`: route table PASS、7 rows。
- `gen/build/gen-5-verify-gate2-sql-final.txt`: 7 checks PASS。
- `gen/build/gen-5-verify-root-ffi-final.txt`: 8 checks PASS。
- `gen/build/gen-5-audit-final.json`: Service 87、route 326、registry 98、正しく出る82・止まる5。
- ゲート2: `gen/_out/kashiwagi-gate2/route-build.txt` / `compiled-route.txt`。生成route表を独立buildし、コンパイル後の326行・82 Serviceの全フィールドをソースと照合した。probeの129エラーが残るbuildだけではこの確認は成立していなかった。

## gen-4 差分と残差

- 検証器の黙って誤り集計は0（前記P1の限界あり）。gen-4の正しく停止だった台帳2 + metrics2は、mainでは宣言無しで停止し、scratchpadではroute化した。
- 末尾形・単複・prefix・root/key・foldedのregistry差は残差として別欄に保持した。Logic / readsによる曖昧解消、`pageview_record`、`store_roster_list`の扱いは別便。

---

# gen-4 真壁 巡2 作業結果

## 状態

- branch: `gen-4`、開始HEAD: `5d84089550408f014d9e07774428642f7ae4c0a4`。
- 柏木ゲート2のP0 4件を修正した。
- prefix欠落・不正はentry名付きexit 4。faces必須検査はentry不在・entries空でも動く。
- root判定は複合key/path_keyの構成要素を照合し、root 2変数は許可、合計3変数はexit 4。
- SQLは単一FKのHas/Held/Linkに対するHas/HasNoneと、逆向きHeldのwithだけを生成する。順方向withとMultiへのHas/HasNoneは未生成・exit 1。
- NotImplementedだけの診断をexit 0にしていた`stop.worst`をexit 1へ修正した。
- musearch本体と正典ファイルは変更していない。生成器から`.mjs`は出していない。

## DDL

無し。migration / schema変更は無く、staging / productionへ適用していない。

## 検証証拠

- 回帰test: `build/gleam-test-final.txt` ── 68 passed, no failures（61 + 7）。
- 負例CLI: `build/regression-cli-final.txt` ── prefix / entry無し / entries空 / 未知面 / 3変数はexit 4、SQL 2形はexit 1。
- route表: `build/verify-route-table-final.txt` ── PASS、7 rows。
- PG SQL: `build/verify-gate2-sql-final.txt` ── 7 PASS。
- root FFI: `build/verify-root-ffi-final.txt` ── 8 PASS。
- 生成物比較: `build/artifact-comparison-final.txt` ── 本便4 SQLとarticle route表が修正前とbyte一致。
- current musearch: `build/generate-musearch-final.txt` / `build/r2-out/musearch/_diagnostics.txt`。

## 数字

- current musearch: 635 files、faces不足exit 4 = 92、prefix不足exit 4 = 5、exit 1 = 0、exit 3 = 1、warning = 21、`.mjs` = 0。停止コード4。
- fixture article: 55 files、route 7行。
- SQL負例fixture: 23 files、対象SQL 2本は未生成、停止コード1。

## 残差

- current musearchの5入口はprefix未追随、92 Serviceはfaces未追随。生成器は名指しで停止するが、musearch側は本便の書込範囲外。
- entry hashへのEntity追加(P1)、同host 2入口、付属入口、`along` / `FirstPerGroup` / `At` / `KeyOf`は未実装のまま。
- 対象Entity無し・動詞空は既存どおりexit 4を維持した。

---

# 指示 A2 ── P0 4件と仮宣言コピー(2026-09-21)

## 状態

- branch `verb-1`。開始 `eacd8b5`。checkpoint は `9bc9a99` / `69cd3a7`。main・staging・production・musearch本番は変更していない。
- boolean cast、通常 delete の `RETURNING` 除去、Draft/Created由来の create RETURNING、単一 phase gate、Update の完全名と `upsert_key` lookup を実装した。
- `verify-verb-sql` 段1は引用文字列・二重引用識別子・dollar quote の内側を保持して、外側の記号周りだけ正規化する self-test を追加した。
- 仮宣言コピーには手書き11本、E類2本、`reorder_widgets`、`update_roster_by_external` を追加。札3本(`advance_article` / `delete_roster_photo` / `delete_store_schedule`)は生成SQLから消え、headerに11名が出る。

## DDL

無し。gate2 harness の検証用 `article` DDL に `phase` / `entered_draft` と `$7` の試験値を追随させただけ。staging / productionへは適用していない。

## 検証証拠

- `build/a2-gleam-test.txt`: `75 passed, no failures`。
- `build/a2-route-table.txt`: route `7 rows` PASS。`build/a2-gate2.txt`: `7` PASS。`build/a2-root-ffi.txt`: `8` PASS。
- `build/a2-verify-main.txt`: generated `241` / handwritten `61` / both `28` / stage1 `6`。一致名は `delete_free_space`, `delete_link`, `delete_widget`, `update_free_space_title`, `update_free_space_visible`, `update_widget_visible`。
- `build/a2-verify-decl.txt`: generated `231` / both `27` / handwritten-only `34` / stage1 `6`。`reorder_widgets` と `update_roster_by_external` が出力。
- `build/a2-verb-self-test.txt`: quoted literal 不一致、`update_free_space_title` 段1一致の2本 PASS。
- `build/a2-diff.txt`: baselineとの差は `db/queries/verb/` 内だけ(241本、外は0、`Only in`も0)。
- 贄川[ORC]が同じ7検査を独立に再現した(run_dir `niekawa-20260921-054627-1324991-3859/evidence/n2-*.txt`)── `gleam test` 75 / route 7 / gate2 7 / root-ffi 8 / stage1 6 / self-test 2本 PASS / `diff -r`の差は`db/queries/verb/`内だけ。`a2-route-table.txt` / `a2-root-ffi.txt` / `a2-verb-self-test.txt` はその再現の写し。

## 残差

- 手書き側の `*Created` 不一致6本(`create_consent`, `create_muse`, `create_screen_reject`, `create_roster`, `create_article`, `create_muse_heaven`)は★手書きを生成へ寄せるF3。生成器の穴ではない。なお固定 `baseline-out/src/gen/draft/article.gleam` の `ArticleCreated` は実測9欄で、指示書の7欄前提とは不一致。生成は実物のDraft/Createdに合わせて9欄を維持した。
- `advance_muse_heaven` / `advance_roster`: ★ Entity に version/連番入力が無く、handの楽観ロックと bump を導けない。`update_article_posted_on`: generic updateのversion bump規則とhandが不一致。`update_store_verified`: generatorのrequire_rows包みとhandの素UPDATEが不一致。
- `update_muse_theme` は gateまで生成したが、★ Museに `version` Propertyが無いため bumpは推測せず未生成。`create_roster` の claim系欄も `auto_key` 宣言が無いため除外していない。

---

# 指示 A3 ── H 類と欠落キャスト(2026-09-21)

## 状態

- branch `verb-1`。A3 の生成器変更、突合器、gate2 検証ハーネス、fixture test、報告を作業域へ反映した。
- `musearch-main` は読み取りのみ。`musearch-decl` は指定された `free_space` / `link` の `ordered_by` 宣言だけを追加した。
- `create_widget` / `create_free_space` / `create_link` は親 `FOR UPDATE`、within 全列の `IS NOT DISTINCT FROM`、`COALESCE(max(...)+1,0)` を一文の CTE + INSERT で出す。`create_links` は語彙が無いため生成していない。

## DDL

無し。gate2 の一時 schema にだけ `category` 表と `cat` 行を追加し、ordered create の親 lock を検証した。staging / production へは当てていない。

## 検証証拠

- `gen/build/a3-h-gleam-test.txt`: `76 passed, no failures`。
- `gen/build/a3-h-route-table.txt`: `verify-route-table: PASS (7 rows, face/http scratch build)`。
- `gen/build/a3-h-gate2.txt`: P0-1 / P0-7 / P0-2 / P0-3 / Range / P0-5 / P0-4 の 7 行 PASS。
- `gen/build/a3-h-root-ffi.txt`: `verify-root-ffi: 8 checks PASS`。
- `gen/build/a3-h-main-generate.txt`: `書いた: 635 ファイル`、exit 4、exit 4 診断 34 行。
- `gen/build/a3-h-main-vs-n2.txt`: 差 0。`gen/build/a3-h-main-vs-baseline.txt`: 差分は `db/queries/verb/` 内だけ。
- `gen/build/a3-h-verify-main.txt`: generated 241 / handwritten 61 / both 28 / stage1 6 / stage2 10 / missing-cast-ph 5 / missing-cast-ty 4。by-placeholder は 7 placeholder、by-type は 5 cast。
- `gen/build/a3-h-verify-decl.txt`: generated 235 / both 29 / stage1 6 / stage2 11 / missing-cast-ph 2 / missing-cast-ty 1。by-placeholder は 3 placeholder、by-type は 1 cast。
- `gen/build/a3-h-verb-self-test.txt`: 既存 2 本 + A3 2 本、全 PASS。
- `gen/build/a3-h-diff-check.txt` と `gen/build/a3-h-node-check.txt`: 出力なし、問題なし。

詳細な 27 本の表、H SQL 本文、残差、20 への記述案は `docs/reports/verb-1.md`。

---

# 指示 A4 真壁 巡4 作業結果(2026-09-21)

## 状態

- branch `verb-1`。開始 `1472f19`。P0-6 を実装し、`ordered_by.field` を `*Draft` から除外、`*Created` には残した。
- 生成器 test に Draft 欄数と create SQL の呼び手入力 placeholder 数の一致検査を追加した。ordered create の有効 fixture 4本(`relation` / `article` / `verb_features` / `ordered_create`)と通常 create の `flag` を検査する。
- `verify-verb-sql` は型の多重集合を正典、placeholder 番号を参考として表示する表記だけを変更した。判定ロジックは変更していない。
- `docs/reports/verb-1.md` を裁定3の合格線、29本の全類別表、I の F3移送に合わせて更新した。
- 固定の `musearch-main` は読取のみ。`musearch-decl` に新しい宣言は足していない。musearch 実体、DDL、staging、production、push は未変更。

## DDL

無し。migration / schema変更は無く、staging / productionへ適用していない。

## 検証証拠

- `gen/build/a4-gleam-test-final.txt`: `77 passed, no failures`。
- `gen/build/a4-route-table.txt`: `verify-route-table: PASS (7 rows, face/http scratch build)`。
- `gen/build/a4-gate2.txt`: P0-1 / P0-7 / P0-2 / P0-3 / Range / P0-5 / P0-4 の7 checks PASS。
- `gen/build/a4-root-ffi.txt`: `verify-root-ffi: 8 checks PASS`。固定写しのソースと実体 build の codec/runtime を組み合わせた一時 harnessで実行。固定写し自体は変更していない。
- `gen/build/a4-main-generate.txt` / `gen/build/a4-output-counts.txt`: 固定写し clean run は635 files、exit 4、exit 4診断34行。全診断ファイルは56行で、exit 4行を34行として数えた。
- `gen/build/a4-main-vs-n2.txt`: `diff -r` の出力なし、差0。
- `gen/build/a4-draft-sql-counts.txt`: 仮宣言コピーの `free_space` は Draft4欄 / SQL4 placeholder、`link` は4 / 4、`widget` は16 / 16。`order` はCreatedに残る。
- `gen/build/a4-verify-main.txt`: by-type `4本/5`、by-placeholder `5本/7`、段2一致10、両側28。
- `gen/build/a4-verify-decl.txt`: by-type `1本/1`、by-placeholder `2本/3`、段2一致11、両側29。
- `gen/build/a4-verb-self-test.txt`: 既存2 + A3追加2の4 checks PASS。

## 残差

- 型の多重集合で残る唯一の欠落は `advance_roster[$2::integer]`。`advance_muse_heaven` は型の多重集合で欠落0。
- I(`create_roster`)は裁定3で本便から外しF3へ移した。`auto_key`相当の語彙追加、仮宣言の実演はしていない。指示書の対象本数は27→26へ更新した。
- Hの意味突合は `create_free_space` / `create_link` / `create_widget`。`create_links` は語彙に無い名指し残差。上限の推測実装はしていない。

---

# 指示 A5 ── ゲート2 P0-7 / P0-8(2026-09-21)

## 状態

- branch `verb-1`、開始 `dc2993a`。P0-7 と P0-8 の2件だけを実装した。
- `CreateMany` を単体 create と同じ欄・初期 phase 規則へ揃え、ordered Entity は親の鍵順 lock、full scope 単位の既存末尾、配列 ordinality の `row_number` で採番する。Draft JSON から `order` / phase / entered timestamp は読まない。
- Entity-local の `handwritten_verbs` は自身の候補名だけと照合し、ER 外 module の札は global 候補名と照合する。抑止側は変更していない。
- 固定の `musearch-main/app` / `musearch-decl/app` は読み取りだけ。framework の語彙、他の残差、musearch 本体、staging、production、push は未変更。A5 で新たに `exit 4` 停止へ回した形は無い。

## DDL

無し。migration / schema変更は無い。`verify-gate2-sql.mjs` が一時 schema `gate2_a5_create_many` に検証用の `category` / `article` 表を作成して削除しただけで、staging / production へは適用していない。

## 検証証拠

- `/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/evidence/a5-gleam-test.txt`: `80 passed, no failures`。
- `/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/evidence/a5-route-table.txt`: `verify-route-table: PASS (7 rows, face/http scratch build)`。
- `/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/evidence/a5-gate2.txt`: 既存7行を維持し、CreateMany の同一 scope / 混在 scope / 既存末尾の3行を加えた計10行 PASS。
- `/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/evidence/a5-root-ffi.txt`: `MUSEARCH_APP=/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/musearch-ffi/app` で `8 checks PASS`。
- `/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/evidence/a5-verb-self-test.txt`: 4 checks PASS。
- `/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/evidence/a5-main-generate.txt` と `a5-main-counts.txt`: 固定写し clean run は635 files / exit 4 / exit 4診断34行(全診断56行)。
- `/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/evidence/a5-main-vs-n4.txt`: `diff -r out-n4 out-a5-main` は出力0行・差0。
- `/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/evidence/a5-decl-vs-n4.txt`: `diff -rq out-decl-n4 out-a5-decl` は出力0行・差0。
- `/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/evidence/a5-verify-main.txt`: 段2一致10、missing-cast(by-type) 4本 / 5 cast。
- `/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/evidence/a5-verify-decl.txt`: 段2一致11、missing-cast(by-type) 1本 / 1 cast。

# 指示 B1 ── ordered create の P0-9 / P0-10 / P0-11

## 状態

- branch `verb-1b`、開始HEAD `784ecd9`。`gen/src/yumemi_gen/emit/verb.gleam` の単体・一括 ordered create に、親 no-op UPDATE lock file、`FOR UPDATE NOWAIT`、`parent_gate`、`order_span` 起点を実装した。
- `gen/fixtures/ordered_create_negative` を追加し、`Range(min: -5, max: 10)` が reader を通り、開始値0になることを fixture test と実 PG で確認した。
- `gen/scripts/gate2c/ordered-create-repro.mjs` / `order-range-repro.mjs` は astra 原本の写し。判定文字列を「no reproduction = P0 が消えた」と明示し、lock SQL を先行実行する形にした。
- musearch の3つの写しは読取のみ。DDL、`src/framework/`、staging、production、push、main への commit は無い。

## DDL

無し。検証スクリプトの一時 schema は実行後に `DROP SCHEMA ... CASCADE` で削除した。migration / schema変更を作っていない。

## 検証証拠

証拠の基点は `/home/yumemism/.codex-agents/runs/niekawa-20260921-131116-1974475-16200/a1`。

- `(cd gen && gleam test)` ── `83 passed, no failures`。`a1/evidence/gleam-test.txt`。
- `bash gen/scripts/verify-route-table.sh` ── `PASS (7 rows, face/http scratch build)`。`a1/evidence/route-table.txt`。
- `verify-gate2-sql.mjs` ── 既存10行を維持。T1は37箱(①あり/なし、3組、3 isolation、UNIQUEあり/なし + rollback)で、全箱重複0。T2は4行、T3は4行、status 0。stdout は `a1/evidence/gate2-final.txt`。
- T1: ①ありの READ COMMITTED は全3組・UNIQUE両方で `0,1`、REPEATABLE READ / SERIALIZABLE はB① `40001`。①無しは競合中のB② `55P03`。rollback 箱はBが0を取得。
- T2: `Range(1,10)` の単体1、宣言無しの単体0、宣言無し CreateMany `0,1,2`、負の下端0。
- T3: 正常入力は通過。valid+missing、全件missing、単体missing はすべて `P0001/conflict` かつ表0行。FKは張っていない。
- `node gen/scripts/verify-verb-sql.mjs --self-test ...` ── 4 checks PASS。`a1/evidence/verify-verb-self-test.txt`。
- 仮宣言の `verify-verb-sql` ── `stage2=11`、`missing-cast(by-type)=1本/1`。`a1/evidence/verify-verb-decl.txt`。
- `verify-root-ffi.mjs` ── `8 checks PASS`。`MUSEARCH_APP` は指定の `musearch-ffi/app`。`a1/evidence/root-ffi.txt`。
- main clean run ── exit 4、exit 4診断34行、警告21行。`diff -rq base-main-out a1/main-out` は差0。`a1/evidence/main-generate.txt` / `diff-main.txt`。
- decl clean run ── exit 4。`diff -rq base-decl-out a1/decl-out` の差は ordered create の既存3本と lock SQL 6本だけ。`a1/evidence/decl-generate.txt` / `diff-decl.txt`。
- astra ordered create ── `P0-9 ordered-create astra direction: no reproduction = PASS`。`a1/evidence/repro-ordered-create.txt`。
- astra Range ── `P0-10 order-range astra direction: no reproduction = PASS`。`a1/evidence/repro-order-range.txt`。
- `git diff --check` ── 出力なし。

## 残差

- `hi` 超過時の飽和の綴りは語彙に無い。
- ①を飛ばした RR 以上の呼び手は、②だけでは救えない。`55P03` は競合が重なったときだけである。
- 親 Entity が引けない `ordered_by`（`within` 先頭が関係でない形）には lock 文が出ない。
- 親欠落の失敗コードは汎用の `'conflict'`。専用名は語彙が要る。
- 負の下端の開始値 `int.max(lo, 0)` は鷹野の裁定 C(2026-09-21 14:45)で確定した。BRIEF「どこまで 2」の括弧書き(`lo`)はこの裁定で更正されたので残差ではない。試験 `T2 negative lower bound starts at 0` はそのまま。
- `within` 先頭が optional の形では NULL scope を親検査・親 lock から外す実装にしたが、専用 fixture と独立した実 PG 箱は未実行。

# 指示 B2 ── lock SQL の出力条件・一括行ロック順・第5引数

## 状態

- branch `verb-1b`、開始点 `3d7a9ba`。commit `c71d0a2` で P0-1b-1 / P1-1b-1 / P2 の実装を入れた。
- `create_<module>_lock.sql` は `emits(app, entity, "create_" <> entity.module)` の真偽に従う。`create_<collection>_lock.sql` は `CreateManyRule` の宣言があり、かつ `emits(app, entity, "create_" <> entity.collection)` が真のときだけ出す。単体と一括は別条件で出力する。
- 一括 lock は `WITH locked AS (...)` の `ORDER BY <親鍵> FOR UPDATE` で親行を鍵順に取り、その後の no-op `UPDATE` で親行の版を進める2段構成にした。単体 lock の SQL 形は変えていない。
- `verify-gate2-sql.mjs` の第5引数(負の下端 fixture 出力)を必須化した。省略時は usage + exit 2、stack trace なし。
- DDL、`src/framework/`、musearch 3コピー、staging、production、push は変更していない。

## DDL

無し。生成・PG検証で一時 schema を使ったが、検証後に削除した。migration / schema は書いていない。

## 検証証拠

- `/home/yumemism/.codex-agents/runs/niekawa-20260921-131116-1974475-16200/a1/evidence/gleam-test-b2.txt`: **86 passed, no failures**。
- `gate2-b2.txt` / `gate2-counts-b2.txt`: 19 PASS、status 0。T1は37行で `no duplicate scope/order`、T2は4行、T3は4行。
- `diff-main-b2.txt` / `diff-main-b2-status.txt`: `base-main-out` との差0、diff status 0。
- `diff-decl-b2.txt` / `diff-decl-b2-status.txt`: `create_free_space` / `create_link` / `create_widget` と対応する `*_lock.sql` の6行だけ、diff status 1(差分ありの通常値)。
- `verify-verb-self-test-b2.txt`: 4 checks PASS。`verify-verb-decl-b2.txt`: stage2=11、missing-cast-ty=1。
- `route-table-b2.txt`: `PASS (7 rows, face/http scratch build)`。`root-ffi-b2.txt`: `verify-root-ffi: 8 checks PASS`。
- `main-counts-b2.txt`: generator status 4、`書いた: 635 ファイル`、exit4=34行/9 service、exit3=0、警告21行。
- `gate2-missing-negative-b2.txt` / status: 第5引数無しは usage のみ、exit 2。stack trace は出ていない。
- `fx-relation-b2` の lock file は `create_photo_lock.sql` の1本。`fx-article-b2/create_articles_lock.sql` は親鍵 `name` の `ORDER BY name FOR UPDATE` と後段 no-op `UPDATE` を持つ。

## 残差

- `hi` 超過時の飽和の綴りは語彙に無い。
- lock 呼び出しを省略した REPEATABLE READ 以上の呼び手は、create 本体だけでは安全にならず、従来どおり transaction 単位の再試行が必要。
- 親 Entity が解決できない `ordered_by` には lock 文が出ない。optional scope の専用 fixture と独立した実 PG 箱は未実行。
