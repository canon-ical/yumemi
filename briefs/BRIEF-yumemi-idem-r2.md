# BRIEF yumemi-idem r2 ── 柏木の P1-1・P1-2 を 0.13.0 の前に閉じる

便: yumemi-idem(r2)
基点: branch `impl/yumemi-idem` `2a68782`(r1 `57d19af`、柏木のゲート 2 は P0 0・P2 2 件を柏木が直した先)
起案: 鷹野[PDM]、2026-10-13。元の BRIEF は `briefs/BRIEF-yumemi-idem.md`、所見は `.scratch/kashiwagi-idem.log` の末尾と results

親ゴール: 元の BRIEF と同じ。応答が失われた書きの再投稿は、同じ 1 件・同じ応答になる。
障害: 出した後に直すと、配った client と記録の形が変わる。

## どこまで(2 つ)

1. **P1-2:file の欄がある書きの再送が 2 件になりうる。**`buildArgs` が送るたびに file を上げ直し、blob の key が毎回新しい UUID になる。Args が変わってキーも変わる。client で File ごとに上げた結果(key)を入力と一緒に保ち、再送では上げ直さず同じ Args・同じキーで送る。workerd で「file の欄がある書きの応答を捨てて再投稿 → 1 件」を叩いて results に貼る(柏木はコードを読んだだけで回していない。まず落ちることを確かめる)
2. **P1-1:RETURNING で埋まる欄が replay で古い値になる。**commit の後に応答を失った形では、記録の直しが走らず、replay の `order` や ★ の `returned` の欄が直す前の値のまま。記録を正しい値で残す形にする(直しを取引の中に入れる、replay のときに行から組み直す、ほか。選んだ理由を 3 行)。test で縛る

P1-3〜5(db_error hook の順、DDL の順、匿名の枠の共有)は今回の外。README と results の記述のままでよい。

## しないこと・失敗例・確かめ・返すもの

元の BRIEF と同じ。results は `briefs/results-yumemi-idem.md` に「## r2」の節を足す。commit は `git-as 真壁`。
