# yumemi-gen-8(WGy)── back の生成器(真壁、2026-09-26)

基点は yumemi main `3209703`、branch `impl/yumemi-gen-8`。写しは musearch `645ec49` を `git archive` で `gen/build/wgy/snap/` に置いた(musearch の作業木には 1 file も書いていない)。証跡は全部 `gen/build/wgy/`(git 管理外)。commit は checkpoint 7 本(`7459588`〜、7 本目はこの report)。**完了条件を全部は満たしていないので squash していない**(下の「届かなかったもの」)。

## r2(2026-09-26 02:58〜、役員 人見の裁定 A「全部閉じる」と鷹野の裁定 2〜5 を受けて)

**DDL:無し**(migration / schema に触れていない。staging / production にも触れていない)。

**結論:閉じていない。**完了条件 6 つのうち、閉じたのは 3(connector)と 4 の一部(生成 SQL を PG で走らせた・cursor の穴の欠陥を直した)と 6(この report)。**1(`runtime.mjs` の生成)と 2(`http_runtime.mjs` の生成)は 1 行も生成していない。**だから 5 の「`api/src/gen` を生成物で丸ごと置き換える」も満たしていない。写しで測れたのは「r1 の back の生成物 15 本 + 本便の connector 9 本を置き、★ の patch を当てた写しで api の test が 690 / 690」まで。690 は基点の 660 に、鷹野の裁定 5 で足した semantic test 30 本を加えた数。**分けて完了にはしていない**。squash もしていない(r1 の 8 本 + r2 の checkpoint を残す)。

### 完了条件ごとの現在地

| # | 条件 | 現在地 | 証拠 |
|---|---|---|---|
| 1 | `runtime.mjs` の verb / reads / root の名ごとの分岐(約 145)を宣言から生成、業務の行は ★ hook | **未着手**。基点の `makeContext` は `name===` の分岐が 173 本。生成 SQL に揃えると手書きの runtime では test が割れる(下の「採用の測り」) | `r2-adopt-test.txt` |
| 2 | `http_runtime.mjs` を framework + 生成に | **未着手**。r1 の棚卸しの「残」のまま | ── |
| 3 | connector 9 本の宣言と FFI の口 | **閉じた**。宣言 `server.connectors`(`Connector` / `Call` / `Send` / `Enqueue` / `Fetch` / `Pure`)、reader、emitter。型と typed な包みは ★ `src/connector/<name>.gleam`、Heaven / lit.link の実装は ★ `src/heaven_ffi.mjs` / `src/litlink_ffi.mjs`(gen の外へ) | `gen/test/yumemi_gen_wgy_test.gleam` の 2 本、写しの 690 / 690 |
| 4 | 生成 SQL の採用 | **一部**。生成 SQL 389 本を PG で PREPARE して 370 本が通る、読み 165 本を EXECUTE して 163 本が通る(落ちるのは下の名指しの ★ 契約)。keyset の cursor の穴に型が無かった生成器の欠陥を直した(`widget_list/published` ほか 2 本)。**GENERATED を名乗る SQL を生成物に揃えるのはしていない** ── 揃えると手書きの runtime と穴の契約が合わない(1 と同じ便でないと閉じない) | `pg-prepare-gen-r2.txt`、`pg-exec-gen-r2.txt`、`sql-adopt-r2.txt` |
| 5 | 写しで sha 無し 0・丸ごとの置き換え・`npm test` が基点と同じ数・生成 SQL を PG で | **一部**。`npm test` 690 / 690(2 回連続)。sha 無しは **91**(r1 の 102 から connector 9 本・ffi 2 本の分が減った)、生成物と byte で不一致 203、生成器が出さない 19。生成 SQL は PG で走らせた(4) | `r2-api-test-2.txt`、`r2-api-test-3.txt`、`nosha-r2.txt` |
| 6 | report の更新 | この節 | ── |

### connector(鷹野の裁定 2)

- 宣言(`src/framework/server.gleam` に新しい型 `Connector` / `Port` を足した。0.11.0 の既存の型は 1 字も変えていない。`git diff v0.11.0 -- src/framework` は 8 file、+358 行、削除 0)
  - `Call(name, op)` / `Send(name, op)` ── framework の operations の `call`(Read / Write の境界)
  - `Enqueue(name, kind)` ── operations の `enqueue`(Write)
  - `Fetch(name, module, js, arity)` / `Pure(name, module, js, arity)` ── ★ の JS(`module` は `src/` からの道)
- 生成物 `src/gen/connector/<name>.gleam` は `@external` と `connector.read` / `connector.write` の包みだけ。引数と戻りは型変数で、型を決めるのは ★ の包み
- 写しの宣言は `snap-g/api/src/server.gleam` の `connectors`(9 本)。★ の import の書き換えは `gen/connector/<name>` → `connector/<name>` の 1 行ずつ(★ Service 30 本、test 11 本)

### 生成 SQL を Postgres で(PG 55540、`musearchwgy`)

`pg-prepare.sh`(1 本ずつ `PREPARE`、取引は ROLLBACK)と `pg-exec.sh`(読みを穴 NULL・clauses 全開で `EXECUTE`)。

| 測り | 結果 |
|---|---|
| PREPARE(生成 389 本) | 370 通る / 19 落ちる(r2 の直しの前は 368 / 21) |
| EXECUTE(読み 165 本) | 163 通る / 2 落ちる(`notification_inbox` の 2 本、下の名指し) |
| EXECUTE(verb の WITH 160 本) | 6 本は通る、142 本は `framework.require_rows` の `conflict`(空の DB で 0 行 ── 文としては走り切っている)、12 本は下の名指し |
| `owner Self` の 28 本 | PREPARE・EXECUTE とも全部通る |

**落ちる 19 本は生成器と ★ の schema の契約のずれ(名指し)**:

| 数 | 何 | 行き先 |
|---:|---|---|
| 12 | `notification` は USER DO の SQLite に置く Entity(★ の注記)なのに、生成器は Neon の `app.notification` の SQL を出す | 器の宣言が要る(生成器)。今は宣言が無い |
| 3 | `muse_setting_spec` の `type_` / `default`(★ の列は `type` / `default_value`、sum を text で持つ)。hook `decode_muse_setting_spec` と同じ理由 | 列名と sum の写像の宣言が要る |
| 2 | `report.message`(sum の `MessageRef` を 2 列 `message_chat` / `message_id` に割る) | 同上 |
| 2 | `page_view.stores`(`List(StoreId)` を ★ は `uuid[]` で持つ、生成器は jsonb) | 同上 |

### 採用の測り ── GENERATED を名乗る SQL を生成物に揃えると

基点(`snap-base-pristine`)の `db/queries` 280 本のうち先頭行が GENERATED の 120 本は、生成と一致 60 / 違う 59 / 生成器が出さない 1。違う 59 本を生成物に置き換えて写しの api test を回すと、**580 秒で打ち切った時点で 634 pass / 105 fail**(`SQL:` の semantic test 44、HTTP の test 61 ほか)。穴の並びが手書きの runtime の呼び方と合わないため。**1(runtime の生成)と同じ便でないと閉じない**のは r1 の鷹野宛 1 のとおりで、本便の時間の中では届かなかった。写しは元に戻した(戻した後に 690 / 690 を 2 回)。

### SQL の 30 本(鷹野の裁定 5)

sql.mjs にだけ在った ★ の SQL 30 本(r1 で `db/queries` に出した)に、SQL manifest の行と semantic test(inside / outside)を足した。`test/sql-cases-wgy-{1,2,3,4}.mjs` に置き、`sql-cases.mjs` の helper を渡す。直した ★ の SQL が 2 本ある:

- `allow/course` ── jsonb の要素の別名 `c` が course の `c` を隠して、どの query に合成しても `column c.phase does not exist` で落ちる(基点の sql.mjs でも同じ。runtime はこの断片を引いていない)。`cl` に直した
- `widget_list/published` ── 古い生成器の出力のまま(`$3 IS NOT NULL` が先に来て PG が型を決められない)。生成物に揃えた

allow の断片のうち 3 本(`allow/ledger` / `allow/muse_schedule` / `allow/shift_target`)は本文が `TRUE` で、断片そのものは何も除かない。outside は包む query の id の条件で除いている(test の文言にそう書いた)。

### WGm に渡す patch(`docs/reports/yumemi-gen-8-patches/`、tracked)

どちらも musearch `645ec49` の写しの上で `patch -p1 --dry-run` が通ることを確かめた。r1 の分(`snap-star.patch`)を含む累積。

| file | 数 | 中身 |
|---|---:|---|
| `star.patch` | 99 file | `src/server.gleam`(宣言)・`src/hooks.mjs`(★ hook)・`src/connector/*.gleam` 9 本(型と包み)・`src/heaven_ffi.mjs` / `src/litlink_ffi.mjs`(gen から移した。相対 import の道を直した)・★ Service 30 本の import・`release_do.mjs`・`db/queries` 30 本(うち 2 本は上の直し)・`gen/sql_manifest.json` の 30 行・test 21 本(import の道、`sql-cases-wgy-*`、`source_contract` の ★ の sha の層)・`docs/evidence/wgy-star-sha256.txt`(書き換え前と後の hash の対、30 行)。**`api/gleam.toml` の hunk は写しで yumemi を作業木の path に向けたもので、WGm は取らない**(0.11.1 を Hex から引く) |
| `gen-hand.patch` | 6 file | 手書きのまま残る `http_runtime.mjs` / `runtime.mjs` への差分(`attached` の import、codec の名 `consentVersion` / `ledgerStore`、connector と ffi の import の道)、framework / ★ へ移った `contracts.mjs` / `driver.mjs` / `heaven_ffi.mjs` / `litlink_ffi.mjs` の削除。**runtime を生成する便で消える差分** |

`source_contract` の ★ の sha の層は、既存の層を書き換えず、「書き換え後の byte のときだけ前の hash として読む」対の表にした(`starHash`)。WGm の判断で、ふつうの新しい層に替えてよい。

### 名指しの ★(生成物が名指しで import するもの・生成器が出さないもの)

| ★ | 置き場 | 理由 |
|---|---|---|
| hook 12 本(`metrics_rollup_args`、`decode_*` 10、`cursor_args`) | `src/hooks.mjs` | r1 の表(下の「★ hook に移した行の一覧」) |
| connector の型と包み 9 本 | `src/connector/*.gleam` | 裁定 2 |
| Heaven / lit.link の取得 | `src/heaven_ffi.mjs` / `src/litlink_ffi.mjs` | 裁定 2(業務) |
| DO の adapter | `src/user_do.mjs` / `src/release_do.mjs` | r1 の宣言 |
| 素の SQL 160 本 + sql.mjs から出した 30 本 | `db/queries/**` | 生成器が出さない SQL(framework の session・outbox・API key、手書きの verb ほか) |
| `http_runtime.mjs` / `runtime.mjs` | `src/gen/`(sha 無し) | **生成していない**(1・2)。本来は ★ でなく生成物になるもの |
| Gleam 側 `allow/` 22・`reads/` 31・`root/` 35・`query.gleam` | `src/gen/`(sha 無し) | 生成物で置き換えると ★ の requalify 45 file と契約のずれ 37 件が要る(r1 の鷹野宛 1 (a))。本便では置き換えていない |

### 閉じた判定に対する現在地

WGm の BRIEF(A / B / C の判定)は、この session から読める場所で見つけられなかった。代わりに、親ゴール(人見 09-26 01:4x「`api/src/gen` に手書きが残らない」)と本便の検収の 3 つに当てる:

- **sha 無し 0**:91(`allow/` 22・`reads/` 31・`root/` 35・`query.gleam`・`http_runtime.mjs`・`runtime.mjs`)。届いていない
- **生成物と byte で一致しない file 0**:不一致 203・生成器が出さない 19。届いていない
- **api の `npm test` が基点と同じ数**:基点の 660 は全部通る(+ 新しい 30 本で 690 / 690)。ただし**丸ごとの置き換えでの数ではない**

残りを閉じるのに要るのは、(a) runtime / http_runtime の emitter(生成 SQL の穴の契約に従う)、(b) GENERATED の 59 本 + 生成器だけが出す SQL の採用、(c) Gleam 側の置き換えと ★ の requalify 45 file・契約のずれ 37 件、(d) 上の 19 本の器・列の写像の宣言。(a) と (b) は同じ便で当てないと test が割れる(採用の測り)。

### 検収(r2)

| 項目 | 結果 | 証拠 |
|---|---|---|
| root `gleam build` | 0 | `r2-root-build.txt` |
| `cd gen && gleam test` | **255 passed**(r1 253、基線 241)。新しい test 2 本(connector の口、読めない口で reader が止まる)。既存の test の書き換えは 1 本(cursor の穴の型の文字列) | `r2-test-2.txt` |
| `gleam format --check src test` | root・gen とも 0 | ── |
| Article fixture ×2 | exit 0、`diff -r` 0、tracked と一致(fixture は connector を宣言しないので生成物は増えない) | `fx-r2`、`fx-r2b` |
| 写し ×2 | exit 4、1454 file(r1 の 1445 + connector 9)、`diff -r` 0。診断は r1 と行ごとに同一(face 97、back 0) | `out-r2-c`、`out-r2-e` |
| 写しの api `npm test` | **690 / 690**(2 回連続)。その前の 1 回は 689(`2a-8` が `ledger_store_taken`。直前に打ち切った採用の測りが DB に残した行で、次の 2 回は通った) | `r2-api-test-2.txt`、`r2-api-test-3.txt`、`r2-api-test-1-after-kill.txt` |
| 0.11.0 の公開型 | `git diff v0.11.0 -- src/framework`:8 file、+358、削除 0 | ── |

### 鷹野宛(r2)

1. **1・2 は届かなかった。**止め線 4:00 の中で、runtime の分岐 173 本と http_runtime を生成して、生成 SQL の採用と一緒に test を通すところまでは届かないと判断し、確かめられる 3・4・5 の一部と裁定 5 を先に閉じた。次の便は「runtime / http_runtime の emitter + GENERATED の 59 本の採用」を 1 つの単位で持つ必要がある(採用の測りで 105 本割れる)
2. **生成器と ★ の schema の契約のずれ 19 本**(上の表)。器(DO の SQLite)と列の写像(列名・sum の多列・`uuid[]`)の宣言が無いと、生成器は正しい SQL を出せない。宣言を足すか、名指しの ★ SQL として残すかの裁きが要る
3. PG 55540 は本便で起こした(`snap-g/api/test/build/pgdata-public`、pid は終端で止める)

# r1(以下は r1 の記録のまま)

## 結論

- **届いた**:宣言 4 つ(+ hook)の型と reader、`http_runtime.mjs` を入力として読む行 0、Route の曖昧 22 → 0、`owner Self` 28 → 0、面の Route を面が参照する Service に絞った(www に `Put` 無し)、back の生成物 15 本(registry / sql / codec / attached / shell / queue / cron / key / subject / source / operations / entry×4 ── `entry/http.gleam` は既存の Route の表に dispatch を足した)、framework の宣言の型 1 module と server の JS 7 本(Hex に載る `src/framework/server.gleam` と `src/framework/server/`)
- **写しで**:生成した back の file 15 本を写しの `api/src/gen` に置き、framework に移った 2 本(`contracts.mjs` / `driver.mjs`)を消した写しで、api の `npm test` は **660 中 659 pass**(基線 660 / 660)。落ちる 1 本は SQL manifest の test で、sql.mjs に埋まっていた ★ の SQL 30 本を `db/queries` に出した分の manifest の行が無いため(下)。registry は基点と **129 行・(method, path) 全行一致**
- **届かなかった**:`http_runtime.mjs`(767 行)と `runtime.mjs`(1132 行)の生成、`connector/*.gleam` 9 本、Gleam 側の生成物(allow / reads / root / query ほか)での丸ごとの置き換え。**「api/src/gen を丸ごと置き換えて基点と同じ数で通る」は満たしていない**。置き換えた後の写しの `api/src/gen` で sha256 ヘッダの無い file は **102**(0 にしていない)。理由と、鷹野さんに裁いてほしい矛盾は「鷹野宛」1

## DDL

無し。migration / schema / database は変更していない。staging / production に触れていない、deploy / publish / push もしていない。

## 宣言(`framework/server`、新しい module)

`src/framework/server.gleam` に型だけを足した。app は `src/server.gleam` に const を置く(どれも無くてよい)。0.11.0 の既存の型の欄・構成子は 1 つも変えていない(下の「0.11.0 の公開型」)。

| const | 型 | 中身 |
|---|---|---|
| `routes` | `Route(service, method, path)` / `RouteVia(.., credential)` / `Internal(service)` | 導出規則と違う口だけ。path は `:name`。`RouteVia` は媒体の合う入口だけが持つ |
| `aliases` | `Alias(name, service, method, path, credential, external_id)` / `AttachedAlias(name, attached, method, path, credential, who)` | REST v1 の別名 |
| `attached` | `Attached(name, method, path, who)` | Service でない口。面の `api.gleam` の `attached` も、back の `attached.mjs` もここから |
| `cron` | `Cron(schedule, jobs: [EachDue(service, query) / Hooked(service, hook)])` | 式ごとの仕事 |
| `durable_objects` | `DurableObject(class, module, adapter, methods)` | DO の class と ★ の adapter |
| `hooks` | `Hook(name, module)` | 生成物が import してよい ★ の名。`decode_*` は codec が re-export する |

Service は名(文字列)で指す ── Service の値は型引数が Service ごとに違い、1 つの List に並ばないため。名が無い行・同じ Service の 2 行・無い attached / hook を指す行は exit 4 で名指し(`reader/server.gleam` の `notes`)。読めない形(List の literal でない、構成子が違う)は reader が止める。

写しに置いた宣言は `gen/build/wgy/snap-g/api/src/server.gleam`(routes 6 行・aliases 6 行・attached 6 行・cron 1 式 2 仕事・DO 2・hooks 12)。**musearch の registry の 129 行のうち、導出と違うのは 6 行だけ**(`pageview_record`・`schedule_list`・`store_roster_list`・`store_api_key_{issue,revoke}`・`roster_upsert`)。

## 向き ── `http_runtime.mjs` を入力として読まない

- `yumemi_gen.gleam` の `attached_routes`(`api/src/gen/http_runtime.mjs` を読む 40 行)を消し、`reader.read` が `src/server.gleam` の `attached` を `App.attached` に入れる。`model.AttachedRoute` に `who` を足した(生成器の内部の型で、公開の型ではない)
- `grep -rn "http_runtime" gen/src` は 6 行で、**全部が生成物の名としての出現**(`emit/entry.gleam` の `@external(javascript, "../http_runtime.mjs", ..)` 3 行と、注記 3 行)。`simplifile.read` で読む file は `source.gleam`(★ の Gleam)・`face.gleam`(面の gleam.toml)・`static_source.gleam` だけ。db/queries は FFI の `sql_files` が ★ の SQL として読む
- 面の emitter:`emit/front.gleam` の `api_routes` を、`emit/entry` が出した `http.gleam` の本文を文字列で割って読む形から、`entry.routes(app)` を直に読む形に変えた(区画は `api_text`〜`attached_route_text` と `api_routes`〜`colon_path` だけ。門の区画 `shell_*` は触っていない)。`blob_copy` の live の頭は `GENERATED from src/server.gleam`
- fixture `article` の `api/src/gen/http_runtime.mjs` を消し、同じ 3 行を `fixtures/article/src/server.gleam` に写した

## Route の曖昧(22 → 0)

`emit/entry.gleam`:

1. **上書き**:`server.routes` の行があればそれを使い、導出しない。`Internal` は口を持たない。path の `:name` を `{name}` にして `path_keys` を引く
2. **対象を allow の Entity から解く**(改名しない):名前の前置きで候補が複数なら、allow の Entity そのもの、無ければ allow の Entity を held で指す候補を採る。前置きが Entity に当たらない名は allow の Entity を対象にし、最後の語を動詞にする。写しでは `schedule_add` / `schedule_withdraw` / `schedule_availability` の 12 行が**上書き無しで**registry と同じ口になった(`schedule_add` → `POST /api/muse_schedule`)
3. **面の Route を面が参照する Service に絞る**(`emit/front.gleam` の `face_service_names`):page の置き場・block・component の calls と reload が名指す Service だけ。写しの 3 面は www 19 / muses 59 / console 23 行(基点の生成は 110 / 109 / 109)、**www の `Method` に `Put` が無い**

写しの診断(×2、`out-final-{a,b}`、`diff -r` 0 行、1445 file):exit 1 / 2 / 3 / 4 = **3 / 0 / 0 / 97**(基点 3 / 0 / 0 / 147)。**back の exit 4 は 0**(基点 50 = Route の曖昧 22 + `Self` 28)。残る 97 は全部 face の行で、基点と行ごとに同一(F6 の射程)。警告 49 も基点と同一。

## `owner Self`(28 → 0、裁定 4 (a))

`emit/sql.gleam`:hw-1 の鷹野宛 1 の案。`-- allow:` の契約に主体の鍵の穴を足した。

- 契約の行:`-- allow: clauses=$N [party=$M] [subject=$K]`。`K` は party の穴があれば `N + 2`、無ければ `N + 1`
- 句:`(cl->>'owner'='self' AND <who の Entity>.<key の列>=$K)`。who の Entity は `As<Entity>` の Entity(`AsMuse` → muse、`AsStore` → store)。`Self` に `As` で始まらない who(`Anyone` など)が付くのは exit 4
- 句が全部 `Self` で、主体の Entity が読みから辿れないとき(`link_import/current_identity` は consent_version を読む)は、主体の行そのものを鍵の穴で引く入れ子の EXISTS にして、相をそこで照らす
- 実測:`store_roster_list/mine` は `… EXISTS(SELECT 1 FROM app.store s WHERE s.id=r.store_id AND EXISTS(… (cl->>'owner'='no_owner' OR (cl->>'owner'='self' AND s.id=$3))))`、契約 `-- allow: clauses=$2 subject=$3`

## back の emitter(`emit/back.gleam`・`emit/codec.gleam`、`src/server.gleam` を宣言した app だけ)

| 生成物 | 導く元 | framework / ★ hook |
|---|---|---|
| `registry.mjs` | Service・entry の導出・`routes` / `aliases`。`fields` は Args の名、`folded` は Service の source を**生成時に** framework の `foldable` で判定、面を 1 つだけ宣言した Service は `entry`。面で prefix の違う Session の口は `<service>_<入口>` の別名の行 | `validateWho`(framework/server/contracts) |
| `sql.mjs` | app の `db/queries/**` + この回に生成した SQL のうち app に無い道(同じ道は app が勝つ ── 実行側の穴の契約は app が採った SQL に合っているため) | ── |
| `codec.mjs` | 値型の scalar 表・整数の値型・Entity ごとの decoder(Property の型から、表は `emit/codec.gleam` の頭) | 共通の口は framework/server/codec。`decode_*` の hook を名指しで re-export(導出より勝つ) |
| `attached.mjs` | `server.attached` | ── |
| `shell.mjs` | cron の式ごとの分岐・DO の class | fetch / queue / AppSystem / DO の器は framework/server/worker |
| `queue_runtime.mjs` | kind = Service が `queue.<kind>` で呼ぶ Service、id の codec = Args の型、consumer = root の 1 文を持たない kind(自分を呼ぶ root 持ちの Service の root を借りる、Staff なら staffRoot) | sweep / consume は framework/server/outbox |
| `cron_runtime.mjs` | `EachDue` → `<動詞><読み>`(`releaseDue`)、`Hooked` → `<動詞><頭の語>`(`rollupMetrics`) | 回し方は framework/server/cron、期間の計算は ★ hook `metrics_rollup_args` |
| `key.gleam` / `subject.gleam` / `source.mjs` | key が値型の Entity / `subject: True` の Entity / payload を持つ sum | ── |
| `operations_ffi.mjs` | root の子の List(with の逆向き矢印、`rootPhotos`) | 4 つの口は framework/server/operations |
| `entry/http.gleam` | Route の表(既存)+ 検査 1〜10 の dispatch(1 本に揃えた) | 検査の実体は `http_runtime.mjs`(★ のまま、下) |
| `entry/{auth,queue,system}.gleam` | framework の session / outbox の契約(固定) | ── |

framework の JS(`src/framework/server/`、7 file、全部新規):`driver.mjs`(Neon の transport)、`contracts.mjs`(`validateWho`、生成時の `foldable` ── 子の payload に root の `it.<欄>` を許した。`store_request_handle` の fold が基点の registry の手書きの値と一致する)、`operations.mjs`、`outbox.mjs`、`cron.mjs`、`worker.mjs`、`codec.mjs`。Cloudflare と Neon に寄る(基盤の前提どおり、裁定 1 (a))。

### 写しでの確かめ(`gen/build/wgy/snap-g`)

写しの ★ の側の変更(全部 `gen/build/wgy/snap-star.patch`):`src/server.gleam` と `src/hooks.mjs` を足す、sql.mjs に埋まっていた ★ の SQL 30 本を `db/queries/**` に出す(`moved-sql.txt`)、`release_do.mjs` の `gen/driver.mjs` を framework へ、test 4 本の import の道(`contracts.mjs` / `driver.mjs` を framework へ)と `logic.test.mjs` の `c.cv` → `c.consentVersion`、api の `gleam.toml` の yumemi を作業木の path に。**手書きのまま残した** `http_runtime.mjs` / `runtime.mjs` には、生成の codec の名(`c.cv` → `c.consentVersion`、`c.ledger` → `c.ledgerStore`)と、`attached` を `./attached.mjs` から import する差分だけを当てた。

| 項目 | 結果 | 証拠 |
|---|---|---|
| 生成した back の 15 本を置いた写しの api `npm test` | **659 / 660 pass**(基線 660 / 660)。落ちる 1 本は `source_contract` の「SQL manifest」で、`db/queries` に出した ★ の SQL 30 本の manifest の行(semantic test 付き)が無い | `final-api-test.txt`、`api-test-base.txt` |
| registry の行 | 基点 129 行と**名の集合・(method, path)・credential・target・externalId・who・folded・module が全行一致**。`fields` だけ 4 行が違う:consumer 3 本(`reservation_notify` / `store_request_notify` / `notification_notify`)は HTTP の口を持たず consumer 側が `['id','event']` で上書きする行、`heaven_embed_code` は Args の名 `heaven`(path の `:heaven` と同じ名)で、基点の手書きは `id` | `registry-compare.txt` |
| route-match(3 面の `api.gleam` を生成物のまま) | pass 3 / fail 0。www の `Method` に `Put` 無し | `final-api-test.txt` |
| 3 面の `gleam build`(生成の `api.gleam` を置いて) | www / muses / console とも exit 0 | `face-*-build.txt` |
| codec の hook を外す試し | `decode_store` を外すと 659(test は通る)が、基点は店の API key の digest を読まない(None)。導出は `secret.hmac(<digest>)` で読むので、保存の境界で digest を HMAC し直す口を開ける。hook に残した。`decode_course` を外すと 658 | `try-decode_*.txt` |

## 棚卸し(行の塊ごと、基点 `645ec49` の `api/src/gen`)

「状態」の ✓ は本便の生成物か framework に移った塊、**残** は本便で生成していない塊(行き先は決めた)。

| file | 行 | 塊 | 分類 | 行き先 | 状態 |
|---|---|---|---|---|---|
| `registry.mjs` | 1–2 | 頭・`validateWho` の import | framework | `framework/server/contracts.mjs` | ✓ |
| | 3–255 | Service / root の import | 生成 | `registry.mjs` | ✓ |
| | 256–259 | `folded*` の const | 生成(生成時の foldable) | `registry.mjs` の `folded` | ✓ |
| | 261–404 | Service 122 行 + v1 の別名 6 行 | 生成(導出 + `routes` 6 + `aliases` 6) | `registry.mjs` | ✓ |
| | 406–408 | `byName`・validateWho の loop | 生成 | `registry.mjs` | ✓ |
| `http_runtime.mjs` | 1–14 | import | 生成 | `http_runtime.mjs` | **残** |
| | 15–68 | cookie・session の cookie・`_mb` の署名と検証・credential・API key・rate limit | framework | `framework/server/http`(未作成) | **残** |
| | 70–133 | `optionalFields`・`idTypes`・`listIdTypes`・`numericTypes` | 生成(Args の型) | 同上 | **残** |
| | 134–218 | 値の検査(invalid / required / enum / integer / date / theme / id list / link pairs)と列挙の集合(`consentKinds` ほか。`widgetKeys` は F6 が消す) | framework(型ごとの写し)+ 生成(sum の構成子) | 同上 | **残** |
| | 219–356 | `decodeField`(key の名ごとの分岐 130 行) | 生成(Args の型)+ ★ hook(`schedule_add` の `bad_range`、`store_request_file` の `bad_kind`、pageview の path の `?`/`#`) | 同上 | **残** |
| | 357–379 | response・`apiEncode` | framework + ★ hook(`schedule_availability` の preps、`link_import` の組) | 同上 | **残** |
| | 380–412 | `logicCodes`・`logicFailureStatus` | 生成(Service の Error の構成子)+ ★ hook(業務の HTTP status の表) | 同上 | **残** |
| | 413–438 | failure・check・`host`(入口の名 → `<NAME>_HOST` の表は生成) | framework | 同上 | **残** |
| | 439–446 | `attached` 6 行 | 生成 | `attached.mjs`(写しの手書きは import に替えた) | ✓ |
| | 447–582 | 検査 2〜9(route・origin・browser・admit・resolve・subject・decode・judge) | framework + ★ hook(pageview の Origin と抑止、socket の Origin、`fan_read` の 404、blob の raw 受け) | 同上 | **残** |
| | 583–682 | blob の put / copy・`userDo`・`pageviewSuppressed`・`recoverRosterUpsert` | ★ hook | `hooks.mjs` | **残** |
| | 683–767 | execute(browser_adult / session_read / session_subject は framework、blob / media / socket / 通知の DO・Accepted の body・制約名 → code の表は ★ hook) | framework + ★ hook | 同上 | **残** |
| `codec.mjs` | 1–128 | import・export | 生成 | `codec.mjs` | ✓ |
| | 129–148 | scalar・integerKeys・checked / parse / option / unwrap / text / tag / encode / phase | 生成(表)+ framework(口) | `codec.mjs` + `framework/server/codec.mjs` | ✓ |
| | 149–310, 356–365 | Entity の decoder 24 本 | 生成 18 本(生成は基点に無い Entity の分も含めて 27 本を導く)+ ★ hook 6(`decode_{muse_schedule,reservation,prep}` 店の時刻を分の整数で持つ列、`decode_course` 列の名の揺れ、`decode_store` 秘密を読まない、`decode_muse_setting_spec` 型の値の名) | `codec.mjs` + `hooks.mjs` | ✓ |
| | 253–258, 311–355, 366–385 | `decodeLedgerStore`・集計の decoder 2 本(と補助 5)・`decodePage`・`cursorArgs` | ★ hook 5(台帳・ER の外の集計・頁) | `hooks.mjs` | ✓ |
| `runtime.mjs` | 1–53 | import | 生成 | `runtime.mjs` | **残** |
| | 54–64, 90–114, 138–162 | statement / run / 取引の再試行・関係の capability・seededId / HMAC・session / API key / 発行 / 失効 | framework | `framework/server/runtime`(未作成) | **残** |
| | 65–89 | 関係の decoder の表 | 生成(Entity の decoder) | 同上 | **残** |
| | 115–137 | 店の時刻・jsonArray・台帳の種別・API key / claim の label | ★ hook(label は ★ の const を名指し) | `hooks.mjs` | **残** |
| | 163–235 | `actorFor` | 生成(allow の who と Actor の型)+ ★ hook(pageview の viewer ほか) | 同上 | **残** |
| | 237–251 | root の集合 15 本 | 生成(root の Entity) | 同上 | **残** |
| | 252–279 | connector の診断 | framework(名の表は生成) | 同上 | **残** |
| | 280–361 | `loadRoot`(Service ごとの穴の並び) | 生成(root の SQL の穴の契約) | 同上 | **残** |
| | 362–934 | `makeContext`:verb の stage 約 60・read 約 75・connector の call 8 の名ごとの分岐 | 生成(verb / reads の SQL の穴の契約)+ ★ hook(heaven / litlink / screen / invite / embed の実装) | 同上 | **残** |
| | 935–1002 | commit(fold)/ enqueue / reject / finish / invoke | framework | 同上 | **残** |
| | 1003–1132 | DO の context | framework + 生成 | 同上 | **残** |
| `driver.mjs` | 1–17 | Neon の transport | framework | `framework/server/driver.mjs` | ✓ |
| `shell.mjs` | 1–35 | import・fetch / queue・cron の分岐 | 生成 + framework | `shell.mjs` + `framework/server/worker.mjs` | ✓ |
| | 36–60 | AppSystem・DO の class 2 | framework(器)+ 生成(class 名・method) | 同上 | ✓ |
| `contracts.mjs` | 1–31 | `validateWho`・`foldable` | framework(foldable は生成時だけ) | `framework/server/contracts.mjs` | ✓ |
| `cron_runtime.mjs` | 1–64 | releaseDue(回し方)・期間の計算 | framework + 生成 + ★ hook `metrics_rollup_args` | `cron_runtime.mjs` / `framework/server/cron.mjs` / `hooks.mjs` | ✓ |
| `queue_runtime.mjs` | 1–63 | kind・id の codec・consumer の表・sweep / consume | 生成 + framework | `queue_runtime.mjs` / `framework/server/outbox.mjs` | ✓ |
| `source.mjs` | 1–16 | `visit.Source` の写し | 生成 | `source.mjs` | ✓ |
| `heaven_ffi.mjs` | 1–286 | Heaven の頁の取得・照合 | ★(connector の実装) | gen の外(`src/heaven_ffi.mjs` など、WGm) | **残**(写しでは動かしていない) |
| `litlink_ffi.mjs` | 1–255 | lit.link の取得 | ★ | 同上 | **残** |
| `operations_ffi.mjs` | 1–6 | 4 つの口・`rootPhotos` | framework + 生成 | `framework/server/operations.mjs` + `operations_ffi.mjs` | ✓ |
| `key.gleam` | 1–139 | Entity の Key | 生成 | `key.gleam` | ✓ |
| `query.gleam` | 1–394 | Select の値 | 生成(既存) | 再生成で揃う(★ の requalify 45 file が要る、下) | **残** |
| `subject.gleam` | 1–8 | subject の 4 つ | 生成 | `subject.gleam` | ✓ |
| `sql.mjs` | 1–310 | `db/queries` の 280 本 | 生成 | `sql.mjs` | ✓ |
| | 311–340 | sql.mjs にだけ在る ★ の SQL 30 本 | ★(手書きの SQL) | `db/queries/**`(写しで出した。manifest は WGm) | ✓(写し) |

**ディレクトリ**(生成物との byte 比較、`out-final-a` と基点):

| 在処 | 数 | 本便の後 | 行き先 |
|---|---:|---|---|
| `allow/` | 22 | 22 本とも本文が違う(hw-2 の `SystemActor` / `Actor`) | 再生成で揃う ── ★ の側の追随(WGm) |
| `connector/` | 9 | 生成器は吐かない。**宣言が無い**(`connector.* declaration` と名乗るが ★ に宣言が無い) | connector の宣言の設計が要る(鷹野宛 2) |
| `entry/` | 4 | 3 本(auth / queue / system)はヘッダだけ違う、`http.gleam` は Route の表 + dispatch の 1 本に揃えた(本文が違う) | ✓ |
| `reads/` | 70 | ヘッダだけ 1・本文 52・吐かない 17(`store_inbox` の「manual SQL」ほか、手書きの読み) | 再生成で揃う + 手書きの読みの宣言(WGm) |
| `root/` | 123 | ヘッダだけ 64・本文 59 | 再生成で揃う |
| `types/` | 86 | 一致 84・本文 2 | 再生成で揃う |
| `draft/` | 35 | 一致 35 | ── |

全体で 369 file のうち、生成器が同じ道を出さないのは **45 → 32**(残りは `http_runtime` / `runtime` / `heaven_ffi` / `litlink_ffi` / `connector/` 9 / `reads/` 17 と、framework に移って消える `contracts` / `driver`)。

### Gleam 側を丸ごと置き換えた試し(`snap-full`)

写しの `api/src/gen` を生成物で丸ごと置き換え、`gen/scripts/requalify.py` で ★ 45 file(From 35 / Field 292 箇所)を付け替えると、api の `gleam build` は 15 file・37 件の error で止まる(`full-build.txt`)。生成器と ★ の契約のずれ:consumer の root(`store_request_notify` の reads が `it.store_request` を読むが Root に無い)、`article_list_mine` の reads の引数の数、`article_search` の `reads.Near`(hw-1 で名指し済み)、`heaven_link` の順序の値の型、`pageview_record` の root の `browser`、他の Service の reads を ★ が引く(`course_add` → `reads.ledger_store_exists`)。**★ の付け替え(requalify)は「業務の行を hook に移す」の外**なので、本便では写しをここで止めた(鷹野宛 1)。

## 0.11.0 の公開型

`git diff v0.11.0 -- src/framework`:**8 file、339 行の追加だけ、削除 0**。既存の module は 1 字も変えていない。

| file | 行 | 種類 |
|---|---:|---|
| `src/framework/server.gleam` | +106 | 新しい module(型 8 つ) |
| `src/framework/server/codec.mjs` | +35 | 新しい JS |
| `src/framework/server/contracts.mjs` | +34 | 新しい JS |
| `src/framework/server/cron.mjs` | +36 | 新しい JS |
| `src/framework/server/driver.mjs` | +18 | 新しい JS |
| `src/framework/server/operations.mjs` | +6 | 新しい JS |
| `src/framework/server/outbox.mjs` | +55 | 新しい JS |
| `src/framework/server/worker.mjs` | +49 | 新しい JS |

版は `gleam.toml` の 0.11.0 のまま(0.11.1 に上げるのは両便の merge の後の鷹野さんの手、と読んだ)。

## 検収

| 項目 | 結果 | 証拠 |
|---|---|---|
| root `gleam build` | exit 0、warning 1(既存の `src/framework/secret.gleam:5`) | `final-root-build.txt` |
| `cd gen && gleam test` | **253 passed, no failures**(基線 241 ── `3209703` の archive で実測)。新しい test は `gen/test/yumemi_gen_wgy_test.gleam` 11 本と hw-1 の test に `Self` の 1 本。既存の test の書き換えは 5 本(attached の読み元・fixture の file 数 15 → 16・root_warning の対象の解き方・hw-1 の `Self` の負例・header の `////`) | `final-gen-test.txt`、`base-gen-test.txt` |
| `gleam format --check src test` | root・gen とも 0 | ── |
| Article fixture ×2 | 2 回とも exit 0、`diff -r` 0 行。tracked の生成物 51 file は 3 本(`admin` / `public` の `api.gleam`:面が参照する Service に絞った・hash、`live/blob_copy.gleam`:頭の入力名)を更新して全部一致。新しい back の生成物 11 本(`src/gen/{registry,sql,codec,attached,shell,operations_ffi}.mjs`・`key.gleam`・`entry/*.gleam`)を tracked に足した | `fx-a`、`fx-b` |
| 写し ×2 | 2 回とも exit 4、1445 file、`diff -r` 0 行 | `out-final-{a,b}`、`final-snap-ab-diff.txt` |
| 写しの診断 | exit 1/2/3/4 = 3/0/0/97。Route の曖昧 0・`Self` 0。face の 97 と警告 49 は基点と行ごとに同一 | `out-final-a/_diagnostics.txt` |
| `http_runtime.mjs` を入力として読む行 | 0(名としての出現 6 行は上) | ── |
| 写しの api `npm test` | 659 / 660(上) | `final-api-test.txt` |
| registry の (method, path) | 基点と全行一致(URL を動かしていない) | `registry-compare.txt` |
| 置き換えた後の sha256 ヘッダ無し | **102 file**(0 ではない) | ── |

## 鷹野宛

1. **矛盾:検収の「api/src/gen を生成物で丸ごと置き換え、業務の行を ★ hook に移しただけの写しで api の test が基点と同じ数」は、この便の中では立たない。**(a) Gleam 側の生成物(0.11 の `query.gleam` ほか)は ★ の requalify(45 file)と、生成器と ★ の契約のずれ 37 件の直しが要り、どちらも「hook に移す」の外の ★ の書き換え。(b) `runtime.mjs` の verb / reads / root の名ごとの分岐(約 145)を生成するには、生成物が SQL の穴の契約に従う必要があり、その契約は**生成した SQL**のもの。写しの `db/queries` は手書き / 古い生成の SQL(生成と違う 42、生成器が出さない 178)のままで、生成した runtime をそこに当てても確かめにならない。`db/queries` の採用(WGm の問い 1)と同じ便でないと閉じない。**案**:本便は「宣言・向き・曖昧・Self・back の表の生成物・framework の JS・codec」で閉じ、`http_runtime` / `runtime` の生成は `db/queries` の生成物を採る便(WGm の前の yumemi 0.11.2、または WGm と対の便)に回す。どちらにするか、または本便を延ばすかを裁いてください
2. **connector の宣言が無い。**`connector/*.gleam` 9 本は「connector.* declaration」と名乗るが、★ に宣言が無い。生成するには宣言の形(型を ★ に置き、生成物は FFI の口だけにするか、型ごと宣言から出すか)を決める必要がある。型を ★ に移すと ★ の import の道が変わる(WGm の書き換え)
3. **codec の名が基点の手書きと違う。**生成は `camel(module)`(`consentVersion` / `ledgerStore`)で、基点の手書きは `cv` / `ledger`。手書きの runtime / http_runtime と test 1 本がこの名を引く(写しでは置き換えた)。WGm で runtime が生成になれば消える差
4. **registry の `fields` の 4 行**:consumer 3 本は Args の名(`['id','event']` ほか、HTTP の口を持たない)、`heaven_embed_code` は Args の名 `heaven`。基点の手書きの `id` は path の `:heaven` と名が合っていない(`idTypes` の表で救っている)。生成の値を正にした
5. **sql.mjs の 30 本**:基点の sql.mjs には `db/queries` に無い ★ の SQL が 30 本埋まっていた(schedule / reservation / prep の root、allow の断片、`framework/session_resolve_staff` ほか)。生成の sql.mjs は `db/queries` から束ねるので、写しでは 30 本を `db/queries` に出した。musearch の SQL manifest の test は file ごとに semantic test を要るので、この 30 本の行が WGm で要る

### ★ hook に移した行の一覧(WGm が musearch に置く ★ の正)

写しの `src/hooks.mjs`(`snap-star.patch`)。`src/server.gleam` の `hooks` に同じ名を宣言する。

| hook | 元の行(基点) | 中身 |
|---|---|---|
| `metrics_rollup_args` | `cron_runtime.mjs` 35–64 | 日次の rollup の期間(JST の前日、月初の前月、保持月数より古い行の purge の境)と、戻りの report |
| `decode_muse_schedule` | `codec.mjs` 259–264 | 店の時刻を分の整数で持つ列 |
| `decode_reservation` | `codec.mjs` 265–277 | 同上 |
| `decode_prep` | `codec.mjs` 278–286 | 同上 |
| `decode_course` | `codec.mjs` 234–239 | 台帳の店の id の列が 2 つの名で来る |
| `decode_store` | `codec.mjs` 228–233 | API key の digest を読まない(None) |
| `decode_muse_setting_spec` | `codec.mjs` 240–252(`minuteTime` を含む) | 型の値の名(`int` → `IntValue`) |
| `decode_ledger_store` | `codec.mjs` 253–258 | 台帳(`public.store` の列名) |
| `decode_metrics` / `decode_metrics_store` | `codec.mjs` 311–355 | 集計の値(metricSource / PageKind / Bucket / Daily / RosterRow を含む) |
| `decode_page` / `cursor_args` | `codec.mjs` 366–385 | 記事の頁と cursor |

本便で hook に移していない業務の行(`http_runtime` / `runtime` を生成する便で hook にする。行き先は上の棚卸し):`pageviewSuppressed`・`recoverRosterUpsert`・blob の put / copy・`logicFailureStatus`・制約名 → code の表・`apiEncode` の 2 件・店の時刻の穴(`shopTimeMinutes`)・台帳の種別・`storeApiKeyIssue` の label・heaven / litlink / screen / invite / embed の connector の実装、`heaven_ffi.mjs` / `litlink_ffi.mjs` の gen の外への移し。

## 確かめたこと / 確かめていないこと

- 確かめたこと:上の検収表の全部。写しの 3 面の `gleam build`(生成の `api.gleam`)。面の `npm test` は基点の写しと生成の写しで同じ数(www 24 pass / 7 fail、muses・console 0 / 1 ── どちらも基点で同じに落ちる、写しの環境の不足)
- 確かめていないこと:生成した SQL(`subject=$K` の句)を Postgres で走らせていない(写しの test は `db/queries` の手書きの SQL を使うので、生成 SQL は当たらない)。`framework/server/worker.mjs` と生成の `shell.mjs` は `cloudflare:workers` を import するので node の test では読まれない(cron の test は shell の本文を正規表現で見るだけ)。Hex に載せた後の package の中身(`gleam publish` の dry run)は見ていない
