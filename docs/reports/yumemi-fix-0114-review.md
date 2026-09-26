# yumemi-fix-0114 柏木ゲート(ゲート 2、1 回だけ、2026-09-26)

対象は `git diff 1cb4a9e 78e699b`(真壁 r1 の squash、17 file、+1490 / -60)。要求は `BRIEF-yumemi-fix-0114.md`、記録は `docs/reports/yumemi-fix-0114.md`。コードは直していない。証跡は `gen/build/kashiwagi-0114/`(gitignore の下)。

**判定:P0 無し。**P1 7 件、P2 無し。

## 1. H9 の client 遷移が守りを迂回しないか

緩む向きの経路は見つからなかった。

- **門(成人の申告・sign-in)。**生成の門(`emit/gate.gleam` の `before_route`、403〜433 行)は、path(`matchRoute`)と session の読み(`readSession` が同じ request の cookie で API を引く)だけで決まり、request の header(`Sec-Fetch-*`・`accept`)を見ない。fetch も頁の読み込みも同じ判定を通る。失敗は `text(403)` か `redirectTo(302 / 303)` で、`navigate.mjs:95` の `opaqueredirect` / `status !== 200` / content-type の検査で頁の読み込みに落ち、門がもう一度判定する。真壁の `real/h9.tsv` の 3 手(申告の無い browser の 403 ×2、sign-in の無い browser の 302)とも合う
- **CSP(`frame_src` の Page)。**`after_response`(gate.gleam 443〜462 行)は `frame_src` の Page の HTML にだけ header を付ける。生成器が route 表から外し(写しの www の route 表 22 本に `/`・`/about/external`・`/for_stores/api/v1` が無いのを `run1` の client で見た)、応答の header でも落とす(`navigate.mjs:95`)ので、守りは二重。CSP は文書に付くので、差し替えても今の文書の CSP は外れない。CSP を持つ頁から出る向きは厳しい側に倒れ、緩む向き(CSP の無い文書に CSP の Page の中身を出す)は header の検査で塞がっている。SSR の head は charset・viewport・title と client の script だけで(`front.gleam` 3757〜3770 行・6327 行)、meta の CSP は無い
- **pageview。**生成器が写しの www の 9 本を外す。route の当て方が重なって数える Page を取ってしまっても、`after_response` は adult の session の 200 の HTML の `</body>` の前に script を差すので、`swappable` の script の検査(`navigate.mjs:52`)で頁の読み込みに落ちる。申告の無い session には script が付かないので数えず、0.11.3 と同じ
- **XSS の面。**DOMParser で作った文書は scripting disabled なので、その script は prepare の途中で already started が立ち、adopt して差し込んでも走らない。加えて `swappable` は client 以外の script を持つ文書を拒む(`querySelectorAll("script")` は SVG の script も拾う)。innerHTML・eval・document.write の経路は無い。on* 属性は server が同じ URL で返す HTML のものなので、頁の読み込みでも走る。新しく開いた面ではない。取りに行くのは同じ origin(`:40`)だけで、`redirect: "manual"`(`:86`)なので、別 origin の応答を差し込む経路も無い。`javascript:` の href は origin が `"null"` になって落ちる
- **click の取り方。**button 0 だけ、修飾キー、`target` が `_self` 以外、`download`、`defaultPrevented`、同じ頁の中の # は取らない(`navigate.mjs:31〜43`)。今の頁と行き先の両方が route 表に当たるときだけ取る。gen test の `navigation_rules` が `download` 以外を当てている

## 2. H10 の再試行が書きを 2 回打たないか

**今の framework と musearch の SQL には、書きを 2 回打つ文が無い。**字で判定する形そのものには外れがあるので P1-1 に書いた。

- 写し `cd9731f8` の `api/src/gen/sql.mjs` の 562 本に `readOnly` を当てると、読み 257 本・書き 305 本で、真壁と同じ数になった。読みに入った 257 本の関数の呼びは全部組み込み(`and`・`any`・`bool_or`・`coalesce`・`count`・`concat_ws`・`exists`・`generate_series`・`jsonb_*`・`lpad`・`max`・`now`・`nullif`・`percentile_cont`・`to_char`・`to_jsonb` ほか)。生の文に `insert` / `update` / `delete` / `merge` / `into` / `lock` / `for update|share` を持つ読みは 0 本(`h10/scan.mjs` → `h10/scan-base.txt`)
- framework の SQL で読みに入るのは `framework/api_key_resolve`・`outbox_get`・`outbox_sweep` の 3 本だけで、どれも SELECT。`outbox_sweep` も行の鍵を取らない。`WITH … INSERT/UPDATE` の文(`session_issue`・`session_resolve(_staff)`・`session_subject(_staff)`・`session_onboard`)はどれも書きに入る(`h10/fw.mjs`)
- `query` を呼ぶのは runtime の `run`(SQL 表の key)と relation の読み(`runtime.mjs:56`、同じ SQL 表)、それに musearch の手書き `api/src/media_runtime.mjs:74`(`SELECT EXISTS`、読み)だけ。`transaction` は分類を通らず、やり直さない(`driver.mjs:22`)
- 字の判定の外れ方(`h10/edge.mjs` → `h10/edge.txt`)。読みに数えてしまう書きは次の 5 つ。`SELECT do_write($1)`(schema の無い利用者の関数)、`SELECT * FROM bump_counter($1)`、`SELECT * INTO app.snapshot FROM …`(表を作る)、`'--'` の literal の後ろで同じ行にある CTE の `UPDATE`、引用付き schema の `"framework"."insert_x"(`。`FOR NO KEY UPDATE`・`$$update$$`・`E'\''` の後ろの UPDATE は、迷う側の書きに数える

## 3. 公開型と既存の生成物

- `git diff --name-status v0.11.3 78e699b -- src test` は 4 行で、`A` が `front/island_style.mjs`・`front/navigate.mjs`・`server/read_retry.mjs`、`M` が `server/driver.mjs`。driver の `-` は `query` と `transaction` の本体の 2 行だけで、export の `database(env, observe)` とその返り値 `query(text, params, key)` / `transaction(operations)` の形は同じ。`v0.11.3` は `4c1f908` を指す
- 写し(`git archive cd9731f8`、4 package の yumemi を作業木への path 依存にした)の commit 済みの生成物 `base` と、1 手の出力 `run1` を `diff -rq` すると、差は 5 本だけ。`api/src/gen/codec.mjs`(354 行の 1 行、H7)、`muses/src/gen/live/blob_copy.gleam`(H5)、3 面の `priv/static/_yumemi/client.mjs`(H8・H9)。api の他の生成物・`db/queries`・他の live に差は無い。記録の表と一致した
- fixture の tracked の生成物で変わったのは 2 本(`public/src/gen/live/blob_copy.gleam`・`public/priv/static/_yumemi/client.mjs`)。どちらも本便で取り直して commit されていて、出力と tracked の 66 file を `cmp` した不一致は 0

## 4. H5・H6・H7

- **H5。**`copy_from` は `{from: url}`(JSON の文字列)を送る。musearch の口(`api/src/http_hooks.mjs:58〜60`)は `raw.from` が文字列であることを求め、`c.parse('page_url', …)` に通す。成功は `decode.at(["key"], decode.string)` で読み、失敗は本文の `code` を使う。`url == ""` と送っている間(`waiting`)は送らない
- **H6。**attached の宣言は Args を持たない(`framework/server.gleam:89` の `Attached(name, method, path, who)`)。本文の形を決めているのは役。server は `raw.kind` が `spec.subjects` に含まれることと `c.parse(kind + '_id', raw.id)`(`http.mjs:289〜295`)を確かめ、`framework/session_subject_staff` に `$3` / `$4::uuid` として渡す(`:337〜340`)。live の `Args(kind: String, id: String)` はこれと合う。役の無い attached の live は、fixture と写しで差 0
- **H7。**`option((r.message_chat==null?null:{chat:…,message:…}), v=>…)`。musearch の `Split` の宣言(`api/src/server.gleam:297〜303`)と schema の CHECK `(message_chat IS NULL) = (message_id IS NULL)`(`schema.sql:489`)の下では、先頭の列の null を見る判定で足りる。未定義の識別子 `message_id` は消えた

## 5. H8 が、自分で render する島の DOM を変えないか

変えない。写しの 3 面を 0.11.4 で build した島の module を node で読み、`app().init` の model に対する `view` と `styled(app).view` の `to_string` を比べた(`h8/probe.mjs`)。

| 面 | 島 | 結果 |
|---|---|---|
| www | 11(全部が自分で `sketch_lustre.render` を呼ぶ形) | 11 本とも同じ。`<style>` は 1 / 1 |
| muses | 37 | 37 本とも同じ。`<style>` は 0 / 0 |
| console | 15 | 15 本とも同じ。`<style>` は 0 / 0 |

`set_stylesheet` は id を鍵にした表に足すだけで(`sketch_lustre/…/internals/global.ffi.mjs:6〜9`)、他の島や SSR の stylesheet を上書きしない。class 付きの島が包まないと panic し、包むと CSS を出すことは gen test `island_renders_sketch_class_under_stylesheet_test` が当てている(301 の中)。ブラウザでの確かめは真壁の `hands14.tsv` を読んだだけ。

## 6. 再走

| 検収 | 結果 | 証跡(`gen/build/kashiwagi-0114/`) |
|---|---|---|
| root `gleam build` | exit 0 | `root-build.txt` |
| `gleam format --check src test gen/src gen/test` | exit 0 | `format.txt` |
| `cd gen && gleam test` | **301 passed, no failures**(本便で足した test は 9 本) | `gen-test.txt` |
| fixture ×2(`-- fixtures/article <out>`) | exit 0 / 0、`diff -r` 0 行。出力 127 file のうち tracked の 66 file と `cmp` して不一致 0 | `fx1`・`fx2`・`fx-cmp.txt` |
| 写し(`cd9731f8` の `git archive` を取り直した)の 1 手 ×2 | exit 0 / 0。4 dir・`db/queries`・3 面の `_yumemi`・`_diagnostics.txt` の `diff -r` は 0 行 | `run1`・`run2`・`gen-run{1,2}.log`・`gate-a.sh` |
| 写しの commit 済みの生成物との差 | 上の 3 のとおり 5 本 | `base`・`base-run1.txt` |
| 写しの api `npm test`(PG 55564、initdb からの新しい DB、auth を先に build) | **700 / 700** | `api.txt`・`gate-d.sh` |
| 3 面(写し):`gleam build` / `format --check src` / `npm run build` / `npm test` | www 0 / 0 / 0 / **52**、muses 0 / 0 / 0 / **30**、console 0 / 0 / 0 / **24**。4 package の manifest は yumemi 0.11.4 の path 依存。build の後の生成物は `run2` と差 0。warning の数(360 / 207 / 134)は真壁の log と同じ | `face-*`・`after-diff.txt` |
| H10 の分類 | 上の 2 のとおり | `h10/` |
| H8 の DOM | 上の 5 のとおり | `h8/` |

api の PG は 5 回目の起動で上がった。止まった 4 回はどれも僕の環境の都合で、便の不具合ではない。1 回目は PG の socket の path が 107 byte を越えて起動しなかった(`api-aborted-socket.*`)。2・3 回目は、1 回目で止めきれなかった僕の `node --test`(pid 3406622)が、listen していない 55564 に接続を繰り返すうちに自分自身と TCP でつながり(`127.0.0.1:55564 ↔ 127.0.0.1:55564`、ESTAB)、PG の bind を塞いでいた。1〜3 回目は PG が無いまま test が走り、528 件落ちている。この pid と親の 3 つを止めた後の 4 回目は、その socket の TIME-WAIT が残っていたので、test を走らせずに止めた(`gate-d.sh` の `pg_isready` の検査)。TIME-WAIT が明けてからの 5 回目で 700 / 700。console の `npm run build` は gate-b で Hex の rate limit により exit 1 になったので、単独で取り直して 0。

## P0(差し戻し)

無し。

## P1(技術的負債、サマリに残す)

1. **H10 の読みの判定は字で見ていて、書きを読みに数える形がある。**`read_retry.mjs:9〜25` の `readOnly` は、次の文を読みとして 1 回やり直す。schema の無い利用者の関数(`SELECT do_write($1)`・`FROM bump_counter($1)`)、`SELECT … INTO`、引用付き schema の関数(`"framework"."fn"(`)。それに、`bare` が注釈を文字列より先に消すため(`:10` が `:12` より先)、literal の中の `--` から行末までが消え、同じ行の後ろにある CTE の `UPDATE` が見えなくなる。1 回目が commit 済みで応答だけが落ちると、2 回書く。今の framework と musearch の SQL にこの形は 0 本(上の 2)。後の patch で返すなら、文字列・引用識別子・注釈を 1 回の走査で外す、組み込みの許可表に無い関数の呼びは書きに数える、`into` を書きの語に足す、の 3 つ
2. **読みの timeout の既定 5000 ms は、重い読みにもかかる。**`metrics_muse/metrics`・`metrics_store/metrics`(`percentile_cont`・`generate_series`)や `article_search/nearest`(vector)のように、正しく 5 秒を越える読みは、0.11.3 なら通ったものが約 10 秒後に 503 になる。env `DATABASE_READ_TIMEOUT_MS` で上げられる。deploy の前に staging の遅い読みの実測を見てほしい(記録には無い)
3. **H9 で頁の読み込みに落ちる行き先は、同じ GET を 2 回受ける。**redirect・200 でない応答・CSP・pageview の script・client 以外の script のときは、fetch の後に頁の読み込みが続く(`navigate.mjs:92・96・99・102`)。門の session の読みと SSR が 2 回走る。GET の Page が読みだけなら結果は変わらない。写しの Page も読みだけで、`/rosters/:id/remove` などは確認の頁。GET に副作用を持つ Page を足すと 2 回走る。Page ごとに client 遷移から外す口も無い(記録の「採る時の手」5)
4. **H9 の # の読みで例外が出ると、島の登録が走らない。**`navigate.mjs:107` の `decodeURIComponent(url.hash.slice(1))` は、壊れた百分率の符号(`#%E0%A4%A`)で URIError を投げる。差し替えと `pushState` の後なので、`boot()` と `yumemi-navigated` が飛び、その頁で初めて出る島の tag が登録されないまま残る。try で包めば返せる
5. **H8 の `island_style.mjs` は sketch_lustre の内部の module を import している。**`../../../sketch_lustre/sketch/lustre/internals/global.mjs` と sketch の `Persistent` を使う。yumemi の依存の幅は `sketch_lustre >= 3.1.2 and < 4.0.0` なので、minor の版で internals が動くと、生成の client が import の時点で全部落ちる。上限を 3.1 系に絞るか、その版で import を当てる test を足せば返せる
6. **H8 の `styled` は、view を描き終えると current の stylesheet を外す(`island_style.mjs:33`)。**lustre 5.7.1 の `element.memo` の thunk は view の後の diff で評価されるので、memo の中の class 付きの要素は stylesheet を失って panic する。自分で render する島(Node の出力)では 0.11.3 のとき current が残っていたので、ここだけは狭まった。写しの 3 面に memo は 0 本
7. **test の穴。**gen test が route 表から外すのを当てているのは pageview だけで、`frame_src` の外しは test が無い(写しの www の route 表で確かめた)。応答の `content-security-policy` で落ちる道は、Playwright の手でも通っていない(コードを読んだだけ)。`navigation_rules` に `download` の手が無い

## P2

無し。記録・README・コメントと実装の食い違いは見つからなかった。

## 確かめていないこと

- 実 API(wrangler・bridge・Playwright)は再走していない。H9 の 3 Page の遷移・戻る / 進む・門の 403 / 302、H5・H6・H8 の実 API、H10 の遅延と失敗の注入は、真壁の `real/h9.tsv`・`hands14.tsv`・`h10.tsv` を読んだだけ
- H9 の CSP の header で落ちる道と、pageview の script で落ちる道は、DOM のある環境で走らせていない
- 真壁の実 API の手で、sign-in の無い browser が 302 に従って `https://auth.yumemism.dev/auth/sign-in` を GET で 1 回開いている(記録の「H9 の外向きの 1 本」)。入力はしていない。僕は外へ request を出していない
- H10 は staging の Neon では見ていない

## port と process

PG 55564 は本ゲートで起こした(写しの `ms/api/test/build/pgdata-public`、socket は `gen/build/kpg`)。終端で `postgres.sh stop` を実行し、`pg_isready -p 55564` が no response を返すこと、55564 に LISTEN と ESTAB が無いこと(残りは TIME-WAIT だけ)を見た。1 回目の取り直しで残った僕の test の process(pid 3406102・3406113・3406146・3406622、cwd はどれも写しの `ms/api`)は pid で止めた。写しの下で動いている process は 0。staging には触れず、publish もしていない。

**verdict:P0 無し。**P1 7 件は上のとおりで、サマリに残してほしい。
