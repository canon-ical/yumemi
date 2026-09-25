# yumemi-fix-0113 ── 生成器の穴 H4、版 0.11.3(真壁[IM]、2026-09-26)

基点は yumemi main `50450bb`(v0.11.2)、branch は `impl/yumemi-fix-0113`。穴は WGm r3(musearch-yumemi-7 `2a36ce5c`)の `docs/yumemi-7/results.md` の「生成器の穴」H4。musearch には書いていない。検収は `git archive 2a36ce5c` の写し(`gen/build/fix0113/ms/`、4 package の yumemi を作業木への path 依存に)でやった。証跡は `gen/build/fix0113/` に置いた(gitignore の下なので commit には入っていない)。

## 直したもの

| # | 穴 | 直し | 場所・test |
|---|---|---|---|
| H4 | commit の後に続きを持つ Service は HTTP で 202 と `{<root>: id}` を返す。生成の live はそれを Out の decoder に通して `Broke("invalid response")` にし、書きは通っているのに頁を読み直さない | **宣言から決める。**Service の source に `step.commit(` が在り、commit を解釈の境だけにする consumer(runtime の `boundaries`)でない Service を「202 を返す」とする(runtime の `commit` がそのとき outbox を書いて `False` を返し、step が `Accepted` で終わるのと同じ条件)。その Service の live だけ、Out の代わりに `Reply` を持つ:`Replied(<service>.Out)`(commit の前に `step.done` で終わる道の 200)と `Accepted(id: String)`(202 の本文)。send の decoder は Out を先に、読めなければ **1 欄の object で値が文字列**のものを `Accepted(id)` に読む。どちらも `Done(Ok(_))` として update に入り、after_send(`ReloadPage` なら `yumemi-done`)へ進む | `emit/accepted.gleam`(新)の `accepts` / `boundary`、`emit/front.gleam` の `reply_type_text` / `reply_decoder_text` / `state_type_text` / `send_text`、`yumemi_fix_0113_test` の 3 本 |
| ── | runtime の `boundaries` の判定が emit/runtime の中に閉じていた | `accepted.boundary` に移し、runtime もそれを使う(front と back で同じ規則)。写しの `runtime.mjs` の `boundaries` は前後で同じ(生成物の差 0) | `emit/runtime.gleam` の `outbox_text` |
| 版 | ── | `gleam.toml` を 0.11.3 に、`gen/manifest.toml` の path 依存も 0.11.3 に。README の framework/server の節に 1 段落 | ── |

**本文の欄の名を宣言の root で縛らなかった理由。**framework の既定は `{<root の Entity>: args.id}` だが、★ `respond` が欄を替えてよい。写しでは `reservation_request` の root は `muse_schedule` で、hook が `{reservation: <作った id>}` を返す(`store_request_handle` も `article` に替える)。root の名で読むと申込が H4 のまま残るので、「1 欄で値が文字列」を 202 の本文の形とした。

**status の数字では分けていない。**`transport_ffi.mjs` は変えていない(2xx の本文を `on_ok` に渡すだけ)。202 を返さない Service の live は Out の decoder のまま。

公開型は変えていない。`framework/front/live` の `State` / `Event` / `Done` / `Set`、`transport_send` の 6 引数はそのまま。変わるのは生成の live の `State` / `Event` の型引数(202 の Service だけ、Out → 生成の `Reply`)。島が `Some(Ok(_))` で受けている限り書き換えは要らない(写しの島 2 本はそう書いてあり、build 0)。`git diff v0.11.0 -- src/framework` は 11 file とも `A`、+1349 / -0 で 0.11.2 と同じ(本便は `src/` を触っていない)。

## 確かめたこと

| 検収 | 結果 | 証跡(`gen/build/fix0113/`) |
|---|---|---|
| root `gleam build` | exit 0 | `root-build.txt` |
| `cd gen && gleam test` | **292 passed, no failures**(基点 289 + 本便の 3:`accepts_follows_commit_test`・`live_reads_accepted_as_success_test`・`live_without_commit_keeps_out_test`) | `test-2.txt` |
| `gleam format --check src test gen/src gen/test` | exit 0 | ── |
| Article fixture ×2(`-- fixtures/article <out>`) | 2 回とも exit 0、`diff -r` 0 行。tracked の 66 file と `cmp` で不一致 0(fixture に `step.commit` の Service は無い) | `fx-one`・`fx-two`・`fx-*.log` |
| `git diff v0.11.0 -- src/framework` | `A` 11、+1349 / -0 | ── |
| 写し(`2a36ce5c`)の 1 手 ×2(`rm -rf` 4 dir → `gleam run -m yumemi_gen -- <写し>/api <写し>`) | 2 回とも停止コード 0。4 dir・`db/queries`・3 面の `priv/static/_yumemi`・`_diagnostics.txt` の `diff -r` は 0 行。警告 33 行は 0112 の `gen2.log` と行の集合が一致 | `run1`・`run2`・`gen1.log`・`gen2.log`・`regen.sh` |
| 写しの commit 済みの生成物との差(`base` と `run1` の `diff -rq`) | **変わったのは 202 の Service の live 6 本と、それを束ねる client 2 本だけ。**live:muses `reservation_approve` / `reservation_reschedule` / `reservation_cancel` / `article_publish` / `article_revise`、www `reservation_request`(どれも source に `step.commit(` が在る)。差の中身は `import gleam/dict`・`Reply` 型・State / Event の型引数・send の decoder・`reply_decoder` / `accepted_decoder` だけで、1 行目の sha は同じ。client:muses / www の `priv/static/_yumemi/client.mjs`(esbuild の束。stdlib の `dict.from` 系が入り、変数名の番号がずれる)。console は差 0。api の `src/gen`(`runtime.mjs` の `boundaries` を含む)・`db/queries`・他の live は差 0 | `base`・`run1` |
| 写しの api `npm test`(PG 55540、`dropdb` からの新しい DB、auth を先に build) | **700 / 700** | `api-1.txt` |
| 3 面(写し):`gleam build` / `gleam format --check src` / `npm run build` / `npm test` | www 0 / 0 / 0 / **52**、muses 0 / 0 / 0 / **16**、console 0 / 0 / 0 / **18**。変わった live 6 本に warning は出ていない。build の後も生成物は `run2` と差 0 | `face-build-*`・`face-fmt-*`・`face-npmb-*`・`face-npmt-*` |
| **実 API で島の live から当てる**(写しの API を wrangler 8841、bridge 8840 → PG 55540)。compile した `gen/live/*.mjs` の `init` → `Set` → `Send` の effect を lustre の `perform` で node から走らせ、返った `Done` を update に通し、その effect も perform した | **承認** 202 `{"reservation":"<id>"}` → `Done(Ok(Accepted(<id>)))`、`waiting=false`、after_send の emit は **`yumemi-done`**、DB は `approved`。**再調整** 202 → 同じ、DB は 13:30(810)。**取消** 202 → 同じ、DB は `cancelled`。**申込**(www、購読済みの fan)202 `{"reservation":"<作った id>"}` → `Done(Ok(Accepted(<id>)))`、emit `yumemi-done`、DB に `requested` の予約。前(0.11.2 の形)の確かめ:同じ 202 の本文を `gen/out/reservation_approve` / `reservation_request` の Out の decoder に通すと `Error`。失敗の道:取消済みをもう一度取消すと 422 `already_cancelled` → `Done(Error(Refused(..)))`、emit 無し(読み直さない) | `ms/real/live-h4.{mjs,out,tsv}`・`live-h4-requests.tsv`・`launch.sh` |

実 API の 1 回目は 4 本とも 400 `invalid_argument` / `value` だった。道具の bridge(0112 の写し)が timestamp を `Date` で返し、Worker の client が null に読んでいた(root の読みで落ちる)。WGm y7 の bridge と同じく timestamp / timestamptz を文字列のまま返す 2 行を bridge に足して取り直した。生成器の側の問題ではない。

PG 55540 は本便で起こした(`ms/api/test/build/pgdata-public`、pid 3159741)。wrangler(3161407)と bridge(3161406 → 足し直しの後 3162034)は `ms/real/pids.txt` の pid で止め、PG も pid で止めた。`pg_isready -p 55540` は no response、55540 / 8840 / 8841 / 9641 は listen していない。

## DDL

無し(生成器と写しの検収だけ。写しの `api/db` にも書いていない)。

## 確かめていないこと

- ブラウザ(Chromium)で島を出して押す形では確かめていない。確かめたのは島が持つ生成の live の send → update → after_send の effect まで
- www の島 `reserve-request` は `Done(Ok(_))` で「申込みました」を出し、live の effect(`yumemi-done`)を `effect.none()` に替えている(島のコード、musearch の側)。だから申込の後に頁は読み直さず、文言が出る形になる。台本の手 6 の文言「申込みました」はこの形を前提にしている。muses の `reservation-actions` は live の effect を `effect.map` で返すので、承認・再調整・取消の後に頁を読み直す
- 202 の本文が空の Service(写しの `pageview_record` は ★ `respond` が空の 202 を返す)は `step.commit` を持たないので対象外で、今までどおり transport が `invalid_response` にする。live で呼ぶ島は写しに無い
- `step.commit(` の判定は Service の module の source の文字列で見ている(framework `server/contracts.mjs` の `step.commit` の判定と同じ粒度)。helper の module に commit を置いて Service から呼ぶ形は拾わない。写しの 12 本はどれも Service の module に直に書いてある
- 生成の live の `Reply` / `Replied` / `Accepted` が、同じ module の `Field` の構成子(Args の欄名の pascal)や Error の構成子と同じ名になると、面の build が名の重複で落ちる。写しには無い(Args に `accepted` / `replied` / `reply` の欄は無い)
- Hex への publish、tag、push はしていない(しないことの指示どおり)

## WGm への申し送り

1. **0.11.3 を採れば、`reservation-actions` と `reserve-request` は書き換えずに通る。**写しで 3 面 build 0・test 52 / 16 / 18、実 API で承認・再調整・取消・申込が `Done(Ok(Accepted(id)))` になるのを見た
2. **1 手で変わるのは live 6 本と、muses / www の `client.mjs`。**muses `article_publish` / `article_revise` の live も 202 の Service なので同じ形になる(`article-form-actions` はまだ手書きの FFI で送っているので今は効かない。live に載せ替えれば 202 を成功として読む)
3. 島が live の結果の値を読むときは、202 の Service では `Ok(approve.Accepted(id))`(本文の id)か `Ok(approve.Replied(out))` になる。`Some(Ok(_))` で受けている今の島は変えなくてよい
