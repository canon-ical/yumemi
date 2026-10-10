# 真壁[IM]へ ── yumemi 0.11.13(便 yumemi-01113、Page の theme が実行時に必ず None になる、直書き、鷹野[PDM] 2026-10-11)

便: yumemi-01113(yumemi リポ、直書き、ゲートなし。終端は鷹野の検収)

**1 session で直に書く。長い処理を背景に回さない。**真壁は母艦の Opus。作業木 `~/yumemism_repo/yumemi-01113`(branch `impl/01113`、基点 forgejo main = 0.11.12)。記録は `briefs/results-yumemi-01113.md`、証跡は `build/01113-*`(git の外)。commit は `git-as makabe`、main に触らない。push・tag・Hex の publish は鷹野。**版は 0.11.13。止め線は経過 45 分。**検収の形は `briefs/BRIEF-yumemi-01112.md` と同じ。

**親ゴール:** musearch の嬢が muses で保存したテーマ(背景色・背景画像・文字色・アクセント)が、www の嬢のページに出る(役員 人見 2026-10-11「muse で設定したものが www で見て色反映されない」)。
- 障害(鷹野が staging で実測):api `GET /api/muse/yumemi/header` は `{"muse":{…,"theme":{"background":"#ccffa6",…,"accent":"#ff00ff"}},…}` を返すのに、www の `/muse/yumemi` の SSR は body に既定の `--bg: #FAF7F0` を出す
- 障害:生成の `shell.mjs` の実行時が `pageTheme(definition, root)` で `root[definition.theme[0]]` を引く(`gen/src/yumemi_gen/emit/front.gleam:6542` 付近)。`root` は sources のうち**最後に読んだ root の Out**(musearch では MuseHeader の後の MuseRead や ArticleRead)で、しかも PageTheme は Out の一番上でなく `muse.theme` の下にある。結果、いつも None
- 障害:生成のとき(`page_theme_service`・`output_has_custom_type`、:3530 付近)は PageTheme を持つ Service を型で選べている。選んだ Service と、Out の中の PageTheme までの path が実行時に渡っていない

## どこまで

1. 生成のときに、theme を取る Service(今の `page_theme_service` の選び)と、その Out の中で PageTheme の値に着くまでの field の path を決め、実行時はその Service の decode 済みの値から path をたどって取る。途中が None(Option)なら None。Page の `theme: Some(name)` の `name` の意味(field 名)は README に書かれた意味に合わせる。合わない・曖昧なら results に書いて、musearch の 9 Page(`theme: Some("theme")`)が意図どおり効く形を選ぶ
2. 型の上で PageTheme に着けない Page は、今の生成と同じに止める(診断の行)か、今どおりの出力。どちらかを results に
3. test:root が 2 つ以上あり、PageTheme が 2 段目(`muse.theme`)にある Page で、実行時に値が取れる・None なら既定になる、を gen の test で縛る
4. README の Page の theme の節と 0.11.13 の段落

**しないこと:**theme の CSS 変数の名前・既定の値・`theme_global` の出力の形を変える、Service・DDL・読みの生成、musearch の source、tag・publish・push。

## 失敗例(差し戻し)

theme を書かない Page の生成の差が出る。読みの回数が増える(theme のために Service をもう 1 回呼ぶ)。

## 検収

- root `gleam test`・gen `gleam test`(基線は 0.11.12 の 24 groups・337 passed)に足して通す。`gleam format --check` 0
- **musearch の写しで**:origin/main の写しを `.scratch/musearch` に置き、基点と本作業木の gen で再生成。差は www の theme を持つ頁の取り出しの所だけで、行で名指し。写しの 4 面の `npm run build`・`npm test` が通る
- **使えば効く 1 回**:写しの www を手元の worker と stub(musearch の `docs/pwa-1/evidence/` の型)で起こし、stub の `/api/muse/:handle/header` と `muse_read` が theme(背景 `#ccffa6`・アクセント `#ff00ff`)を返す嬢の `/muse/:handle` と `/muse/:handle/article` で、body の `--bg`・`--accent` がその値。theme が null の嬢では既定
