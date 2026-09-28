# yumemi-s-2 真壁 ── 0.11.6:outbox に書いた要求は status によらず sweep、重なった sweep で同じ行を 2 回送らない(2026-09-29)

証跡は `gen/build/s2-*.txt`(git の外)。入力の musearch は main `597cf6e8` を `git archive` した写し(musearch には書いていない)。

## 状態

- 1〜4 は全部済み。版 0.11.6(`gleam.toml`・`gen/manifest.toml`)
- root build 0、format 0(root・gen)、gen test 318 / 0(0.11.5 の 315 + 足した 3)、fixture ×2 差 0
- musearch main を入力にした生成:exit 0、診断は基点と同じ行、6251 file のうち差は `api/src/gen/sql.mjs` の 1 行(`framework/outbox_claim` の既定の 1 文)だけ(`s2-ms-diff.txt`)

## 1・2 どの要求で sweep するか(`framework/server/worker.mjs`・`outbox.mjs`)

- 選んだ形:**db の wrapper が outbox への INSERT を数える**。`outbox.mjs` の `recording(db)` が要求の db を包み、`query` / `transaction` が成功で返った(= commit された)文のうち `INSERT INTO framework.outbox` を含むものがあれば `wrote()` が true。字の判定は `read_retry.mjs` の `strip` を通した後なので、注釈と文字列の中の字は数えない。`WITH … INSERT INTO framework.outbox` も当たる
- 生成の書き(`framework/outbox_parent`・`outbox_child` を transaction で)も手書きの SQL(musearch の `verb/notice_link`・`notice_roster`・`cancel_reservations_of_schedule` は全部 `INSERT INTO framework.outbox`)も同じ判定。musearch の `api/src` に要求の db を通らない書きは無い(`database(` を呼ぶのは生成の shell だけ)
- fetch:`202 || wrote()` なら同じ invocation の `waitUntil(sweep(db, env))`。sweep には包む前の db を渡す。dispatch が投げても、それまでに commit した outbox の書きがあれば sweep する(`try … finally`)
- 起こさないもの:読みだけの要求(文の字を見るだけで、SELECT は増やさない)、失敗した文、rollback した transaction(`db.transaction` が投げれば数えない)
- 引用識別子(`"framework"."outbox"`)は見ない。musearch には無い

## 3 sweep は行を 1 回だけ送る

- 選んだ形:**送る前に状態を進める条件付き UPDATE**。sweep は `framework/outbox_sweep` で行を並べた後、行ごとに `framework/outbox_claim` を走らせ、1 行返った行だけ送る。0 行(他の sweep が先に取った)は飛ばす

  ```sql
  UPDATE framework.outbox SET sent_at=now() WHERE id=$1 AND done_at IS NULL
  AND (sent_at IS NULL OR sent_at<now()-interval '1 hour') RETURNING id;
  ```

- 重なった 2 本目は 1 本目の行の鍵を待ち、commit の後に条件を読み直して 0 行になる(READ COMMITTED の UPDATE の再評価)。送り直しの幅(1 時間)は musearch の `outbox_sweep` と揃えた
- **SQL の置き場**:framework の SQL は app の ★(`db/queries/framework/*.sql`)という今の契約のまま、**生成器が既定の 1 文を `src/gen/sql.mjs` に足す**(`emit/back.gleam` の `bundle`、schema 名は `framework/schema`)。app に `db/queries/framework/outbox_claim.sql` があればそちらが勝つ。musearch の file を足さなくても、0.11.6 を取り込んだ回から sweep は止まらない
- `framework/outbox_sent` は呼ばなくなった(README の表に注記)。claim の後に send が落ちた行は、送り直しの幅(1 時間)の後の sweep が送る(0.11.5 は sent_at を送った後に進めたので、次の sweep ですぐ送り直していた)。consumer の冪等は今のまま
- `sweep` の返り値は送った行の数(0.11.5 は並べた行の数)。cron の `eachDue` は返り値を使わない

## 4 cron

触っていない(`shell.mjs` の scheduled の分岐・式・間隔は差 0)。

## test(gen/test/yumemi_s2_test.gleam、3 本)

- fetch の口(node の子で `worker.mjs` を回す。`cloudflare:workers` は `module.registerHooks` で差し替え)9 手:手書きの SQL で積んで 200 → 1 回 / 生成の書きで積んで 200(hook が 202 を 200 に)→ 1 回 / 積んで 500 → 1 回 / 積んで投げる → 1 回 / 読みの GET → 0 回 / outbox の無い書き(注釈・文字列に `INSERT INTO framework.outbox`)→ 0 回 / 202 → 1 回 / rollback → 0 回 / 失敗した INSERT → 0 回
- 重なった sweep 7 手(偽の DB は claim を 1 回の同期の区間で読んで書く = 行の鍵の直列化、他の文は await を挟んで順を混ぜる):3 本を並べて各行 1 回 / 返り値の和 = 行数 / 登録の無い kind は送らない / claim は生成の 1 文 / 後の sweep は何も送らない / 1 時間を過ぎた送り済みの行は 1 回だけ送り直す / **claim の無い 0.11.5 の sweep は同じ偽の DB で 2 回送る**(この test が重なりを作れている証)
- 生成 1:fixture の写しで既定の 1 文が sql.mjs に入る、`db/queries/framework/outbox_claim.sql` を置くとそれが勝つ
- 感度:変更前の `worker.mjs`・`outbox.mjs` に差し戻して同じ子を回すと、fetch の 4 手(200・生成 200・500・投げる)と sweep の 3 手が NG(`s2-ffi-base-out.txt`)。変更後は 16 手全部 ok(`s2-ffi-out.txt`)

## 実 PG(PostgreSQL 16.15、scratchpad の一時 cluster、`s2-pg.txt`)

- musearch の `framework.outbox` と同じ表に 40 行 + 1 時間より前に送った行 + done の行。3 本の sweep(SELECT の後に行ごとに claim)を並べて:送った 41 行は全部別、2 回以上 0、done の行 0、未送 0(各 sweep 15 / 11 / 15)
- A が claim して鍵を 2 秒持つ間に B が同じ行を claim:B は 1.52 秒待って 0 行、A だけが取る

## DDL

無し(表・列・索引は変えない。claim は既存の `sent_at` を使う)。

## 残り・鷹野さんへ

- musearch への取り込み:足す file は無い(既定の 1 文が sql.mjs に入る)。musearch 側で ★ にするなら `db/queries/framework/outbox_claim.sql` に上の 1 文。musearch の `test/outbox.test.mjs`・`queue-2b4.test.mjs` の sweep は `outbox_sweep` だけを差し替えて他の key を実 DB へ素通しするので、claim もそのまま走るはず(走らせていない)。`sql_manifest.json` / `sql-cases.mjs` に `framework/outbox_claim` の意味の test を足すかは musearch 側の判断
- queue の口(consumer が `enqueue` で子を積む・続きの親を積む)は今のまま sweep しない。本便の範囲(要求の応答)の外として残した。consumer が積んだ行は、次の書きのある要求か 202 か cron まで待つ
- staging(Workerd・Neon)で created → sent を測っていない
