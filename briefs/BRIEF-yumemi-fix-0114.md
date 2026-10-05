# 真壁[IM]へ ── yumemi 0.11.4(便 yumemi-fix-0114、musearch を yumemi で止めない最後の patch、直書き、鷹野[PDM] 2026-09-26)

便: yumemi-fix-0114

作業木 `~/yumemism_repo/yumemi-fix-0114`(branch `impl/yumemi-fix-0114`、基点 yumemi main `4c1f908` = v0.11.3)。本便は 1 session で直に書き、終端で柏木のゲートを 1 回だけ受ける。P0 があれば鷹野が新しい session で 1 回起こす。

**親ゴール:** musearch の開発が yumemi の穴で止まらない状態にする(役員 人見 2026-09-26「本セッションの射程は、MuseArch の開発に yumemi とその追随で block されるものがなくなること」)。musearch に残る手書きの送り口と、framework に無い口をここで埋める。

**障害:**
- 公開型を壊す、既存の生成物(島の live・codec・client)を黙って変えて musearch の 3 面が落ちる
- musearch の側で回避を書かせる(手書きの FFI・島の中の独自の遷移)
- SPA の遷移が門・CSP・成人の申告を迂回する

**先に読む:**musearch `~/yumemism_repo/musearch/docs/yumemi-8/results.md` の「B の表」「鷹野宛」、`docs/yumemi-8/review.md` の P1-4、`docs/yumemi-7/review.md` の 82 行(decodeReport)と 85 行(SPA)、`docs/yumemi-7/results.md` の 187 行。yumemi の `docs/reports/yumemi-fix-0113.md`(前の patch の型)。**musearch には書かない。**

## 穴(直すもの)

- **H5 BlobCopy の URL の写し。**生成の `blob_copy` の live は file の upload だけを送る。`POST /api/blobs` に `{from: url}` を送る口が無い(`emit/front.gleam` 1443・1583 行付近で attached の汎用の live から外している)。musearch の `link_import_apply_ffi.mjs` の `copy_icon` がこれで残った
- **H6 attached の live が body を送らない。**汎用の attached の live は body を常に null で送る(`attached_live_text`)。`POST /api/session/subject` の `{kind, id}` が載らず、musearch の `session_subject_ffi.mjs` ×2 が残った。宣言の Args を body に載せる
- **H7 `decodeReport` の未定義の識別子。**生成の `codec.mjs` の `decodeReport` が `option(r.message_chat, message_id, …)` と未定義の `message_id` を渡す(musearch `api/src/gen/codec.mjs:354`)。Report を返す Service を足した日に ReferenceError
- **H8 島の描画で sketch の stylesheet が無い。**sketch の class 付きの要素を島で描くと、ブラウザでだけ `Stylesheet is not initialized` で panic する(musearch console の `roster_issue_code`、yumemi-8 は class 無しの要素に逃がした)。生成の client が島の stylesheet を用意する。node の test でも捕まえられる形の test を足す
- **H9 Page 間の client 遷移(SPA)。**framework に Page 間の client 遷移の口が無く、musearch の予約の 3 Page は a の link(頁の読み込み)で遷移する。役員 人見 09-26 の裁定は「SPA で遷移」。生成の client が、同じ面の Page の route 表に当たる同じ origin の link を取り、次の Page を server に取りに行って(門・CSP・pageview は server の 1 回の request として通る)差し替え、島を起こし直し、history を積む。戻る / 進むで同じ。取れない・route 表に無い・修飾キー付きの click は頁の読み込みに落とす。宣言の側に Page ごとの口を足すなら追加だけ
- **H10 driver の読みの止まり。**staging で Neon の HTTP driver の読みが 8〜71 秒止まってから 503 になる(musearch `docs/fix-link403/results.md`)。`src/framework/server/driver.mjs` に timeout も再試行も無く、失敗の本文を log に出さない。**読みだけ** timeout と 1 回の再試行、失敗は本文を log に。書きは再試行しない

## 直す向き

- どれも宣言から決める。status の数字や名前の文字列で分岐しない
- 当たらない生成物は 1 byte も変えない(生成物の diff で、変わった file を穴ごとに名指し)
- 版 0.11.4。公開型は追加だけ(`git diff v0.11.3 -- src/framework` が追加だけ、変えるなら理由を行で)

## 検収(自分で回す)

root build 0、gen test(穴ごとに test を足す)、format、fixture ×2 差 0。**musearch main `cd9731f8` の写し**(git archive、作業木の外)で:生成 1 手 ×2 の diff 0、変わる生成物の一覧、api `npm test`(PG 55562、新しい DB)、3 面 build・test。**実 API で:**H5 は取り込みのアイコンの写し、H6 は店・嬢の主体の切り替え、H8 は console の claim の URL の発行を class 付きの要素で描いて panic しないこと、H9 は www の予約の 3 Page を click で進んで頁の読み込みが起きないこと(Playwright で navigation の回数)・戻るで前の Page・成人の申告の無い browser は門で止まること。H10 は driver に遅延を注入して timeout → 再試行 → 成功と、2 回とも落ちた時の log。

## しないこと

musearch に書かない(写しに当てた変更は捨てる)、publish / tag / push しない。止め線は **経過 2 時間(壁時計ではない)**。穴が大きくて止め線を越えそうなら、H9 を残して他を閉じ、H9 の現在地を書いて終端にする。PG は 55562 だけ、port は 9482〜9497・9931〜9937。起こした process は pid で止める。

終端:`docs/reports/yumemi-fix-0114.md`(穴ごとに 直し・test・実 API の結果、変わった生成物の一覧、musearch が採る時の手)。commit は `git-as makabe`、1 本に squash。
