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
| install | 10971 字 | 差 33(言語名の無い塊 33) |
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
- **3 Paged の整数の列**:向きのそろった keyset(`uniform_keyset`)の頭の穴と key の穴の型を `uniform_cast` に(integer・bigint・boolean・double precision を足し、それ以外は今までの `cast_of`)。PG 18 で、基点の形 `($2 IS NULL OR (n.rank,n.id)<($2,$3::uuid))` は型の分からない穴で PREPARE が落ち(`build/0131-paged-pg-base.txt`:「パラメータ$2のデータ型が特定できませんでした」)、生成した 0.13.1 の SQL は integer・bigint・boolean・double precision の 4 表で 1 頁目と次の頁(カーソルを text で渡す)が正しい行を返した(`build/0131-paged-pg.txt`)。bigint は Gleam の型から出ないので SQL を手で 1 語替えて見た。test:`paged_by_integer_casts_the_cursor_test` ほか 3 本(text の列は型を書かない今のまま)
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
- 面を置いた app で `src/external_hosts.mjs` か `docs/api-v1.md` が無いとき、exit 3 で止めずに通る(その写しは出ない)。両方ある app の出力は同じ
- 向きのそろった Paged の一覧が integer・bigint・boolean・double precision の列で並ぶとき、SQL の頭の穴と key の穴に型が付く(その一覧は今まで 503 で、動いていた app の SQL は変わらない)
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
