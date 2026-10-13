# BRIEF yumemi-0131 r2 ── 柏木の P1 のうち 3 つを 0.13.1 の前に閉じる

便: yumemi-0131
基点: `9d95d4f`(真壁 r1 `f20fa18` + 柏木 ゲート 2 の P2)
起案: 鷹野[PDM]、2026-10-13
親: `briefs/BRIEF-yumemi-0131.md`、`briefs/results-yumemi-0131.md`、柏木の所見 `~/.codex-agents/runs/kashiwagi-20261013-182511-1306956-145/last-message.md`(P0 0・P1 6)

親ゴール: r1 と同じ。加えて、書き手を信用しない本文(1 つの app では嬢が書く記事)を `post()` で毎回描いても、頁が 503 にならず Worker の CPU に収まる。
- 障害: 病的な本文 1 本でその頁が落ちる、または CPU の上限に当たる

## 現在地

柏木は P0 0。P2 は `9d95d4f` で直した(key の穴は今までの `cast_of` に戻した ── 変えない)。P1 は 6 つ、うち 3 つをこの巡で閉じる(鷹野の裁き):

- **P1-1** 読みが stack を尽くす・2 乗で遅くなる入力(code span 1875 個、引用 1484 段、1 行の入れ子の箇条 1474 段、`[` 30KB で 2.8〜3.5 s、閉じない `<code>`・`<http`、`split_at` を case の主語で先に評価 `markdown.gleam:933-936`)。証拠は `build/kashiwagi-probe.txt`・`kashiwagi-depth*.txt`
- **P1-2** 頭が text の向きのそろった Paged も、型の無い穴で PREPARE が落ちる(`build/kashiwagi-pg2.txt`)。今 503 の一覧の SQL だけが変わる
- **P1-3** 穴 6 の log の `message` に入力の値が載ることがある(SQLSTATE 22 の類、`http.mjs:208`)

P1-4(公開の型の形)・P1-5(css の網羅の case)・P1-6(基点から在る事業名)は直さない。results に残す。

## どこまで

1. **P1-1:**柏木の挙げた入力のどれでも、3 つの既定(`document()`・`post()`・`outline()`)が投げずに返り、30KB の本文が node で 1 回 100 ms 以内。入れ子の深さに上限を置いてよい(越えた分は字のまま)。上限の値と根拠を results に。病的な入力の test を足す(時間は緩い上限で縛る)
2. **(a)(b) の互換は崩さない。**r1 の突き合わせ(`.scratch/cmp-ab`、表 47・乱数 30000、(b) の表 4)と 21 頁(`.scratch/cmp-c`)を回し直し、r1 と同じ結果
3. **P1-2:**向きのそろった keyset の頭の穴に text の型も付ける。PG で 1 頁目と次の頁が正しい行を返す。動いている一覧(頭が timestamptz・uuid 等)の SQL は byte 同じ
4. **P1-3:**log から入力の値が出ない形に(`message` を落とすか、値を含まない SQLSTATE の類だけ残す)。check を足す
5. fixture と事業 app の写しの生成物が r1 と同じ(差 0)、`gleam test` が字で `no failures`

## しないこと

- 版の行・tag・publish(鷹野)。P1-4・5・6 と「次の版へ」の項
- 503 を 409 に替えない

## 失敗例

- 深さの上限を (a) の読みに効かせて、(a) の普通の本文の木が変わる
- 速さを測らずに「直した」と書く(before / after の数字を results に)

## 返すもの

`briefs/results-yumemi-0131.md` に `## r2`。commit は `git-as 真壁`、checkpoint の後に 1 本でよい。
