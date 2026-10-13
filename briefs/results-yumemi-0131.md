# results yumemi-0131 ── 0.13.1:実行時の Markdown の Component と 6 つの穴

便: yumemi-0131 / 基点: `1eb718c`(v0.13.0)/ 真壁[IM] r1 / 2026-10-13
証拠のパス:`build/0131-*.txt`(作業木の `build/`、git の外)、突き合わせの道具は `.scratch/{cmp-ab,cmp-c,ms-base,ms-new,docsite}`(同じく git の外)。版の行(`gleam.toml` の 0.13.0)は替えていない。

## 1〜6 の充足

| # | どこまで | 結果 | 証拠 |
|---|---|---|---|
| 1 | 実行時の Markdown を読んで描く Component・読みの木の公開 | `yumemi/front/markdown`(新しい module)。`view(text, options, look)` が Block から呼ぶ view の関数、木は `parse` / `blocks` で公開 | 下の「公開の形」、`test/yumemi_0131_markdown_test.gleam` |
| 2 | 読む範囲と読み方を使う側が選べる | `Options`(15 欄)と 3 つの既定 `document()`((c) の範囲)・`post()`((a) の読み)・`outline()`((b) の読み)。どの欄も `Options(..document(), tables: False)` で替えられる | 同上 |
| 3 | (a)(b) の互換を test で縛る | (a)(b) の test の入出力の表を一般の題材に書き直して yumemi の test に(`post_*` 9 本・`outline_*` 2 本)。写しの突き合わせで (a) は表 47 件・乱数 30000 件とも木・HTML・抜粋・行の中・区切り線の判定が全部同じ。(b) は表 4 件(規約の実 file 2 本を含む)が木・HTML とも同じ、乱数の差は 2 種だけ(下) | `build/0131-cmp-ab.txt`、`build/0131-cmp-b-classify.txt` |
| 4 | (c) の 21 頁で突き合わせ | 12 頁が byte 同じ、9 頁に 70 箇所の差。差は 3 種で全部 PoC の側の形(下の表) | `build/0131-cmp-c.txt`、`build/0131-cmp-c-kinds.txt` |
| 5 | 穴 2・3・6・9・10 | 全部閉じた(下) | `test/yumemi_0131_test.gleam` ほか |
| 6 | fixture と事業 app の写し | fixture 28 本が基点の生成器と停止コード・出力とも同じ。notes・article・cms の場で 2 回 exit 0・差 0。事業 app の写しは全面の生成物が基点の yumemi と byte 同じ(差 0)、www 452/452・muse_editor 396/396 | `build/0131-fixcmp.txt`、`build/0131-gen-final-*`、`build/0131-ms-gen-diff.txt`、`build/ms-new-*-test.txt` |

`gleam test`:基点 `471 passed, no failures`(`build/0131-test-before.txt`)→ 今 **`497 passed, no failures`**(`build/0131-test-final.txt`、末尾の字で見た)。`gleam format --check src test` exit 0。root の `npm ci` exit 0(`build/0131-npm-ci.txt`)。

## Component の公開の形と使い方

```gleam
import yumemi/front/css
import yumemi/front/html
import yumemi/front/markdown

fn look() -> markdown.Look {
  markdown.Look(
    ..markdown.bare(),
    heading: fn(level) { markdown.Part(css.class(style.heading(level)), []) },
    paragraph: markdown.Part(css.class(style.para), []),
    code: markdown.Part(css.class([css.OverflowX(css.OverflowAuto), css.Spaces(css.Pre)]), []),
    table_frame: option.Some(markdown.Part(css.class([css.OverflowX(css.OverflowAuto)]), [])),
    link: markdown.Part(css.class(style.link), []),
  )
}

pub fn view(it: In) -> el.Element {
  html.article(css.class(style.page), [], [
    markdown.view(it.article.body, markdown.document(), look()),
  ])
}
```

- 木:`Document(meta, blocks)`、`Block` = `Heading(level, inlines)` / `Paragraph(lines)` / `Code(lang, text)` / `Quote(blocks)` / `Bullets(items)` / `Numbered(start, items)` / `Table(header, rows)` / `Rule` / `Blanks(count)`、`Inline` = `Plain` / `Strong` / `Emphasis` / `CodeSpan` / `Link(href, label)`。箇条の項目は塊の並び(1 行の項目は `Paragraph` 1 つ)
- 読む口:`parse`・`blocks`・`inlines`・`field(doc, "status")`(前書き)・`plain`(抜粋)・`rule`(区切り線の行か)・`inline_text`
- 描く口:`view`(断片を返す、包む要素は app)・`render(blocks, look)`・`render_inlines(items, look)`。`Look` は要素の種類ごとの `Part(class, attributes)` と `spaces`(`KeepSpaces` は (a) の空白の残し方)
- 柵:生の HTML は字で escape(口は無い)。リンクは `Links` の柵(`WebLinks` = (a) の http(s) だけ、`SafeLinks` = `attr.safe_url`、相対も通す)を通らなければ `Link` にせず字のまま。`![..](..)` は読まない
- 色付けはしない。言語名は `pre` の `data-lang`
- 置き場と名は真壁が決めた:`yumemi/front/markdown`(生成器の `yumemi/gen/markdown` とは別)。`Look` と `Part` の名は「要素の見た目の束」の意

文書サイトの形の写し(`.scratch/docsite`、article の fixture から `src/external_hosts.mjs` と `docs/api-v1.md` を外し、Block の本文を `markdown.view(.., document(), bare())` に)で生成 exit 0・停止コード 0、面の `gleam build` exit 0、SSR は `<h2>見出し</h2><p>本文の <em>強調</em> と <code>code</code></p><table>…<pre data-lang="gleam">…</pre><p>&lt;script&gt;alert(1)&lt;/script&gt; [x](javascript:alert(1))</p>`(`build/0131-docsite-*.txt`)。

## 3 (a)(b) の互換

突き合わせの道具(`.scratch/cmp-ab`):事業 app main `28d3d6896` の `www/src/{article_markdown,legal_doc,style,multiline}.gleam` を写しのまま置き、(a) の描画は `www/src/blocks/article_detail.gleam` の本文を描く関数(`block_views` ほか)を写した(`article_font.body()` を同じ値の `attr.data("ma-article-body", "")` に置いた 1 箇所だけ)。yumemi の木を (a)(b) の木の形に写して `==` で比べ、HTML は (a) の Block の写しの出力と、yumemi の `view` を (a) と同じ class・属性の `Look` で描いた出力を字で比べた。

| 比べたもの | 表(test の入力) | 乱数(種 20261013、印 59 種を 1〜25 個) |
|---|---|---|
| (a) 木 `article_markdown.blocks` | 47/47 | 30000/30000 |
| (a) HTML(Block の写し vs `view`) | 47/47 | 30000/30000 |
| (a) 抜粋 `plain` | 47/47 | 30000/30000 |
| (a) 行の中 `inlines`・`inline_text` / 区切り線 `rule` | 87/87 | 30000/30000 |
| (b) 木 `legal_doc.parse`(前書きの札を含む) | 4/4(規約の実 file 2 本を含む) | 23423/30000 |
| (b) HTML(`legal_doc.view` vs 器と札を app 側に書いた `view`) | 4/4 | 23423/30000 |

**(b) の乱数の差は 2 種だけ**(`build/0131-cmp-b-classify.txt`、差の入力から印を外して分けた。そのほか 0):

- 単独の CR(`\r` の後に `\n` が無い)── (b) は字に残し、yumemi は (a) と同じく落とす(4175 件)。描くと (b) は空白 1 つに見える
- 符号付き(`-1. `・`+2. `)か 10 桁以上の番号 ── (b) は `int.parse` が通るので番号の項目にし、yumemi は 1〜9 桁の数字だけを番号にする((a) と CommonMark と同じ、266 件)。(b) は番号を描かないので、`-1. 字` は番号の 1 項目「字」になっていた

この 2 種を (b) と同じにする欄は足さなかった(下の「贄川さんに確認」)。規約の実 file と test の表では差は無い。

yumemi の test には、(a) の `ed-2-rule-ssr`・`ed-1-article-format`(往復の表の入力と読み込みの形)・`ed-2-editor`・`article-list-ssr`、(b) の `3-5a-legal` の入出力を、事業名と人の呼び名の無い題材に替えて木で書いた(`test/yumemi_0131_markdown_test.gleam` の `post_*` 9 本、`outline_*` 2 本)。

## 4 (c) 21 頁の突き合わせ

本文は PoC の `dev/ingest.mjs` の `build` と同じ形(前書きを外し、`## ` より前の `# ` の行を落とす)。PoC の `md.gleam`・`md_view.gleam`・`style.gleam` は `poc` `400a4ed` の写しのまま(`.scratch/cmp-c`)、yumemi は `document()` と PoC の `style` の class を写した `Look`(`code_frame`・`table_frame` は PoC と同じ `scroll_x`)。原稿は yumemi の木に写していない。

| 頁 | 本文 | 結果 |
|---|---|---|
| README | 5580 字 | 差 3(斜体 1 対、言語名の無い塊 1) |
| writing-gleam | 6340 字 | 差 2(斜体 1 対) |
| install | 10971 字 | 差 33(言語名の無い塊 32、`ol` の `value` 1) |
| documentation/index | 2681 字 | 差 2(斜体 1 対) |
| documentation/command-line-reference | 11762 字 | 差 1(言語名の無い塊 1) |
| documentation/compatibility-reference | 2347 字 | 同じ |
| documentation/conventions-patterns-and-anti-patterns | 16592 字 | 差 10(斜体 5 対) |
| documentation/externals | 20191 字 | 同じ |
| documentation/gleam-toml-reference | 7089 字 | 同じ |
| documentation/language-server-reference | 17853 字 | 同じ |
| documentation/source-bill-of-materials | 5307 字 | 差 16(斜体 8 対) |
| frequently-asked-questions | 4482 字 | 同じ |
| deployment/fly | 1814 字 | 同じ |
| deployment/linux-server | 6690 字 | 同じ |
| cheatsheets/gleam-for-elixir-users | 11244 字 | 同じ |
| cheatsheets/gleam-for-elm-users | 19211 字 | 同じ |
| cheatsheets/gleam-for-erlang-users | 9672 字 | 同じ |
| cheatsheets/gleam-for-php-users | 29180 字 | 差 1(`ol` の `value` 1) |
| cheatsheets/gleam-for-python-users | 16441 字 | 差 2(斜体 1 対) |
| cheatsheets/gleam-for-rust-users | 9204 字 | 同じ |
| roadmap | 8159 字 | 同じ |

差の種類(70 箇所の全部):

| 差 | 数 | PoC | yumemi | 理由 |
|---|---|---|---|---|
| 言語名の無いコードの塊 | 34 | `<pre class=.. data-lang>` | `<pre class=..>` | 言語名が無いときに空の属性を出さない(色付けの手がかりが無いことを空の属性で示す意味は無い) |
| 斜体 | 17 対 | `<span>…</span>` | `<em>…</em>` | PoC は `html` に `em` が無く `span` で並べていた(穴 9)。PoC の誤りを直した差 |
| 1 から始まる番号の箇条 | 2 | `<ol class=.. value="1">` | `<ol class=..>` | PoC は始まりの数を `ol` の `value` に置いていた(`ol` に `value` は無く効かない)。yumemi は 1 以外のときだけ先頭の `li` の `value` に置く。PoC の誤りを直した差 |

21 頁に現れず差にならなかった PoC との違い(読みの差として残るもの):`h5`・`h6` を PoC は `h4` に寄せていた(yumemi は `h5`・`h6`)、太字の中身の頭と尻が空白の `** x **` を PoC は太字にする(yumemi は (a) と CommonMark と同じく字)、段落の途中の `#` で始まる行・`|` で始まる行を PoC は段落の終わりにする(yumemi は見出し・表として読める行だけ)、`javascript:` のリンクを PoC は `href` の無い `<a>` にする(yumemi は字)、`![alt](src)` を PoC は `!` とリンクにする(yumemi は字)、段落の行末の空白を yumemi は落とす、符号付きと 10 桁以上の番号。

速さ:`gleam-for-php-users`(29180 字)を読んで描く 1 回は yumemi 46.6 ms・PoC 48.9 ms(node、20 回の平均、`build/0131-cmp-c-perf.txt`)。Worker の上では測っていない。

## 5 穴 2・3・6・9・10

- **2 静的資料**:`static_source.load_present` が 2 つの file をあるものだけ読み、無い file の写し(`gen/external.gleam`・`gen/doc/api_v1.gleam`)を出さない。あって形の違う file は今までどおり止める(exit 2)。`gen/doc/api_v1.gleam` は面の `src/style.gleam` が `body`・`ink`・`heading` を pub で持たなければ class 無し(`css.class([])`)で出す。`load` と `emit` は残した(今までの test が使う)。test:`static_materials_are_optional_test`(2 つとも無い・片方だけ無いの 3 通り)、`malformed_external_hosts_still_stops_test`、`api_v1_names_the_face_style_only_when_it_has_them_test`。写しで style の 3 名の無い面の `api_v1.gleam`(`#####`・`######` を含む)が `gleam build` exit 0(`build/0131-docsite-build2.txt`)。両方ある fixture(article・cms)の生成物は byte 同じ
- **3 Paged の整数の列**:向きのそろった keyset(`uniform_keyset`)の頭の穴の型を `uniform_cast` に(key の穴は今までの `cast_of` のまま ── 行の比較の中だけに在り列から型が決まる。r1 は key の穴も `uniform_cast` にしていて、key が整数の entity の動いていた一覧の SQL が `$3` → `$3::integer` に変わったので、柏木 ゲート 2 で戻した)(integer・bigint・boolean・double precision を足し、それ以外は今までの `cast_of`)。PG 18 で、基点の形 `($2 IS NULL OR (n.rank,n.id)<($2,$3::uuid))` は型の分からない穴で PREPARE が落ち(`build/0131-paged-pg-base.txt`:「パラメータ$2のデータ型が特定できませんでした」)、生成した 0.13.1 の SQL は integer・bigint・boolean・double precision の 4 表で 1 頁目と次の頁(カーソルを text で渡す)が正しい行を返した(`build/0131-paged-pg.txt`)。bigint は Gleam の型から出ないので SQL を手で 1 語替えて見た。test:`paged_by_integer_casts_the_cursor_test` ほか 3 本(text の列は型を書かない今のまま)
- **6 一意の制約の違反の log**:`http.mjs` の `failure` が `unavailable` に畳む 5xx の前に `{"yumemi":"request.unavailable","service","code","constraint","table","column","name","message"}` を `console.error` に 1 行。`detail`(鍵の値)は出さない。子の node の check 8 項(`test/yumemi_0131_check.mjs`)が全部 ok、基点の `http.mjs` に差し替えると 2 項が NG(`build/0131-check-unavailable-base.txt`)。応答の status は替えていない(503 `unavailable` のまま)
- **9 タグ**:`html` に `caption`・`del`・`em`・`h5`・`h6`・`i`・`kbd`・`sup`(class を取る形と `_` の形)
- **10 Style**:`css.Center`(`margin-left/right: auto`)、`css.OverflowX(Overflow)`、`css.Spaces(WhiteSpace)`、`css.Slant(FontSlant)`、`BorderEdge` に `LeftEdge`・`RightEdge`

## 6 事業 app の写し

`git archive main`(`28d3d6896`)を 2 つ置き(`.scratch/ms-base` は基点 `1eb718c` を archive した yumemi へ、`.scratch/ms-new` は本作業木へ path 依存)、7 package の `gleam deps download` exit 0(ms-new は Hex の API の rate limit に当たったので ms-base の manifest を写して path だけ替えた)、brand・fonts・legal を作って、api と 5 面の `src/gen` を消し api から `gleam run -m yumemi/gen -- <api> <root>`。

- 生成器:両方とも 1 回目 exit 0・停止コード 0・2372 ファイル、2 回目も exit 0・差 0 行・未追跡 0(`.scratch/ms-{base,new}-gen-{1,2}.txt`)
- **生成物の差(基点の yumemi と本作業木、全面):0**(`diff -rq` で `gleam.toml`・`manifest.toml` の path の行のほかに差は無い。`build/0131-ms-gen-diff.txt` に出るのは archive の中の行き先の無い symlink(`.claude/agents`・`.claude/commands`)の 4 行だけ)。main の commit 済みの生成物との差は 0.13.0 の分(`sql.mjs` の冪等の 4 本、`shell.mjs` 2 行、`idempotency.sql`、5 面の `client.mjs`、`_diagnostics.txt`、`build/0131-ms-new-gen-vs-main.txt`)で、0.13.1 の分は無い
- **www** `npm run build` exit 0・`npm test` **452/452**、**muse_editor** `npm run build` exit 0・`npm test` **396/396**(`build/ms-new-{www,muse_editor}-{build,test}.txt`)。src は書き換えていない

fixture:28 本を写しに置き、基点の生成器と本作業木の生成器で回して停止コードと書いた file を比べた ── 全部同じ停止コード・差 0(`build/0131-fixcmp.txt`)。notes・article・cms の場では 2 回とも exit 0・HEAD からの差 0(`build/0131-gen-final-*`)。

## 外から見える契約の差

- `css.Style` に 4 つ、`css.BorderEdge` に 2 つの構成子が足された。app が `css.Style` か `BorderEdge` を `case` で網羅していれば compile が止まる(足すだけの型の変更だが、網羅の `case` には破壊的)
- 新しい公開 module `yumemi/front/markdown`、`yumemi/gen/static_source` に `Present`・`Hosts`・`ApiV1`・`load_present`、`yumemi/gen/emit/static` に `emit_present`
- `css` に新しい公開の型 `Overflow`・`WhiteSpace`・`FontSlant`(構成子 `OverflowAuto` ほか 11)、`html` に 8 つのタグの関数 16(`caption`・`del`・`em`・`h5`・`h6`・`i`・`kbd`・`sup` と `_` の形)。足すだけ
- 面を置いた app で `src/external_hosts.mjs` か `docs/api-v1.md` が無いとき、exit 3 で止めずに通る(その写しは出ない)。両方ある app の出力は同じ
- 向きのそろった Paged の一覧が integer・bigint・boolean・double precision の列で並ぶとき、SQL の頭の穴に型が付く(その一覧は今まで 503 で、動いていた app の SQL は変わらない。key の穴は今までの型のまま)
- 内部の失敗の 503 の前に log が 1 行増える(応答は同じ 503 `{"code":"unavailable"}`。409 には替えていない)

## DDL

無し。

## 贄川さんに確認

- (b) の乱数の差 2 種(単独の CR、符号付きか 10 桁以上の番号)を `outline()` で (b) と同じにするなら、`Options` に欄が 2 つ要る(CR の落とし方、番号の数字の形)。CommonMark とも (a) とも違う読みのための欄なので足さなかった。実 file と test の表に差は無い。(b) の乗り換えの便で要るなら足す

## 次の版へ

- 一意の制約の違反を 409 `conflict` にするか(今は log だけ。0.13 の client は 5xx でキーを保って送り直すので、23505 の書きは同じ失敗を繰り返す)
- 画像の記法(`![alt](src)`)を読むか(今は字。描くなら `el.img` の `Src` の柵が要る)
- `~~取り消し~~`(`del` はある)・見出しの id(頁の中のリンク)・表の列の揃え(`:---:`)
- 生成器は写しの場の外の古い生成物(`gen/external.gleam` など)を消さない。静的資料を外した app は手で消す
- 穴 1・4・5・7・8・12〜15 は外(BRIEF のとおり触っていない)

## r2

便: yumemi-0131 r2 / 基点: `9d95d4f`(r1 + 柏木 ゲート 2 の P2)/ 真壁[IM] / 2026-10-13
証拠:`build/r2-*.txt`(作業木の `build/`、git の外)、道具は `.scratch/r2/`(同じく git の外)。版の行は替えていない。P1-4・5・6 は直していない(下の「残したもの」)。

### 1〜5 の充足

| # | どこまで | 結果 | 証拠 |
|---|---|---|---|
| 1 | P1-1:柏木の挙げた入力で 3 つの既定が投げずに返り、30KB が node で 1 回 100 ms 以内 | 全部返る。柏木の入力は冷えた 1 回目で 40 ms 以内、温まって 2〜15 ms。入れ子の上限 16(根拠は下)。病的な入力の test 3 本 | 下の表、`build/r2-bench-{before,before-extra,after,cold-after}.txt`、`build/r2-bench-table.md` |
| 2 | (a)(b) の互換と 21 頁が r1 と同じ | `.scratch/cmp-ab` の出力が r1 の記録と全文同じ(表 47・乱数 30000、(b) 表 4)。21 頁は表が同じ、出した 84 file が byte 同じ。r1 の読みとの突き合わせの乱数 42 万件が全部同じ | `build/r2-cmp-ab.txt`、`build/r2-cmp-c.txt`・`r2-cmp-c-out-vs-r1.txt`、`build/r2-fuzz-r1-vs-r2.txt` |
| 3 | P1-2:頭が text の向きのそろった keyset に型、PG で 1 頁目と次の頁が正しい | 頭の穴に `::text`。PG 18 で r1 の形は PREPARE が落ち、r2 の形は 1 頁目・次の頁とも答えの並びどおり。時刻・uuid の頭の SQL は byte 同じ | `build/r2-paged-text-pg.txt`、fixture・事業 app の写しの差 0 |
| 4 | P1-3:log から入力の値が出ない、check を足す | `message` は値を含まない SQLSTATE の類だけ。check 3 項を足して 11 項全部 ok、r1 の `http.mjs` では 3 項 NG | `build/r2-check-unavailable{,-r1}.txt` |
| 5 | fixture と事業 app の写しが r1 と同じ、`gleam test` | fixture 28 本が r1 の生成器と停止コード・出力とも同じ。notes・article・cms の場で 2 回 exit 0・差 0。事業 app の写しは 2372 file が r1 の出力と差 0(2 回とも) | `build/r2-fixcmp.txt`、`build/r2-gen-*-status.txt`、`build/r2-ms-gen-{1,2}.txt`・`r2-ms-gen-diff.txt` |

`gleam test`:**`500 passed, no failures`**(`build/r2-test-final.txt`、末尾の字で見た)。r1 の 497 に test を 3 本足し、`paged_by_text_and_time_is_unchanged_test` を `paged_by_time_is_unchanged_and_text_casts_the_cursor_test` に替えた。`gleam format --check src test` exit 0。

### P1-1 読みの速さと stack

直したもの(`src/yumemi/front/markdown.gleam`、木と HTML の読み方は r1 と同じ):

- **行の中の読みは長さに線形。** 閉じの印を先へ探した結果を 1 回の `scan` の間覚える(`Seen`)。閉じの無い `**`・`*`・`</code>`・逆引用符の連なりは 1 度見たら先を探さない。リンクの字は `[`・`]` に当たった所で止める(含めばリンクにならない)。URL と自動リンクは、柵で落ちると先で決まる字(閉じの `)`・`>`、空白、`http(s)://` の柵の禁じ字、`attr.safe_url` の scheme の区切り)の位置を覚え、開きの印ごとに行の尻まで読み直さない。scheme が ASCII の 7 字以上なら区切りまで読まずに落とす(許す scheme は 6 字まで)。位置は読んだ字の数で、`\` と次の字の対を割らない所だけを読むので、覚えはその間のどこから読んでも同じ
- **code span は stack を積まない。** `scan` と `code_span` の相互の呼び出しを `scan` の中に畳んだ(JS で loop になるのは自分の末尾の呼び出しだけ)。`<code>` の閉じは `CodeMark` のときだけ探す(r1 は case の主語で先に探していた)
- **入れ子(引用と箇条の項目)は 16 段まで。** 17 段目からの `>` と箇条の印は字のまま(段落の字)。段を数えるのは `document()` のような `quotes` か `nesting` の読み方だけで、`post()`・`outline()` の読みには効かない(どちらも入れ子を読まず、塊を読む深さは 0 のまま)
- **字の中の長い空白で遅くならない。** gleam_stdlib の JS の `trim_end` は正規表現 `[空白]*$` で、字の中の空白の連なりに長さの 2 乗かかる(3 万字の空白で 1 回 270 ms、行ごとに何度も呼ぶ)。同じ空白の集合を尻から読む `trim_end` を `src/yumemi/front/text_ffi.mjs` に置き、markdown と `attr.safe_url` が使う。行ごとの字下げと印の頭は、頭が ASCII なら code unit で数える(stdlib は Intl.Segmenter で行の全部を字に割り、`drop_start` は行の全部を UTF-8 に直す)。番号・見出し・区切り線の行も字に割らずに見る。どれも stdlib と同じ値を返す ── 乱数 20 万件で stdlib の `string.length` の差・`drop_start`・`trim_end` と比べて違い 0(`.scratch/r2/ffi-fuzz.mjs`)

**入れ子の上限 16 の根拠:**

- stack:node 24 で `--stack-size` を絞って、16 段の引用・箇条・混ぜたものを読んで描くのに要る stack は 70〜80 KB(module を読んで `x` 1 字を描くだけで 60 KB)。既定の約 984 KB に対して 16 段の分は 20 KB 前後で、app の Block の再帰に残りを残す。r1 は 1480 段前後で尽きていた(柏木の実測)
- 時間:字下げした入れ子は段ごとに深い行の字下げを読み直すので、段 × 行の数かかる。170 段の字下げの箇条(29KB)が冷えた 1 回目で 33 ms
- 文書:21 頁の入れ子はどれも 16 段に届かない(21 頁の出力が r1 と byte 同じ)。markdown-it の CommonMark の既定(`maxNesting` 20)と同じ桁

**速さ(node 24、30KB 前後、ms):** r1 は同じ process の中の 1 回目(冷えていない)、r2 は入力と読み方ごとに node を新しく起こした 1 回目と、同じ process の 5 回の最小。全行は `build/r2-bench-table.md`(40 種)。

| 入力(柏木の挙げたもの) | r1 document / post / outline | r2 冷えた 1 回目 | r2 温まった最小 |
|---|---|---|---|
| `[` × 30000 | 3488 / 2904 / 7 | 22 / 19 / 11 | 8 / 9 / 2 |
| code span `` `a` `` × 7500 | 投げる / 8 / 7 | 30 / 12 / 10 | 10 / 3 / 2 |
| `` `` x ` `` × 4285 | 投げる / 7 / 22 | 40 / 14 / 10 | 14 / 2 / 2 |
| `>` × 30000 | 投げる(2.2 s の後)/ 6 / 6 | 13 / 11 / 12 | 2 / 2 / 2 |
| `- ` × 15000(1 行の入れ子) | 投げる(5.6 s の後)/ 7 / 7 | 16 / 10 / 10 | 6 / 2 / 2 |
| `1. ` × 10000 | 投げる(13.5 s の後)/ 10 / 11 | 15 / 11 / 10 | 4 / 2 / 2 |
| `> - ` × 7500 | 投げる(5.7 s の後)/ 7 / 6 | 16 / 10 / 10 | 4 / 2 / 2 |
| 閉じない `<code>` × 5000 | 639 / 560 / 580 | 13 / 12 / 11 | 3 / 2 / 2 |
| 閉じない `<http` × 6000 | 708 / 8 / 6 | 18 / 12 / 11 | 7 / 2 / 2 |
| 字下げの箇条 170 段 | 161 / 9 / 2 | 33 / 11 / 7 | 3 / 2 / 0 |

| 入力(r2 で足した同じ類) | r1 document / post / outline | r2 冷えた 1 回目 | r2 温まった最小 |
|---|---|---|---|
| `[a](x` × 5999 + `:)`(scheme が長い) | 8806 / 1408 / 7 | 29 / 21 / 10 | 12 / 7 / 2 |
| `[a](http://x` × 2499 + ` )`(空白で落ちる) | 25 / 2994 / 7 | 21 / 17 / 11 | 6 / 6 / 2 |
| `[a](` × 7499 + `)` | 26 / 1632 / 6 | 22 / 23 / 11 | 7 / 11 / 2 |
| `<httpx:` × 4284 + `>` | 6079 / 8 / 8 | 28 / 12 / 11 | 13 / 2 / 2 |
| `<http://x` × 3332 + ` >` | 1004 / 8 / 6 | 29 / 12 / 10 | 13 / 2 / 2 |
| `x` + 空白 29998 + `x` | 1412 / 1352 / 1986 | 10 / 10 / 10 | 2 / 2 / 2 |
| `- a\nb\n` × 5000 | 485 / 326 / 333 | 79 / 70 / 72 | 56 / 50 / 51 |
| `- a\n` × 7500 | 355 / 175 / 44 | 58 / 43 / 50 | 26 / 15 / 15 |

- 40 種 × 3 の冷えた 1 回目の最大は、1 行に 15000 セルの表(`document()`、出力 330KB)の 101 ms、次が 5000 行の表の 90 ms。どちらも線形で、出力が本文の 5〜11 倍。r1 はそれぞれ 125 ms・50 ms(冷えていない)。それ以外は 81 ms 以内
- 投げた入力は 0(r2 の 240 回の計測の全部)。描いた HTML の字数は、入れ子が 16 段を越える 6 種(うち 4 種は r1 が投げた)と r1 が投げた code span の 2 種のほかは r1 と同じ
- Worker の上では測っていない

**病的な入力の test**(`test/yumemi_0131_markdown_test.gleam`、時間は `test/yumemi_0131_markdown_test_ffi.mjs` で測る):

- `hostile_text_returns_in_time_test`:上の類の 18 種(30KB 前後)× 3 つの読み方が投げずに空でない HTML を返し、1 回 1000 ms 以内(目安 100 ms の 10 倍で緩く縛る)
- `nesting_stops_at_sixteen_test`:16 段までは今までどおり、20 段の `>`・`- ` は 16 段の後ろが字(`>>>> x`・`- - - - x`)、`post()` の木は替わらない
- `links_decided_ahead_read_as_before_test`:先で決めたリンクの読みが r1 と同じ(scheme の長い URL は字、後ろの印から始まる `tel:` は通る、空白で落ちた URL の後ろの印も通る)
- r1 の `markdown.gleam` に差し替えて `gleam test` を回すと、前の 2 本が落ちる(`RangeError: Maximum call stack size exceeded`、498 passed・2 failures、`build/r2-test-with-r1-markdown.txt`)。3 本目は r1 でも通る(読みが同じことを縛る test)

**r1 の読みとの突き合わせ**(`.scratch/r2/diff`、r1 の `markdown.gleam` を `old_markdown` として置いた):木(`string.inspect`)・`bare()` の HTML・`inlines`・`plain`・`rule` を、7 つの読み方(3 つの既定、`document()` を `WebLinks` に、`post()` に行の中の印を全部と `SafeLinks`、`\` 無しの `document()`、入れ子無しで前後の空白を落とす `document()`)で比べた。乱数は 3 種(記法の全般 100 種の印、リンクと自動リンクとコードの閉じの印、`http(s)://` の柵の印)を 20000 件ずつ、**140000/140000 × 3 が同じ**(`build/r2-fuzz-r1-vs-r2.txt`)。柏木の (a) の乱数(種 131、50000 件)も r1 の記録と全文同じ(`build/r2-kashiwagi-fuzz-a.txt`)。

### P1-2 頭が text の Paged

`uniform_cast`(`src/yumemi/gen/emit/sql.gleam`)に `text` を足した。向きのそろった keyset の頭の穴が `($2::text IS NULL OR (n.rank,n.id)<($2,$3::uuid))` になる。key の穴は今までの `cast_of` のまま。時刻・uuid・整数ほかの頭は r1 と同じ。

- PG 18(`.scratch/r2/pgdata`、試した後に止めた):notes の fixture の一覧を text の列 `rank` の降順に替えて生成した SQL で、r1 の形は「パラメータ$2のデータ型が特定できませんでした」で PREPARE が落ち、r2 の形は 1 頁目(e・d と次の有無の c)、次の頁(カーソル `d` と id を text で渡して c・c・b)が全件の並びのとおり(`build/r2-paged-text-pg.txt`)
- SQL が変わるのは頭が text の向きのそろった一覧だけで、その一覧は r1 まで必ず 503 だった。fixture 28 本と事業 app の写しの生成物は r1 と差 0
- test:`paged_by_time_is_unchanged_and_text_casts_the_cursor_test`(`$2::text IS NULL` が出て、型の無い `$2 IS NULL` は出ない、key の穴は `$3::uuid` のまま)

### P1-3 log の message

`src/yumemi/server/http.mjs` の `unavailableLog`:`message` は SQLSTATE が 08・23・25・40・42・53・54・57 の類のときだけ出し、それ以外は `null`。

- 23(一意・外部キー・NOT NULL・CHECK の違反)の文言は制約・表・列の名だけで、値は `detail` に入る(出さない)。08・25・40・53・54・57 は接続・transaction・資源・上限・中断、42 は生成した SQL と型の名(`could not determine data type of parameter $2` もここ)
- 22 の類は入力の値を文言に含む(`invalid input syntax for type uuid: "…"`)ので出さない。SQLSTATE の無い JS の例外も出さない ── `JSON.parse` は入力の切れ端を文言に含む(`Unexpected token '秘', "秘密の本文" is not valid JSON`)。`name` と `code` は今までどおり出る
- check(`test/yumemi_0131_check.mjs`)に 3 項:一意の違反の文言は残る、22P02 の文言(値入り)は出ない、`JSON.parse` の切れ端は出ない。平の例外の項は「message が出る」から「出ない」に替えた。11 項全部 ok、r1 の `http.mjs` に差し替えると 3 項 NG(`build/r2-check-unavailable{,-r1}.txt`)。応答は今までどおり 503 `unavailable`

### 外から見える契約の差(r2 の分)

- `document()` のように引用か入れ子を読む読み方で、17 段目からの `>` と箇条の印は字になる(r1 は読んだ。1480 段前後で stack が尽きていた)。`post()`・`outline()` の木は替わらない
- 向きのそろった Paged の一覧が text の列で並ぶとき、頭の穴が `::text` になる(r1 まで 503 だった一覧だけ)
- `request.unavailable` の log の `message` が、上の類のほかは `null` になる
- `yumemi/front/text_ffi.mjs` が増えた(内部、公開の関数は無い)。`attr.safe_url` の答えは替わらない
- README:Markdown の項に書き手を信用しない本文の速さと入れ子の上限、0.13.1 の Paged の項に text、log の項に `message` の出し方

### 残したもの

- P1-4(`Options`・`Block`・`Inline` の公開の形が次の版の追加を破壊的にする)、P1-5(`css.Style`・`BorderEdge` の網羅の case)、P1-6(基点から在る事業名 10 件):鷹野さんの裁きのとおり直していない
- 1 行に 15000 セルの表は冷えた 1 回目で 101 ms(出力 330KB)。線形で、この巡では詰めていない
- 「次の版へ」の項は r1 のまま

### DDL

無し。

## 0.13.1 の後に見つかったもの(次の版へ、鷹野 2026-10-13)

文書サイトの PoC を 0.13.1 に乗り換えた窓と、事業 app の取り込みの便(柏木のゲート 2)から:

1. **(バグ)`q.Pick` の一覧が実行時に 503。**SQL は列を絞り、reads の型(ItemsRow)も出るが、生成の `gen/runtime.mjs` の `out` が `['entity', <名>]` のままで、Pick した行を Entity として decode して `invalid stored phase` で落ちる
2. **冪等の記録を Service ごとに外す手が無い。**秘密を一度だけ返す書き(API 鍵・発行のコード)の応答の平文が `framework.idempotency.result` に残り、同じキーの再送で同じ平文がもう一度返る(0.13.0 から)。事業 app は `early` hook で該当の Service だけ `Idempotency-Key` を外して塞いだ ── 手が入ったら外す
3. `Center` を grid・flex の子に掛けると左右の margin auto で幅が縮む。`Width` に割合が無く 100% と併せられない
4. markdown の `Look` に言語ごとの口が無い(言語名ごとにコードの枠を変えるには木を自分で歩く)
5. `Cond` に `Or` が無い
6. markdown の読みと描きが 1 つの module で、読みだけ import する client の束にも描く側(`el`・`css`・`sketch` ほか)が入る(事業 app の編集器の束が 239KB → 342KB)
