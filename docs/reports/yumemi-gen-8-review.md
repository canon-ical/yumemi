# yumemi-gen-8(WGy)レビュー(柏木[CM]、2026-09-26、ゲート 1 回)── 差し戻し、P0 1 件

**差し戻し。**検収の数字は柏木の手元で全部再現した(root build 0、gen test 262 passed、format 0、fixture ×2 で diff 0・tracked 64 file 一致、写し ×2 で diff 0、写しの api `npm test` 690 / 690 を新しい DB で 2 回、PG 55541)。**鷹野さんの物差し(musearch の `owner Self` 28 本のうち、`Out` を通して他の主体の行を返すもの)には 1 本も当たらない。**28 本の表は下の「見ること 1」。

P0 は生成器の規則の側に 1 件ある。「句が全部 `Self` なら読みの行を絞らない」という規則が、**allow の Entity と主体の Entity が違う形にも掛かる。**この形では読みの SQL から Self の絞りが消え、exit 0・診断 0 件で通る。基点(0.11.0)は同じ形を exit 4 で止めていた。本便でそれが「黙って開く」に変わり、そのまま Hex の 0.11.1 に載る。musearch の 19 Service はどれもこの形ではないので、直しても写しの生成物は 1 byte も変わらない。

基点 `3209703`、先端 `bf578da`。柏木の証拠は全部 `gen/build/kashiwagi/`(git 管理外)に置いた。写しは musearch `645ec49` を `git archive` で出し、`star.patch` を当てて作り直した(真壁の `snap-g` は使っていない)。musearch と門の作業木には書いていない。PG 55541 は柏木が起こし(pid 2980120)、終端で `pg_ctl stop` で止めた。`pg_isready -p 55541` は no response。

## 検収の再走(柏木が出した値)

| 項目 | 結果 | 証拠 |
|---|---|---|
| root `gleam build` | exit 0 | `kashiwagi/root-build.txt` |
| `cd gen && gleam test` | **262 passed, no failures**(基点 241) | `kashiwagi/gen-test.txt` |
| `gleam format --check src test` | root・gen とも exit 0 | `kashiwagi/fmt-*.txt` |
| Article fixture ×2 | 2 回とも exit 0 で 125 file、`diff -r` 0 行。tracked の 64 file は `cmp` で全部一致 | `kashiwagi/fx-{a,b}` |
| 写し(`645ec49` + `star.patch`) | `patch -p1 --dry-run` で 269 file、当てて exit 0。真壁の `snap-g` との差は api の `gleam.toml` / `manifest.toml`(yumemi を作業木の path に)・`wgy-case-runner.mjs`(debug)・3 面の `api.gleam`(生成物を置く前)だけ | `kashiwagi/star-dryrun.txt` |
| 写し ×2 | 2 回とも exit 4、`diff -r` **0 行**。診断は exit 1 / 2 / 3 / 4 = 3 / 0 / 0 / 97。exit 4 は全部 3 面の行(`console/` `muses/` `www/` の外は 0)。警告 48。真壁の `out-r3-w` との差は `www/_diagnostics/www-runtime.txt` の所要時間 1 行だけ | `kashiwagi/out-{a,b}`、`gen-a.txt` |
| 置き換えた `api/src/gen` | 403 file。sha256 ヘッダ無し 0、生成物と byte で不一致 0。GENERATED を名乗る `db/queries` のうち生成物と違うもの 0(採用は patch に入っている) | ── |
| 写しの api `npm test` | 新しい DB(dropdb → `postgres.sh`)と clean build(`build/dev/javascript/{musearch_api,yumemi}` を消す)で **690 / 690 を 2 回**。初回の 687 / 686 は柏木の写しに auth の build が無く、`2a-6` が import で落ちた環境の不足(auth を build して解消) | `kashiwagi/api-test-{1,2,3}.txt`、`test.sh` |
| `http_runtime.mjs` を入力として読む行 | 0。`gen/src` の出現は生成物の名・`@external` の道・注記だけ | ── |

## 見ること 1 ── `owner Self` の 28 本(鷹野さんの物差し:P0 無し)

28 本とも、実行されるのは**生成器の SQL**(22 本は `db/queries` の GENERATED を生成物で揃えたもの、6 本は生成器だけが出して `sql.mjs` に束ねたもの)。どれも `-- allow:` の契約を持たず、runtime の読みの表でも `allow:[]`。Service は 19 本で、どれも allow の module が主体の Entity そのもの(`gen/allow/muse` × `AsMuse` が 15、`gen/allow/store` × `AsStore` が 4)。

| # | 読み | Logic が穴に渡す値 | 読む行の持ち主 | `Out` に出るか | 基点の SQL との差 |
|---:|---|---|---|---|---|
| 1 | `heaven_link/by_shop` | `shop: args.shop_id`(利用者の入力) | **他の嬢の行を含む** | **出ない。**`held_by` / `girl_held` の判定(`AlreadyLinked` / `GirlTaken`)だけ。Out は作った MuseHeaven | 同一 |
| 2 | `heaven_link/top_order` | `muse: key.muse(by.id)` | 主体 | 出ない(次の order) | 同一 |
| 3 | `link_import/current_identity` | `identity_kind: consent.Identity`(定数) | 主体を持たない参照表(consent_version) | 出ない(版を consent に焼く) | 同一 |
| 4 | `link_import_apply/existing` | `muse: owner`(= `key.muse(by.id)`) | 主体 | 間接(重複を除いて作った links) | 同一 |
| 5 | `link_import_apply/latest` | `muse: owner`、`source: args.source` | 主体 | 間接(採った候補から作った links) | 同一 |
| 6 | `link_import_apply/top_tail` | `muse: owner` | 主体 | 出ない | 同一 |
| 7 | `link_import_candidate_add/proposal` | `import_id: args.import_id`、`muse: key.muse(by.id)` | 主体(`i.muse_id=$2`) | 出ない(Out は Nil、在るかだけ) | 同一 |
| 8 | `link_import_candidate_edit/candidate` | `args` の id、`muse: key.muse(by.id)` | 主体(`i.muse_id=$2`) | 出ない(Nil) | 同一 |
| 9 | `link_import_candidate_toggle/candidate` | 同上 | 主体 | 出ない(Nil) | 同一 |
| 10 | `link_import_read/latest` | `muse: key.muse(by.id)` | 主体 | 出る | 同一 |
| 11 | `link_move/mine` | `muse: key.muse(by.id)` | 主体 | 出ない(Nil) | 同一 |
| 12 | `link_reorder/mine` | `muse: key.muse(by.id)` | 主体 | 出る(並べ直した links) | 同一 |
| 13 | `roster_add/same_name` | `store: key.store(by.id)`、`name: args.name` | 主体(`r.store_id=$1`) | `NameTaken(id)` に自店の行の id | 同一 |
| 14 | `roster_claim/by_code` | `code: secret.hmac(args.code)` | **他の店の未 claim の在籍** | **出る。ただし claim の verb で主体に結んだ後の行**(`roster.owned`、party と claim_code を落とす)と店の公開の形(`store.public`)。コードそのものが capability(HMAC の像で等値、1 回限り) | 同一 |
| 15 | `roster_list_mine/mine` | `muse: key.muse(by.id)` | 主体 | 出る | `($2 IS NULL OR r.id=$2)` を Logic の `list.filter` へ移した。主体の鍵 `r.muse_id=$1` は SQL に残る |
| 16 | `roster_reorder/place` | `store: key.store(by.id)` | 主体 | 出ない(Nil) | 同一 |
| 17 | `roster_upsert/by_external` | `store: key.store(by.id)`、`external: args.external_id` | 主体 | 出る(自店の行を直した形) | 同一 |
| 18 | `roster_upsert/same_name` | `store: key.store(by.id)`、`name: args.name` | 主体 | `NameTaken(id)` に自店の id | 同一 |
| 19 | `space_add/count` | `muse: mine` | 主体 | 出ない(上限の判定) | 基点は root の 1 文(`m.id=$1` = subject)に畳んでいた。生成は別の往復で、主体の鍵で引く |
| 20 | `space_add/last_order` | `muse: mine` | 主体 | 出ない(次の order) | 同上 |
| 21 | `space_reorder/mine` | `muse: key.muse(by.id)` | 主体 | 出ない(Nil) | 同一 |
| 22 | `store_roster_list/mine` | `store: key.store(by.id)` | 主体 | 出る | 同一 |
| 23 | `widget_add/counts` | `muse: mine` | 主体 | 出ない(`Limit` / `Duplicated` の判定) | 基点は root の 1 文に畳んでいた |
| 24 | `widget_add/heaven_linked` | `muse: mine`、`heaven: args.heaven` | 主体(`h.muse_id=$1`) | 出ない(`NotLinked`) | 同上 |
| 25 | `widget_add/heaven_used` | `muse: mine`、`kind`、`heaven` | 主体 | 出ない(`Duplicated`) | 同上 |
| 26 | `widget_add/last_order` | `muse: mine`、`space` | 主体 | 出ない(次の order) | 同上 |
| 27 | `widget_add/space_owned` | `muse: mine`、`space: args.space` | 主体(`s.muse_id=$1`) | 出ない(`SpaceNotFound`) | 同上 |
| 28 | `widget_reorder/place` | `muse: key.muse(by.id)`、`space` | 主体 | 出ない(Nil) | 同一 |

**分け方:**主体の鍵で引く 25 本、利用者の入力で引く 2 本(1・14)、参照表 1 本(3)。**他の主体の行を読むのは 1 と 14 だけで、1 は判定にだけ使い、14 はコードを持つ者が claim した後の行だけを返す。**22 本の SQL 本文は基点と byte で同一、1 本(15)は id の絞りを Logic へ移しただけ、6 本(19・20・23〜27)は基点が root の 1 文に畳んでいたものを主体の鍵の読みに割ったもの。**基点より行が広がった読みは無い。**

`by` の出所も確かめた。framework の `actorFor` は `direct` の主体を session の `subject_kind` / `subject_id` の行から作る(`src/framework/server/runtime.mjs:142-145`)。利用者が値を差し込む口は無い。相(`Only([Onboarded])`)は、root を持たない 18 Service では入口の `phaseGates` が主体の相で照らす(`http.mjs:293-294`。生成の表は 33 本で、基点の手書きの `rootlessOnboardedOnly` 4 本を含む)。root を持つ `link_import_apply` では ★ の root の SQL が `m.id=$1` と相を照らす。

**r1 の主体の鍵の穴(`subject=$K`)との違い。**r1 は Self の句を「読みの行 → allow の Entity → 主体の鍵」で絞った。その結果、1 は自分の行しか見えなくなり、`GirlTaken` の判定が素通りした(最後の砦は DB の部分一意だけになる)。14 は未 claim の行(`muse_id` が NULL)が 0 行になり、claim ができなくなった。r3 は句が全部 Self のとき SQL を絞らず、主体の門(入口の who と相)と Logic の主体の鍵に任せる。これは hw-1 のゲートで柏木が推した案 (c) と同じ意味で、基点の SQL とも同じ。句に Self と他の owner が混ざる形は、r1 の `subject=$K` のまま残る(写しでは 0 本)。

**判定:受けてよい。ただし「allow の Entity = 主体の Entity」の形に限る。**そうでない形に規則が掛かるのが下の P0-1。

## P0

### P0-1 句が全部 `Self` の規則が、allow の Entity ≠ 主体の Entity の形でも絞りを黙って落とす

- 該当:`gen/src/yumemi_gen/emit/sql.gleam:885-899`。`all_self` の分岐は、who が `As<X>` で X の Entity が在ることだけを確かめる(`subject_of`、`:1120`)。X が allow の Entity と同じかは見ない。同じ根の `phase_gate`(`gen/src/yumemi_gen/emit/http.gleam:272-316`)も、句の `Only` の相を主体の相として照らす
- 実測:fixture article の写し(`gen/build/kashiwagi/fxs/article`)に Entity `memo`(`staff: Held(Staff)` を持つ)と、root を持たない Service `memo_self` を足した。allow は `gen/allow/memo`、句は `Clause(who: AsStaff, at: AnyPhase, owner: Self)` の 1 つ(「その memo の staff が自分」の意味)。生成器は **exit 0、診断に memo の行 0**。`db/queries/memo_self/items.sql` は `SELECT m.* FROM app.memo m WHERE m.title=$1 ORDER BY m.title ASC;` で、Self の絞りも契約の行も無い。runtime の表は `'memo_self/items':{…,allow:[]}`、`phaseGates` にも無い。**どの staff でも、どの staff の memo でも読める**(`kashiwagi/fx-self-out`)
- 基点と r1:0.11.0 はこの形を exit 4(`owner Self は party の穴で表せない`)で止めていた。r1 は `(cl->>'owner'='self' AND <staff>.id=$K)` で絞っていた。r3 で「黙って開く」に変わった。test はこの挙動を固めている。`allow_clause_that_cannot_be_placed_is_exit_four_test` は Self の例を `AsStaff` から `Anyone` に替え(`gen/test/yumemi_gen_hw1_test.gleam:455`)、新しい test(`:1153`)は `article` × `AsStaff` × `Self` が「`-- allow:` も owner も無く、診断も無い」ことを確かめている
- なぜ P0 か:所有と認可の穴で、Hex に載る生成器の契約として出る。allow の語彙はこの形を正しい書き方として受ける(hw-2 の allow の emitter は、Entity が主体を held で指せば `is_self` の比較を作る。roster × `AsStore` × `Self` がそれ)。「店が自分の在籍を読む」を `gen/allow/roster` × `AsStore` × `Self` で書けば、他店の在籍が読めるものが exit 0 で出る。hw-1 の P0-1(句が黙って落ちる)と同じ類
- 直し方の向き(案):`all_self` の分岐に入るのを、**Self の句の `As<X>` の X が全部 allow の Entity と同じとき**に限る。違う形は r1 の `restricted`(`subject=$K` で辿る)に回すか、辿れなければ exit 4 で名指しする。`phase_gate` も同じ条件のときだけ出す。test は、主体の形(`gen/allow/staff` × `AsStaff` × `Self`)で「絞らない」、別の Entity の形(`memo` × `AsStaff` × `Self`)で「絞る、または exit 4」の 2 本に割る。名は中身に合わせる(下の P2-1)
- 写しへの影響:musearch の Self の 19 Service と `phaseGates` の 33 Service は、全部「allow の Entity = 主体の Entity」(`gen/allow/muse` × `AsMuse`、`gen/allow/store` × `AsStore`)。直しても写しの生成物は変わらない見込み。確かめは写し ×2 の `diff -r` を `kashiwagi/out-a` と取るだけで足りる

## 見ること 2〜7

### 3. 0.11.0 の公開型

`git diff v0.11.0 bf578da --name-status -- src test gleam.toml` は **10 行、全部 `A`(新しい file)**:`src/framework/server.gleam` と `src/framework/server/{codec,contracts,cron,driver,http,operations,outbox,runtime,worker}.mjs`。削除行 0、既存の file の変更 0、`gleam.toml` の変更 0(版は 0.11.0 のまま。上げるのは鷹野さん)。既存の型・構成子・公開関数の型は 1 つも変わっていない。3 面と api と auth の写しには `src/framework/` が無く、module 名の衝突も無い。**P0 無し。**

### 4. registry の (method, path) と URL

基点の手書き `registry.mjs` と生成物を行ごとに突き合わせた(`kashiwagi/regcmp.py`)。**129 行 対 129 行、名の集合が一致、(method, path) の差 0、method を持つ行 122 対 122。**ほかの差は次のとおり。

- `fields` の 4 行(`heaven_embed_code`・`notification_notify`・`reservation_notify`・`store_request_notify`):r1 の裁定 4 どおり
- `folded`:基点は const の名で、生成は同じ値を行に直書き(8 行とも値は同じ)
- `entry`:`pageview_record: 'www'`・`roster_upsert: 'api'` の 2 行が増えた。前者は `route_skip` の hook が基点と同じ 404 を保ち、後者は API key の入口にしか合わないので、どちらも到達は基点と同じ

attached の 6 行(`browser_adult`・`session_read`・`session_subject`・`blob_copy`・`media_read`・`socket`)は、method / path / who が基点の `const attached=[` と字面で同一。URL は 1 本も動いていない。

### 5. ★ hook の境

- 生成の JS が `../hooks.mjs` / `../http_hooks.mjs` から名指しで import する名は 56、`codec.mjs` が re-export する名は 9(`decode_*` 8・`cursorArgs`)。合わせて `server.gleam` の `hooks` 65 と一致した。**宣言に無い名の import は 0**
- 生成の Gleam の `@external` が ★ を指すのは `connector/heaven.gleam`(`heaven_ffi.mjs` 3)と `connector/litlink.gleam`(`litlink_ffi.mjs` 1)だけで、どれも `connectors` の `Pure` / `Fetch` の宣言どおり
- それ以外に ★ を import するのは、型(`service/*`・`entity/*`)、列挙の module(`ledger_store`・`metrics`・`move_direction`)、宣言した DO の adapter(`user_do.mjs`・`release_do.mjs`)だけ
- 業務の行:生成の `runtime.mjs` / `http_runtime.mjs` / `registry.mjs` ほかに `name===` の分岐は 0。`runtime.mjs` の関数は queue の payload の写し 8 行と `rootKey`、`Carried`(宣言)の 6 つだけ、`codec.mjs` の関数は Entity の decoder(Property の型から導いたもの)だけ

### 6. Hex に載る framework の JS の musearch 固有の名

**在る(P1-1)。**`Adult` / `Use` / `Handling` / `Identity` は 0.11.0 の `framework/require` の語彙なので、`adult` / `consent_missing` / `identity` は framework の語として数えない。そのほかに次がある。

- `media_read` の名と URL `^/media/(.+)$` の直書き(`http.mjs:192-196`)、`media_read` の成人の門(`:295`)
- 成人の browser cookie `_mb`、署名鍵の binding `MB_KEY`、payload の `adult_declared_at`、有効期間 395 日(`http.mjs:22,32-47,218,312`)。BRIEF の棚卸しは「browser / 成人 / `_mb` の署名」を framework に置くと決めているが、cookie と binding の名は musearch の綴り
- attached の名 `browser_adult` / `session_read` / `session_subject` を framework の予約の口として扱う(`http.mjs:271,308,315,319`、生成器の `emit/http.gleam:27`)
- 失敗の符号の許可表の `handle_taken` / `mail_taken`(`http.mjs:143`)。業務の符号は `:150` の規則でどれも通るので、表に載せる理由は無い
- framework が引く SQL の key `framework/session_resolve_staff` ほか 16 本は、musearch の `db/queries/framework/**`(★ の DDL に依る)に在る。Staff を特別扱いする行(`runtime.mjs:129`、`outbox.mjs:41`)も在る

### 7. `emit/front.gleam` の区画

本便の差は 3 か所(hunk 5 つ):`blob_entry_live_text` の頭の 1 行(`:1597`、`app.attached` の読み手)、`api_text`・`face_service_names`・`attached_names`(`:4479-4545`)、`api_route_text`〜`api_route_for`(`:5606-5700`)。門の区画(`shell_text` `:4583` 以降、`shell_runtime_text` まで)には 1 行も触れていない。門の branch(`e7faed3`)の hunk(`route_text` `:4421-4433`、`shell_*`、`island_components` の削除、`component_services` の周り)とも行が重ならない。本便が使う `component_services` は門が残す側。`gen/src/yumemi_gen.gleam` は本便の `:133` と門の `:125-134` が近く、載せ直しで文脈の衝突が出るかもしれない(区画の違反ではない)。

## 追加で見たこと(認可が緩む向き)

- **採用した GENERATED の SQL**:基点で `-- GENERATED` を名乗る 120 本のうち、本文(頭の 1 行を除く)が変わったのは 6 本。`article_list_mine/mine` と `roster_list_mine/mine` は `($N IS NULL OR id=$N)` を外しただけで、主体の鍵は残る。前者の `id` の口は新しい読み `one`(`a.muse_id=$1 AND a.id=$2`)に移り、主体の鍵で引く。残り 4 本は別名(`target` → `t`)と `surface` の写像だけ
- **★ が生成の key を影で上書きしていた 4 本**(`article_search/nearest`・`article_list/published`・`store_{link_ledger,onboard}/existing_link`)を生成物に揃えた分:`nearest` は基点の `OR (owner='via_muse_party' AND m.party=$3)` が消えた。ただし `article_search` の句は `Anyone` × `Only([Published])` × `NoOwner` の 1 つだけで、基点でも owner の枝は常に `no_owner` で真になる。相の絞りは残るので意味は同じ。他の 3 本も絞りは同じ
- **root の穴**:生成の `roots` 76 本の穴の並びを、基点の手書き runtime の if の連鎖と機械で突き合わせた(`kashiwagi/rootcmp.mjs`)。71 本が一致した。残り 5 本は root の SQL を持たない 4 本と、`widget_add`(`opt:` と `arg:` は同じ写し)。主体・party・引数の入れ替わりは 0
- **入口の judge**:基点の手書きと比べると、相の門は基点の 4 本 → 生成の 33 本で、締まる向き。`write_gate`(AsMuse だけの書きは Onboarded 限定)は ★ の `writeGate` に移って配線されている。who の札に `as_staff` と素の `muse` / `store` / `fan` が増えたが、musearch の allow の `Who` にこの名の構成子は無く、当たる句は増えない
- ★ の Service の書き換え(63 file)のうち、`roster_read` の店・嬢・写真は root の 1 文から取る形になった。root の SQL は基点と同一で、`m.phase IN ('onboarded','retiring')` の LEFT JOIN も同じなので、退いた嬢は `None` で隠れる。`pageview_record` の閲覧者は Root の `Carried`(session の party / subject)から取り、args からは取らない。`schedule_availability` の `Anonymous` → `AnyActor` は、基点と同じ対応(muse / fan 以外は AnyActor)

## P1(記録、直さない)

- **P1-1 framework の JS(Hex)に musearch の名と値が入っている**(上の 6)。今の利用者は musearch だけなので害は出ないが、yumemi の基盤の語ではない。後の patch で `media_read` の path と成人の門、cookie と binding の名、予約の口の名を宣言(`server.attached` か hook)の側に出し、既定の値は今の綴りのまま残すのがよい(musearch の cookie と URL は外から見える契約なので、値は変えない)。`handle_taken` / `mail_taken` は表から外しても振る舞いは変わらない
- **P1-2 framework の JS が暗に要るもの**:app の `db/queries/framework/**` の SQL 16 key(鷹野さんの裁定 2 (a) で ★ のまま)、npm の `@neondatabase/serverless`(`driver.mjs:3`)、`cloudflare:workers`(`worker.mjs:4`)。Gleam の package は npm の依存を書けないので、Hex の README か `server.gleam` の頭に名指しで置いておく
- **P1-3 WGm への渡しの穴**:`star.patch` は api の `gleam.toml` / `manifest.toml` を含まない。musearch `645ec49` の api は `yumemi = ">= 0.7.0 and < 0.8.0"` で、写しの test は作業木の path で通している。生成の `api/src/gen` は `yumemi/framework/server/*.mjs`(0.11.1 から在る)を import するので、WGm は api の要求を `>= 0.11.1` に上げる必要がある。report の「WGm での生成の手順」にこの 1 行が無い
- **P1-4 root を持たない、句が全部 Self の読みの行の範囲は、★ の Logic が主体の鍵を渡すことに依る。**基点と同じ意味で、28 本とも守られている(上の表)。ただし生成器はそれを確かめない。Logic が `args` の値を主体の鍵の穴に渡せば、他の主体の行が読める。後で lint(穴の型が主体の `Key(<X>)` のとき、値が `by.id` 由来か)を足す余地がある

## P2(記録。今回はコードを直さない指示なので、柏木は直していない)

- **P2-1** `gen/test/yumemi_gen_hw1_test.gleam:1151-1171` の名(`allow_clause_self_uses_the_subject_key_hole_test`)と doc(「主体の鍵の穴 `subject=$K` を足し」)が、中身(穴を足さないことを確かめる)と逆。`emit/sql.gleam:1117-1119` の `subject_of` の doc も、全部 Self の形では穴を使わないことに触れていない。P0-1 の直しで一緒に直す
- **P2-2** report の r3 の頭で食い違いがある。`docs/reports/yumemi-gen-8.md:3` は「r3 の checkpoint 10 本をこの 1 本へ squash した」、`:9` は「squash しない(r1・r2・r3 の checkpoint を残す)」。git の実物は r3 が 1 本(`bf578da`)なので、`:9` の方が誤り

## 判定

**P0 あり(1 件)── 差し戻し。**

| P0 | 要旨 | 該当 |
|---|---|---|
| P0-1 | 句が全部 `owner Self` の読みを絞らない規則が、allow の Entity ≠ 主体の Entity の形(例 `memo` × `AsStaff` × `Self`)にも掛かり、exit 0・診断 0 で Self の絞りが SQL から消える。基点は exit 4、r1 は `subject=$K` で絞っていた | `gen/src/yumemi_gen/emit/sql.gleam:885-899`(`all_self`)、`emit/http.gleam:272-316`(`phase_gate`)、`gen/test/yumemi_gen_hw1_test.gleam:455,1153` |

鷹野さんの見ること 1 の物差し(musearch の 28 本で、`Out` を通して他の主体の行が返る Service)には 0 本で当たらない。P0-1 は生成器の規則の穴で、musearch の写しの生成物には出ていない。直しても写しの生成物は変わらない見込みなので、直した後の確かめは gen の test と写し ×2 の `diff -r`(`kashiwagi/out-a` と比べる)で足りる。見ること 2〜7 は、検収の再走・0.11.0 の公開型・registry の 129 行・★ hook の境・front の区画のどれも条件を満たしている。見ること 6 は P1-1 として記録した。
