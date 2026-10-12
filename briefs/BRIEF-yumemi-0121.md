# BRIEF yumemi-0121 ── 0.12.1:生成の form が JS 無しで本文を URL に載せない、ほか musearch の移行で見つかった 4 つの穴

便: yumemi-0121
基点: yumemi main `d09832b`(tag `v0.12.0`)
起案: 鷹野[PDM]、2026-10-12(0.12 段 E)
親: `~/canonical/tech/_drafts/gleam-framework/51-front-types.v6.md`(型の正本案)、`80-baton-012.md`「段 D からの申し送り」の「yumemi 0.12.x の宿題」

親ゴール: musearch を 0.12 系で production に出す前に、0.12.0 の生成物が利用者のデータを漏らす穴と、断りの文言を取り違える穴を、★ を壊さない 0.12.1 で塞ぐ。
障害: JS の無い browser(読み込みの途中・JS の失敗を含む)から送られた本文が URL・履歴・アクセスログに載る/★ の書き方が変わり musearch の書き直しが要る版になる。

## 現在地

musearch の段 D(main `afe6279f5`、`docs/m012-api-fill/results.md`「鷹野に返す点」と水無瀬の表)が、逃げ道で手当てして yumemi へ返した穴。musearch は 0.12.0 で staging に出ている。

## どこまで(5 つ、上ほど急ぐ)

1. **生成の `<form>` が method を持たない。**JS の無い送りが GET になり、本文(チャット・登録の欄)が URL に載る。JS の無い送りは 0.12 で持たない(51 v6、鷹野の裁き)ので、JS が無いときに本文を外へ出さない形にする。GET の頁送り(一覧の `?page=` 等)の form を壊さない
2. **同名の reads を 2 本 import すると runtime が取り違える。**別の Service の同じ名の reads を 1 つの頁で使っても、それぞれの Out が正しい所に入る
3. **閉じた dialog に作り手の display が勝つ。**生成の CSS で `dialog:not([open])` が表示されない(作り手の Style より強く、`@layer` 等の順で)
4. **`when(Failed)` が Refused でも出る。**Failed と Refused を分け、断りのときに汎用の失敗の文が並ばない
5. **requires の符号(`consent_missing`・`declaration_missing` ほか)が Refused に乗らない。**Component が「同意の欠けのときだけ同意の口」を出せるようにする

各項に test。★ の書き方は変えない(musearch が lock を上げて生成し直すだけで通ること)。51 v6 に足す行があれば results の「51 v6 に足す行」に。

## しないこと

- 版を替えない・tag を打たない・publish しない(鷹野がする)
- 80 の宿題の残り(attached の `Entry`、`out` の record、Out の別名、消えた生成物、逃げ道の数え、`isList`、動的な dialog の key、Page の Var `date`、decoder の import)は今回の外。触れるなら results に「次の版へ」で書く
- 事業名と役員の名を src・README・commit message に書かない(0.12 から生成器の src も Hex に載る)

## 失敗例

- method="post" を足して、GET で頁を送る form まで POST にする
- 1 を直すのに ★ の Component の宣言に欄を足させる(musearch の書き直しになる)
- `gleam test | grep passed` の終了コードで合否を読む(字で見る)

## 確かめ

root で `npm ci` → `gleam test`、fixture の各面で生成器 2 回 exit 0・差 0。musearch の写し(`~/yumemism_repo/musearch` main `afe6279f5` を `.scratch/` に)で path 依存にして 4 面を生成し直し、生成器 exit 0 と www・muses の test が通ること(Hex の rate limit で 1 回目が落ちたら間を置いて回し直し、results に書く)。

## 返すもの

`briefs/results-yumemi-0121.md`。commit は `git-as 真壁`。
