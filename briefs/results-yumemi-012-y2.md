# results ── yumemi-012-y2(0.12 段 B、要素の木を自前で持ち ★ から lustre を外す、Css の語彙と頁の色の型、生の CSS の逃げ道、真壁 r1)

基点 `31db577`(BRIEF の commit、段 A の merge `087b2d8` の上)。branch `impl/012-y2`。証跡は `build/012-y2-*`(git の外)。版の行(`0.12.0-dev`)は触っていない。

## やったこと

1. **要素の木**(`src/yumemi/front/el.gleam`・`html.gleam`(新)・`attr.gleam`(新))。78 の試作を元にした。
   - `el.Element` / `el.Attribute` は opaque で型引数なし(構成子 `Node`・`Text`・`RawText`・`Fragment` / `Attribute`・`NoAttribute`)。公開は `text`・`fragment`・`none`・`each`・`to_string`・`opener`・`closer`・`badge`・`each_modal`・`img(class, attrs)`・`stylesheet`・`static_sheet`・`legacy_island`。`element`・`namespaced`・`raw_text`・`attribute`・`no_attribute`・`class_attribute`・`styled`・`to_document_string`・`escape` は `@internal`
   - `html`:musearch の 53 種と `svg`・`svg_`・`path(d)`(SVG の名前空間)、殻の部品(`html`・`head`・`body`・`body_`・`meta`・`title`、`@internal`)。class を取る形と `_` の 2 本ずつ、名前と引数の順は sketch_lustre と同じ。`style`・`script`・`link` は無い
   - `attr`:試作の型付き属性 37 種+`label`・`scope`・`minlength`・`maxlength`・SVG の 4 つ、`data`・`aria`・`role(Role)`・`none`。`class`・`style`・`on*`・名前を自由に渡す口は無い
   - 細目 3 つ(70 の鷹野の How):`data` / `aria` の名が `[a-z][a-z0-9-]*` でなければ `NoAttribute`(panic しない)/生成物の `<style>` の中身は `</`→`<\/`・`<!--`→`<\!--`/同名の属性は後勝ちで 1 つ(並べ替えの安定に頼らず、後ろから初出だけ残してから名前順。class だけは値をつなぐ)
   - `attr.href` / `attr.src` は、HTML の URL の parser が捨てる空白・タブ・改行を除いた値で、scheme が `http`・`https`・`mailto`・`tel` か無い(最初の `:` の前に `/`・`?`・`#` がある相対を含む)ときだけ出す
   - 文字列化は試作のまま(doctype・void 14 種・`xmlns` は根に 1 回・5 文字の escape・名前順・textarea / pre / listing の先頭の改行、Fragment の印を出さない)
   - Class:`css.class(styles) -> css.Class`(opaque、中身は Style の列)。class 名は要素を作るとき `sketch_css.class_name` が、いま集めている sketch の stylesheet(`sheet_ffi.mjs` の変数 1 つ、sketch_lustre の global の代わり)に規則を足して得る。`el.styled(body, extra_css)` が頁の body を描く間の class を集め、body の先頭の `<style>`(`RawText`)に出す
2. **生成物の SSR から lustre を外した**(`emit/front.gleam` の持ち場、`emit/static.gleam` と `markdown.gleam` の docs)。load の `render`・`view`・Area / placement の helper・rows の helper・Block リスト(`blocks_preview`)・骨組み(`skeleton`)・docs(`doc/api_v1`)を yumemi の `el` / `html` / `css.class` で描く。殻の文書の文字列化は `shell.mjs` が `yumemi/front/el.mjs` の `to_document_string` を import する(lustre の `element.mjs` を見ない)。Shell の head の要素は `el.element("link" | "meta", ..)`
3. **★ に lustre を import させない**(`reader/front.gleam`)。第 1 条(★ の `lustre`・`lustre/*`・`sketch/lustre`・`sketch/lustre/*` の import、exit 4)、第 3 条(yumemi の `@internal` の口の参照、exit 4)。例外は **0.11 の形の interactive Component**(`components/` で `pub fn app` を持つ module、`is_legacy_component`)だけ。生成の live module は `src/gen/` の中なので検査の外。例外の数を面ごとに 1 行の警告(exit 0)で出す:`public: 第 1・2 条の例外(0.11 の lustre の interactive Component、段 C の Y3 で消す): 4 module (..)`。0.11.15 の禁則 4 種(`attribute.class`・`attribute.style`・`element.element` の直呼びと `lustre/internals` の import)は 51 v6 のとおり第 1 条に吸収して消した。Block から 0.11 の島を置く一時の口は `el.legacy_island(tag, [#(name, value)])`(名で段 C に消すと分かる形、タグ名が custom element の名でなければ何も出さず、引数の名の不正・`on*`・`style`・`class`・`srcdoc` は落とす)。第 2 条(面の `gleam.toml` の `[dependencies]` に `lustre` / `sketch_lustre`、exit 4)は例外の module を持つ面では止めない
4. **Css の語彙**(`css.gleam`・`sketch_css.gleam`)。色の欄は `Paint`(`Hex`・`Token`・`Theme(ThemeSlot)`・`Mix(a, b, percent)`・`Transparent`・`CurrentColor`)。形の合わない `Hex`・`Token` は `unset`、`Mix` の percent は 0〜100 に寄せる。`TextAlign(TextStart / TextCenter / TextEnd)`、`BorderEdge` の `TopEdge`。`Interaction` に `Waiting`・`Succeeded`・`Failed`(祖先の custom state、`.css-…:is(:state(waiting) *)`)と `ThemeImage`(`.css-…:is([data-yumemi-theme-image] *)`)。`:state()` は `@supports selector(:state(x))` の中と `@supports not selector(:state(x))` の中(`[data-yumemi-state~="x"]`)の 2 通り。`Responsive` の中では sketch が media の中の at-rule を落とすので、`@supports` で包まずに 2 通りの選択子を並べる。`Animation` は消した。第 23・24・25 条は literal を reader が見て exit 4
5. **interactive Component の Style の Css 側は Y3 に残した。**理由は下の「島の Style を本便で外さなかった理由」。`island_style.mjs` と shadow root はそのまま(`client_text` の import と `client_registration` も触っていない)
6. **頁の色と色の Type**。`yumemi/front/color.Color`(opaque、`parse` は `#` と 16 進 6 桁だけ、r・g・b の数から `#rrggbb` の小文字を組み直して 1 欄に持つ ── 1 欄なので back の JSON の写し `codec.encode` で字のまま出る、`blob.Blob` と同じ形)、`to_css`・`to_string`・`decoder`。`yumemi/front/theme`:`PageTheme`(4 値)・`Defaults`・`decoder`、`@internal` の `body_rule`・`has_image`
   - 生成器は Out の欄を `yumemi/front/theme.PageTheme` の型で探す(`resolved_path` が `yumemi/front/theme` で型名が `PageTheme`、型名の字だけの一致は拾わない)。`theme: Some(name)` の Page の source のどれにも無ければ第 27 条で exit 4
   - 面の写し(`src/gen/out/*`):`PageTheme` と `Color` は `import yumemi/front/theme.{type PageTheme, decoder as page_theme_decoder}` / `yumemi/front/color.{type Color, decoder as color_decoder}` で yumemi の型のまま(`Blob` は前から `yumemi/blob`)。back の `gen/codec.mjs` は `Color` を `checked(color.parse(String(v)))` で読む
   - 出力:body の `--yumemi-theme-bg`・`--yumemi-theme-bg-image`・`--yumemi-theme-text`・`--yumemi-theme-accent`(頁の `<style>` の末尾、`theme.body_rule`)。地の画像は今の形のまま app の `media.url(blob, media.W1600)` で URL を組み、`url("..")` の CSS の文字列は `\`・`"`・改行を escape する。地の画像のある頁は body に `data-yumemi-theme-image`。Shell は `pub const theme: theme.Defaults`(第 26 条:3 色が `#rrggbb` の literal でなければ exit 4、地の画像の path が `priv/static` に無ければ exit 3)。badge の CSS の `var(--bg)` / `var(--accent)` も新しい名へ
   - Block リストの既定値に `Color`(`#000000`)と `PageTheme`(全部 `None`)を足した
7. **生の CSS の逃げ道**(`emit/front.gleam` の `surface_notes`、検査と数えは新しい `yumemi/gen/raw_css.gleam`)。`shell.stylesheets` と `el.stylesheet(el.static_sheet(path))` の file を読み、第 28 条(file が `priv/static/` に無い、exit 3)、第 29 条(選択子に `[data-yumemi-`・`.css-` + 16 進 8 桁・`yumemi-` で始まる要素名、exit 4)、第 30 条(`@import`、exit 4)、第 31 条(`static_sheet` の path が literal でない、exit 4、reader)。規則は comment と文字列を除いて最上位の塊ごとに 1 つ(`@media` の塊も 1 つ)で数え、面ごとに 1 行の警告(exit 0):`public: 生の CSS の逃げ道 2 file(shell.stylesheets 1・el.static_sheet 1)、規則 4`。`_diagnostics.txt` にも同じ行が出る。`gen.gleam` には警告の呼び出しを 1 行(`front_emit.surface_notes(..)`)だけ足した(81 の取り決めどおり)
8. **fixture と README**。article の public・admin の Block・Layout・style・shell を新しい語に(`css.Color(css.Hex(..))`、`css.class`、`attr.data`、`el.legacy_island`、`theme.Defaults`)。0.11 の島 4 本は `import sketch/lustre/element as el` に替えて lustre のまま(例外)。back の `service/article_read` の `PageTheme` を `theme.PageTheme` に。足したもの:public の `media.gleam`(`W1600` と `url`)、`shell.stylesheets = ["/fixture.css"]` と `priv/static/fixture.css`、Notice Block の `el.stylesheet(el.static_sheet("article_font.css"))` と `priv/static/article_font.css`。admin の `gleam.toml` から `lustre`・`sketch_lustre` を外した(島が無いので第 2 条に掛かる)。README に「Elements and attributes (0.12)」「The raw-CSS escape」を足し、Shell・Page theme・Style の節を現物に直した

## 検収

### test(before / after)
- before(基点):`Framework checks passed: 25 groups`・`345 passed, no failures`(`build/012-y2-before-test.txt`)
- after:`Framework checks passed: 25 groups`・`368 passed, no failures`(`build/012-y2-after-test.txt`)。345 + 新しい `test/yumemi_012_y2_test.gleam` の 23 本。消した test は無い
- `gleam format --check src test`:0
- **期待値を書き換えた test**(理由はどれも本便の意図の変更)

| test | 理由 |
|---|---|
| `yumemi_test`:`look_background_border_and_outline_render_to_css`・`look_styles_work_inside_state_and_responsive`・`look_styles_reach_island_shadow_style`・`v0119_current_state_renders_aria_current_selector`・`v01114_focus_visible_and_hover_capable_render_to_css` ほか Css の色を書く所 | 色の欄が `Paint` になった(`"var(--x)"` → `css.Token("x")`、`"red"` 等の色名 → `css.Hex("#ff0000")` 等)。`color-mix(in srgb, #000 50%, #fff)` の期待は `css.Mix` の出力 `color-mix(in oklab, #000000 50%, #ffffff)` に。色の字が変わった規則の class 名の hash(`.css-…`)は実測の値に(`Hover`・`Focus`・`Disabled`・`Current`・`FocusVisible`・`HoverCapable` の 6 つ)。`assert_equal` / `assert_contains` は落ちたときに label と実値を出すようにした(判定は同じ) |
| `yumemi_test`:`area_overlay_controls_share_the_area_id`・`badge_counts_keep_the_same_dom_shape`・`each_modals_use_stable_scoped_ids` | lustre の `element.to_string` / `fragment` を `el.to_string` / `el.fragment` に(期待の字は同じ、Fragment の印が無いので each_modal の比較も同じ字で通る) |
| `yumemi_gen_test.a_clean_app_has_no_notes_test`・`yumemi_s1_test.missing_root_sql_stops_generation_test`・`port_service_without_root_sql_is_not_stopped_test` | fixture が本便の警告 2 行(第 1・2 条の例外の数、生の CSS の規則の数、どちらも exit 0)を出すようになった。`without_stage_b_counts` でその 2 種だけを外して見る(停止コードの判定は同じ) |
| `every_file_carries_the_generated_header_test` | 警告で `_diagnostics.txt` が書かれるようになった。生成した source でない報告なので頭の検査から外す |
| `direct_attribute_class_is_exit_four_test`・`lustre_internal_import_is_exit_four_test` | 0.11.15 の lustre の禁則は第 1 条に吸収(51 v6)。exit 4 は同じで、文言が「第 1 条」に |
| `present_shell_missing_theme_field_is_exit_three_test` | fixture の Shell が `theme.Defaults(.., background_image: None)` になった。外す行の字を合わせた |
| `front_emit_shell_carries_language_title_and_theme_test`・`front_emit_shell_includes_viewport_meta_test`・`front_emit_shell_head_consts_render_in_head_test`・`front_emit_shell_stylesheets_render_in_head_test`・`front_emit_shell_without_head_consts_is_unchanged_test` | 生成の load が `raw_html.*` / `attribute.attribute` から `html.*` / `el.element` / `el.attribute` に。既定の色は `option_string(..)` から `theme_defaults()` の `theme.Defaults(..)` に。fixture が `stylesheets` を持つので、`shell_with_head` は足す前に fixture の `stylesheets` を外す(`without_head_consts` は外した Shell で見る) |
| `front_emit_blocks_preview_places_layout_blocks_by_area_test`・`front_emit_frame_without_style_keeps_plain_grid_test`・`front_emit_overlay_area_and_badge_use_generator_css_test`・`front_emit_page_styled_frame_makes_page_grid_test`・`front_emit_styled_frame_grid_style_test` | 生成の字が `attribute.attribute(` → `el.attribute(`、`sketch_css.class(` → `css.class(` |
| `front_emit_blob_theme_wraps_image_in_quoted_css_url_test` | 地の画像の `url("..")` は生成物の字でなく `theme.body_rule` が組む。生成物は `media.url(value, media.W1600)` を、quote と escape は `body_rule` の出力(`url("/media/a\"b")`)を見る |
| `front_emit_page_theme_follows_out_path_test`(helper `synthetic_front_files_with_nested_theme`) | fixture の Out が `Option(theme.PageTheme)` に。Data の欄は `Option(theme.PageTheme)`、既定は `theme.Defaults` の行を見る。shell.mjs の theme の path(`look` → `theme`)と実行時の取り出しは同じ期待のまま通る |
| `static_material_copy_keeps_front_four_names_and_markdown_structure_test` | docs の生成物の型が `List(el.Element)` に |

### fixture の生成
- 本作業木の生成器で `gleam run -m yumemi/gen -- gen/fixtures/article gen/fixtures/article`:停止コード 0、`書いた: 96 ファイル`、警告 2 行(上の 1・7)。2 回目も停止コード 0、`git status` の差 0(`build/012-y2-gen1.txt`・`build/012-y2-gen2.txt`)
- 面と back の `gleam build`(public・admin・article):error 0
- 基点の commit 済みの fixture の生成物は段 A の名前替えの後で生成し直されておらず、基点の生成器で回すだけで 64 file が変わった(頭の sha と import の並び)。基点の出力は `.scratch/base` に生成し直したものを使った

### 出力の突き合わせ(Chromium)
- 基点(`.scratch/base`、基点の生成器で fixture を生成し直したもの)と本作業木で、fixture の全 Page(public の `/status`・`/article/:slug`、admin の `/`)を sample の Out で描き、`/article/:slug` は頁の色ありでも描いた(4 文書)。描き方は `.scratch/tools/render-pages.mjs`、比べ方は `.scratch/tools/dom-compare.mjs`(playwright 1.63 の Chromium、comment を除き、生成クラス名を出現順の番号に替えた head・body の outerHTML)
- **生成クラス名の hash は 4 文書とも基点と同じ**(Paint から組んだ色の字が基点の字と同じなので、sketch の hash が変わらない)
- 違いの全部(`build/012-y2-dom-diff.txt`、43 行)
  1. 頁の色の custom property の名(本便の意図):`--bg` / `--bg-image` / `--text` / `--accent` → `--yumemi-theme-*`(4 文書)
  2. 色の字が小文字(本便の意図、`color.Color` が r・g・b から組み直す):`#FAF7F0` → `#faf7f0` ほか
  3. 地の画像(本便の意図):`--bg-image: blob-key`(基点は Blob でない String を素通し)→ `url("/media/w1600/blob-key")`、body に `data-yumemi-theme-image=""`(頁の色ありの 1 文書)
  4. fixture に足した生の CSS の逃げ道(本便の意図):head の `<link href="/fixture.css" rel="stylesheet">`(public の 3 文書)、Notice Block の `<link href="/article_font.css" rel="stylesheet">`(`/article/:slug` の 2 文書)
  5. Fragment の印(78 の 1):基点の文字列は各文書に `<!-- lustre:fragment -->` の 1 組(body の `<style>` と本文の包み)、本作業木は 0。comment を除いた DOM では同じ
- script 要素は 4 文書とも基点 0・本作業木 0

### 細目と柵(Chromium、`build/012-y2-chromium.txt`、`.scratch/tools/chromium-checks.mjs`)
- raw text:生成物の `<style>` に `a{}</style><script>window.pwned=1</script><style>` を入れた文書で、script 要素 0・style 要素 1・`window.pwned` null
- 不正な属性名(`data-x" onfocus="alert(1)`)は落ち、同名の `id` は後の `b` だけ:div の属性 `[id=b]`
- `javascript:` の href:`a` に href が無い
- `color.parse("#fff;}</style>")` は `Error(Nil)`(test `color_parses_only_six_hex_digits_test`)
- gleam の test でも同じ 4 つと URL の柵(`JaVaScript:`・先頭の空白・途中のタブ・`data:`・`vbscript:` を落とし、http・https・mailto・tel・`/relative`・`page.html`・`#top`・`?q=a:b`・`./a:b` を通す)

### `:state()`
- 出力に 2 通りの規則:`@supports selector(:state(waiting)) { .css-…:is(:state(waiting) *) {..} }` と `@supports not selector(:state(waiting)) { .css-…:is([data-yumemi-state~="waiting"] *) {..} }`(test `component_states_render_two_ways_test`)
- Chromium:`ElementInternals.states` を立てる小さな custom element(`probe-box`)の中の span の色が、初め `rgb(0, 0, 0)` → `states.add("waiting")` で `rgb(255, 0, 0)` → `waiting` を外して `error` で `rgb(0, 0, 255)`。`CSS.supports("selector(:state(waiting))")` は true で、属性の写しの規則(`@supports not` の中)は当たらない(`rgb(0, 0, 0)`)── `:state()` の無い browser での属性の側は Chromium では見られない

### 条文の止まり方(`test/yumemi_012_y2_test.gleam`)
| 条 | test | 停止コード |
|---|---|---|
| 1 | `article_1_lustre_import_stops_outside_legacy_components_test`(Block の `lustre/attribute`・`sketch/lustre/element/html` で 2 件。fixture の島 4 本は止まらず、警告の数が 4) | 4(例外の数は 0) |
| 2 | `article_2_lustre_dependency_stops_without_legacy_components_test`(島を外した面の `gleam.toml` に `lustre・sketch_lustre`。島のある面は止めない) | 4 |
| 3 | `article_3_internal_calls_stop_test`(`el.attribute`) | 4 |
| 7 | `article_7_literal_data_name_stops_test`(`attr.data("Bad_Name", ..)`、`good-name` は止めない) | 4 |
| 8 | `article_8_static_duplicate_attribute_stops_test`(`id` 2 つと `data-k` 2 つ、名の違う data は止めない) | 4 |
| 23・24・25 | `article_23_to_25_css_literals_stop_test`(`Hex("#fff")`・`Token("Bad_Token")`・`Mix(.., 120)`、正しい literal は止めない) | 4 |
| 26 | `article_26_shell_theme_literals_test`(`background: "red"` は 4、`Some("bg/missing.png")` は 3、在る path は止めない) | 4 / 3 |
| 27 | `article_27_page_theme_must_be_the_framework_type_test`(Out の theme を app の `PageTheme` にすると拾わない) | 4 |
| 28・29・30 | `article_28_to_30_raw_css_files_test`(無い file は 3、`[data-yumemi-area=..]`・`@media` の中の `.css-1A2B3C4D`・`main > yumemi-escape` の 3 件は 4、`@import` は 4。島のタグ名と `:state()`、`var(--yumemi-theme-bg)` は止めない) | 3 / 4 |
| 31 | `article_31_static_sheet_path_must_be_literal_test` | 4 |
| 数え | `fixture_surface_counts_rules_once_per_face_test`(面に 1 行)、`raw_css_rules_are_counted_by_top_level_block_test`(comment の中の `{ }`・文字列の中の `}` を数えず、`@media` を 1) | 0 |

### interactive Component
- fixture の島 4 本を、基点と本作業木の `/article/:slug` の文書に client.mjs を足して Chromium で動かした(API は playwright の route で模す、`.scratch/tools/islands.mjs`)。出力は基点と 1 行も違わない(`build/012-y2-islands-{base,new}.txt`)
  - like-button:`<button>いいね</button>` → 押すと `POST /api/articles/article/publish` が 1 回出て `<button>❤ 7</button>`
  - blob-save・article-blob-copy:shadow の中の form(file の input・button・状態の文言)が基点と同じ
  - pick-tag:基点・本作業木とも未定義(given の島で、shell.mjs が出す given の値を、この比べ方では渡していない)
  - console の error:どちらも 0
- client.mjs の差:変数名を正規化して比べると、違いは `Animation` の構成子と旧 `el.text` の別名が消えたことと、`css` の新しい構成子(`TopEdge`・`Waiting` ほか)・`sketch_css` の新しい関数が増えたことだけ(`build/012-y2-client-diff.txt`)。島の runtime の字は同じ
- shadow root と `island_style.mjs` は外していない(下)

### 島の Style を本便で外さなかった理由(鷹野の裁き 2 → Y3)
同じ Style の列から作る class 名を 3 つの場所で比べた(`build/012-y2-classname.txt`、色 `#123456`・padding 8px)。
- node(gleam の dev build):SSR の道(`css.class` → `sketch_css.class_name`)も島の道(`sketch_css.class` → `sketch.class_name`)も `css-E84CDA3F`
- esbuild の bundle に lustre と sketch_lustre を入れたもの(島の client.mjs と同じ形、minify なし):`css-336AF8E8`
- 同じ bundle を minify:`css-B529F394`
- lustre を入れない bundle:minify なしは `css-E84CDA3F`(dev と同じ)、minify は `css-550A2374`

sketch は class 名を Style の `string.inspect` の hash で作り、`inspect` は JS の constructor の名を使うので、bundle の中で constructor が改名されると(lustre の `Property` との衝突、minify)名が変わる(78 の「sketch の class 名が bundle で変わる」が当たった)。島の client.mjs は lustre を含むので、生成器(node)で集めた CSS の class 名と島が client で描く class 名は一致しない。一致を示せないので、`island_style.mjs` と shadow root は Y3 に残した。Y3 への引き継ぎ:class 名を constructor の名に依らない形(css.Style を yumemi が自分で文字列にしてから hash する)に替えないと、light DOM の島も、生成時に作る `_yumemi/style.css` の島の規則も合わない。SSR の頁の `<style>` は、同じ bundle の中で class 名と CSS を同時に作るので今も合う

### Hex の tarball
- `gleam export hex-tarball`:requirements 8 つ ── argv・glance・gleam_stdlib・glexer・**lustre**・simplifile・sketch・**sketch_lustre**(`build/012-y2-tarball-deps.txt`)。`src/yumemi/front/` の file:el・html・attr・css・sketch_css・color・theme・track・live・sheet_ffi.mjs・navigate.mjs・island_style.mjs
- lustre と sketch_lustre が残る理由:0.11 の形の interactive Component(段 C の Y3 まで共存、鷹野の裁き 1)── `island_style.mjs` が sketch_lustre と lustre の module を import し、生成器が書く live module と client.mjs の島の登録が lustre を使い、島の ★ が `sketch_css.class`(sketch の Class)と sketch_lustre の html を使う。yumemi の Gleam の module で lustre を import するものは無い(`grep` で `island_style.mjs` だけ)

### musearch の写しで数えた件数(`build/012-y2-ms-*`)
origin/main `1b0244412` を `git archive` で `.scratch/musearch` に置き、Y1 と同じ名前の置き換え(`.gleam` の `framework/<module>` → `yumemi/<module>`、JS の `yumemi/framework/` → `yumemi/yumemi/`、2286 file)と 5 package の `yumemi` を本作業木への path 依存に。本作業木の root から `gleam run -m yumemi/gen -- .scratch/musearch/api .scratch/musearch`:停止コード 4、`[exit` の行 386。写しは捨てた。

| 条 | admin | console | muses | www | 計 |
|---|---|---|---|---|---|
| 第 1 条(★ の lustre の import の行、exit 4) | 30(14 file) | 40(20 file) | 99(50 file) | 143(74 file) | 312(158 file) |
| 第 1・2 条の例外(0.11 の島、警告) | 13 module | 17 module | 67 module | 32 module | 129 module |
| 第 27 条(theme の Out が `theme.PageTheme` でない、exit 4) | 0 | 0 | 0 | 7 | 7 |
| 第 28 条(stylesheets の file が `priv/static` に無い、exit 3) | 0 | 3 | 3 | 1 | 7 |
| 第 29 条(生成物を名指す選択子、exit 4) | 0 | 0 | 0 | 8(`www.css`) | 8 |
| 生の CSS の規則(警告) | ── | 3 file・0 | 3 file・0 | 4 file・34 | |

- 第 28 条の 7 件は `/brand/tokens.css`・`/brand/faces.css`・`/fonts/ui.css` で、musearch では `.gitignore` の build 物(`console/priv/static/brand/`)。`git archive` の写しには無いので止まる。生成器を回す前に brand の build が要る
- 第 29 条の 8 件は 51 v6 の「www.css の生成物を名指す 7 塊」に当たる。本便は選択子の前置き(prelude)ごとに 1 件で数え、同じ塊が `@media` の中と外にあるもの・`,` で 2 つの選択子を持つものがあり 8
- 第 2・3・7・8・23〜25・30・31 条は 0。Css の色は生成器の条文でなく Gleam の型で止まる(写しは compile しない):`css.Color(` 106・`css.Background(` 126・`color: "` 128(`Border` / `Outline`)。ほかに `el.island(` 144(→ `el.legacy_island` か段 C の `gen/islands`)、`attribute.attribute("data-` 618(→ `attr.data`)、`attribute.attribute("style"` 41、`PageTheme` 12 行、`css.Animation(` 0
- 写しの compile と npm test は回していない(lustre の import で止まるのが期待どおりで、数えるだけの依頼)

## BRIEF・51 v6 との食い違いと選んだこと
- **`attr.Role` の値**:51 v6 の抜粋は `Status Alert Dialog Navigation Tab Tablist Tabpanel Button Link Img Presentation` だが、78 の試作と musearch の ★ の現物(`grep`:status 49・alert 21・button 2・group 2・toolbar・textbox・radiogroup・radio・listitem・list・dialog 各 1)は `Alert Button Dialog Group List Listitem Radio Radiogroup Status Textbox Toolbar` の 11 値。現物の 11 値にした
- **`el.img`**:51 v6 の `img(class, src: Src, alt, attrs)` と `el.static_src` は段 C の継ぎ目(BRIEF の「しないこと」)なので、`el.img(class, attributes)` のまま(src は `attr.src` の柵を通る)
- **`:state()` の属性の側**:BRIEF は「その外の属性」、51 v6 は「`@supports not selector(:state(x))` の中」。51 v6 の形にした(`:state()` のある browser で属性の規則が当たらない)
- **`html.textarea` / `option` の子**:sketch_lustre と同じく `List(Element)`(lustre 本体の `textarea(attrs, String)` ではない)
- **島を置く口**:51 v6 は `el.island` を無くし `gen/islands` に置くが、`gen/islands` は Y3。0.11 の島を Block から置く一時の口として `el.legacy_island(tag, List(#(String, String)))` を足した(★ に名前を自由に渡す属性の口を開けないため、引数は島の要素の上だけで名を検査する)
- **第 2 条の例外**:BRIEF の例外(`pub fn app` の module と生成の live)を、面の依存の検査では「例外の module を持つ面は止めない」と読んだ
- **頁の色の既定の字**:Shell の 3 色は生成器が literal を検査し、出力は `color.parse` を通した小文字(基点は字のまま)
- **`Color` の中身**:51 v6 は「出力は r・g・b の数から組み直す」。parse で数にしてから `#rrggbb` を組み直し、その字 1 欄を持つ(`Color(red, green, blue)` の 3 欄にすると back の generic な JSON の写しが `{red, green, blue}` を出して front の decoder と合わない)

## 確かめていないこと
- workerd の上の SSR(node と Chromium だけ)。島の SSR の bundle で class 名が dev と変わることは測ったが、SSR の Worker の bundle の中で頁の `<style>` と class 属性が一致することは、同じ実行の中で作る構造からの推測(Worker では回していない)
- `color.Color` を Service の **Args** に持つ形。`emit/http.gleam`(Y5 の持ち場)の Args の decode の語彙に `Color` を足していない。Args に Color がある Service は今の生成器では止まるか、decode できない(試していない)
- `color.Color` を Entity の Property に持つ形の back の読み(`gen/codec.mjs` の `color.parse` の行は足したが、fixture に Color の Property が無く、走らせていない)。Out に `PageTheme` と `Color` を直に持つ形は、fixture を一時に書き換えて生成・面の compile まで見た(Block の `pub const sample` は opaque な Color を持てないので、その間は sample を外した)
- `:state()` の無い browser での属性の側(Chromium は `:state()` を持つ)
- pick-tag(given の島)の動き(基点と同じく、この比べ方では定義されない)
- musearch の写しの compile と test
- `gen/scripts` の verify の各 script(段 A の前の置き場を見ているものがあり、回していない)

## 段 C(Y3)へ
- 島の Style を SSR の `<style>` と `_yumemi/style.css` に出し、`island_style.mjs` と shadow root を外すこと。先に class 名を constructor の名に依らない hash にする(上の理由)
- `el.legacy_island`・`sketch_css.class`・`is_legacy_component`(第 1・2 条の例外)を消すこと
- 81 の継ぎ目:`el.Src` と `gen/media.src`、地の画像の URL(今は app の `media.url(.., media.W1600)` を焼く)、逃げ道の数えの統合(今は面ごとに 1 行)

## DDL

無し
