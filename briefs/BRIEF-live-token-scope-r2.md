# BRIEF live-token-scope r2 ── ログインしていれば誰でも通る読みの Live も生成器で止める(0.14.1 に同梱)

便: live-token-scope(r2)
基点: branch `impl/live-token-scope` の先頭(柏木の P2 `f9cd66b` の後)
起案: 鷹野[PDM]、2026-10-17
親: 柏木のゲート 2 の P1-1(写し `briefs/gate2-live-token-scope.md`、全部読む)。0.14.1 は未公開なので同梱する(鷹野の判断)。ゲートは掛け直さない。直ったかは鷹野の検収で閉じる

**真壁さんへ(Opus)。**止め線は経過 45 分。commit は `git-as 真壁`、push・tag・Hex・柏木の起動はしない。

親ゴール: 合図の札を持てるのは、その宛先の書きの時刻を知ってよい人だけになる。
- 障害: allow の句が `Party` × `NoOwner`(session があれば誰でも root のどの行も通る)の読みを `Live` に置くと、ログインした第三者が同じ root の書きの時刻を聞ける

## どこまで(柏木の案 1〜4 をそのまま採る)

1. `Live` の Block の読みの allow に、`who: Party` かつ `owner: NoOwner` の句があれば停止コード 4(`Anyone` と同じ所、`public_read` を広げる)。文言は柏木の案 4 の形
2. Entity の主体(`Staff`・`AsFan` など)× `NoOwner` の句は警告(停止コード 0)で名指しする
3. 中身を読めない句(定数の参照・spread)は判定できないので停止コード 4
4. musearch の `chat_read`(`AsMuse × ViaMuseParty`、`AsFan × ViaFanParty`)は 1〜3 のどれにも当たらないこと。musearch の作業木(`~/yumemism_repo/musearch` の main、読むだけ)の allow を写して確かめる
5. test:1〜3 の各形の停止・警告と、当事者の句(`Self`・`Via<Entity>Party`)は通ること。既存の検査(`yumemi_live_check`・`yumemi_live2_*`・`yumemi_block_door_*`)が通ったまま。`gleam test`
6. README の「A read carries a token」と `Live` の節、CHANGELOG の 0.14.1 に止める条件を足す。限界(root の当事者は、同じ root の自分に見えない書きの時刻も聞ける、★ の判断)も 1 文

## しないこと

札の形・socket の口・runtime の変更。P1-2(registry の 1 行目の注記)は直してよい(注記だけなら)。

## 返すもの

`briefs/results-live-token-scope.md` に `## r2` の節(1〜6 の充足、文言、test の表)。
