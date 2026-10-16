# BRIEF yumemi-live-1 ── 他人の書き込みを画面に届ける合図の器と札(0.15 の 1 便目)

便: yumemi-live-1
基点: yumemi main `8a1c930`(v0.13.2)
起案: 鷹野[PDM]、2026-10-17
親: tech `_drafts/gleam-framework/87-realtime/01-design.v0.md`(水無瀬[PL]、裁定つき)。裁定(役員 人見 2026-10-17):案 (i′) を採る、0.15 にする、書きかけの保護は「取り直しても書きかけのある欄には触らない」を既定、合図の宛先は読みと書きの root の Entity と id から生成器が導き、一覧の並びや件数は v0 では動かない

親ゴール: ある Entity に書きが commit されたら、その Entity を今読めている画面にだけ「替わった」の 1 語が届く。合図に本文も差分も載らない。
- 障害: 読めない人(他の party・別の Origin)が socket を張って合図を受ける
- 障害: 合図が書きの応答を待たせる、合図が落ちたら書きも落ちる
- 障害: ★ が宛先や socket を手で書くことになる

## どこまで(設計の細部は任せる。87 の「配信の土台」「宣言の形」の生成器が書くもの のうち api の側)

1. 生成の DO class `YumemiLive`(storage を持たない、Hibernation WebSocket、`idFromName("<entity>:<id>")`、`publish()` で繋がっている全部に 1 語、ping/pong は auto response)
2. 書きの Service の Done の commit の後に、root の Entity と id へ `ctx.waitUntil(publish)`。binding `YUMEMI_LIVE` が無い Worker では撃たない。宛先の取り方は生成器が registry に表で書く(★ は書かない)
3. 札:allow の Entity を持つ読みの応答に、宛先・party・期限(1 時間)を `YUMEMI_LIVE_KEY` の HMAC で包んだ札の header を付ける(鷹野の判断 2026-10-17:全部の読みに付ける)。鍵が無ければ札を付けず、合図も撃たない(黙って鍵無しに落ちない形は 0.13.2 の `IDEMPOTENCY_HASH_KEY` に揃える)
4. socket の口:札の署名・期限・session の party・`Origin` が面の host か、を見てから DO へ渡す。外れは 403、理由は log に 1 行(札・鍵の値は出さない)
5. test:workerd で、書き → 合図が届く、読めない party・他の Origin・期限切れ・改ざんの札は張れない、binding・鍵が無いと撃たない、合図の失敗が書きの応答を変えない
6. README に 0.15 の節の下書き(binding・DO の migration・secret の 3 つが app の手、宣言には現れない)

## しないこと

client の runtime・`Live`・`Edge`・`el.each_keyed`・`el.fresh`・shell の断片の口・morph(便 yumemi-live-2)。musearch。版上げ・tag・Hex(鷹野。0.14 との順も鷹野)。

## 返すもの

`briefs/results-yumemi-live-1.md`(1〜6 の充足、採った形と退けた形、test の表と証拠、2 便目に渡す札の形)。commit は `git-as 真壁`、branch `impl/yumemi-live-1`。止め線は経過 2 時間。終わったら柏木のゲート 2 を 1 回(鷹野が起こす)。

## 失敗例(差し戻し)

合図に本文・差分・Entity の値が載る。札が無くても socket が張れる。合図の DO が落ちると書きが 5xx になる。★ の Gleam の型に宛先の宣言が増える。
