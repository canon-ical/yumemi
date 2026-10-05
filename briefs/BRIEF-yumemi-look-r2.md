# 真壁[IM]へ ── yumemi-look r2(鷹野[PDM] の検収の差し戻し 1 点、2026-09-30)

便: yumemi-look

作業木・記録・commit・しないことは `BRIEF-yumemi-look.md` のまま。経路は K3、1 session。記録は `results-look.md` に `## r2` を足す。

**親ゴール:** `BRIEF-yumemi-look.md` と同じ。

## 直すもの 1 点

- `Outline` が `outline-width`・`outline-offset`・`outline-color` しか出さず、**`outline-style` を出さない。**`outline-style` の既定は `none` なので、アプリが `State(Focus, [Outline(..)])` を書いても輪は描かれない(ブラウザの UA が `:focus-visible` に付ける `auto` に頼る形になり、`:focus` の要素や UA の違いで消える)
- `Outline` から `outline-style: solid` も出す。型の形(`style` の欄を足すか、solid 固定か)は真壁の選択、理由を results に。`Border` と揃えるなら `BorderStyle` を使ってよい
- test:`State(Focus, [Outline(..)])` の CSS に `outline-style` が出ること。island の shadow の test にも 1 行

## 検収

`gleam test`(root と `gen/`)、format 0。musearch main を入力にした生成の差 0 をもう 1 回(r1 と同じ手)。

## 見積

中央 0:15。**止め線は経過 40 分。**
