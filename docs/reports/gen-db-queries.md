# gen-db-queries ── SQL 出力先を `gen/sql/queries/` から `db/queries/` へ

根拠:tech `_drafts/gleam-framework/56-repo-shape.v0.md`(読みの SQL は `api/db/queries/<service>/<name>.sql`)、`_drafts/musearch/57-redraw-inventory.v0.md`「yumemi 側に無いもの」。

## 変えた箇所(13 file、grep "gen/sql" で 0)
- 出力 path 本体 3 箇所:`emit/sql.gleam:72,143`、`emit/verb.gleam:578`
- doc comment / 表:`yumemi_gen.gleam:5`、`emit/sql.gleam:1,61`、`emit/reads.gleam:176`、`emit/hash.gleam:10`
- script:`scripts/compare.py`、`scripts/probe-compile.sh`、`scripts/verify-root-ffi.mjs`、`scripts/verify-gate2-sql.mjs`、`scripts/gate2c/{reorder-concurrent,reorder-negative,draft-typed}.mjs`
- test:`test/yumemi_gen_test.gleam`(96 行)
- `docs/reports/gen-1〜4.md` の過去言及(4件)は歴史として不変更
- SQL 表の鍵 `<service>/<query>` は無変更、`src/framework/**` も無変更

## source.gleam の入力フィルタ(手順4)
`source.load` は `<app>/src` 配下だけを歩く(`gen/` 始まりを除外)。`db/queries/` は `<app>/src` の外(app 直下)なので、この filter の射程に入らない ── 実測ではなく読みで確認(`db/` を歩く経路自体が無い)。変更不要。

## 検算
- `cd gen && gleam test` → **72 passed**(基線と同数)
- 生成器を musearch main(`0a5a7ee`)の `app/` に対し before(main `b8b6b6b`)/ after(本 branch)で実行、双方とも **exit=4、`exit 4 宣言の矛盾` 34 行(distinct service 9)、出力 635 file** で一致
- `diff -r` で before の `gen/sql/queries` を `db/queries` に rename した木と after の出力を比較 → **差分 0**(path 以外完全一致)

## 罠 / 鷹野宛の判断点
- gen-5 の commit message は musearch ★ 87 本中「5 が止まる」だったが、今回の実測では distinct service 9 本(`ledger_store_add/search`、`metrics_muse/store` が追加)。**これは本便の変更と無関係 ── musearch 側が gen-5 merge 後に増えた service によるドリフト**、before/after で同数なので回帰ではない。放置してよいか、それとも別便で musearch 側の宣言を裁定するかは鷹野の判断が要る
