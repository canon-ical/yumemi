# results ── yumemi-0122b(0.12.2、`auto_key` の Entity を作る Service の 400、穴の size 1 未満の 503、真壁 r1)

基点 `f3f2382`(BRIEF の commit、その下が `cb0341a`)、branch `impl/yumemi-0122b`。証跡は `build/0122b-*.txt`(git の外)。写しと PG・workerd の作業域は `.scratch/`(git の外)。版の行・tag・publish は触っていない。

## 1 再現(直す前に落ちる test)

`test/yumemi_0122b_test.gleam`(4 本)と子の node の `test/yumemi_0122b_check.mjs`(`auto` 5 項・`size` 5 項)。notes の ★ を先に `auto_key` の形にした(下の「fixture」)。

- 直す前の `gleam test`:**`461 passed, 3 failures`**(新しい 3 本が落ちた。複合の key の test は後で足した、`build/0122b-test-before-fix.txt`)
- 直す前の生成器で notes を吐き(`build/0122b-gen-notes-pre.txt`)、その `create_note` の行を子の node に渡すと、stage が **`{"message":"invalid_argument","status":400,"field":"note_id"}`** で落ちた(`build/0122b-check-auto-before.txt`)。生成の verb の表は `params:[['f','title',..],['f','body',..],['f','created_at',null]]`(key の穴が無い)、`created:[..,['id','title','body','created_at'],'note_id']`
- size 0・-1 は `Cannot read properties of undefined (reading 'n')`(`cursorText(keyset, undefined)` の TypeError)で落ち、SQL に 2 回流れた(`build/0122b-check-size-before.txt`)

## 2 直し ── `auto_key` の key は runtime が採番して INSERT に渡す

選んだ理由(3 行):
1. 作った値(`NoteCreated`)は logic が `step.apply` の続きで受け取って使う値で、commit(要求の全文を 1 つの transaction で流す)より前に要る。RETURNING の後に組む形は、logic を commit の後まで待たせるか文を先に流すことになり、transaction の 1 本化を崩す
2. runtime はもともと key の穴に `['id']`(要求の seed から作る UUID、`seededId(seed, n)`)を詰める道を持っている。`auto_key` の key もこの道に乗せれば、作った値の key と行の key が同じ値になり、同じ seed なら同じ key になる
3. flag の fixture の `auto_key` の注記が「id は実行側が UUID を採番する」で、宣言の意図と合う。key を作る app(`auto_key` 無し)の SQL と verb の表は 1 字も変わらない

変えたもの:
- `src/yumemi/gen/emit/verb.gleam`:1 件を作る INSERT の列(`create_fields`)に `auto_key` の key を戻し、key の穴は `auto_key` かどうかに関わらず `['id']`。Draft から外すのは今までどおり(`draft.gleam` は触っていない)。**CreateMany は変えない**(`many_create_fields`、入力 JSON は Draft の欄だけなので key の列を書かず DB の DEFAULT に任せる、今までと同じ SQL)
- `src/yumemi/gen/reader.gleam`:`validate_auto_keys`。`auto_key` の key が Uuid の値型 1 つでなければ exit 4 で止める(`auto_key の key が Uuid でない: <名>`)。複合の key に `auto_key` を書いても exit 4(`auto_key は 1 つの Property の key にだけ書ける`)── runtime の作った値は key の欄すべてに同じ採番の値を入れるので、複合の key は黙って崩れる
- `src/yumemi/server/runtime.mjs` の `stageVerb` は変えていない

test:`auto_key_create_stages_a_runtime_key_test`(Draft に id が無い、INSERT に id の列、子の node で stage が通り、INSERT の 1 番目の穴と作った値の key が同じ UUID、同じ seed で同じ key)、`auto_key_on_a_non_uuid_key_stops_test`(notes の `note_id` を `Text` にすると exit 4)、`auto_key_on_a_composite_key_stops_test`(flag の Chunk の複合 key に `auto_key = ["a"]` で exit 4)。

既存の test を 2 本書き換えた(期待が今回の直しと逆):
- `yumemi_gen_test.auto_key_is_excluded_only_by_explicit_declaration_test`:widget の INSERT の列は `(name,place,visible,"order")` → `(id,name,place,visible,"order")`。Draft の期待は同じ
- `yumemi_gen_test.draft_fields_match_create_sql_placeholders_test`:「Draft の欄の数 = INSERT の穴の数」に `auto_key` の数を足した(widget だけ +1)

## 3 README

`yumemi/server` の節の 0.12.2 の項に `auto_key` の 1 項を足した:何をする宣言か(Draft から外し、runtime が要求の seed から UUID を採番して INSERT に渡し、作った値もその key を持つ)、使える key の型(Uuid の値型 1 つだけ、それ以外と複合の key は exit 4)、CreateMany は DB の DEFAULT が要ること、`auto_key` の無い Entity は 1 字も変わらないこと。冒頭の「four holes」は「five holes」にした。

## 4 穴の size が 1 未満(柏木 P1-1)

- `src/yumemi/gen/emit/runtime.gleam` の `keyset`:size が穴なら `sizeArg` の隣に穴の名 `sizeField`(`Param(Limit)` なら `'limit'`)
- `src/yumemi/server/runtime.mjs`:`pageSize` が size を出すとき、1 未満(`!(size>=1)`、NaN も含む)なら 400 `invalid_argument`、field は `sizeField`(無い生成物は `size`)。`read` は size を **SQL を流す前に** 見る(1 未満を DB へ流さない)。定数の size と畳みの道は触っていない
- test:`page_size_below_one_is_invalid_argument_test`(生成の keyset の字、子の node で size 0・-1 が 400・field `limit`・SQL に流れない、size 1 は 1 件と next、`sizeField` の無い keyset は field `size`)
- 上限は今回の外(README にも「上限は無い、app が切る」と書いた)

## 5 fixture `gen/fixtures/notes` を `auto_key` の形に

★ の差は 2 file:`src/entity/note.gleam` に `pub const auto_key: List(String) = ["id"]`、`src/service/note_create.gleam` は `note_id.parse(it.seed)` をやめて Draft に id を渡さない。`db/schema.sql` は変えていない(`id uuid PRIMARY KEY DEFAULT gen_random_uuid()` のまま、runtime が値を渡すので DEFAULT は使われない)。

workerd:r1 と同じ組(wrangler 4.131.1 の `wrangler dev --local`、空の PG 16 に `db/schema.sql`、Neon の HTTP の口を手元の proxy で PG へ、host は `x-test-host`)。port だけ替えた(PG 55942・proxy 55943・wrangler 8809)。写しの build は `gleam build` exit 0。最終の結果(`build/0122b-notes-probe-final.txt`、末尾の 2 行は今回足した):

```
host other.test GET /api/notes?limit=5 -> 404 {"code":"not_found"}
empty list limit=5 -> 200 {"page":{"items":[],"next":null}}
POST /api/notes #1 -> 200 {"id":"17d73c91-d459-4bf8-84fe-a5bea40afd7c","title":"note 1","body":"body 1","created_at":"2026-10-12T16:40:57.753Z"}
POST 25 notes: 25 ids
POST empty title -> 400 {"code":"invalid_argument","field":"title"}
GET /api/notes/<1st> -> 200 {"id":"17d73c91-…","title":"note 1",…}
PUT /api/notes/<1st> -> 200 null
GET after PUT -> 200 {"id":"17d73c91-…","title":"note 1 edited","body":"body 1 edited",…}
DELETE /api/notes/<25th> -> 200 null
GET deleted -> 404 {"code":"not_found"}
limit=1 page 1 -> 200 items 1 next set [note 24]
limit=1 page 2 -> 200 items 1 next set [note 23] overlap 0
limit=5 page 1 -> 200 items 5 next set [note 24, note 23, note 22, …]
limit=5 page 2 -> 200 items 5 next set [note 19, note 18, note 17, …] overlap 0
limit=20 page 1 -> 200 items 20 next set [note 24, note 23, note 22, …]
limit=20 page 2 -> 200 items 4 next null [note 4, note 3, note 2, …] overlap 0
limit=5 walk -> 5 pages, 24 items, 24 distinct, last next null: true
limit=0 -> 400 {"code":"invalid_argument","field":"limit"}
limit=-1 -> 400 {"code":"invalid_argument","field":"limit"}
```

- limit 1・5・20 と 2 頁目、limit 5 で最後まで送る行は、yumemi-0122 の数字(`results-yumemi-0122.md`)と同じ
- PG:`app.note` 24 行(25 作って 1 消した)、`framework.audit` 162 行(`note_create` の entry・resolve ほか)。行の id は POST の返した id と同じ(`17d73c91-…`)
- 対照(`build/0122b-notes-probe-control.txt`):写しの build の木の `notes/gen/{sql,runtime}.mjs` を直す前の生成器の吐いた版に、`yumemi/server/runtime.mjs` を `cb0341a` の版にして wrangler を起こし直すと、`POST /api/notes -> 400 {"code":"invalid_argument","field":"note_id"}`、`limit=0`・`limit=-1 -> 503 {"code":"unavailable"}`。行は増えなかった(24 のまま)。差し替えは戻し、src と同じ字であることを `cmp` で見た。PG・proxy・wrangler は止めた

## 既存 fixture の生成物の差分(全部)

生成器は notes・article・cms とも 1 回目 exit 0、`git add` の後の 2 回目も exit 0・未 stage の差 0 行(`build/0122b-gen-{notes,article,cms}-{1,2}.txt`)。article・cms は面の node_modules に esbuild が要るので、根の node_modules への symlink を置いて回し、回した後に消した(r1 と同じ)。

| file | 差 | 理由 |
|---|---|---|
| `{article,cms}/src/gen/runtime.mjs` | `article_list/items` の keyset に `sizeField:'limit'` | 4 |
| `notes/src/gen/runtime.mjs` | `note_list/items` の keyset に `sizeField:'limit'`、頭の hash | 4、★ が変わった |
| `notes/src/gen/draft/note.gleam` | `NoteDraft` から `id: NoteId` が消える、頭の hash | 5(notes を `auto_key` に)。`NoteCreated` は同じ |
| `notes/src/gen/sql.mjs` | 頭と各文の hash だけ。`verb/create_note` の本文は r1 と 1 字も同じ(`INSERT INTO app.note(id,title,body,created_at) VALUES($1::uuid,..)`) | ★ が変わった |
| `notes/src/gen/` のほか 24 file | 頭の hash の 1 行だけ | ★ が変わった |

notes の `runtime.mjs` の `create_note` の行(verb の表)も r1 と同じ字。つまり notes の生成物で振る舞いが変わるのは Draft の型だけ。

## musearch の写し

main `955e34eb7` を `git archive` で `.scratch/musearch` に置き、api・www・muses・console・admin・auth の yumemi を本作業木への path 依存にした(`gleam deps download` は 6 つとも exit 0、`yumemi v0.12.1`)。node_modules は手元の musearch への symlink。brand・fonts・legal の 6 本は exit 0。写しを git にして、5 面の `src/gen` を消して api から `gleam run -m yumemi/gen -- . ..`。

- 生成器:exit 0・停止コード 0・2103 ファイル。2 回目も停止コード 0・差 0 行・未追跡 0(`build/0122b-ms-gen-{1,2}.txt`)
- 生成物の差(main の commit 済みの生成物から):**`api/src/gen/verb.gleam` の 1 行だけ**(`../operations_ffi.mjs` → `./operations_ffi.mjs`、r1 の 2 の差で、今回の直しの差は無い)。musearch は `auto_key` を書いていないので key と INSERT は変わらず、Paged は全部定数の size なので `sizeField` も出ない。ほかに `_diagnostics.txt`(警告だけ、停止コード 0)が出る
- **www**:build exit 0・test **452/452**。**muses**:build exit 0・test **514/514**(`build/0122b-ms-{www,muses}-{build,test}.txt`)
- **api**:auth を build(exit 0)、`MUSEARCH_TEST_PG_PORT=55945` で `api/test/postgres.sh`、`npm test` で **1766/1766**(`build/0122b-ms-api-test.txt`)。PG は止めた。build と test の後も写しの追跡 file の差は上の 1 行のまま

## 確かめ

- root:`npm ci` exit 0(`build/0122b-npm-ci.txt`、esbuild の allow-scripts の警告だけ)。`gleam test` は再現の test を足して直す前 `461 passed, 3 failures` → 直した後 **`465 passed, no failures`**(`build/0122b-test-final.txt`、字で見た)。`gleam format --check src test` 0

## 次の版へ(触っていない)

- **CreateMany の `auto_key`**:key の列を書かず DB の DEFAULT に任せたまま。runtime は CreateMany に作った値を組まない(`created` の無い verb の表)ので今回の 400 は出ないが、`List(Created)` を受ける logic が何を受けるかは見ていない。key を runtime で採番する形に揃えるかは別の便で
- `auto_key` の無い Entity は、Draft の key を runtime が `['id']` の採番で上書きする(r1 の notes も `note_id.parse(it.seed)` を渡していたが、行の id は `seededId(seed, 0)`)。BRIEF のとおり触っていない。複合の key(flag の Chunk)も key の欄すべてが同じ採番の値になる形のまま
- results-yumemi-0122「次の版へ」の残り(server.gleam の無い app の exit 0、Host の variant の意味)、柏木の P1-2〜4(畳みの道の size、variant の数、kind の無い queue の ack)、size の上限は触っていない

## DDL

無し。`gen/fixtures/notes/db/schema.sql` は変えていない。当てたのは `.scratch` の手元の PG(notes 55942、musearch api の test 55945、どちらも止めた)だけで、staging / production には当てていない。
