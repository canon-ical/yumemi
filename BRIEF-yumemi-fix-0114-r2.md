# 真壁[IM]へ ── yumemi 0.11.4 r2(便 yumemi-fix-0114、全面 SPA と柏木 P1 の前倒し、直書き、鷹野[PDM] 2026-09-26 17:5x)

便: yumemi-fix-0114(r2)

作業木は同じ `~/yumemism_repo/yumemi-fix-0114`(branch `impl/yumemi-fix-0114`、基点は r1 `78e699b` + 柏木 `f84ae87`)。新しい session。柏木のゲートは r1 で済んだ(P0 無し、P1 7)。**r2 に柏木の 2 回目は無い。鷹野が実 API で検収する**ので、確かめた手は全部証跡に残す。

**親ゴール:** r1 と同じ(musearch の開発が yumemi で止まらない)。加えて役員 人見 2026-09-26「全面 SPA だよね?」── Page 間の移動と書いた後の読み直しを、頁の読み込みでなく client の遷移にする。

**障害:**
- pageview を 2 回数える、または数え落とす(今は server が adult の session の 200 の HTML に script を差して 1 回数える)
- CSP・門・script の検査(柏木 r1 の §1 で「緩む向き無し」と確かめた形)を崩す
- 書いた後の読み直しが古い中身を出す

**先に読む:**`docs/reports/yumemi-fix-0114.md`(r1)と `docs/reports/yumemi-fix-0114-review.md`(柏木、特に §1 と P1)。

## どこまで

1. **pageview の Page も client 遷移にする。**生成器が route 表から pageview の Page を外すのをやめる。数えるのは 1 回の遷移につき 1 回だけ、server が数えたはずの時だけ(adult の session・200 の HTML・pageview の Page)。形は真壁が決める ── 例:navigate の fetch は印の header を付け、門はその応答に script でなく数える印(属性か meta)を差し、client が差し替えの後に同じ送り先(`/api/pageviews`)へ送る。頁の読み込みに落ちた時に 2 回数えないこと
2. **書いた後の読み直しを client 遷移の取り直しに。**島の Done の後の読み直し(`listenReload` / `yumemi-done`)は、今の頁が route 表に当たれば今の URL を navigate の道で取り直す(history は積まない、scroll は保つ)。当たらなければ今までどおり頁の読み込み
3. **CSP の Page(`frame_src`)は頁の読み込みのまま。**外す test を足す(柏木 P1-7)
4. **柏木 P1 の前倒し:**
   - P1-1 H10 の読みの判定を 1 回の走査に(文字列・引用識別子・注釈を先に外す)、`into` を書きの語に、組み込みの許可表に無い関数の呼びは書きに数える。書きを読みと数えて再試行する形を test で 0 に
   - P1-2 読みの timeout の既定を 10000 ms に(metrics・vector の重い読みで 503 を出さない)。env で替えられるのはそのまま
   - P1-4 # の decode を try で包み、例外でも `boot()` と `yumemi-navigated` を走らせる
   - P1-5 `sketch_lustre` の上限を 3.1 系に絞る(internals の import)
   - P1-7 `navigation_rules` に `download` の手
5. 版は 0.11.4 のまま(未 publish)。公開型は追加だけ

## 検収(自分で回す、鷹野が回し直す)

root build 0、gen test(1〜4 の test を足す)、format、fixture ×2、musearch 写し `cd9731f8` の 1 手 ×2 差 0、写しの api `npm test`、3 面 build・test(`adopt-source.patch` を当てた形でも)。**実 API で(Playwright、navigation の回数と pageview の行数を DB で数える):**
- www `/search` → `/muse/:handle` → 記事 → 予約の 3 Page と戻る・進む:navigation 1 のまま、pageview は Page ごとに 1 行ずつ(adult の session)、申告の無い browser は 0 行で門で止まる
- CSP の `/` と `/about/external` へは頁の読み込み、その頁から出る時も頁の読み込み
- muses と console の Page 間を 3 手以上 click で:navigation 1 のまま
- 書いた後(muses の link の追加・console の在籍の並べ替えなど 3 本):navigation 1 のまま、画面が新しい中身
- H10:書きの形(`SELECT fn()`・`INTO`・literal の `--` の後の CTE)を再試行しないこと

## しないこと

musearch に書かない、publish / tag / push しない。止め線は **経過 1 時間 30 分(壁時計ではない)**。PG は 55565、port は 9682〜9697・10131〜10137。起こした process は pid で止める。

終端:`docs/reports/yumemi-fix-0114.md` に `## r2` を足す(1〜4 の直し・test・実 API の表、変わった生成物、musearch が採る時の手の差分、`adopt-source.patch` を当て直すなら新しい版)。commit は `git-as makabe`、r2 を 1 本に squash(r1 の commit は残す)。
