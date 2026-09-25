# yumemi-fix-0113 ── 柏木[CM] ゲート(2026-09-26)

対象は `git diff 50450bb b145215`(50450bb = v0.11.2、真壁 r1 の 1 本 `b145215`、H4)。要求は makabe の task(`makabe-20260926-074015-…/task.md`)、背景は musearch-yumemi-7 の `docs/yumemi-7/results.md` の r3 節(H4)。証跡は `gen/build/kashiwagi/`(gitignore の下)。musearch には書いていない。PG は 55541 だけを起こし、終端で止めた。

**判定:P0 無し。**P1 を 4 件、下に残す。P2 は 1 件で、僕が直した(`4f1ed28`)。

## 見たこと

### 1. 202 の判定の出所

- framework で `Accepted` を作るのは `step.commit` だけ(`step.gleam:81`、runtime の `commit` が `false` を返したとき)。runtime の `commit` が `true` を返すのは `spec.boundaries` に入っている Service だけ(`runtime.mjs:390`)。HTTP はそれを 202 と `{<root>: c.text(s.args.id)}` にする(`http.mjs:179`、★ `respond` が先に取れる)
- `accepted.accepts` は「source に `step.commit(` があり、かつ queue の kind で boundary でもある、ではない」。`queued` は back の `queue_kinds`(`back.gleam:738`)と同じ規則で、source を引く道も `service_source` と同じ。runtime の `boundaries` は `kinds` を `accepted.boundary` で絞ったもので、判定を 1 箇所に寄せた後も写しの `runtime.mjs` は前後で差 0。**front と back は同じ規則で決めている**
- 外れる形を fixture の写しで生成して確かめた(`probe/{c1,f1,n1}`)
  - **別名の import**:`import framework/step.{…, commit}` と `use article <- commit(…)` にすると `accepts` は偽で、live は Out のまま(`n1`)。helper の module に置いた commit も同じ(Service の module の文字列しか見ない)。runtime は 202 を返すので、島は 0.11.2 と同じく `invalid response` になる。**書きの成功を失敗と読む向き(H4 と同じ症状)で、失敗を成功と読む向きではない**
  - **コメント中の `step.commit(`**:commit しない Service でも `accepts` は真で、live は `Reply` を持つ(`f1`)。decoder は Out を先に試すので 200 の Out は `Replied(out)` に読まれる。DO の runtime(`user_do_runtime.mjs:74` の `commit` は `true` を返す)で走る写しの `notification_notify` も同じく真になるが、live は生成されていない
  - どちらの外れも、2xx 以外を成功に読む道は作らない(下の 2)
- 粒度は framework の `contracts.mjs` の `foldable` と同じ(Service の module の文字列、`step.commit(` の綴り)。P1-1 に残す

### 2. 202 の本文の読み

transport(生成の `transport_ffi.mjs`)は `response.ok`(2xx)の本文だけを `on_ok` に渡し、それ以外は `on_error`。`reply_decoder` は `on_ok` の中でだけ走る。compile 済みの写しの muses の live に、fetch を差し替えて status と本文を当てた(`probe/decode/probe.{mjs,txt}`):

| 当てたもの | `reservation_approve`(202 の Service) | `reservation_send`(202 でない Service) |
|---|---|---|
| 202 `{reservation:"R1"}` | `Ok(Accepted("R1"))`、emit `yumemi-done` | `Error(Broke("invalid response"))`(0.11.2 と同じ) |
| 200 Out 全体 | `Ok(Replied(out))`、emit `yumemi-done` | ── |
| 202 Out 全体 | `Ok(Replied(out))` | ── |
| 200 `{id:"R1"}` / 200 `{code:"x"}` | `Ok(Accepted("R1"))` / `Ok(Accepted("x"))` | `{code:"x"}` は `Error(Broke("invalid response"))` |
| 202 `{reservation:null}` / `{reservation:123}` / `{}` / `{a:"x",b:"y"}` | どれも `Error(Broke("invalid response"))`、emit 無し | ── |
| 202 本文なし(★ `early` の `emptyResponse`) | `Error(Broke("invalid_response"))`、emit 無し | ── |
| 422 `{code:"not_requested"}` | `Error(Refused(NotRequested))`、emit 無し | `Error(Broke("not_requested"))` |
| 409 `{reservation:"R1"}` / 503 `{code:"unavailable"}` | `Error(Broke(…))`、emit 無し | ── |

- **2xx 以外が成功になる形は 0。**本文が 1 欄の文字列の形でも、status が 409 なら失敗のまま。★ `early` が書かずに返す空の 202 も失敗のまま
- **宣言は見ている、status は見ていない。**成功か失敗かは transport の 2xx で分かれ、`Replied` と `Accepted` のどちらになるかは本文の形だけで決まる(202 に Out 全体なら `Replied`、200 に 1 欄の文字列なら `Accepted`)。写しの 6 本の Out はどれも 2 欄以上の必須の欄を持つので、札の取り違えは起きない。島が札で分岐すると取り違える形は残る(P1-2)
- 写しの ★ `respond`(`http_hooks.mjs:126`)で、`Fail` に 2xx を返す枝は無い(`not_atarget` は 422)

### 3. 202 を返さない Service の live

写し(`2a36ce5c` の `git archive`、新しく取り直した)の commit 済みの生成物(`base`)と 1 手の出力(`run1`)の `diff -rq` の差は、muses の `reservation_approve` / `reservation_reschedule` / `reservation_cancel` / `article_publish` / `article_revise`、www の `reservation_request` の live 6 本と、muses / www の `client.mjs` の 2 本だけ。api の `src/gen`(`runtime.mjs` の `boundaries` を含む)・`db/queries`・console・他の live は差 0。6 本の中身の差は `import gleam/dict`・`Reply` 型・State / Event の型引数・send の decoder・`reply_decoder` / `accepted_decoder` だけ。僕の `run1` は真壁の `run1` と `diff -r` 0 行。

### 4. 0.11.2 の公開型と名の衝突

- `git diff 50450bb b145215 -- src test` は 0 行。`git diff v0.11.0 b145215 -- src/framework` は 11 file とも `A`、+1349 / -0。`gen/src` の `pub` の増は新しい module `emit/accepted` の `accepts` / `boundary` だけ
- 変わるのは生成の live 6 本の `State` / `Event` の型引数(Out → 生成の `Reply`)。写しでこれを import する島は muses `reservation_actions`(3 本)と www `reserve_request` の 2 本で、どれも `Some(Ok(_))` で受けている。3 面の build 0。`Some(Ok(out))` で Out の欄を読む島なら compile で落ちる(黙っては通らない)
- **名の衝突は黙って壊れず、生成器が止まる。**fixture の写しで commit の後に続きを持つ `article_publish` の Error に `Accepted` を足すと(`probe/c1`)、生成器は **exit 1**(`[exit 1 生成器の不足] public: client runtime 用 Gleam build に失敗した`)で止まり、全文(`out/public/_diagnostics/public-runtime.txt`)は `error: Duplicate definition` で 26 行目の `Accepted`(Error)と 37 行目の `Accepted(id: String)`(Reply)を名指しする。ただし `_diagnostics.txt` の要約の 1 行が出すのは後続の `Type mismatch`(`Accepted` の型が Error)で、宣言の不足(exit 3)としては止めない。既存の `Refused` / `Broke` と同じ扱い(P1-4)。Args の欄の pascal(`Field` の構成子)も同じ値の名前空間。`Reply` は型の名前空間なので、欄 `reply` の `Field` の構成子 `Reply` とは衝突しない

### 5. 再走

| 検収 | 結果 | 証跡(`gen/build/kashiwagi/`) |
|---|---|---|
| root `gleam build` | exit 0 | `root-build.txt` |
| `gleam format --check src test gen/src gen/test` | exit 0 | `format.txt` |
| `cd gen && gleam test` | **292 passed, no failures** | `gen-test.txt` |
| fixture ×2(`-- fixtures/article <out>`) | exit 0 / 0、`diff -r` 0 行。出力 127 file のうち tracked の 66 file と `cmp` して不一致 0 | `fx1`・`fx2`・`fx-diff.txt` |
| 写し(musearch `2a36ce5c` の `git archive`、4 package の yumemi を作業木への path 依存に)の 1 手 ×2 | exit 0 / 0、4 dir・`db/queries`・3 面の `_yumemi`・`_diagnostics.txt` の `diff -r` 0 行 | `run1`・`run2`・`gen-run{1,2}.log`・`run-all.sh` |
| 写しの commit 済みの生成物との差 | 上の 3(live 6 本と client 2 本だけ) | `base`・`base-run1.txt` |
| 写しの api `npm test`(PG 55541、`dropdb` からの新しい DB、auth を先に build) | **700 / 700**(`api-2`)。1 回目(`api-1`)は 699 / 700 で、落ちた `compile_fail: mixed_system` の理由は `Hex API failure … rate limit … exceeded`。3 面の build と同時に走らせたための外因で、単独で取り直して 700 / 700 | `api-1.txt`・`api-2.txt` |
| 3 面(写し):`gleam build` / `gleam format --check src` / `npm run build` / `npm test` | www 0 / 0 / 0 / **52**、muses 0 / 0 / 0 / **16**、console 0 / 0 / 0 / **18**。console の `npm run build` は 1 回目が同じ Hex の rate limit で exit 1、単独で取り直して 0。変わった live 6 本に warning は 0。build の後の生成物は `run2` と差 0 | `face-*`・`after` |
| 判定の外れ方・名の衝突 | 上の 1・4 | `probe/{c1,f1,n1}`・`probe/*.log` |
| 本文と status の読み | 上の 2 | `probe/decode/probe.{mjs,txt}` |

PG 55541 は本ゲートで起こした(`ms/api/test/build/pgdata-public`)。終端で `postgres.sh stop` し、`pg_isready -p 55541` が no response、55541 は listen していないのを見た。

## P1(技術的負債、サマリに残す)

1. **202 の判定は Service の module の文字列 `step.commit(` で見ている。**helper の module に置いた commit、`import framework/step.{commit}` の `commit(`、step の別名では外れて、H4 がそのまま残る(書きは通り、島は `invalid response`)。コメント・文字列中の `step.commit(` や、DO の runtime で走る Service では誤って `Reply` になる(200 の Out は `Replied` に読まれるので、結果は変わらない)。**どちらの外れも、失敗を成功に読む向きにはならない。**写しの 12 本はどれも Service の module に `use x <- step.commit(` と書いてあり、外れは 0。glance の AST で `step.commit` の呼びを見るか、宣言で 202 を名指す形にすれば後の patch で返せる
2. **`Replied` と `Accepted` の札は、status でなく本文の形で決まる。**成功か失敗かは 2xx で分かれるので向きは正しい。ただし Out が 1 欄の文字列の Service や、★ `respond` が 200 を 1 欄で返す Service では札を取り違える(probe:200 `{code:"x"}` → `Accepted("x")`、202 に Out 全体 → `Replied`)。WGm への申し送り 3 のように島が `Accepted(id)` と `Replied(out)` で分岐するなら、札は目安だと伝えてほしい。transport が status を `on_ok` に渡す形にすれば、`Reply` の型を変えずに後で返せる
3. **202 の本文に文字列の id が無い形は、今までどおり `invalid response`。**framework の既定の本文は `{<root>: c.text(s.args.id)}` なので、Args に `id` の無い Service(写しの `reservation_request` の形)を ★ `respond` 無しで commit させると `{<root>: null}`、id が数なら数になり、どちらも `Broke("invalid response")`(probe の `{reservation:null}` / `{reservation:123}`)。安全側に倒れる(書きは通っていて、島は失敗を出す)。写しでは hook が埋めている
4. **live の予約の名(`Refused`・`Broke`・`Replied`・`Accepted`)と、Args の欄・Error の構成子の衝突は、生成器が exit 1 で止めて全文の診断で名指しするが、宣言の検査としては止めない。**要約の 1 行は後続の `Type mismatch` を出し、分類は「生成器の不足」。Service に commit を足しただけで、その live の予約の名が 2 つ増える。生成器で予約の名と突き合わせ、exit 3 で名指しすれば返せる(0.11.2 の `Refused` / `Broke` から続く穴)

## P2(直した)

| # | 何 | 直し | commit |
|---|---|---|---|
| 1 | `b145215` が `results.md` を 24 行に置き換え、前の便までの記録 1412 行(yumemi-fix-0112 から遡る全部)を消していた。これまでの便はどれも先頭に足す形(`6c8cba8` +19 / -0 ほか) | 真壁の 0113 の節(24 行)はそのまま、その下に `50450bb` の `results.md` の本文を 1 字も変えずに戻した。2 つの範囲がそれぞれ `b145215` と `50450bb` の本文に一致するのを `diff` で見た | `4f1ed28` |

## 確かめていないこと

- 実 API(wrangler / bridge)への request は再走していない。真壁の `ms/real/live-h4.*` の結果(承認・再調整・取消・申込が 202 → `Done(Ok(Accepted(id)))` → `yumemi-done`、DB の状態)は読んだだけ。live の読みは、同じ compile 済みの live に fetch を差し替えて status と本文を当てて見た(上の 2)
- ブラウザ(Chromium)で島を押す形
- 202 の後の続き(outbox の sweep)が終わる前に島が頁を読み直す順序。写しの承認・再調整・取消は状態の書きを commit の前に置いているので、読み直した頁には反映されている。続きは通知だけ
- gleam_stdlib の下限(0.44)での `decode.dict` の JS の object の読み(0112 の P1-4 と同じ)

## 判定

**P0 無し。**P1 4 件(上)、P2 1 件(`4f1ed28`)。
