# BRIEF yumemi-live-1 r2 ── 柏木 ゲート 2 の P0 と P1 を閉じる(2026-10-17、鷹野[PDM])

便: yumemi-live-1(branch `impl/yumemi-live-1`、今の先頭 `6d2552f` + この BRIEF)
親: `briefs/BRIEF-yumemi-live-1.md`、`briefs/results-yumemi-live-1.md`、柏木のゲート 2 `~/.codex-agents/runs/kashiwagi-20261017-021646-1979548-19364/last-message.md`(P0 1、P1 5、P2 2。probe は同じ所に書かれた scratchpad の path)

**真壁さんへ。新しい session。ゲート 2 は掛け直さない。**止め線は経過 1 時間。

## 直すもの(鷹野の裁定)

1. **P0-1:張った socket は札の期限で閉じる。**入口が DO への内部の要求に `exp`(と party)を載せ、DO は `serializeAttachment` で持つ。`publish()` は期限切れの socket に送らず閉じる。期限で閉じるのに書きを待たない形(alarm など)は任せる。test:期限の近い札で張った socket は、期限後の書きで `1` を受けず閉じられる(柏木の probe を移す)
2. **P1-2:party が null の札は browser に結ぶ。**anonymous の札が持参人の札にならないこと。張るときに今の browser と照らす。test を足す
3. **P1-4:`YUMEMI_LIVE_KEY_PREVIOUS`(任意)。**確かめは今と前の鍵の両方、作るのは今の鍵だけ。0.13.2 の `IDEMPOTENCY_HASH_KEY_PREVIOUS` と同じ形と README の替え方
4. **P1-1:札は query のまま(v0)。**README に「札は URL に載り、Cloudflare の request log に残る。札だけでは張れない(session と Origin が要る)」を 1 文。P2-2 の README の言い過ぎも同じ所で直す
5. **P1-3:**`step.commit`(Accepted)の書きは HTTP の commit の時点で 1 回撃ち、queue の後の書きは撃たないことを README に明記
6. **P1-5 と P2-1:**API key の入口に口も札も無い、★ の `origin` hook がある、commit の後に投げた書きは撃つ、DO の `fetch` が投げた socket、の test。通った書きの応答に札が無いことを見る test に直す

## 返すもの

`briefs/results-yumemi-live-1.md` に「## r2」の節(1〜6 の充足、test の表、mutation で P0 の直しが捕まること)。`gleam test` と workerd の check。commit は `git-as 真壁`。
