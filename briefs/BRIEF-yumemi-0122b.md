# BRIEF yumemi-0122b ── 0.12.2:`auto_key` の Entity を作る Service が 400 になる、穴の size が 1 未満で 503

便: yumemi-0122b
基点: branch `impl/yumemi-0122` `cb0341a`(r1 `320f99f`、柏木のゲート 2 は P0 無し・P2 1 件を柏木が直した先)
起案: 鷹野[PDM]、2026-10-13。0.12.2 に入れるのは役員 人見の裁定(2026-10-13「いれる」)
親: `~/canonical/tech/_drafts/gleam-framework/51-front-types.v6.md`、`briefs/results-yumemi-0122.md`「次の版へ」の 1 行目

親ゴール: id を DB に任せる素直な Entity(`pub const auto_key = ["id"]`)でも、最小の app が生成→起動→CRUD まで通る。
障害: 作る Service の POST が全部 400(`invalid_argument`、field は key)で、行も audit も入らない/直しで seed から id を作る app(musearch)の生成物と振る舞いが変わる。

## 現在地

yumemi-0122 で真壁が notes の最初の形を workerd で叩いて見つけた。生成の INSERT は key を DB の DEFAULT に任せる。一方 runtime の `stageVerb` は、作った値(`NoteCreated` 等)を commit の前に組むので、`c.parse('<key>', null)` で落ちる。`auto_key` は README に無く、musearch は使っていない(flag の fixture だけ)。

## どこまで

1. 直す前に落ちる test で再現する(`auto_key` の Entity を作る Service の POST が 400)
2. 直す。直し方は真壁が決める。runtime が採番するか、作った値を RETURNING の後に組むか、ほかの形か。results に選んだ理由を 3 行で書く
3. `auto_key` を README に書く(何をする宣言か、key の型に何が使えるか)
4. **柏木の P1-1(yumemi-0122 の後退):穴の size が 1 未満(`limit=0`・`-1`)で 503 `unavailable` になる**(`decodeRows` が `cursorText(keyset, undefined)` で TypeError。0.12.1 は 200 で 1 件・0 件)。1 未満は 400 `invalid_argument`(field は size の引数の名)で止める。上限は今回の外
5. fixture の notes に `auto_key` の Entity を 1 つ足すか、notes を `auto_key` の形にして workerd で CRUD を叩く。yumemi-0122 で取った数字(limit 1・5・20、2 頁目)が変わらないこと

★ の書き方は変えない。

## しないこと

- 版を替えない・tag を打たない・publish しない(鷹野がする)
- results-yumemi-0122「次の版へ」の残り(server.gleam の無い app の exit 0、Host の variant の意味)と、柏木の P1-2〜4(畳みの道の size、variant の数、kind の無い queue の ack)、size の上限は外。触れるなら results に「次の版へ」で
- 事業名と役員の名を src・README・commit message・fixture に書かない

## 失敗例

- seed から key を作る Entity の INSERT や作った値の組み方まで変える
- key の型が uuid 以外(連番・文字列)の `auto_key` で黙って壊れる形を残す。扱わない型は生成器で止める
- `gleam test | grep passed` の終了コードで合否を読む(字で見る)

## 確かめ

root で `npm ci` → `gleam test`。既存の fixture の各面で生成器 2 回 exit 0・差 0、既存 fixture の生成物の差分は results に全部挙げる。musearch の写し(`~/yumemism_repo/musearch` main を `.scratch/` に)で生成し直し、生成物の差が無いことと、www・muses・api の test が通ること。

## 返すもの

`briefs/results-yumemi-0122b.md`。commit は `git-as 真壁`。
