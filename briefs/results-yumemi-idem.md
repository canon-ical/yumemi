# results ── yumemi-idem(0.13.0、冪等キーと SQL の接続先の口、真壁 r1)

基点 `86343e9`(BRIEF の commit、その下が `876ce7d` = `v0.12.2`)、branch `impl/yumemi-idem`。証跡は `build/idem-*.txt`(git の外)。notes・musearch の写しと PG・shim・workerd の作業域は `.scratch/`(git の外)。gleam.toml の版の行・tag・publish は触っていない(README の節だけ 0.13.0 の形)。

## 矛盾(贄川さんに確認が必要)

**BRIEF の「1 か所で api・auth の両方に効くこと」は、yumemi の側だけでは満たせない。**musearch の auth の Worker(`auth/wrangler.jsonc` の main は `gen/worker.mjs`)は yumemi の `driver.mjs` を通らず、auth の自前の `auth/src/gen/shell.mjs` の `database(env)` が `neon(env.DATABASE_URL)` を直に呼ぶ(musearch main `130635971`、写しで grep。yumemi の `server/` を import する file は auth に無い)。設計 v0「musearch の api・auth は yumemi の `driver.mjs` を通る」の前提が現物と違う。

- yumemi の側でしたこと:`driver.mjs` の `database(env)` の 1 か所(api の生成の Worker の fetch・queue・cron・`AppSystem` の全部がここを通る)と、`neon()` を直に呼ぶ Worker のための `useSqlEndpoint(env)` の export(`database` も中でこれを呼ぶ)
- auth に効かせるには、musearch の側で auth の `database(env)` の `neon()` の前に `useSqlEndpoint(env)` を 1 行足す(auth は yumemi を gleam の依存に持つので import できる)か、同じ 1 行を auth の生成器に書く。musearch の便(便 6)で足すか、この便で yumemi の外を触るかは決めていない

## 設計の選択と理由

**効かせる Service は「書きの Service の全部、要求がキーを持つときだけ」**(宣言は足さない)。
1. 二重になる書きは作るだけでない ── 状態の遷移・数の加算・断りの記録(`step.reject`)も再投稿で 2 回走る。作る・送るだけに絞ると、設計 v0 の案 C と同じく Service ごとに守りが割れる
2. 宣言で選ぶ形は ★ を書き換えることになる(BRIEF「★ の書き方は変えない」)。キーを送るかどうかは client が決め、キーの無い要求は 1 字も変わらない(表を引かない)ので、選ぶ宣言が要らない
3. 費用はキーのある書きだけに掛かる:事前の引き 1 本と、書きの transaction の中の INSERT 1 文。読みの Service・attached の口・port(`service_<name>`)はヘッダを見ない

ほかの選択:
- **記録は書きの transaction の先頭の文**(`runtime.mjs` の `finish`)。後ろに置くと、並んで来た 2 本目が業務の文(相の遷移の `require_rows` など)で先に落ち、業務の失敗を返してしまう。先頭なら PG の一意の索引が 2 本目を 1 本目の commit まで待たせて 23505 で落とす。応答は transaction の前に組む(`step.done` の値と `step.commit` の 202 が分かる時点)ので、`io.finish_with` / `io.reject_with` を足して `step.done` / `step.reject` が結果を `finish` に添える。添えない古い context(test の偽の ctx・★ の器)は `finish()` のままで、記録しない
- **何を保存するか**:送った応答の status・content-type・本文の字だけ(`{status,type,body}`)。応答に出さない値は入らない。引くのは (party, key) で、party は session・API key の party、無ければ browser の印 `browser:<id>`、どちらも無ければ `anonymous` の 1 つの枠
- **409 の比べ**:`request_hash` = Service の名と、decode の段の欄(query・JSON 本文・path の穴を合わせ、鍵を並べ替えた JSON)の SHA-256。違えば 409 `idempotency_conflict`(業務の `conflict` と分けた)
- **失敗の後の引き直し**:キーのある書きが落ちたとき(23505・commit の後の 503・業務の失敗)は記録をもう 1 度引き、あれば 1 本目の応答を返す。引けなければ元の失敗。commit の後に応答だけ失った要求も、同じ要求の中で DB に届けば 200 になる(下の (d'))
- **RETURNING で埋まる欄**(並びの Entity の `order`、★ の `returned`)は transaction の前には分からない。最終の応答が記録と違えば transaction の直後に `framework/idempotency_repair` で直す。**直しの前に落ちると、再投稿の応答の `order` は 0 のまま**(行は正しい)。README に書いた
- **client**:書きの送り(読み・GET・上げ口でない)は Args ごとに UUID を作って `Idempotency-Key` に載せる。5xx と網の失敗はキーと入力を保ち、**失敗の After(読み直し・移動)に移らない**(読み直すと入力が消えるため)。2xx・4xx でキーを捨て、Args が変われば新しいキー。保つのは要素の上(頁を読み直せば入力と一緒に消える)
- **保持期間**:Worker の env `IDEMPOTENCY_RETENTION_HOURS`(正の数、既定 24)。消しは生成の `shell.mjs` の scheduled が式によらず起動のたびに呼ぶ `purgeIdempotency`。app の `db/queries/framework/idempotency_sweep.sql` が既定の文に勝つ
- **接続先**:`neon()` は送り先を引数で受けない(1.0.2 の `index.mjs` は `neonConfig.fetchEndpoint` だけを読む)ので、env にあるときだけ `neonConfig.fetchEndpoint` を替え、無いときは触らない(test が `neonConfig` を自分で替える形も壊さない)

## DDL

- path:`db/framework/idempotency.sql`(生成器が `src/server.gleam` を宣言した app に吐く。fixture では `gen/fixtures/{notes,article,cms}/db/framework/idempotency.sql`)
- 変える表:`framework.idempotency` を新しく作る。列 `party text NOT NULL`・`key text NOT NULL`・`request_hash text NOT NULL`・`result jsonb NOT NULL`・`created_at timestamptz NOT NULL`。制約 `idempotency_pkey PRIMARY KEY (party, key)`。索引 `idempotency_created_at (created_at)`。`CREATE ... IF NOT EXISTS` で、ほかの表は触らない
- schema の全体像への追随:app の DDL(musearch なら `api/db/schema.sql` と migration)に同じ表を足すのは app の側。yumemi の `notes/db/schema.sql` は変えていない(workerd の確かめは schema.sql と生成の DDL の 2 本を当てた)
- 当てたのは `.scratch` の手元の PG(notes 55952、musearch api の test 55955、どちらも止めた)だけ。staging / production には当てていない

## 変えたもの

| file | 中身 |
|---|---|
| `src/yumemi/server/http.mjs` | 事前の引き・replay・409・失敗の後の引き直し・`repair`、decode の段で `s.rawArgs` |
| `src/yumemi/server/runtime.mjs` | `finish(outcome)` が記録を transaction の先頭へ、`commit` は `Accepted` を、`reject(stage, outcome)` は断りの transaction へ |
| `src/yumemi/step.gleam`・`io.gleam`・`io_ffi.mjs` | `io.finish_with` / `io.reject_with`(結果を添える)。`io.finish` / `io.reject` は残す |
| `src/yumemi/server/cron.mjs` | `purgeIdempotency`(既定 24 時間) |
| `src/yumemi/server/driver.mjs` | `DLEAM_SQL_ENDPOINT` → `neonConfig.fetchEndpoint`、`useSqlEndpoint(env)` |
| `src/yumemi/front/interactive.mjs` | キーを作る・保つ・捨てる、unsettled の失敗で After に移らない |
| `src/yumemi/gen/emit/idempotency.gleam`(新)・`back.gleam` | 既定の SQL 4 本(★ が勝つ)、DDL の file、shell の消し |
| `README.md` | `yumemi/server` の節に 0.13.0 の項、SQL の表に 4 行、Worker env に 2 つ |
| `test/yumemi_idem_*` | 生成器 2 本・server 28 項(柏木ゲート 2 で 1 項足した)・client 10 項・purge 3 項 |

生成物の差(fixture、全部):`src/gen/sql.mjs` に既定の 4 本、`src/gen/shell.mjs` に `purgeIdempotency` の import と scheduled の 1 行、`db/framework/idempotency.sql` を新しく、`public/priv/static/_yumemi/client.mjs`(article・cms、同梱の interactive の差)。

## 確かめ

### root

- `npm ci` exit 0(`build/idem-npm-ci.txt`、esbuild の allow-scripts の警告だけ)
- `gleam test`:基点で **`465 passed, no failures`**(`build/idem-test-before.txt`)→ 今 **`470 passed, no failures`**(`build/idem-test-final.txt`、末尾の字で見た)。途中で既存の 2 本が落ちた(DDL の header に `[sha256:` が無い、偽の DOM の fetch が status を返さず 503 扱い)ので、header に DDL の本文の hash、網の失敗は fetch が投げたときだけにして直した
- `gleam format --check src test` exit 0
- 新しい check を基点の `http.mjs`・`runtime.mjs` に差し替えて回すと 27 項中 ok 1、`a: one row` が 2 行で NG(`build/idem-check-server-control.txt`)。差し替えは戻して `cmp` で同じ字を見た

### fixture の生成器

notes・article・cms とも 1 回目 exit 0、`git add` の後の 2 回目 exit 0・未 stage の差 0 行(`build/idem-gen-{notes,article,cms}-{1,2}.txt`)。article・cms の面には根の esbuild の symlink を置いて回し、回した後に消した。

### workerd(notes、`build/idem-notes-probe-final.txt`)

wrangler 4.131.1 の `wrangler dev --local`(musearch api の node_modules)、空の PG 16 に `db/schema.sql` と `db/framework/idempotency.sql`。Neon の HTTP の口は `~/yumemism_repo/yumemi-bench/neonshim/server.mjs` を写した shim(要求を数える・`/__drop_next?then=n` で次の transaction を COMMIT した後に 503 + `Retry-After: 60` を返し、その後の n 本も 503)。`DATABASE_URL` の host は `db.notes.invalid`、on の Worker だけ `DLEAM_SQL_ENDPOINT=http://127.0.0.1:55953/sql`。worker は `neonConfig` を替えない。

```
ready on=200 off=503
(a) POST #1 key=a-5660e2eb… -> 200 {"id":"cdeb7e3b-b866-4a2f-998c-5450f42bef07","title":"idem a","body":"same","created_at":"2026-10-12T18:01:32.993Z"}
(a) POST #2 same key, same body -> 200 (replayed) {"id":"cdeb7e3b-b866-4a2f-998c-5450f42bef07","title":"idem a","body":"same","created_at":"2026-10-12T18:01:32.993Z"}
(a) same status true, same body true, rows with title 'idem a' = 1, idempotency rows = 1
(a) record: party=anonymous hash_len=64 result={"body":"{\"id\":\"cdeb7e3b-…\",…}","type":"applicati…
(b) POST same key, other body -> 409 {"code":"idempotency_conflict"}; rows with title 'idem a' = 1
(c) POST without key x2 -> 200, 200; ids differ true; rows with title 'idem c' = 2; idempotency rows = 1 (unchanged from (a))
(c) GET /api/notes?limit=2 (no key) -> 200 items 2
(d) POST, response dropped after COMMIT and the re-read also 503 -> 503 {"code":"upstream_unavailable","connector":"neon"}; committed rows = 1
(d) client retry, same key -> 200 (replayed) {"id":"6dbc9e85-dbe7-4ba1-8e11-8c5672bdf7b0","title":"idem d","body":"lost","created_at":"2026-10-12T18:01:33.046Z"}
(d) retry id = committed id true; rows with title 'idem d' = 1
(d') POST, only the transaction's response dropped -> 200 (replayed) {"id":"2dbd2208-…","title":"idem d2",…}; rows with title 'idem d2' = 1
(race) 2 parallel POSTs same key -> 200R, 200; same body true; rows = 1
(put) PUT x2 same key -> 200 null / 200 (replayed) null
(key) 256-char key -> 400 {"code":"invalid_argument","field":"idempotency_key"}; rows = 0
(no DDL) keyed POST -> 503 {"code":"unavailable"}; POST without key -> 200; rows with title 'idem noddl' = 1
(e) with DLEAM_SQL_ENDPOINT: POST -> 200 {"id":"ae0a0d07-…","title":"idem e","body":"on",…}; shim requests 27 -> 28
(e) without it (DATABASE_URL host db.notes.invalid): POST -> 503 {"code":"upstream_unavailable","connector":"neon"}, GET -> 503 {…}; shim requests 28 -> 28; rows with title 'idem e' = 1
```

- (d) は `then=2`(引き直しの読みと、読みの 1 回のやり直しも 503)で、利用者に 503 が返り、再投稿が commit 済みの 1 件を返す形。`then=0`(応答だけ失う)は同じ要求の中で記録を引いて 200 を返す((d'))
- (e) の off の Worker の log では、driver は `api.notes.invalid` を引きに行って名前解決で落ちた(15 回、`wrangler-off.log`)── env が無ければ今までの送り先
- (no DDL):表を一時的に改名して回し、戻した
- 対照(`build/idem-notes-control.txt`):基点 `876ce7d` を `git archive` した yumemi と、その notes の生成物で同じ shim に向けた Worker。同じキーの 2 回で `rows with title 'base a' = 2`(id が違う 2 件)、commit の後に応答を捨てた再投稿で `rows with title 'base d' = 2`
- cron(`build/idem-notes-purge.txt`、`--test-scheduled`):25 時間前と 23 時間前の行を入れて `/__scheduled` → `before scheduled: new-23h,old-25h` / `after scheduled: new-23h`
- PG・shim・wrangler は止めた

### 子の node の check(`build/idem-check-{server,client,purge}.txt`、全部 ok)

- server 28 項:先頭の記録、(a)〜(d)、並んだ 2 本(1 本目を 2 本目の commit まで待たせ、1 本目は 23505 で落ちて引き直し)、別の party の同じキーは別の書き、業務の失敗は記録しない、断りは断りの transaction に記録して再投稿で断りの行が増えない、order の直し、読みはキーを見ない、形の外れたキー、匿名の枠、★ の db_error が業務の一意の制約で落ちた書きを走らせ直したときの記録(柏木ゲート 2:`recorded` を commit の前に置いていたため、走らせ直した書きが記録なしで commit され、同じキーの再投稿で 2 行になっていた。`recorded` を commit の後に置いて直した)
- client 10 項:UUID のキー、503 で After に移らず入力が残る、網の失敗と次の再送で同じキー、成功で捨てる、Args が変われば新しいキー、4xx で捨てる、読みはキーを載せない
- purge 3 項:既定 24 時間、env の 1 時間、0 は既定へ

## musearch の写し

main `130635971`(yumemi 0.12.2 の lock)を `git archive` で `.scratch/musearch` に置き、api・www・muses・console・admin・auth の yumemi を本作業木への path 依存にした(`gleam deps download` 6 つとも exit 0、`yumemi 0.12.2 source = "local"`)。node_modules は手元の musearch への symlink。muses・console の brand・fonts、www の fonts・legal は exit 0(www に `build:brand` は無い)。写しを git にして、api・www・muses・console・admin の `src/gen` を消して api から `gleam run -m yumemi/gen -- . ..`。

- 生成器:exit 0・停止コード 0・2104 ファイル。2 回目も exit 0・差 0 行・未追跡 0(`build/idem-ms-gen-{1,2}.txt`)
- 生成物の差(main の commit 済みから):`api/src/gen/sql.mjs` に既定の 4 本、`api/src/gen/shell.mjs` に 2 行、`api/db/framework/idempotency.sql` が新しく、4 面の `priv/static/_yumemi/client.mjs`(同梱の interactive)。ほかに `_diagnostics.txt`(警告だけ)。★ は 1 字も替えていない
- **www**:`npm run build` exit 0・`npm test` **452/452**。**muses**:`npm run build` exit 0・`npm test` **514/514**(`build/idem-ms-{www,muses}-test.txt`)
- **api**:auth を build(exit 0)、`MUSEARCH_TEST_PG_PORT=55955 api/test/postgres.sh` の後に `api/db/framework/idempotency.sql` を当て(`framework` の表 9 → 10、`build/idem-ms-ddl.txt`)、`npm test` **1768/1768**(`build/idem-ms-api-test.txt`)。PG は止めた
- api の test はキーを送らないので、冪等の道は通っていない(キーの無い要求が今のままであることの確かめ)

## しなかったこと・次の版へ

- 版の行・tag・publish、Dleam 専用のドライバ(0.14)、86 の道、0.12.2 の「次の版へ」は触っていない
- 上の矛盾(musearch の auth の接続先)
- client のキーは要素の上に持つ。頁を読み直す・tab を閉じると、入力と一緒にキーも消える(sessionStorage に保つ形は今回の外)。★ の逃げ道(musearch の編集器など、自前の fetch)はキーを持たない ── 載せるなら逃げ道の側で `Idempotency-Key` を作る
- RETURNING で埋まる欄の記録の直しは transaction の外(上の「設計の選択」)
- `anonymous` の枠は、同じキーと同じ本文を知る別の匿名の要求には記録の応答を返す(キーは client の UUID なので、知るのは送った本人だけの前提)
