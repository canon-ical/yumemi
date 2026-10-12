# BRIEF yumemi-idem ── 0.13.0:再投稿で書きが二重にならない冪等キーと、SQL の接続先を env で替える口

便: yumemi-idem
基点: yumemi main `876ce7d`(tag `v0.12.2`)
起案: 鷹野[PDM]、2026-10-13(役員 人見「分けたほうが自然なら、進めて」── 0.13 = 冪等キーと接続先、Dleam 専用のドライバは 0.14)
親: tech `~/canonical/tech/_drafts/dleam/01-design.v0.md`「## 再投稿で二重にならないよう、冪等キーは yumemi の側で持つ」「## 繋ぎ替えは fetchEndpoint を env で渡す形にする」「便 Y」、`00-requirements.v0.md`「## 障害時は止まらず、保存できていない書き込みに 200 を返さない」、`_drafts/gleam-framework/86-session-roundtrip.v0.md` 末尾の節、型の正本案 `51-front-types.v6.md`

親ゴール: musearch を GA で出すとき、DB の切り替えや網の切れで書きの応答が失われても、利用者の再投稿が同じ 1 件になり、保存できていない書きに 200 を返さない。DB の置き場(Neon / Dleam)は env だけで替えられる。
障害: commit 済みで応答だけ失われた書きを再投稿すると 2 件になる(記事が 2 本、予約が 2 つ)/冪等の記録を業務の取引の外に置き、commit と記録の間で落ちて食い違う/同じキーで中身の違う要求を黙って最初の結果で返す/キーを持たない今の client・app が 0.13 で壊れる。

## 現在地

yumemi には冪等の仕組みが無い。書きの id は要求ごとの seed から作るので、同じ入力の再投稿は別の id の 2 件になる。DB に届かないときは `upstream_unavailable` の 503(`http.mjs`)、読みは 1 回やり直し、書きと transaction はやり直さない。driver は `@neondatabase/serverless` の HTTP で、接続先は接続文字列から決まる。Dleam の前段は Neon の `/sql` と同じ JSON・同じ非対話 transaction を受け、DB に届かないときは 503 + `Retry-After: 60` を返す(Dleam の窓と合意済み、86 末尾)。

## どこまで

1. **冪等キー(Dleam と合意した形)**
   - 表 `framework.idempotency (party, key, request_hash, result, created_at)`、(party, key) に一意の制約。DDL は results の `## DDL` に(当てるのは鷹野)
   - client は入力を作ったときにキー(UUID)を作り、入力と一緒に保ち、成功するまで同じキーで再投稿する。header は `Idempotency-Key`。yumemi の生成の送信(`front/`)が持つ。503 のとき入力とキーを保つ
   - server は書きの Service で、キーの記録と結果の保存を業務の書き込みと**同じ transaction** に入れる。同じキー・同じ本文の 2 回目は 1 回目の結果を返す。同じキー・違う本文は 409(`request_hash` を比べる)。並んで来た 2 回目は一意の制約で落ちた後、1 回目の結果を返す
   - キーの無い要求は今のままの振る舞い(古い client・手書きの呼び出し・cron・outbox を壊さない)
   - 古い行は保持期間(既定 24 時間、app が替えられる形)の後に cron で消す
   - どの Service に効かせるか(書きの全部か、作る・送るだけか、宣言で選ぶか)は真壁が決め、results に理由を 3 行
2. **接続先の口**:`driver.mjs` で `DLEAM_SQL_ENDPOINT`(名は Dleam と合意済み)が env にあれば `fetchEndpoint` をそれに、無ければ今のまま。1 か所で api・auth の両方に効くこと
3. 版は 0.13.0 の形で作る(表が要るので app の側に DDL が要る = 0.12 系の lock のままでは上げられない)。README に冪等キーと接続先の口の節

★ の書き方は変えない(musearch が lock を上げて生成し直し、DDL を当てるだけで通ること)。

## しないこと

- 版を替えない・tag を打たない・publish しない(鷹野がする)
- Dleam 専用のドライバ(0.14)、86 の道(頁で session を 1 回等)、0.12.2 の「次の版へ」は今回の外
- 事業名と役員の名を src・README・commit message・fixture に書かない

## 失敗例

- 冪等の記録を業務の取引の後に別の文で書く
- 409 にすべき「同じキー・違う本文」を、最初の結果で 200 にする
- キーの無い要求まで 400 にして既存の app を壊す
- 結果の保存に、応答に出さない値(他人の行・内部の id)を混ぜ、同じキーを知る別の party に返す(party で引くこと)
- `gleam test | grep passed` の終了コードで合否を読む(字で見る)

## 確かめ

root で `npm ci` → `gleam test`。fixture の各面で生成器 2 回 exit 0・差 0。notes の fixture を workerd で起こし、(a) 同じキー・同じ本文の 2 回で行が 1 つ・応答が同じ、(b) 同じキー・違う本文で 409、(c) キー無しは今のまま、(d) commit の後に応答を捨てた形(test の中で)の再投稿で 1 件、(e) `DLEAM_SQL_ENDPOINT` を立てた shim(`~/yumemism_repo/yumemi-bench/neonshim/` を写して使ってよい)へ要求が行くこと、を叩いて results に貼る。musearch の写し(`~/yumemism_repo/musearch` main を `.scratch/` に)で lock を path 依存にして生成し直し、生成器 exit 0 と、DDL を当てた PG で www・muses・api の test が通ること。

## 返すもの

`briefs/results-yumemi-idem.md`(`## DDL` 必須、設計の選択の理由、確かめの実測、musearch の写しの結果)。commit は `git-as 真壁`。
