# BRIEF yumemi-live-2 r2 ── 柏木 ゲート 2 の P2 と P1 を閉じる(2026-10-17、鷹野[PDM])

便: yumemi-live-2(branch `impl/yumemi-live-2`、今の先頭 `04d1e2d` + この BRIEF)
親: `briefs/BRIEF-yumemi-live-2.md`、`briefs/results-yumemi-live-2.md`、柏木のゲート 2 `~/.codex-agents/runs/kashiwagi-20261017-033425-2181503-6755/last-message.md`(P0 0、P2 7、P1 8。probe は同じ所に書かれた scratchpad の path)

**真壁さんへ。新しい session。ゲート 2 は掛け直さない。**止め線は経過 1 時間半。

## 直すもの(鷹野の裁定)

1. **P2-1:**断片も置き場の `cell` で包む(頁と断片の HTML の形を同じに)
2. **P2-2:**取り直した後は期限を前もって見ずに張り、期限は server の `4001` に任せる。どの輪にも倍々の待ちを掛け、止まらない取り直しの道を無くす
3. **P2-3:**断片の 5xx と通信の失敗は頁ごとにせず、倍々の待ち(揺らぎつき)で取り直す。頁ごとは redirect・403・404 だけ
4. **P2-4:**足した規則の表は document の今の sheet から作り直す(頁をまたいで残さない)。遷移で外れた規則は足し直す
5. **P2-5:**focus のある節と、書きかけのある Component・control を含む節は、前へ探す照合で消さない(鍵の無い同じ tag の兄弟が前に入っても)。README:497 の言い切りを、実際に守れる形と合わせる
6. **P2-6:**`yumemi.block` が別の URL から返した要素は取った href を持ち、合図・`visibilitychange` ではその href で取り直す
7. **P2-7:**README と results の文面(Layout の読み、client.mjs の差)を事実に、`gen/fixtures/{article,cms}` の `client.mjs` を生成し直す
8. **P1-2・P1-3:**socket が開いたら毎回 1 回取り直す(最初も、張り直しも)。繋ぎ直しの待ちと開いた後の取り直しに揺らぎ
9. **P1-4:**警告を `el.each` の字だけでなく、鍵の無い並び(`list.map` の並びを含む)に interactive Component か素の `details` を持つ形にも広げる(広げられない形は README に)
10. **P1-8:**上の 1〜6 のそれぞれを捕まえる test(柏木の probe を移す)。mutation で 1〜6 を戻すと落ちること

P1-1(断片の読みが 87 より多い)・P1-5(足した規則の勝ち負け)・P1-6・P1-7 は直さない。results の「確かめていないこと」に残す。

## 返すもの

`briefs/results-yumemi-live-2.md` に「## r2」の節(1〜10 の充足、test の表、mutation)。`gleam test`。commit は `git-as 真壁`。
