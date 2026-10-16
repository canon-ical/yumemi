# BRIEF live-token-scope ── 合図の札を Live の Block の読みだけに付ける(0.14.1 に同梱)

便: live-token-scope
基点: branch `impl/block-door` の `a30ffa5`(block-door の柏木のゲート 2 が並行で走っている。その P2 の commit が後から block-door に乗ったら鷹野が合わせる)。branch `impl/live-token-scope`
起案: 鷹野[PDM]、2026-10-17
親: musearch の便 m-live(87 M1)の柏木のゲート 2 のエスカレーション(写し `briefs/gate2-m-live-escalation.md`、全部読む)。87 の v0 で鷹野が「札は allow の Entity を持つ読みに全部付ける」と判断したのが誤りで、その判断を鷹野が取り消す(How)。0.14.1 は未公開なので、block-door と一緒に 0.14.1 で出す

**真壁さんへ(Opus)。**止め線は経過 1 時間半。細かい設計は任せる。commit は `git-as 真壁`、push・tag・Hex は触らない。柏木のゲート 2 は鷹野が起こす。**柏木を自分で起こさない**(block-door の便で真壁が Codex の柏木を起こしたが、ゲートは鷹野の手)。

親ゴール: 合図の札を持てるのは、その宛先の書きの時刻を知ってよい人だけになる。
- 障害: 公開の読み(allow に Anyone)で取った札で、ログインしていない第三者が、同じ root の非公開の書き(嬢の顧客台帳など)の時刻を即時に追える(柏木が musearch の `muse_top` → `muse:<id>` → `customer_add` で再現した)

## 鷹野の判断(How)

1. **札は、どこかの面の Page で `Live` に置かれた Block の読みの Service にだけ付ける。**生成器は api と面を一度に生成するので、`Live` の Block の Service の一覧を api の生成物(registry の表など)へ書ける。87 の「api は面の宣言を知らない」は生成の順の話で、生成器は両方を見ている。表に無い読みは 0.14.1 から札を返さない
2. **`Live` の Block の読みの allow が `Anyone`(公開)なら、生成器は止める(停止コード 4)か、少なくとも警告にする。**どちらにするかと文言は任せる。理由:公開の読みに `Live` を置くと、同じ root の非公開の書きの時刻を誰でも聞ける。止める形を推す(★ が意図して公開の頁を Live にしたいときの逃げ道が要るなら、results に案として書く。今は作らない)
3. 札の中身・socket の口・合図の撃ち方・`YumemiLive` は変えない。0.14.0 の札を持っている頁は、読み直せば新しい規則の札(または札なし)になる

## どこまで

1. 上の 1・2
2. test:公開の読み(Anyone)の応答に札が付かない、`Live` でない読みに札が付かない、`Live` の Block の読み(party が root の当事者)には付く。生成器の停止(または警告)。0.14.0 と block-door の Live の検査(`yumemi_live2_check`・`yumemi_live2_shell_check`・`yumemi_block_door_*`)が通ったまま
3. README の「A read carries a token」の節と CHANGELOG の 0.14.1 に、札の範囲の変更を書く(0.14.0 から振る舞いが変わる点として明記)。fixture の lock・生成物の追随(rule 41)
4. `gleam test` と検査の台本

## しないこと

札の形・socket の口・合図の撃ち方の変更。`touches`(root でない Entity の書き)。musearch の変更(後の便)。

## 失敗例

- api の実行時に面の宣言を読みに行く形にする(生成物の表で足りる)
- 札を付けない読みでも `x-yumemi-live` の空の header を返す(付けないなら header ごと無し)

## 返すもの

`briefs/results-live-token-scope.md`(1〜4 の充足、生成器が止める条件と文言、test の表、確かめていないこと)。
