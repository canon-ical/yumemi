# results yumemi-live-1 ── 他人の書き込みを画面に届ける合図の器と札(0.15 の 1 便目、api の側)

真壁[IM]、2026-10-17。基点 `9e35a52`(`8a1c930` + BRIEF の commit)。branch `impl/yumemi-live-1`。証跡は `build/live-*.txt`(git の外)。版の行・tag・Hex は触っていない。

## 1〜6 の充足

| # | 中身 | 置き場 | 充足 |
|---|---|---|---|
| 1 | DO `YumemiLive`:storage を持たない、`acceptWebSocket`(Hibernation)、`publish()` で繋がっている全部に `1`、`setWebSocketAutoResponse(ping → pong)`。宛先は `idFromName("<entity>:<id>")` | `src/yumemi/server/worker.mjs`(class)、生成の `shell.mjs` が `export { YumemiLive } from …worker.mjs` | 済(workerd で ping/pong・`1`・宛先ごとの分離を見た) |
| 2 | 書きの transaction が commit したら、応答の後に `execution.waitUntil(publish)`。binding `YUMEMI_LIVE` が無ければ撃たない。宛先の表は生成の `registry.mjs` の `live`(★ は書かない) | `http.mjs` の `livePublish`、`runtime.mjs` の finish の `state.afterCommit?.()`、`worker.mjs` の `handlers` が `execution` を dispatch に渡す、生成器 `emit/back.gleam` の `live_text`・`emit/http.gleam` | 済 |
| 3 | 札:読みの Service が 200 で通ったら header `x-yumemi-live`。宛先・party・期限 1 時間を `YUMEMI_LIVE_KEY` の HMAC-SHA256 で包む。鍵が無い・空・32 字未満・読めないなら札を付けず、log 1 行(`live.key_missing`)、合図も撃たない | `src/yumemi/server/live.mjs`(`issue`・`verify`・`keyOf`)、`http.mjs` の `liveIssue` と `response` | 済 |
| 4 | socket の口 `GET <入口の prefix>/_yumemi/live?token=…`:upgrade・binding・鍵・`Origin`・署名・期限・session の party を見てから DO へ。外れは 403 と log 1 行(`live.refused`、理由だけ) | `http.mjs` の `route`(口の判定)・`liveSocket`・`liveRefused`、`failure`(門の段の拒否も 403 と 1 行) | 済 |
| 5 | workerd の test | `test/yumemi_live_check.mjs`(束ねて workerd に載せ、node の WebSocket・HTTP で叩く)、`test/yumemi_live_worker.mjs`(試験の api Worker)、`test/yumemi_live_test.gleam` | 53 件 ok・NG 0 |
| 6 | README の 0.15 の節の下書き(binding・migration・secret の 3 つが app の手、宣言には現れない)と Worker env の行 | `README.md`(0.13.2 の節の後) | 済 |

★ の Gleam の型・宣言は 1 つも増えていない(`yumemi/server.gleam`・`front.gleam` は無変更)。DDL 無し。

## 採った形と退けた形

- **札の形**:`<payload>.<署名>`(どちらも base64url)。payload は `{"to":"<entity>:<id>","party":<party か null>,"exp":<秒>}`、署名は `yumemi-live/1\n<payload>` の HMAC。**party は payload に平文で置いた。**退けた形は「party を HMAC の入力にだけ混ぜる」── 他人の札も改ざんも同じ `signature` になり、BRIEF の「理由は log に 1 行」で party の外れを区別できない。自分の party は `/api/session` でも本人に見えているので、本人に渡す札に載せて新しく漏れるものは無い。Entity の値(本文・title)は載らない(test で見た)
- **札は query `?token=`**:browser の WebSocket は header を付けられない。退けた形:`Sec-WebSocket-Protocol` に載せる(server が同じ値を echo する作法が要り、DO まで運ぶと面倒)、cookie(宛先ごとに要る)
- **口の場所は api の入口の prefix + `/_yumemi/live`**(pageviews の受け口 `/_yumemi/pageviews` と同じ形)。API key の入口には口も札も無い(札は session の party に結ぶ)
- **Origin の期待値**は `https://` + 要求の host(= その入口の host)、★ の `origin` hook があればその値。`s.hosts`(全入口の host)にしなかったのは、別の面の頁から張る道を開けないため
- **撃つ条件**:元の要求の書きの transaction が commit した(`afterCommit` の印、★ の db_error が写しで走らせ直しても元の要求に立つ)、かつ応答が業務の失敗(`Fail`)でない。`step.reject`(断りの行だけを commit)は撃たない ── BRIEF の「Done の commit の後」。commit の後に投げた要求は撃つ(合図は余っても害が無く、足りない方が困る)。1 要求で 1 回
- **鍵の確かめは `waitUntil` の中**(合図の側)。読みの側は札を作るので応答の前に鍵を読む(import した鍵は isolate で使い回す)。鍵の読みが投げても読みは 200 のまま(札無し・1 行)
- **鍵の形は 0.13.2 の `IDEMPOTENCY_HASH_KEY` と同じ**(Secret Store の `.get()` か素の字、32 字以上)。ただし 503 にはしない:札が無いだけで読み書きは正しく、0.13.2 のように「鍵が無いと正しくない記録になる」ものが無いため。黙らない点(1 行)を揃えた。関数は `live.mjs` に別に持った(0.13.2 の `idempotencyHashKeyOf` には触らない)
- DO の migration の種類は README に `new_sqlite_classes` と書いた(storage を使わないが、class には migration が要る。どの plan でも受ける種類)
- **生成器**:`live` の表は root の Entity を持つ Service 全部(`root.root_for` が Some、読みも書きも)。id の列は root の 1 文の行の `id` 固定(表の 2 つ目)。★ の器の class 名 `YumemiLive` は宣言の矛盾(exit 4)
- **生成物の差**:`registry.mjs`(`live` の表)・`http_runtime.mjs`(import と `http({.., live, ..})`)・`shell.mjs`(export 1 行)の 3 file。fixture の notes・article・cms をこの 3 file だけ生成し直して commit した(header の `[sha256:…]` は入力の hash なので動かない)

## test の表と証拠

| # | 何を | 結果 | 証拠 |
|---|---|---|---|
| 1 | `gleam test` | **`503 passed, no failures`**(末尾の字、500 + 本便の 3)、exit 0 | `build/live-test-2.txt` |
| 2 | `node test/yumemi_live_check.mjs`(workerd 2026-09-15、`node_modules/.bin/workerd`) | ok 53、NG 0 | `build/live-check-2.txt` |
| 3 | 札 | 読めた読みに header、payload は `to`・`party`・`exp`(今 + 3600±5 秒)の 3 欄だけ、Entity の値を含まない。読めない party は 404 で札無し。書きの応答に札無し。binding 無し・鍵無し・短い鍵は札無しで 200、鍵の不足は 1 行ずつ(binding 名と `absent`/`short`) | 同上 `token: …` 8 件 |
| 4 | socket の口 | 本人は開く(WebSocket と生の 101)。他の party・session 無し → `party`、他の Origin・Origin 無し → `origin`、期限切れ(鍵で作り直した過去の exp)→ `expired`、party を書き換えた・宛先を書き換えた・別の鍵 → `signature`、札無し・形違い → `token`、upgrade 無し → `upgrade`、binding 無し → `binding`、鍵無し → `key`。どれも 403 で WebSocket も開かず、log の理由が一致。拒否の行に札・鍵・宛先が無い | 同上 `socket: …` 25 件 |
| 5 | 合図 | party-c が n1 を書く → n1 の 2 本(書いた本人の頁も)に `1` が 1 回、n2 の socket には来ない。業務の失敗・`step.reject`(断りの行は commit した)・root で 404 の書きは撃たない。ping → pong | 同上 `signal: …` 9 件 |
| 6 | 合図の失敗が書きの応答を変えない | binding 無し・鍵無し・DO の publish が投げる・namespace が投げる・publish が 3 秒かかる、の 5 通りで status と本文が基準と同じ、3 秒の publish でも応答は 1.5 秒未満、壊れた binding は呼ばれた(1 回ずつ)、失敗は 1 行ずつで宛先・鍵を持たない、書きは 5 通りとも commit 済み | 同上 `write: …` 11 件 |
| 7 | test が誤りを捕まえるか(build の写しを書き換えて回し、戻した) | party の比べを外す → NG 4、Origin を外す → NG 4、期限を外す → NG 2、合図を await にする → NG 1(3 秒待つ)、署名の外れを通す → NG 6、合図の側の鍵の確かめを外す → NG 1、Fail で撃たない条件を外す → NG 2(`step.reject` の件)。戻して NG 0 | `build/live-mut-*.txt` |
| 8 | 生成器 | `registry.mjs` の `live` の表(notes:note_delete・note_edit・note_read、root の無い note_create と一覧 note_list は無い)、`http_runtime.mjs` の受け渡し、`shell.mjs` の export、`YumemiLive` の名の ★ の器は Conflict | `test/yumemi_live_test.gleam` の 2 件(#1 に含む) |
| 9 | fixture の生成 | notes は作業木の場で 2 回 exit 0・2 回目の差 0。article・cms は写し(`.scratch/fx`、面に root の esbuild を link)で 2 回 exit 0・停止コード 0、3 file は 2 回とも commit した fixture と同じ。写しの `src/gen/reads/*.gleam` の差は 0.13.2 の results にある formatter の差(本便の外) | `build/live-gen-*.txt` |
| 10 | `gleam format --check`(本便で触った gleam 4 file) | exit 0 | このセッションの実行 |

## 2 便目に渡す札の形

- **取り方**:面の shell が `readFromApp(env.APP, …)` で Block の読みを叩いた応答の header `x-yumemi-live`。読みが 200 のときだけ在る(binding か鍵が無い api では無い ── そのときは `<yumemi-live>` を出さないか token 無しで、client は socket を張らない)
- **張り方**:`wss://<面の host><api の入口の prefix>/_yumemi/live?token=<encodeURIComponent(札)>`。cookie(session)と Origin は browser が付ける。札の party と session の party が違えば 403 なので、session が替わったら(切り替え・ログアウト)Block を取り直して新しい札で張る
- **届く字**:`1` だけ。他の字(`pong`)は合図でない。client が `ping` を送れば `pong`(DO は起きない)
- **期限**:payload(base64url の JSON)の `exp`(秒)。client は解いて期限の前に Block を取り直し、来た札で張り直せる。署名は client では確かめない(鍵は api だけ)
- **拒否**:WebSocket の API には status が見えない(`error` → `close`)。張れなければ Block を取り直す(門・root が 404・403 なら頁ごと取り直す道、87 の「読めなくなった人」)
- **宛先**:札の `to` は `<root の Entity>:<root の行の id>`。読みと書きの root が同じ Entity なら同じ宛先

## DDL

無し。

## 確かめていないこと

- 実の Cloudflare(`wrangler deploy`)での DO の migration(`new_sqlite_classes`)と、Hibernation で実際に眠ること・眠った後の `publish()`。workerd の手元の起動だけ
- Secret Store の binding での鍵(workerd の test は素の字の text binding。`.get()` の形は 0.13.2 と同じ関数の形で、node では見ていない)
- 実の PG と、生成した実の app(api と面)での読み書き。test の api は入口・runtime・adapter が本物で、表と DB が偽物
- 書きの道のうち test していないもの:冪等キーの再投稿(Service を走らせないので撃たない、と読んで決めた)、★ の db_error が写しで走らせ直した書き(`afterCommit` が元の要求に立つ、と読んで決めた)、commit の後に応答が DB から届かず落ちた書き(commit を知らないので撃たない ── 合図は落ちてよい側)
- queue の consumer・cron が走らせる書きは撃たない(`execution` が HTTP の入口にしか無い)。README に 1 文。要るなら次の便
- ★ の `respond` hook が自前の Response を返す読みには札が付かない(`response()` を通らない)。README に 1 文
- DO の `fetch` が投げた socket は 503(入口の失敗の道)と読んで決めた。test していない
