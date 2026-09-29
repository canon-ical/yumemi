# 真壁[IM]へ ── yumemi 0.11.7(便 yumemi-look、Style に見た目の語彙を足す、直書き、鷹野[PDM] 2026-09-30)

便: yumemi-look

作業木 `~/yumemism_repo/yumemi-look`(branch `impl/yumemi-look`、基点は yumemi main の本 BRIEF の commit = v0.11.6 の上)。本便は 1 session で直に書き、終端で柏木のゲートを 1 回だけ受ける。記録は `results-look.md`(リポ直下)。commit は `git-as makabe`(path 指定)、`main` に触らない、push・tag・Hex の publish は鷹野。**版は 0.11.7**(`gleam.toml`)。musearch には触らない(取り込みと 4 面の再生成は鷹野が merge で持つ)。**経路は K3(`kimi-makabe`)。tool 1 回は 300 秒まで ── build と test は `setsid nohup … &` で起こし、`sleep 240; tail` で待つ。**

**親ゴール:** MuseArch www の画面を、ブランドガイド v0.1 の色・罫線・書体で組める(役員 人見 2026-09-29「www の画面を実際にフロントエンドで組ませて」、割りは tech `_drafts/musearch/75-www-front.v0.md`)。
- 障害:`src/framework/front/css.gleam` の `Style` で書けるのは文字の色・余白・寸法・角丸・文字だけ。`Color` は文字の色にしかならず、地の色が書けない。だから www の赤い帯も主ボタンの深朱の地も出ない
- 障害:`FontFamily` は 4 値(System・SansSerif・Serif・Monospace)だけで Noto Sans JP を名指しできない。`FontWeight` に 600 が無い
- 障害:component は shadow DOM の中で描かれ、document の CSS の規則は届かない(CSS 変数だけは継承で届く)。語彙を Style に足せば、component が使った Style は shadow の中の `<style>` にも出る

## どこまで

1. `Style` に次の 7 つを足し、`sketch_css.gleam` が CSS に写す。型の形(variant を足すか、`SpaceProperty` を広げるか、新しい型か)は真壁の選択、理由を results に
   - 地の色(`background-color`)
   - 罫線 ── 全周と下だけ(太さ・線の種類・色)。タブの下線 2px を書ける
   - focus の輪 ── 幅・離れ(外へ 3px)・色(`outline` と `outline-offset`)。`State(Focus, …)` の中で使える
   - 最小と最大の寸法 ── `min-height`・`min-width`・`max-width`
   - 書体を名で指す形 ── CSS 変数(`var(--ma-font-ui)` など)か family の名を書ける
   - 太さ 600
   - 画像の切り抜き ── `object-fit` と縦横比(`aspect-ratio`)
2. **色の値は文字列のまま渡す。**`var(--ma-color-bg)` や `color-mix(...)` を書ける(今の `Color` と同じ扱い)
3. 足すだけにする。既存の variant の意味と出力を変えない。**musearch main を入力にした生成の差は 0**(package の版の行を除く)
4. `State`・`Responsive` の中でも新しい語彙が使える
5. README の Style の節に 7 つを足す

**しないこと:**Layout・Area・Frame の形の変更、生成器(`gen/`)の検査の緩め(`class`・`style` 属性・`element.element` の禁止はそのまま)、`attribute.attribute("style", …)` の抜け穴を塞ぐ変更(別便)、musearch への書き込み、deploy・publish・push。

## 失敗例(これをやったら差し戻し)

既存の `Color` の意味を地の色に変える。新しい語彙が component の shadow の `<style>` に出ない。hex を yumemi の中に焼く(色の値はアプリが持つ)。musearch を入力にした生成物が版の行以外で変わる。

## 検収

- `gleam test`(root と `gen/`)。7 つそれぞれに、Style → CSS の文字列を見る test と、`State(Focus, …)`・`Responsive(PC, …)` の中の test
- component が使った新しい Style が、island の shadow の `<style>` に出る test(`island_style` の経路)
- musearch main(`~/yumemism_repo/musearch`、読むだけ)を入力に生成を 2 回、差 0 を results に(やり方は `results-s-2.md` の musearch の差の節に倣う。出力は作業木の中か scratch へ)

## 見積

中央 0:45。**止め線は経過 1 時間 30 分。**
