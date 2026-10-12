# results ── yumemi-0122(0.12.2、最小の app が生成→起動→一覧まで通らない 4 つの穴、真壁 r1)

基点 `d770c59`(tag `v0.12.1`)、branch `impl/yumemi-0122`。証跡は `build/0122-*.txt`(git の外)。写しと PG・workerd の作業域は `.scratch/`(git の外)。版の行・tag・publish は触っていない。BRIEF のファイル(`briefs/BRIEF-yumemi-0122.md`)は未 commit のまま置いてある。

## 4 点の再現と直し

4 点とも基点で再現した。再現しなかった点は無い。patch(`.scratch/yumemi-fix-bench-findings.patch`)は材料にとどめ、1・3・4 は直し方を変えた。

| 点 | 再現(基点で落ちたもの) | 直し | test |
|---|---|---|---|
| 1 host | 子の node で `http().host` を叩くと、`ApiHost` と入口 `api` の組で 404 になった(2 項)。notes を workerd で起こすと全要求が 404(`build/0122-notes-probe-base-http.txt`)。既存の fixture の article(`PublicHost`/`public`)と flag(`TestHost`/`test`)も同じ形 | `server/http.mjs` の `host`:表(入口の名 → `<NAME>_HOST`)を入口の名で引く。**Host の variant を 1 つも持たない入口は、どの host にも出さず Origin にも入れない** | `entrance_host_follows_the_entry_name_test`(check 6 項) |
| 2 verb の FFI | 基点の生成物を esbuild で bundle すると `../operations_ffi.mjs` が解けず止まった(`build/0122-notes-bundle-base.txt`) | `gen/emit/verb.gleam`:`@external(javascript, "./operations_ffi.mjs", "stage")`(隣の生成物) | `verb_stage_comes_from_the_generated_ffi_test`、`every_generated_import_resolves_test` |
| 3 queue・subject | 同じ bundle が `./queue_runtime.mjs`(shell.mjs)と `./subject.mjs`(runtime.mjs)で止まった。生成器は exit 0 を返していた。article・cms の fixture にも両方の file が無い | `gen/emit/back.gleam` の `queue_text`:kind が無いときは空の口を吐く(`registeredKinds=[]`、`sweep=async()=>0`、`consume=async()=>{}`、import は無し)。`gen/emit/runtime.gleam`:`./subject.mjs` の import は、subject の Entity があるとき(`subject_file` と同じ条件)だけ書く | `no_queue_kind_still_writes_the_queue_runtime_test`、`subject_import_follows_the_subject_file_test`(subject の Entity を足した写しで import と `subject.gleam` が出ることも見る)、`every_generated_import_resolves_test` |
| 4 頁の size | 子の node で size 1・5 を読むと limit+1 件・next が null(6 項)。size の穴が 2 番目の穴でも同じ。notes を workerd で起こすと limit=1 で 2 件・next null(`build/0122-notes-probe-base-runtime.txt`) | `gen/emit/runtime.gleam` の `keyset`:size が穴なら `sizeArg:<args の番号>` を添える。`server/runtime.mjs`:`pageSize(entry,input)` が、`readParams` が SQL に渡すのと同じ式(`encodeValue`)で穴の値を取り、`decodeRows` はその値で切る。定数の size と、畳み(fold)の道は keyset の size のまま | `page_size_hole_cuts_the_page_test`(check 10 項)、`constant_page_size_is_unchanged_test`(守り。基点でも通る) |

- 再現の test を先に足して基点で回した:`455 passed, 6 failures`(新しい 6 本が落ち、定数の size の test だけ通る、`build/0122-test-before-fix.txt`)
- patch との違い
  - 1:patch は入口の名だけで引き、`hosts` の並びを見ない。musearch の写しの api の test `dispatch.test.mjs` の N4(入口の `hosts` を空にすると 404・Origin も 403)がこの形で落ちた(1765/1766、`build/0122-ms-api-test.txt`)。並びが空の入口は出さない形にして 1766/1766
  - 3:patch の `consume` は throw する(queue の message は retry され続ける)。outbox の `consume` が表に無い kind の行を受けたときと同じく、何もせず返す形にした
  - 4:patch は runtime で `Number(values[sizeArg])` を別に組む。穴の値が SQL に渡る値と食い違わないよう、`readParams` と同じ `argValues` と `encodeValue` を通す形にした
- 生成器の側の判断:1 は runtime だけで直し、生成の `hosts` の表の字は変えていない。README の `<ENTRY>_HOST` per entrance のまま

## fixture `gen/fixtures/notes`

Host `ApiHost` と入口 `api`、queue の kind なし、subject の Entity なし、src に手書きの `.mjs` なし、`Paged(size: Param(Limit), after: Param(Cursor))`。Entity `note`(id・title・body・created_at)、Service は `note_create`・`note_read`・`note_edit`・`note_delete`・`note_list`。`db/queries` に root の 3 文と `framework/audit`、`db/schema.sql` に DDL。

- 生成器:`gleam run -m yumemi/gen -- gen/fixtures/notes gen/fixtures/notes` は exit 0・30 ファイル。`git add` の後の 2 回目も exit 0・未 stage の差 0 行(`build/0122-gen-notes-{1,2}.txt`)
- bundle:写し(`.scratch/notes-app`、yumemi は本作業木への path 依存)を `gleam build`(exit 0)して `gen/shell.mjs` を esbuild。基点の生成物は 3 件の Could not resolve で exit 1、直した生成物は exit 0(131.8kb)
- workerd:wrangler 4.131.1(workerd 1.20260911.1)の `wrangler dev --local`。DB は空の PG 16 に `db/schema.sql` を当て、`@neondatabase/serverless` の HTTP の口を手元の proxy で PG へ流した。要求の host は `x-test-host` で書き換えた。手書きの橋は入れていない(差し替えたのは Neon の送り先と host だけ)。最終の版の結果(`build/0122-notes-probe-final.txt`、POST の #2〜#25 は省略):

```
host other.test GET /api/notes?limit=5 -> 404 {"code":"not_found"}
empty list limit=5 -> 200 {"page":{"items":[],"next":null}}
POST /api/notes #1 -> 200 {"id":"1ef4969f-…","title":"note 1","body":"body 1","created_at":"2026-10-12T16:19:00.529Z"}
POST 25 notes: 25 ids
POST empty title -> 400 {"code":"invalid_argument","field":"title"}
GET /api/notes/<1st> -> 200 {"id":"1ef4969f-…","title":"note 1","body":"body 1",…}
PUT /api/notes/<1st> -> 200 null
GET after PUT -> 200 {"id":"1ef4969f-…","title":"note 1 edited","body":"body 1 edited",…}
DELETE /api/notes/<25th> -> 200 null
GET deleted -> 404 {"code":"not_found"}
limit=1 page 1 -> 200 items 1 next set [note 24]
limit=1 page 2 -> 200 items 1 next set [note 23] overlap 0
limit=5 page 1 -> 200 items 5 next set [note 24, note 23, note 22, …]
limit=5 page 2 -> 200 items 5 next set [note 19, note 18, note 17, …] overlap 0
limit=20 page 1 -> 200 items 20 next set [note 24, note 23, note 22, …]
limit=20 page 2 -> 200 items 4 next null [note 4, note 3, note 2, …] overlap 0
limit=5 walk -> 5 pages, 24 items, 24 distinct, last next null: true
```

- 対照:同じ写しの build の木の `http.mjs` だけを基点の版にすると全要求が 404。`runtime.mjs` だけを基点の版にすると `limit=1 page 1 -> 200 items 2 next null`。差し替えは戻し、src と同じ字であることを `cmp` で見た

## 既存 fixture の生成物の差分(全部)

article と cms は同じ 5 本ずつ(面の `client.mjs` ほか、面の生成物に差は無い)。2 回目は 3 つとも exit 0・未 stage の差 0 行(`build/0122-gen-{article,cms}-{1,2}.txt`)。

| file | 差 | 理由 |
|---|---|---|
| `{article,cms}/src/gen/queue_runtime.mjs` | 新規(4 行の空の口) | 3。どちらも queue の kind が無く、shell.mjs が import していた file が無かった |
| `{article,cms}/src/gen/runtime.mjs` | `import * as subject from './subject.mjs';` が消える | 3。どちらも subject の Entity が無く、`gen/subject.gleam` が無かった |
| 同上 | `article_list/items` の keyset に `sizeArg:0` | 4。`Paged(size: q.Param(Limit), ..)` |
| `{article,cms}/src/gen/verb.gleam` | `../operations_ffi.mjs` → `./operations_ffi.mjs` | 2 |

面の node_modules の esbuild の symlink は回した後に消した。

## musearch の写し

main `955e34eb7` を `git archive` で `.scratch/musearch` に置き、api・www・muses・console・admin の yumemi を本作業木への path 依存にした(`gleam deps download` は 5 つとも exit 0、`yumemi v0.12.1`)。node_modules は手元の musearch への symlink。runbook の手で brand・fonts・legal を作り(6 本とも exit 0)、5 面の `src/gen` を消して api から `gleam run -m yumemi/gen -- . ..` を回した。

- 生成器:exit 0・停止コード 0・2103 ファイル。2 回目も停止コード 0・差 0(`build/0122-ms-gen-{1,2}.txt`)。Hex の rate limit には当たっていない
- 生成物の差(main の commit 済みの生成物から):**`api/src/gen/verb.gleam` の 1 行だけ**(`../operations_ffi.mjs` → `./operations_ffi.mjs`)。musearch には queue の kind と subject の Entity があるので 3 の差は出ない。Paged は全部 `size: q.Num(20)` なので 4 の差も出ない。手書きの `api/src/operations_ffi.mjs` は残り、verb.gleam から import されなくなるだけ
- **www**:build exit 0・test 452/452。**muses**:build exit 0・test 514/514(`build/0122-ms-{www,muses}-{build,test}-2.txt`、最終の `http.mjs` で回し直した分)
- **api**(BRIEF の外、`http.mjs`・`runtime.mjs` を変えたので回した):新しい PG(port 55935)で 1766/1766(`build/0122-ms-api-test-2.txt`)。回した後に止めた。1 回目(patch と同じ形の 1)は N4 が 1 本落ちた(上の「patch との違い」)。auth の build は要るので写しの auth も build した

## 確かめ

- root:`npm ci` exit 0(`build/0122-npm-ci.txt`、esbuild の allow-scripts の警告だけ)。`gleam test` は基点 `454 passed, no failures` → 再現の test を足して基点のまま `455 passed, 6 failures` → 直した後 **`461 passed, no failures`**(`build/0122-test-final.txt`、字で見た)。`gleam format --check src test` 0
- 新しい test(`test/yumemi_0122_test.gleam` 7 本、`yumemi_0122_test_ffi.mjs`、子の node の `yumemi_0122_check.mjs` の host 6 項・page 10 項)
- README:「0.12.2 fixes …」の 4 項を `yumemi/server` の節に足した(版の行は 0.12.1 のまま)

## 次の版へ(触っていない)

- **5 つ目の穴:`auto_key` の Entity を作る Service は 400 になる。**notes の最初の形(`pub const auto_key = ["id"]`)を workerd で叩いたら、POST が全部 `{"code":"invalid_argument","field":"note_id"}` で、行も audit も入らなかった。生成の INSERT は id を DB の DEFAULT に任せる一方、runtime の `stageVerb` は作った値(`NoteCreated`)を commit の前に組み、`c.parse('note_id', null)` で落ちる。`auto_key` は README に無く、musearch も使っていない(flag の fixture だけが書いている)。直し方(runtime が id を採番するか、作った値を RETURNING の後に組むか)は設計の判断なので触っていない。notes は musearch と同じく id を seed から作る形(`note_id.parse(it.seed)`、手書きの FFI は使わない)にした
- `src/server.gleam` の無い app には back の生成物(runtime・shell・sql ほか)が 1 本も出ないのに、生成器は exit 0 で終わる。notes の最初の形で当たった。そのとき `gen/verb.gleam` は書かれ、今回の 2 で隣の `operations_ffi.mjs`(back の生成物)を指すようになった(server.gleam の無い app はもともと起こせない)
- Host の variant の意味:0.12.1 までは variant の名を入口の名として引いたので、`hosts: [Www]` を別の入口に書くと www の host でも答える形が成り立っていた(musearch は使っていない)。今は入口自身の `<NAME>_HOST` だけで、variant は「1 つ以上あるか」だけを見る。variant を複数書く意味を持たせるかは 51 で決める
- results-yumemi-0121 の「次の版へ」と 80 の宿題は触っていない

## DDL

- `gen/fixtures/notes/db/schema.sql`(新規、fixture の材料):`app.note`(id uuid PK DEFAULT gen_random_uuid()・title・body・created_at timestamptz、索引 `(created_at DESC, id DESC)`)、`framework.audit`(musearch の同じ表の列から CHECK を外した形)、`framework.require_rows`(musearch と同じ関数)。生成器は読まない。当てたのは `.scratch` の手元の PG(port 55932、止めた)だけで、staging / production には当てていない
- yumemi の本体と musearch の schema は変えていない
