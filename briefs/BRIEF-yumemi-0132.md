# BRIEF yumemi-0132 ── 冪等の記録の request_hash を鍵付き(HMAC)にする

便: yumemi-0132
基点: yumemi main `ff9ff18`(tag `v0.13.1` の後、briefs だけの差)
起案: 鷹野[PDM]、2026-10-15(役員の裁定「やる」)
親: `briefs/BRIEF-yumemi-idem.md`(0.13.0 の冪等キー)、README の「A retried write lands once」の節

親ゴール: 冪等の記録を残しても、DB を読める人が書きの中身(Args)を戻せない。再投稿の判定(同じ本文は replay、違う本文は 409)は 0.13.1 と同じ。
障害: Args に候補の少ない値(電話番号は約 3 億、郵便番号、生年月日)があると、鍵の無い hash は総当たりで平文に戻る/鍵の差し替えや版の切り替えの間に、同じキーの再投稿が 2 件目の書きになる/鍵が無い設定で黙って鍵無しの hash に戻る。

## 現在地

`src/yumemi/server/http.mjs:466` の `idempotencyOf` が `request_hash = sha256(Service名 + "\n" + canonical(rawArgs))` を `framework.idempotency` に残す。塩も鍵も無い。レビュアーが app の PG で実測し、申込の Args の番号を hash から戻した(422 で断られた書きの記録からも戻る)。記録は保持期間(既定 24 時間)と cron の間隔で最大約 36 時間残り、DB の履歴(point-in-time の控え)にはもっと長く残る。browser の署名 cookie は既に env の binding(`.get()` で文字列を返す Secret Store)を HMAC の鍵にしている(`browserKey`、`server.gleam` の `BrowserCookie.key_binding`)。

## どこまで

1. **request_hash を HMAC-SHA256 にする。**鍵は Worker の env の binding。名は固定で `IDEMPOTENCY_HASH_KEY`(`IDEMPOTENCY_RETENTION_HOURS` と同じく app が宣言しない名)。Secret Store の binding(`.get()`)を受ける。素の文字列の secret も受けるかは真壁が決める。鍵の取り込み(`importKey`)は isolate の中で使い回してよい
2. **鍵が無いときは閉じる。**鷹野の案:`Idempotency-Key` を持つ書きの要求だけを 503 `unavailable` で断り、何も書かない。log に binding の名を 1 行(値は出さない)。キーの無い要求・読み・port・attached は今のまま。黙って sha256 に戻る、header を無視して走らせる、はどちらも不可。別の形(生成器で縛る、起動相当で落とす)のほうがよいと判断したら、理由を results に 3 行
3. **鍵の差し替えと版の切り替え。**残す値に版の印を付け(例 `h1:` + hex。形は真壁)、鍵の差し替えの間は前の鍵の binding(`IDEMPOTENCY_HASH_KEY_PREVIOUS`、任意)でも比べる。0.13.1 までの鍵の無い行(印の無い 64 桁の hex)の扱いは真壁が決める:(i) 比べるときだけ sha256 で比べる(新しく残す値は必ず HMAC)、(ii) 比べられない行として扱う。どちらでも「同じキーの再投稿が 2 件目の書きにならない」ことを test で縛り、選んだ理由と、切り替えの間に利用者に見える振る舞い(replay / 409)を results に 3 行。差し替えの手順(新しい鍵を入れる → 前の鍵を PREVIOUS に → 保持期間 + cron の間隔の後に PREVIOUS を外す)を README に
4. **README**:「A retried write lands once」の節の「The same body is the SHA-256 …」を直し、0.13.2 の節(上げる app は secret を先に入れる、入れないと鍵付きの書きが 503)を足す。DDL の変更は無い見込み(`request_hash text` のまま)。変えるなら results に `## DDL`

★ の書き方と公開の Gleam の型は変えない。app は lock を上げて secret を入れるだけで通ること。

## しないこと

- 版を替えない・tag を打たない・publish しない(鷹野がする)
- `briefs/results-yumemi-0131.md` の「次の版へ」(Service ごとに記録を外す宣言ほか)は今回の外
- 事業名と役員の名を src・README・commit message・fixture・test に書かない

## 失敗例

- 鍵が無いと sha256 に戻る、または鍵の無い記録を新しく残す
- 鍵の値・HMAC の入力を log・応答・記録に出す
- 鍵の差し替えの直後に、同じキー・同じ本文の再投稿が 2 件目の書きになる
- 同じキー・違う本文が 409 にならない
- `gleam test | grep passed` の終了コードで合否を読む(字で見る)

## 確かめ

root で `npm ci` → `gleam test`(字で全数)。`test/yumemi_idem_check.mjs` の形で:(a) 同じキー・同じ本文で replay、(b) 違う本文で 409、(c) 記録の値が `sha256(name+"\n"+canonical)` と一致しない・鍵を替えると値が替わる、(d) 鍵の無い env で鍵付きの書きが断られ何も書かず、キー無しの書きは通る、(e) PREVIOUS で記録した行に新しい鍵で replay、(f) 0.13.1 の形の行への再投稿で 2 件目の書きにならない。fixture の各面で生成器 2 回 exit 0・差 0。

止め線: 経過 1 時間。超えそうなら書きかけを commit して results に残りを書く。

## 返すもの

`briefs/results-yumemi-0132.md`(選択の理由、確かめの実測、README の差)。commit は `git-as 真壁`。
