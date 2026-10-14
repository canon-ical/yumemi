# results yumemi-0132 ── 冪等の記録の request_hash を鍵付き(HMAC)に

真壁[IM]、2026-10-15。基点 `716eee1`(`ff9ff18` + BRIEF の commit)。branch `impl/0132`。

## 変えたもの

| file | 中身 |
|---|---|
| `src/yumemi/server/http.mjs` | `idempotencyOf` が `h1:` + HMAC-SHA256(env `IDEMPOTENCY_HASH_KEY`、`name+"\n"+canonical`)を作る。比べは `keyed.same(stored)`:今の鍵 → `h1:` の行なら `IDEMPOTENCY_HASH_KEY_PREVIOUS` → 印の無い 64 桁 hex なら素の SHA-256、それ以外は違う本文(409)。鍵が無ければ `execute` が 503 `unavailable`、log 1 行 |
| `test/yumemi_idem_check.mjs` | server の env に鍵。0.13.2 の check 45 件を足した(c・a・b・d×6 通り・e・f・log) |
| `test/yumemi_idem_test.gleam` | server の件数 30 → 75 |
| `README.md` | 「A retried write lands once」の "The same body" の文、0.13.2 の節(4 項)、Worker env の行 |

## 選んだこと

**鍵の形**:Secret Store の binding(`.get()`)と素の字の secret(`wrangler secret put`)の両方を受ける。素の字を受けないと、Secret Store を使っていない app が鍵を入れる手段が無い。どちらも **32 字未満は鍵が無いのと同じに断る**(短い鍵は総当たりで割れて、鍵を付けた意味が無い。README に `openssl rand -hex 32`)。`importKey` は module の Map(鍵の値 → CryptoKey の Promise、4 件で捨てる)で isolate の中で使い回す。値で引くので Secret Store の値が替わっても古い鍵は使わない。

**鍵が無いとき(鷹野の案のまま)**:`Idempotency-Key` を持つ書きの Service だけ、キーの形の検査(400)の後、何も走らせる前に 503 `{"code":"unavailable"}`。log は `{"yumemi":"idempotency.key_missing","binding":"IDEMPOTENCY_HASH_KEY","reason":"absent"|"short"|"unreadable","service":…}` の 1 行で値は出さない(`request.unavailable` の行は出さない ── 二重にしない)。生成器で縛る・起動で落とす、は採らなかった:secret は生成の時に見えず、起動相当で落とすとキーの無い要求・読みまで止まる。client は 503 でキーと入力を保つので、secret を入れた後の再送で 1 回で通る。

**版の印と旧行 ── (i) を選んだ**:
1. 0.13.1 までの行(印の無い 64 桁 hex)は比べるときだけ素の SHA-256 で比べる。新しく残す値は必ず `h1:` の HMAC(test で縛った)。
2. 理由:(ii) は上げた直後の正しい再送(同じ本文)を 409 にし、利用者は「書けたのに失敗に見える」。(i) の旧行は既に DB にある値で、比べても新しく漏れるものは無く、cron が保持期間(既定 24 時間)のうちに消す。
3. 見える振る舞い:上げをまたぐ再送は 0.13.1 と同じ(同じ本文は replay、違う本文は 409)。鍵の差し替えの間は PREVIOUS で同じ。PREVIOUS を早く外しすぎた・知らない形(`h9:` など)の値は 409 で、どれも 2 件目の書きにはならない。

**差し替えの手順の順序を BRIEF から替えた**:BRIEF は「新しい鍵を入れる → 前の鍵を PREVIOUS に」。README には **(1) PREVIOUS に今の鍵の値を入れる → (2) `IDEMPOTENCY_HASH_KEY` を新しい値に → (3) 保持期間 + cron の間隔の後に PREVIOUS を外す** と書いた。BRIEF の順だと (1) と (2) の間、旧い鍵の記録への再送が 409 になる。(1) を先にすれば、新しい鍵だけで旧い鍵が無い時間ができない。(1) の時点では振る舞いは変わらない(test `rotate: step 1 …`)。

## DDL

無し。`request_hash text` のまま。生成の `db/framework/idempotency.sql` の注記「request_hash は Service の名と欄の SHA-256」は**直していない**:直すと DDL の file と header の `[sha256:…]` が変わり、当て直しの便が要るように見える(中身は `IF NOT EXISTS` で何も変わらない)。注記の文言は次の版の DDL の便で直す候補。

## 確かめ

| # | 何を | 結果 | 証拠 |
|---|---|---|---|
| 1 | root `npm ci` | exit 0 | `build/0132-npm-ci.txt` |
| 2 | `gleam test` | **`500 passed, no failures`**(末尾の字で見た)、exit 0。test 関数は増やしていない(server の check の件数だけ 30 → 75) | `build/0132-test.txt` |
| 3 | `node test/yumemi_idem_check.mjs server` | ok 75、NG 0 | `build/0132-idem-server.txt` |
| 4 | (c) 記録の値 | `h1:` + 64 hex、`sha256(name+"\n"+canonical)` と一致せず部分にも含まない、test 側で別に計算した HMAC(KEY_A) と一致、KEY_B で値が替わる、binding と素の字で同じ値、記録に鍵と本文の値(`090`)が無い | 同上 `hmac: …` 6 件 |
| 5 | (a)(b) | 鍵付きで同じ本文は replay(行 1)、違う本文は 409(行 1) | `hmac a/b` |
| 6 | (d) 鍵の無い env | 無い・空・短い(9 字)・`.get()` が null・`.get()` が throw・PREVIOUS だけ、の 6 通りで:キー付きの書きは 503 `unavailable`、DB に 1 文も届かない(行 0・記録 0・audit 0・DB の log 0)、log は 1 行で binding 名を持ち本文・鍵の値を持たない、キー無しの書きと読み(キー付き)は 200 | `missing key (…)` 24 件 |
| 7 | (e) PREVIOUS | KEY_A で記録 → KEY_B + PREVIOUS=KEY_A で同じ本文は replay・違う本文は 409・新しい記録は HMAC(KEY_B)。(1) の段(両方 KEY_A)は replay。PREVIOUS 無しの KEY_B は 409(2 件目の書きにならない)。短い PREVIOUS は使わず binding 名で log | `rotate: …` 6 件 |
| 8 | (f) 0.13.1 の形の行 | 印の無い SHA-256 の行に同じ本文は replay・違う本文は 409・鍵を替えても replay、行は書き換えない、新しい記録は `h1:`、`h9:` の値は 409。どれも行は増えない | `legacy: …` 6 件 |
| 9 | 全 log に鍵が無い | ok | `log: no line holds a key` |
| 10 | test が実装の誤りを捕まえるか(build の写しを書き換えて回し、戻した) | 鍵が無いと sha256 に戻す形 → NG 24 件。PREVIOUS を見ない形 → `rotate: a record under the previous key…` が NG。旧行を「無い」扱い → `legacy:` 3 件 NG。戻して ok 75 | このセッションの実行(file には残していない) |
| 11 | fixture の生成器 | notes は作業木の場で 2 回 exit 0・HEAD からの差 0。article・cms は写し(`.scratch/fx`、面に root の `node_modules` を link)で 2 回とも exit 0・停止コード 0。3 本とも基点 `716eee1` の生成器の出力と **差 0 行** | `build/0132-gen-*-{1,2}.txt`、`build/0132-gen-{article,cms}-vs-base.txt`(0 行) |

注:article・cms の写しは、committed の fixture と `src/gen/reads/article_*.gleam` の 4〜5 file で差が出る(`io.Relation(` の折り返しだけ)。基点の生成器でも同じ差が出るので本便の外 ── 手元の gleam 1.19.2 の formatter と fixture を作った版の違い。`gleam format --check src test` も本便で触っていない 13 file(`src/yumemi/front/markdown.gleam` ほか)で落ちる、同じ原因と見ている(本便で触った `test/yumemi_idem_test.gleam` は入っていない)。

## README の差

- 「A retried write lands once」:"The same body" は `IDEMPOTENCY_HASH_KEY` の HMAC-SHA256、`h1:` + 64 hex(0.13.0–0.13.1 は素の SHA-256 で、候補の少ない欄は表を読める人に戻せた)
- 0.13.2 の節(0.13.1 の節の後):上げる app は secret を先に入れる(入れないとキー付きの書きが 503)、DDL 無し・型と ★ は不変・生成物は byte 同じ。4 項 ── 鍵の形と 32 字、鍵が無いときの 503 と log の行、差し替えの 3 段、0.13.1 の行の扱いと控え(point-in-time の復元・backup)に残る旧い hash
- Worker env の行に `IDEMPOTENCY_HASH_KEY`・`IDEMPOTENCY_HASH_KEY_PREVIOUS`

## 確かめていないこと

- 実の Workers(workerd)と Secret Store の binding での動き。test は `.get()` を持つ偽の binding と素の字
- 実の PG での replay・409(偽の DB だけ)。事業 app の写しでの生成と test は回していない(生成器の出力は基点と差 0 で、変えたのは runtime の http.mjs だけ)
- 版・tag・publish はしていない(鷹野)
