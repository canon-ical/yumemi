# 真壁[IM]へ ── yumemi 0.11.6(便 yumemi-s-2、outbox の sweep の穴、直書き、鷹野[PDM] 2026-09-29)

便: yumemi-s-2

作業木 `~/yumemism_repo/yumemi-s-2`(branch `impl/yumemi-s-2`、基点 yumemi main の本 BRIEF の commit = v0.11.5 の上)。本便は 1 session で直に書き、終端で柏木のゲートを 1 回だけ受ける。記録は `results-s-2.md`(リポ直下)。commit は `git-as makabe`(path 指定)、`main` に触らない、push・tag・Hex の publish は鷹野。**版は 0.11.6**(`gleam.toml` と `gen/` の版)。musearch には触らない(musearch 側の追随は鷹野が merge で持つ)。

**親ゴール:** Service が outbox に積んだ知らせが、応答の status や他の要求の有無によらず、数秒〜数十秒で Queue に送られる。
- 障害:`src/framework/server/worker.mjs:13` は fetch が 202 を返したときだけ `sweep` を `waitUntil` で起こす。outbox に行を積んでも 200 を返す Service(musearch の `link_add`・`roster_claim`・`heaven_link`・`schedule_withdraw` は手書きの SQL で積む、`link_edit` は hook が 202 を 200 に書き換える)の行は、関係の無い誰かの 202 か、12 時間ごとの cron まで動かない。staging の実測で created → sent が最大 2 時間 21 分(09-16 の「応答の直後に即時で拾うので定期の sweep はほぼ要らない」の前提が崩れている)
- 障害:近い時刻の sweep が重なると、同じ行を 2 回 Queue に送る(staging で 7 件、今は consumer が空振りするだけ)。sweep を増やすと増える
- 証拠:tech `_evidence/2026-09-29_musearch-outbox-latency.md`(水無瀬[PL] 実測、行番号・GraphQL・psql 付き)

## どこまで

1. **その要求が outbox に行を書いたら、status によらず(2xx に限らず、commit された書きなら)同じ invocation の `waitUntil` で sweep する。**生成の書きでも手書きの SQL でも同じに効く形にする ── 判定の置き場(db の wrapper が outbox への INSERT を数える、dispatch が印を返す、など)は真壁の選択。書きの無い要求では sweep を起こさない(GET の度に SELECT を増やさない)
2. 202 の今の挙動(202 なら sweep)は壊さない。rollback した要求では sweep しない
3. **sweep は行を 1 回だけ送る。**重なった sweep が同じ行を取らない形(`FOR UPDATE SKIP LOCKED` か、送る前に状態を進める条件付き UPDATE)。consumer の冪等は今のまま残す
4. cron の sweep はそのまま(取りこぼしの保険)

**しないこと:**tech 69 の他の yumemi の宿題(本便は sweep だけ)、musearch への書き込み、cron の間隔の変更、Queue の設定の変更、deploy・publish・push。

## 失敗例(これをやったら差し戻し)

GET を含む全要求で sweep を起こす。手書きの SQL で積んだ行だけ取りこぼす。2 本の sweep が同じ行を送る。rollback した要求の後に sweep が走って、積まれていない行を探す。

## 検収

- root の build 0、`gen` の test(0.11.5 の 315 本 + 足した分)、format 0
- runtime の test:outbox に積んで 200 を返す要求 → sweep が 1 回起きる / 書きの無い GET → 起きない / 202 → 今のまま起きる / rollback → 起きない / 2 本の sweep を同時に走らせて同じ行が 1 回だけ送られる
- musearch main を入力にした生成で、sweep の口以外の生成物の差 0(sha の頭の行を除く)

## 見積

中央 1:00。直書きの比で真壁 0:25、柏木 0:20。**止め線は経過 1 時間 30 分(壁時計ではない)。**
