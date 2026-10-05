# 真壁[IM]へ ── yumemi 0.11.9(便 yumemi-0119、Layout に今の route・aria-current・Overlay の寄せ・Length の 3 つ、直書き、鷹野[PDM] 2026-10-03)

便: yumemi-0119(yumemi リポ、直書き、ゲートなし。終端は鷹野の検収)

**1 session で直に書く。**真壁は母艦の Opus。作業木 `~/yumemism_repo/yumemi-0119`(branch `impl/0119`、基点 forgejo main 319c087 = 0.11.8)。記録は `results-0119.md`(リポ直下)、証跡は `build/0119-*`(git の外)。commit は `git-as makabe`、main に触らない。push・tag・Hex の publish は鷹野。**版は 0.11.9**(`gleam.toml` と `gen/manifest.toml` の path 依存の行)。musearch の作業木には書かない。**止め線は経過 1 時間** ── 越えそうなら済んだ所まで commit し、残りを results に書く。割りの正典は tech `_drafts/musearch/95-console-front.v0.md`(「yumemi の 3 つの縛り」、裁定の共有の下拵え 2)・`94-muses-front.v0.md`(「重ねの語彙」、B5)・`85-www-design-import-1.v0.md` の W15、musearch `design/YUMEMI-WISHES.md`。

**親ゴール:** musearch の console と muses の前面が、ナビの今いる所・アカウントのメニューの位置・短い頁と safe area の余白を、配信側の CSS を足さずに Style だけで書ける(役員 人見 2026-10-03「muse 面と console 面のフロントも組み始めましょう」)。
- 障害:Layout の block は今の page を知れない。`gen/src/yumemi_gen/reader/front.gleam` の `placement_var_location_notes` が Layout の Path・Query・Session を止めるので、ナビの選択の下線(ガイド §6)が出せない
- 障害:`State` は Hover・Focus・Disabled だけで、`aria-current` に Style を掛けられない
- 障害:`pin: Overlay` の popover は UA の既定で画面の中央に開き、開いたボタンの下・上に寄せる語彙が無い
- 障害:`Length` は `Px`・`Rem` だけで、`var(--ma-*)`・`env(safe-area-inset-*)`・`100dvh` を書けない

## どこまで

1. **(a) Layout に今の route。**`front.From` に「今描いている Page の route の綴り」(例 `/rosters/:id`)を値に持つ variant を 1 つ足し、Layout にも Page にも置けるようにする。値は生成器が Page ごとに知っている定数で、要求の URL の字(引数の実値・query)を写さない。**`Path(name)` を Layout に許す形は採らない** ── Path は route の引数の名で、Layout を共有する page ごとに有無が違い、今どの page かを表さない。variant の名は真壁の選択、理由を results に
2. **(b) aria-current の状態。**`css.Interaction` に今いる所の状態を足し、`State(<それ>, styles)` が `aria-current` の属性の選択子の規則になる(`="page"` に絞るかは真壁の選択、理由を results に)。component の shadow の `<style>` にも出る
3. **(c) Overlay を開いたボタンに寄せる。**Overlay の Area に、開いた `el.opener` の下か上へ、始端か終端をそろえて開く語彙を足す。推奨は CSS anchor positioning で、支えの無い browser では今どおり中央に開く(壊れない)。寄せた Overlay は backdrop を暗くしない
4. **(d) `Length` に 3 つ。**`Var(name)` → `var(--name)`、`Env(<safe area の 4 辺>)` → `env(safe-area-inset-*, 0px)`、`Dvh(n)` → `n dvh`。Var の名は `[a-z0-9-]` だけを通す。Env の辺は閉じた型。root の `sketch_css` と、gen の reader・emit(Area の flow の gap、`style` の定数の読み)の両方で通す
5. 足すだけにする。既存の variant の意味と出力を変えない(中央の Overlay・`[popover]::backdrop` の規則も)
6. README の Style・Layout・Overlay の節、0.11.9 の変更点の段落、`placement_var_location_notes` の文言

**しないこと:**`Path`・`Query`・`Session` を Layout に許す、`popovertargetaction` の toggle と `:popover-open` の状態(muses の 2 段ナビは島で持つ ── 94 の B1 案 A)、Style の他の語彙、Service・DDL・読みの生成、`navigate.mjs`、musearch の source、tag・publish・push。

## 失敗例(差し戻し)

- 足した語彙を使わない musearch で、生成の差が 0 にならない
- 今の route の値に、要求の path の実値か query が混ざる
- Var の名に `;`・`}`・`)`・空白を通す
- Length の新しい variant を gen の reader が読めず、gap や `style` の定数を黙って落とす
- anchor を支えない browser で、Overlay が見えない位置に開く

## 検収

- root `gleam test`(基線 17 groups)に (a)〜(d) の test を足して通す。gen の `gleam test`(基線 320 passed)に、Layout の route の変数・shell の var の行・寄せた Overlay の CSS・新しい Length の CSS の test を足して通す。`gleam format --check` は root・gen とも 0
- **musearch の写しで差 0:**musearch main(起こす時の HEAD)の node_modules 込みの写しを `<作業木>/.scratch/musearch` に置き(commit しない、形は `results-look2.md` に倣う)、基点 319c087 の gen と本作業木の gen で全面(api を含む)を再生成して、`git diff --stat` が 0、診断の行が全行一致。写しの全面の `npm run build`・`npm test` が通る
- **使えば効くことを 1 回だけ示す**(写しの source に足してよい、写しは捨てる):console の Layout の帯の block に route を渡して 1 項目に `aria-current` と (b) の `State`、Overlay の Area を寄せ、`Dvh` と `Env` を 1 か所ずつ。生成の CSS の抜粋と、Chromium 1280px の計算値(下線 2px と色、popover の上端がボタンの下端に付く、`min-height` の px)を results に
