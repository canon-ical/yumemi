# BRIEF yumemi-live-2 ── Live の Block を取り直して morph で当てる(0.15 の 2 便目)

便: yumemi-live-2
基点: branch `impl/yumemi-live-1` の `1d85a6a`(ゲート 2 と r2 の後。0.14 の前に main へ入れないので、2 便目もこの branch の上に積む。札の形は `briefs/results-yumemi-live-1.md`「2 便目に渡す札の形」)
起案: 鷹野[PDM]、2026-10-17
親: tech `_drafts/gleam-framework/87-realtime/01-design.v0.md`(裁定つき:案 (i′)、0.15、書きかけの保護は既定、宛先は生成器が導く)。中身は同じ文書の「案 (i′)」「宣言の形」「書きかけの保護」「配信の土台」の client と面の側

親ゴール: 相手の書きが届いたら、その Block だけが取り直されて最新が見え、入力中の文字(IME の変換中を含む)・開いた details・スクロールの位置が残る。★ が書くのは Page の置き場の `Live` 1 つ。
- 障害: 書きかけ・変換中の文字・focus が消える(今の body の差し替えと同じ)
- 障害: 断片の CSS の規則が来ない(musearch の sched-css で踏んだ)
- 障害: client に状態ができる(本文を client で組む)

## どこまで(設計の細部は任せる)

1. ★ の語:`Placement` に `Live(area:, block:, cell:, edge:)`、`Edge`(`Bottom`・`Top`・`Anywhere`)、`el.each_keyed`、`el.fresh`。87「宣言の形」のとおり。生成器の停止コード 4 と警告も同じ節のとおり
2. 面の shell の断片の口:`x-yumemi-block` の要求で、その Block の `sources` だけを読み、`<style>` と要素だけを返す。門は今の道(数えない印)。門が頁を返さなければ client は頁ごと取り直す
3. client の runtime:`<yumemi-live>`(`display: contents`)が札で socket を張り、合図(`1`)で Block を取り直し、87「案 (i′)」の当て方の 4 規則で morph する。繋ぎ直し(1 秒から倍々、上限 30 秒、繋がったら 1 回取り直す、`visibilitychange`、札の期限の前の取り直し)、取り直しの前の 0〜500ms の揺らぎ、`edge` ごとのスクロール、`el.fresh`、Args が替わり書きかけのある Component の `:state(stale)`
4. 逃げ道の口 `yumemi.block`(Block を取り直して当てる。musearch の day_swipe が後で乗る)
5. test:Playwright で 2 者(相手が送ると、変換中のまま最新が見える ── CDP の IME。87 の PoC の検査を移す)、details の開閉・focus・スクロールの 3 つの edge・断片の CSS・鍵の無い並びの警告・門が 302/404 のとき頁ごと・JS 無しは今のまま。生成器の test
6. README の 0.15 の節を client の側まで書き足す

## しないこと

`ReloadPage` を morph に寄せる(後の便)。一覧の並び・件数(v0 の外)。musearch。版上げ・tag・Hex(鷹野)。

## 返すもの

`briefs/results-yumemi-live-2.md`(1〜6 の充足、採った形と退けた形、test の表と証拠、Android の Gboard と iOS の日本語入力で確かめていないことの明記)。commit は `git-as 真壁`、branch `impl/yumemi-live-2`。止め線は経過 2 時間。終わったら柏木のゲート 2 を 1 回(鷹野が起こす)。

## 失敗例(差し戻し)

合図の本文や差分を client で継ぎ足す。送りの欄が取り直しで作り直される。断片の `<style>` を捨てる。チャット専用の分岐。
