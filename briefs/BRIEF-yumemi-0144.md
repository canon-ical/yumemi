# BRIEF yumemi-0144 ── Style に左の内側の余白だけを置く語(`PaddingLeft`)

便: yumemi-0144(branch `impl/yumemi-0144`、基点 forgejo/main `5b8fd93` = 0.14.3)
起案: 鷹野[PDM]、2026-10-17

**真壁さんへ(Sonnet)。**止め線は経過 30 分。commit は `git-as 真壁`。tag・push・publish は触らない(鷹野が打つ)。ゲートは無い。

親ゴール: 使う側の面が、見出しの左に帯(`Border(edge: LeftEdge, ..)`、0.13.1)を引いたとき、帯と字の間を左だけ空けられる。上・下・右の余白は変わらない。
- 障害: `Padding` の 4 辺を動かしてしまい、見出しの上下が広がる
- 障害: 版を上げたのに fixture の lock が古く、root の test が落ちる

## 現在地

- `src/yumemi/front/css.gleam` の `SpaceProperty` は `Margin`・`Padding`・`Gap`・`Width`・`Height`・`Radius`・`MinWidth`・`MinHeight`・`MaxWidth`。片側の余白は無い
- 出力は `src/yumemi/front/sketch_css.gleam:190` 付近の 1 か所(`css.Padding -> sketch_css.padding_(..)`)。sketch には `padding_left_` が在る
- 生成器(gen/)は `SpaceProperty` を名指ししていない(grep 済み)。名指しが見つかればそこも足す

## どこまで

1. `SpaceProperty` に `PaddingLeft` を足す。doc は 1 行「左の辺の内側の余白だけ(`padding-left`、0.14.4)。見出しの帯と字の間など」。`Margin` 等と同じく `Length` を取る
2. `sketch_css` に `css.PaddingLeft -> sketch_css.padding_left_(length_to_string(value))`
3. test 1 本:`Space(property: PaddingLeft, value: Px(8.0))` が `padding-left: 8px` を出し、`padding:` の 4 辺の宣言を出さない。`Border(edge: LeftEdge, ..)` と並べた Style でも両方出る
4. `gleam.toml` の version を `0.14.4`。fixture の各面(`gen/fixtures/{article,cms}/{admin,public}`)で `gleam update yumemi`(版の行を替えると第 41 条が lock の `-dev` を止めて root の test が落ちる)
5. `CHANGELOG.md` の頭に `## 0.14.4 (2026-10-17)` を 3〜4 行。**事業名・人名を書かない**(Hex に載る)。`git grep -i "musearch\|人見" -- README.md CHANGELOG.md src` が 0
6. root の `gleam test`。合否は終了コードでなく出力の `passed` / `failures` の字で見る

## しないこと

`PaddingRight`・`MarginLeft` など他の片側の語。既存の `Padding` の出力を変えること。tag・push・Hex publish。

## 返すもの

`briefs/results-yumemi-0144.md`(1〜6 の充足、test の数、確かめていないこと)。commit は 1〜2 個。
