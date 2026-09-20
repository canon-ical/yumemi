# gen-4 真壁 A 作業結果

## 状態

- branch: `gen-4`
- framework entry / reader / model / emit を実装。
- fixture article は route 7 行を生成し、`gleam test` は 60 passed。
- `gen/scripts/verify-route-table.sh` は PASS。
- generator の musearch 出力に `.mjs` は 0。本便の追加生成物は `face.gleam` と `entry/http.gleam`。
- musearch 本体・canonical は書き換えていない。musearch の写しは `gen/_out/musearch-gen4-scratch/` のみ。
- DDL: 無し。

## 検証証拠

- test: `gen/build/route-table-test-final-pre.txt`
- route scratch build: `gen/build/verify-route-table-final.txt`
- musearch current generation: `gen/build/final-generate-musearch.txt`
- probe stage counts: `gen/build/final-probe-compile.txt`
- root 8: `gen/build/final-root-ffi.txt`
- gate 2 7: `gen/build/final-gate2-sql.txt`

## 数字

- musearch current: 631 files、exit 4 faces missing 92、exit 3 1、warning 21、exit 1 4。
- scratch faces: Api 6 / Store 13 / Admin 5 / Front+Console 63 / System `[]` 5。
- scratch route table: 133 rows。registry 98 行の突合は `gen/_out/musearch-gen4-scratch/route-registry-compare.tsv`。
- probe original app: 段 3 = 129。

## 未解決

- musearch の旧 entry に prefix が無いので、7a は空 prefix として `/api` を補わず生成した。7b の写しには front/console `/api`、store `/api/store`、admin `/api/staff`、api `/api/v1/store` を明示した。
- scratch の仮割当では Store 面の `who AsStaff` 6 本と、対象 Entity が無い route 17 行が exit 4。URL は直していない。
