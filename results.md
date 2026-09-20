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
