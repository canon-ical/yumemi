# yumemi-fix-0114 ── musearch を yumemi で止めない最後の patch、版 0.11.4(真壁[IM]、2026-09-26)

基点は yumemi main `4c1f908`(v0.11.3)、branch は `impl/yumemi-fix-0114`。穴は BRIEF の H5〜H10。musearch には書いていない。検収は `git archive cd9731f8` の写し(`gen/build/fix0114/ms/`、4 package の yumemi を作業木への path 依存に)でやった。証跡は `gen/build/fix0114/` に置いた(gitignore の下なので commit には入らない)。

## 直したもの

| # | 穴 | 直し | 場所・test |
|---|---|---|---|
| H5 | 生成の `blob_copy` の live は file の upload だけで、`POST /api/blobs` に `{from: url}` を送る口が無い | BlobCopy の live に `copy_from(state, url)` を足した。`{from: url}` を JSON で送り、本文の `key` を `Done(Ok(key))` に読む。失敗は本文の `code`(無ければ `url copy failed`)。`Args` / `Field` / `State` / `Send`(upload)は変えていない | `emit/front.gleam` の `blob_entry_live_text`、`blob_copy_live_copies_from_url_test` |
| H6 | 汎用の attached の live は body を常に null で送る | **宣言から決める。**framework の役が本文の形を決める口だけ Args を持つ。`SwitchSubject` の口(`server/http.mjs` の switch_subject が `s.args.kind` / `s.args.id` を読む)の live は `Args(kind, id)`・`Field { Kind Id }` を持ち、`{kind, id}` を送る。役の無い口の live は 0.11.3 と 1 byte も同じ | `emit/front.gleam` の `attached_body_fields` / `attached_live_text`、`attached_live_sends_role_body_test`・`attached_live_without_role_body_keeps_null_test` |
| H7 | `decodeReport` が `option(r.message_chat,message_id,…)` と未定義の識別子を渡す | `Split` の宣言を持つ record の欄は、列から欄の object を組み直して読む:`option((r.message_chat==null?null:{chat:r.message_chat,message:r.message_id}),v=>…)`。Option でない欄は object をそのまま。`a,b` の列の綴りを JS に入れない | `storage.split_columns`、`emit/codec.gleam` の `prop_value`、`codec_reads_split_record_from_columns_test` |
| H8 | sketch の class 付きの要素を島で描くと、ブラウザでだけ `Stylesheet is not initialized` で panic | `framework/front/island_style.mjs`(新)の `styled(app)`。島ごとに stylesheet を 1 つ持ち、view の間だけ current にし、その島が使った class の CSS を島の中の `<style>` に出す。class の無い島と、自分で `sketch_lustre.render` を呼ぶ島(www の島 11 本の形)の DOM は変えない。生成の client は全ての島を `styled(x.app())` で包んで登録する | `emit/front.gleam` の `client_text` / `client_registration`、`island_renders_sketch_class_under_stylesheet_test`(node で包まない view が panic し、包んだ view が CSS を出すのを見る) |
| H9 | Page 間の client 遷移の口が無い | `framework/front/navigate.mjs`(新)の `start({routes, boot})`。今の頁と行き先がどちらも route 表に当たる同じ origin の a の素の左 click だけを取る。次の頁を 1 回の fetch(`redirect: "manual"`)で取り、head と body を差し替え、島の登録(`boot`)を走らせ直し、history を積む。戻る / 進むも同じ道で取り直す(# だけの移動は触らない)。redirect・200 でない・`content-security-policy` の header・client 以外の script・登録済みの given の島・修飾キー・`target`・`download` は頁の読み込みに落とす。**route 表は宣言から:**面の Page の route から、門の `frame_src`(CSP)と `pageview` の Page を外す。どちらも頁の読み込みの応答にしか効かないため。生成の client は登録を `boot()` にまとめ、登録済みの tag は登録し直さない(`defined(tag)`) | `emit/front.gleam` の `navigable_routes` / `client_text`、`client_starts_navigation_over_page_routes_test`・`navigation_skips_counted_pages_test`・`navigation_intercepts_only_routed_plain_clicks_test` |
| H10 | driver の読みに timeout も再試行も無く、失敗の本文を log に出さない | `framework/server/read_retry.mjs`(新)。**読みの判定は文から:**1 文で `SELECT` / `WITH` / `VALUES` / `TABLE` で始まり、書きの語(`FOR UPDATE`・nextval を含む)も schema で修飾した関数の呼び出し(`framework.insert_links_guarded(` のような app の関数)も持たない文。迷う文は書きに数える。読みは 1 回を `DATABASE_READ_TIMEOUT_MS`(既定 5000)で切り、DB の外の失敗(timeout・fetch の失敗・HTTP 5xx)なら 1 回だけやり直す。SQLSTATE の失敗はやり直さない。書きと transaction はやり直さず timeout も付けない。DB の外の失敗は読みも書きも本文を 1 行の JSON で log に出す(`{"yumemi":"driver.failed",kind,key,attempt,ms,code,status,name,body}`) | `server/driver.mjs`、`driver_reads_retry_once_on_timeout_test` |
| 版 | ── | `gleam.toml` を 0.11.4 に、`gen/manifest.toml` の path 依存も 0.11.4 に。README の framework/server の節に 0.11.4 の 6 行 | ── |

**H6 で宣言を足さなかった理由。**`Attached` の型に欄を足すと公開型が変わる。本文の形を決めているのは framework の役(`SwitchSubject`)なので、役から Args を導いた。役の無い attached の口の hook が本文を読む形は今回の射程に無い(musearch の残りは session_subject ×2 だけ)。

**H10 の読みの判定を key の名で決めなかった理由。**`framework/session_resolve_staff`・`credential_floor` は `query()` を通るが UPDATE / INSERT を含み、`verb/create_free_space` は `SELECT * FROM framework.insert_free_space_guarded(..)` で書く。key の接頭辞では分けられない。写しの SQL 562 本では読み 257 本・書き 305 本に分かれ、`verb/` で読みに入るのは `verb/pageview_duplicate`(`SELECT id FROM app.page_view …`)だけだった(`gen/build/fix0114/classify.mjs`)。staging で止まった `session_resolve_staff`(UPDATE を含む)は BRIEF の「書きは再試行しない」に従って対象外で、log だけ出る。

**公開型。**`git diff v0.11.3 -- src/framework` は 4 file、+241 / -2。`A` 3 本(`front/island_style.mjs`・`front/navigate.mjs`・`server/read_retry.mjs`)と `M` 1 本(`server/driver.mjs`)。driver の -2 行は `query` と `transaction` の本体の 1 行ずつで、読みを `read_retry` に通し、失敗を log に出すため。export の `database(env, observe)` とその返り値の `query(text, params, key)` / `transaction(operations)` の形は同じ。Gleam の公開型は変えていない。生成の live で変わる型は H6 の役の口の `Args` / `Field`(今まで生成されていなかった live)と、H5 の `copy_from`(足しただけ)。

## 変わった生成物

写しで基点(commit 済み)と本便の 1 手を `diff -rq` した結果、変わったのは 5 file だけ。

| file | 穴 | 中身 |
|---|---|---|
| `api/src/gen/codec.mjs` | H7 | `decodeReport` の 1 行 |
| `muses/src/gen/live/blob_copy.gleam` | H5 | `import gleam/json` と `copy_from` / `transport_send` / `send_from`(+43 行) |
| `www/priv/static/_yumemi/client.mjs` | H8・H9 | `styled` / `start` の import、登録を `boot()` にまとめて `defined` で守る、`startNavigation({routes: […22 本], boot})`(esbuild の束) |
| `muses/priv/static/_yumemi/client.mjs` | H8・H9 | 同上 |
| `console/priv/static/_yumemi/client.mjs` | H8・H9 | 同上 |

console の `gen/live/blob_copy` は写しに無い(console の `blob_copy` 島は live を使わない)。api の他・`db/queries`・他の live・`_diagnostics` は差 0。session_subject の live は写しの島が target を宣言していないので生成されない(下の「musearch が採る時の手」で生まれる)。

fixture(`gen/fixtures/article`)の tracked の生成物も 2 本変わった(`public/src/gen/live/blob_copy.gleam`・`public/priv/static/_yumemi/client.mjs`)。本便で取り直して commit した。

## 確かめたこと

| 検収 | 結果 | 証跡(`gen/build/fix0114/`) |
|---|---|---|
| root `gleam build` | exit 0 | `root-build.txt` |
| `cd gen && gleam test` | **301 passed, no failures**(基点 292 + 本便 9) | `test-final.txt` |
| `gleam format --check src test gen/src gen/test` | exit 0 | ── |
| Article fixture ×2 | 2 回とも exit 0、`diff -r` 0 行。tracked の 66 file と `cmp` で不一致 0(取り直した 2 本を含む) | `fx-one`・`fx-two` |
| 写し `cd9731f8` の 1 手 ×2 | 2 回とも exit 0、4 dir・`db/queries`・3 面の `priv/static/_yumemi`・`_diagnostics.txt` の `diff -r` は 0 行。`[exit` の診断 33 行は基線(0.11.3 の生成器で同じ写しを走らせた `gen0.log`)と行の集合が一致 | `run1`・`run2`・`gen-r1.log`・`gen-r2.log`・`regen.sh` |
| 写しの api `npm test`(PG 55562、`dropdb` からの新しい DB、auth を先に build) | **700 / 700** ×2(2 回目は H10 の log の名を直した後) | `api-1.txt`・`api-2.txt` |
| 3 面(写し):`gleam build` / `format --check src` / `npm run build` / `npm test` | www 0 / 0 / 0 / **52**、muses 0 / 0 / 0 / **30**、console 0 / 0 / 0 / **24**(yumemi-8 の値と同じ)。build の後も client は `run2` と同じ | `face-*` |

**実 API で**(写しの面 wrangler 9482〜9484、proxy 9492〜9494、API 9491、bridge 9490 → PG 55562。H5・H6・H8 は写しの島を下の「採る時の手」の形に載せ替えて押した。載せ替えは `adopt-source.patch` に残し、写しは基点へ戻した):

| 穴 | 手 | 結果 | 証跡(`real/`) |
|---|---|---|---|
| H9 | www の予約の 3 Page を click で進む(手 1 のコマ → 手 2 → コースを選ぶ → 島 `reserve-time` の中の a で手 3)。Playwright で main frame の navigation request を数え、`window` に置いた印が残るかを見た | 4 回の click とも **navigation 1 のまま**(最初の `goto` だけ)、印は残った。手 3 で「申込む」の button が出た | `h9.tsv` |
| H9 | 戻る → 手 2(コース付き)、戻る ×3 → 手 1、進む → 手 2 | どれも navigation 1 のまま、URL と頁の中身が前の Page | 同上 |
| H9 | route 表の外(pageview を数える `/muse/:handle`)への a | 頁の読み込み(navigation 2) | 同上 |
| H9 | 成人の申告の無い browser(session だけ)が `/consent` から手 1 と `/me/reservations` へ | fetch 403 → 頁の読み込み → document 403「adult declaration required」 | 同上 |
| H9 | sign-in の無い browser(申告だけ)が手 1 から `/me` へ | fetch 302(opaqueredirect)→ 頁の読み込み → 302 で sign-in へ | 同上 |
| H9 | pageerror | 無し | 同上 |
| H8 | console `/rosters/:id` で claim の URL を発行(写しの島は sketch の class 付きの `a` に戻した) | 200、URL を描いた、shadow の `<style>` に class `css-8C6EB131` の CSS、pageerror 無し | `hands14.tsv` |
| H6 | muses `/settings` で名義を切り替え | 生成の live が `{"kind":"muse","id":…}` を送り 200、頁を読み直し、`framework.session` の主体が変わった | 同上 |
| H6 | console `/switch` で店の名義へ(先に DB で主体を外した) | `{"kind":"store","id":<店>}` を送り 200、読み直し、DB の主体が店に戻った | 同上 |
| H5 | muses `/links` の取り込みで、アイコンの URL を写して保存 | `POST /api/blobs` `{"from":"https://prd.storage.lit.link/…"}` → 200 `{key}` → `POST /api/link_imports/apply` の `icon` がその key → 200 → 読み直し、`app.muse.icon` が key になった | 同上 |
| H5 | 許す host に無い URL | 400 `invalid_argument` / `from`、保存は送らない | 同上 |
| H10 | 写しの api の build の `driver.mjs` を bridge → PG 55562 に繋ぎ、Neon の `fetchFunction` に遅延と失敗を注入(`DATABASE_READ_TIMEOUT_MS=1000`) | 読み:1 回目が止まる → 1001 ms で timeout → 再試行 → 成功(log 1 行 `body: timeout`)。2 回とも落ちる → 2 回目の 503 を投げ、`connector: neon` / `status: 503`、log 2 行(2 行目に 503 の本文)。3 秒かかる読みは 1 秒で切って 2 回目で返る。書き:503 でもやり直さず log 1 行、3 秒かかる書きも切らずに通る。SQLSTATE(22012)の読みはやり直さず log 0 | `h10.tsv` |

**local だけの道具(`real/`、repo に入れていない)。**yumemi-8 の `build/y8/real/` を写し、port と DB を替えた。`api-worker.mjs` に 1 つ足した:blob の写しの取得先 `prd.storage.lit.link` を外へ出さず 1x1 の PNG を返す fetch の差し替えと、R2 の binding `MEDIA`(wrangler の local)。wrangler は写しの node_modules の 4.129.0 が compatibility date 2026-09-11 を読めないので、`musearch-yumemi-8` の 4.137.0 を使った。

**H9 の外向きの 1 本。**sign-in の無い browser の手で、Chromium が 302 に従って `https://auth.yumemism.dev/auth/sign-in` を GET で開いた(頁の読み込みに落ちたことの確かめ)。送ったのは GET 1 本で、入力はしていない。

## musearch が採る時の手

`adopt-source.patch`(写しで build 0・format 0、muses test 30 / 30、console test 24 / 24 を見た形)。

1. 4 package の yumemi を 0.11.4 に上げ、生成器を 1 手で回す。変わる生成物は上の 5 本
2. **H5:**muses `components/link_import_apply.gleam` を `gen/live/blob_copy` の `copy_from` に載せ替え、`link_import_apply_ffi.mjs` を消す。Model に `copy: blob_copy.State` を持ち、`Copied(blob_copy.Event)` の `Done(Ok(key))` で保存を送る
3. **H6:**muses / console の `components/session_subject.gleam` に `pub const target: api.Target = front.Entry(api.SessionSubject)` を置き、生成の `gen/live/session_subject` の `Set(Kind / Id)` と `Send` で送る。`session_subject_ffi.mjs` ×2 を消す。console は FFI が `GET /api/session` で店の id を引いていたので、`blocks/session_switch.gleam` が `store_list_mine.Out.stores` の先頭の `id` を島に渡す形にした
4. **H8:**`roster_issue_code` の URL の `a` は class 付きに戻してよい。島を node で動かす test の道具(`*/test/island-harness.mjs`)は、生成の client と同じく `build/dev/javascript/yumemi/framework/front/island_style.mjs` の `styled` で app を包む。包まないと class 付きの島の test は node でも `Stylesheet is not initialized` で落ちる(写しの console で確かめた)
5. **H9:**生成器を回せば入る。予約の 3 Page の a はそのまま。遷移を頁の読み込みにしたい Page は、今の形では門の `frame_src` か `pageview` に入れる以外に外す口が無い
6. **H10:**deploy で入る。timeout を替えるなら Worker の env `DATABASE_READ_TIMEOUT_MS`
7. B の表から `session_subject` ×2 と `link_import_apply`(`copy_icon`)の 3 行を消せる

## DDL

無し(生成器と framework の JS と写しの検収だけ。写しの `api/db` にも書いていない)。

## 確かめていないこと

- H9 の遷移で差し替えた頁の中の島のうち、確かめたのは www の予約の島(`reserve-time`・`reserve-request`)と頁の読み直しの島の登録まで。muses / console の Page 間を click で進む手は押していない(route 表には入る)
- H9 は `data-yumemi-given` を持つ島が既に登録済みなら頁の読み込みに落とす(lustre の component は登録の時に 1 度だけ init を呼ぶので、2 本目の given を渡せない)。写しの 3 面の client に `registerWithGiven` は無いので、この道は今は通らない
- H9 の差し替えの後、島 `yumemi-done` の読み直し(`listenReload`)は今までどおり頁の読み込み
- H9 で CSP を持つ Page を外すのは生成器の route 表だけで、その Page に a で入る時は頁の読み込みになる。行き先の応答に `content-security-policy` があれば navigate.mjs も頁の読み込みに落とす(二重の守り)。今の頁の CSP を JS から読む手は無い
- H10 の読みの判定は文の字で見ている。schema で修飾しない利用者の関数で書く文(`SELECT do_write()`)は読みに数えてしまう。写しの SQL にその形は無い
- H10 は staging の Neon では確かめていない(deploy は鷹野さん)。止まりの中身が fetch の失敗か proxy の応答かは、deploy の後に log の `body` で見える
- H8 の比較:基点の client(0.11.3)で同じ島をブラウザで押して panic するのは yumemi-8 の手 13 で見た形で、本便では押し直していない

## port と process

PG 55562 は本便で起こした(写しの `api/test/postgres.sh`、pid 3384830)。実 API の道具(bridge・API の wrangler・面の wrangler 3 本・proxy、`real/launch.sh` の `pids.txt`)は pid で止め、9482〜9497・9931〜9937 が listen していないのを見た。PG は `pg_ctl stop` で止め、55562 が listen していないのを見た。
