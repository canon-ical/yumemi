# 真壁[IM]へ ── yumemi 0.12 段 B(便 yumemi-012-y2、要素の木を自前で持ち ★ から lustre を外す、Css の語彙と頁の色の型、生の CSS の逃げ道、直書き、鷹野[PDM] 2026-10-12)

便: yumemi-012-y2(yumemi リポ、Opus 真壁の直書き、終端で柏木のゲートを便に 1 回 ── `KASHIWAGI_ROUTE=opus`)

**1 session で直に書く。細かい設計は真壁さんが決める(役員 人見 2026-10-12)。**作業木 `~/yumemism_repo/yumemi-012-y2`(branch `impl/012-y2`、基点は本 BRIEF の commit = 段 A の merge 後の forgejo main `<sha:鷹野が起動時に埋める>` の上)。記録は `briefs/results-yumemi-012-y2.md`、証跡は `build/012-y2-*`(git の外)。commit は `git-as makabe`、main に触らない。push・tag・Hex の publish は鷹野。**版の行(`0.12.0-dev`)に触らない。止め線は経過 2 時間 30 分。**

**並行の便:**同じ基点から Y4(`briefs/BRIEF-yumemi-012-y4.md`、遷移)と Y5(`briefs/BRIEF-yumemi-012-y5.md`、門と CMS の機能)が別の作業木で走る。file の持ち場は下の「持ち場」と tech `_drafts/gleam-framework/81-stage-b-ownership.v0.md`。merge は Y2 → Y4 → Y5 の順で、本便が最初。

**親:**tech `_drafts/gleam-framework/51-front-types.v6.md` の「要素の木」「要素の木の細目 3 つ」「属性の型」「html と el」「Css の語彙」「頁の色」「生の CSS の逃げ道」「interactive Component のスコープ」「Style の置き場」と「生成器が止めるもの」の第 1〜3・7・8・23〜31 条、`78-own-element-tree-poc.v0.md`(試作の形と lustre との突き合わせ)、`74-css-vocabulary-line.v0.md`、`70-brief-front-rethink.md` 末尾の 2 節。

**親ゴール:**★ は yumemi の型付き要素と閉じた Css だけで書け、DB から来る色は framework の色の Type でしか CSS に入らない。段 C の Y3(interactive Component)と段 D の musearch の移行は、この要素の木と Css の上に書く。
- 障害:★ の記述面が lustre / sketch_lustre の型と関数を直に使い(`el.Element` は `sketch/lustre/element.Element` の別名)、yumemi の記述面が上流の版と方針(AI の書いた issue を断る、lustre #498)に縛られる
- 障害:面の写しが `Color` を `String` に落とし、生成の loader が `raw_css.property` で escape の無い `<style>` へ素で入れる。安全が app の Spec 1 行に乗っている(74 (b))
- 障害:`shell.stylesheets` が生成物(`[data-yumemi-*]`・生成クラス名)を名指して上書きでき、生成器の出力の形を変えると黙って外れる
- 障害:島の Style を JS(`island_style.mjs`)が shadow root の中へ出し、文書の stylesheet も lustre が各島へ写している

## 現在地(段 A の merge 後の main。置き場は Y1 の移設のとおり `src/yumemi/` と `src/yumemi/gen/`、fixture は段 A の置き場)
- `yumemi/front/el` は sketch_lustre の element の別名と `text`・`img`・`each`・`opener`・`closer`・`badge`・`each_modal`(152 行)。タグは ★ が `sketch/lustre/element/html` を、属性は `lustre/attribute` を直に呼ぶ
- 生成器の禁則は `attribute.class`・`attribute.style`・`element.element` の直呼びと `lustre/internals` の import だけで、`attribute.attribute("style", ..)` は抜ける(0.11.15 の `reader/front.gleam:3598-3608`)
- Css の色は `String` の素通し、`Interaction` は 6 値、`Animation` は `@keyframes` がどこにも無く書いても効かない
- 頁の色は、生成器が app の型を型名 `"PageTheme"` の文字で拾い、`--bg` ほか 4 本を `raw_css.property` に素通しする(`emit/front.gleam` の `theme_global_text` ほか)。地の画像は app の `media.url(.., media.W1600)` を焼く
- 島は `lustre.register` の custom element で、shadow root の中に描き、`island_style.mjs` が島ごとの sketch の stylesheet を `<style>` に出す。生成の live module は lustre の effect で fetch する
- fixture の ★ で lustre を import する file は 37(生成物を除く)、うち島は article の public の 4 本。`shell.stylesheets` を持つ fixture は無い。`PageTheme` は article の back の `article_read` にある

## どこまで
1. **要素の木を自前で持つ。**`yumemi/front/el`(`Element`・`Attribute` は opaque で型引数なし)、`yumemi/front/html`(musearch の ★ が使う 53 種と殻の部品、class を取る形と `_` の形の 2 本ずつ、`style`・`script`・`link` は置かない)、`yumemi/front/attr`(型付き属性と `data`・`aria`・`role`。名前を自由に渡す口・`class`・`style`・`on*` は置かない)と文字列化。形は 78 の試作と 51 v6、名前と引数の順は sketch_lustre / lustre に揃える。細目 3 つは 70 の鷹野の How のとおり ── 値から作る属性名の不正は panic せず落とす、raw text の `</`・`<!--` は無害化、同名の属性は後勝ちで 1 つ。`attr.href`・`attr.src` は scheme が http・https・mailto・tel か相対でなければ出さない
2. **生成物の SSR から lustre を外す。**load・shell・Block リスト・骨組みの生成物は yumemi の el で描き、殻の文書の文字列化も自前。Block の Style の SSR の `<style>` も自前の木で出す
3. **★ に lustre を import させない。**第 1〜3・7・8 条。例外は 0.11 の形の interactive Component(`pub fn app` を持つ module)と生成の live module だけで、段 C の Y3 で消す一時の口と名で分かる形にし、例外にした数を診断に出す(下の「鷹野に返す点」1)
4. **Css の語彙。**色の欄を `Paint`(`Hex`・`Token`・`Theme`・`Mix`・`Transparent`・`CurrentColor`)に閉じる。`TextAlign`、`BorderEdge` の `TopEdge`、`Interaction` に `Waiting`・`Succeeded`・`Failed`(`:state(waiting)`・`:state(ok)`・`:state(error)`)と `ThemeImage`(framework が地の画像のある頁の body に立てる `data-yumemi-theme-image`)を足す。`:state()` の規則は `@supports selector(:state(x))` の中と、その外の属性(`[data-yumemi-state~=..]`)の 2 通りで出す。`Animation` は消す。第 23〜25 条
5. **interactive Component の Style の Css 側。**島の Style の const を Block と同じく生成器が集め、SSR の `<style>` と `_yumemi/style.css` に出す。JS が style を出す仕事(`island_style.mjs`・shadow root への写し)を 0 にするのは、client の bundle で描く class 名と SSR の CSS の class 名が一致すると Chromium で示せた場合だけ本便でやる。示せなければ Y3 に残し、results に理由を書く(78「sketch の class 名が bundle で変わる」が当たる見込み。下の「鷹野に返す点」2)
6. **頁の色と色の Type。**`yumemi/front/color.Color`(`#rrggbb` だけを parse する opaque、出力は r・g・b の数から組み直す、decoder、Spec と codec は `Blob` と同じく framework の値の型)、`yumemi/front/theme.PageTheme`(地・地の画像・字・差し色の 4 値)、`theme.Defaults`(Shell の既定)。生成器は Out の欄を型 `theme.PageTheme` で探し、面の写し(`src/gen/out/*`)は `Color`・`Blob`・`PageTheme` を `String` に落とさない。出力は body の `--yumemi-theme-bg`・`--yumemi-theme-bg-image`・`--yumemi-theme-text`・`--yumemi-theme-accent` で、★ は `css.Theme(..)` で読む。第 26・27 条。地の画像の URL の組み方は今の形のまま(`gen/media` は Y5、つなぐのは段 C)
7. **生の CSS の逃げ道。**`shell.stylesheets` と、Block から読む `el.stylesheet(el.static_sheet(path))` を許し、生成物の名指し(`[data-yumemi-`・`.css-<16 進 8 桁>`・`yumemi-` で始まる要素名)と `@import` を止め、置いた規則の数を数える。第 28〜31 条。数えは exit 0 の警告で面ごとに 1 行、`_diagnostics.txt` にも同じ数(escape と数える口の送り先の数は他の便。1 行への統合は段 C)
8. fixture の ★ を新しい語に書き換え、`shell.stylesheets` と `el.stylesheet` を使う fixture を足す。README の front の節(要素の木・Css・頁の色・生の CSS)を現物に直す

## 持ち場(並行の便との切り分け。全体は 81)
- **本便の file:**`src/yumemi/front/` の `el`・`html`(新)・`attr`(新)・`css`・`sketch_css`・`color`(新)・`theme`(新)・`island_style.mjs`、`src/yumemi/front.gleam`、`gleam.toml` の依存と `manifest.toml`、生成器の `reader/front.gleam`、`emit/codec.gleam` と `emit/typing.gleam`(`Color` を framework の値の型にする分だけ)
- **`emit/front.gleam` の中で本便が持つ所:**SSR(`page_view_text`・`page_render_text`・`shell_head_text`・Area と placement の text・`rows_helper_text`・load と layout の import)、Block リストと骨組み、`shell_runtime_text` の文字列化と `<style>`、CSS(`style_text` から `static_area_rule` まで、`badge_css`・`anchored_overlay_*`)、頁の色(`page_theme_service`〜`theme_paths`、`theme_source`〜`option_background_text`)、面の写し(`out_file` から後の decoder と型の収集)、`client_text` の `island_style` の import と `client_registration`
- **触らない:**`src/yumemi/front/navigate.mjs` と、`emit/front.gleam` の `navigation` と `client_text` の遷移の行(Y4)。`src/yumemi/gate.gleam`・`require.gleam`・`server.gleam`・`entry.gleam`・`server/*.mjs`、生成器の `reader/gate.gleam`・`reader/server.gleam`・`emit/gate.gleam`・`emit/entry.gleam`・`emit/sql.gleam`、`emit/front.gleam` の `gate_file`〜`gate_notes` と `emit` の client.mjs を出す条件(Y5)。`src/yumemi/front/live.gleam` と生成の live module の中身(Y3)
- `emit/front.gleam` の 403・404 の文言 2 行(0.11.15 の 6781・6783 行)は Y5 が替える。`shell_runtime_text` を組み替えても、この 2 行の字は動かさない
- `emit/http.gleam` は Y5 が申告と同意で書き換える。`Color` のために触るなら関数を分け、Y5 の所と同じ行を動かさない
- 既存の test は SSR と CSS の出力を見るものと、`yumemi_fix_0114_test` の `island_renders_sketch_class_under_stylesheet_test`(島の style を外さないなら触らない)。同じ file のほかの関数は Y4・Y5
- fixture の ★ は Block・Layout・Page・style・shell・components を本便が書き換える。門(`src/gate.gleam`)と back の `server.gleam`・Service の `requires` は触らない(Y5)
- 生成物(fixture の `src/gen/`・`priv/static/_yumemi/`・`_diagnostics.txt`)の衝突は、merge のとき鷹野が ours で取って生成し直す。手で解く前提の書き方をしない

## しないこと
interactive Component の runtime(form と custom state への写し)・view の形(`view(Args)`)・`gen/islands` の改名・`live.gleam` の After と `reloads`・update を書かせない検査・連鎖の検査・名前付きの FFI の逃げ道(段 C の Y3)。`el.Src` と `el.img` の src の型・`el.static_src`(第 43 条)・`el.dialog` の 3 つ・`el.notice`(段 C の継ぎ目)。navigate.mjs(Y4)。門・申告・同意・数える口・CSP・media・失敗の文言(Y5)。`@scope`・anchor の語の拡張・74 の 9 語の残り。musearch の source(写しだけ)。版の行・tag・publish・push。

## 失敗例(差し戻し)
- ★ の fixture が lustre を import したまま通る。第 1 条の例外が `pub fn app` の module と生成の live の外へ広がる
- 不正な属性名・`</style>` を含む raw text・`javascript:` の href で頁が 500 になる、またはそのまま出る
- 面の写しに `pub type Color = String` が残る。parse を通さずに `String` から `Color` を作る公開の口がある
- 生成物を名指す規則を `shell.stylesheets` に置いても止まらない。規則の数え方が file ごとにぶれる(`@media` は 1 塊)
- 島の class 名が SSR の CSS と食い違ったまま `island_style.mjs` を消し、fixture の島の見た目が崩れる
- 書き換えで変わった test の期待値を、理由を書かずに直す。落ちた test を消して本数を合わせる
- Y4・Y5 の持ち場の file・行を触る

## 検収
- root `gleam test` が通り、本数は基点から減っていない(before / after を results に。期待値を書き換えた test は名と理由を列で)。`gleam format --check` 0
- fixture の全面を生成して停止コード 0・2 回目の差 0
- **出力の突き合わせ:**基点と本作業木で fixture の全 Page を描き、Chromium に読ませた head・body の DOM(comment を除き、生成クラス名を出現順の番号に替えたもの)を比べる。違いは全部 results に挙げ、78 の 5 種(Fragment の印・同名の属性・textarea と pre の先頭の改行・raw text・名前の検査)か本便の意図(テーマの custom property の名・`data-yumemi-theme-image` ほか)で説明できること
- **細目と柵:**不正な属性名は落ちる、raw text の `</style><script>` で script 要素ができない(Chromium)、同名の属性は 1 つ、`javascript:` の href は出ない、`color.parse("#fff;}</style>")` は Error
- **`:state()`:**出力に 2 通りの規則があり、test の中で `ElementInternals.states` を立てる小さな custom element で、Chromium の見た目が替わる
- 第 1〜3・7・8・23〜31 条の 1 条ずつに、止まる fixture か test が 1 つ以上あり、停止コードが 51 v6 の値
- **interactive Component:**fixture の島 4 本が今と同じに動く(送り・結果の表示)。本便で shadow root と `island_style.mjs` を外したなら、島に `shadowRoot` が無く、島の中の要素の class が全部文書の規則に当たる(Chromium)
- `gleam export hex-tarball` の依存の列を results に(lustre・sketch_lustre が残るなら理由)
- **musearch の写しで数えるだけ:**origin/main(`~/yumemism_repo/musearch`)を `.scratch/musearch` に置き、Y1 と同じ名前の置き換えだけをして本作業木の生成器を当て、止まる条文ごとの件数を results に(止まるのが期待どおり。段 D の書き換え量の材料)。写しは捨てる

## 鷹野の裁き(2026-10-12)
1. 0.11 の lustre の interactive Component とは段 C まで共存させる。lustre は Y3 まで内部の依存に残し、第 1・2 条は `pub fn app` を持つ module と生成の live module だけを例外にし、例外の数を診断に出す。test は消さない
2. shadow root と `island_style.mjs` は、SSR と client の class 名の一致を示せたら本便で外す。示せなければ Y3 で外し、results に食い違いの事実を書く
3. 止め線は経過 2 時間 30 分
4. 段 B の 3 便の merge 順は Y2 → Y4 → Y5(Y2 が遅れたら Y4 を先に)。どの便も単独で閉じられない継ぎ目 7 つ(`el.Src` と `gen/media.src`、地の画像の URL、route の照合の共有、逃げ道の数えの統合、`boot` を外す、共存の外し、`el.dialog`)は段 C の Y3 に「段 B の継ぎ目」として載せる。
