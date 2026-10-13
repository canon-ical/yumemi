//// yumemi-0131(0.13.1)── 実行時の Markdown の Component(`yumemi/front/markdown`)。
//// 読み方 3 つ:`post()`(書き手の投稿)・`outline()`(規約のような文)・`document()`(文書)。
//// `post()` と `outline()` の表は、既に Markdown を描いている app の読みが縛っている入出力を一般の題材に書き直したもの
//// ── この表が通る限り、その app の木は替わらない。

import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import yumemi/front/attr
import yumemi/front/css
import yumemi/front/el
import yumemi/front/html
import yumemi/front/markdown.{
  Blanks, Bullets, Code, CodeSpan, Emphasis, Heading, Link, Numbered, Paragraph,
  Plain, Quote, Rule, Strong, Table,
}

fn post(text: String) -> List(markdown.Block) {
  markdown.blocks(text, markdown.post())
}

fn doc(text: String) -> List(markdown.Block) {
  markdown.blocks(text, markdown.document())
}

/// 1 行の段落。
fn line(items: List(markdown.Inline)) -> markdown.Block {
  Paragraph([items])
}

/// 1 行の項目。
fn item(items: List(markdown.Inline)) -> List(markdown.Block) {
  [Paragraph([items])]
}

fn kinds(blocks: List(markdown.Block)) -> List(String) {
  list.map(blocks, fn(block) {
    case block {
      Heading(..) -> "Heading"
      Paragraph(..) -> "Paragraph"
      Code(..) -> "Code"
      Quote(..) -> "Quote"
      Bullets(..) -> "Bullets"
      Numbered(..) -> "Numbered"
      Table(..) -> "Table"
      Rule -> "Rule"
      Blanks(..) -> "Blanks"
    }
  })
}

fn bare_html(text: String, options: markdown.Options) -> String {
  el.to_string(markdown.view(text, options, markdown.bare()))
}

// ── post():区切り線 ────────────────────────────────────────────────────────

/// 前後の半角の空白・タブ・行末の CR を除いて `---` だけの行は区切り線。全角の空白は字下げの字なので字のまま。
pub fn post_rule_is_three_dashes_only_test() {
  list.each(["---", "  ---", "---  ", "\t---\t", "---\r", "  ---  "], fn(text) {
    post(text) |> should.equal([Rule])
  })
  post("　---") |> kinds |> should.equal(["Paragraph"])
  list.each(["***", "___", "----", "--", "--- 字", "字 ---", "-—-"], fn(text) {
    { post(text) == [Rule] } |> should.be_false
  })
  post("- - -") |> should.equal([Bullets([item([Plain("- -")])])])
}

/// 区切り線は段落を割る。前の行を見出しにする読み(下線)はしない。
pub fn post_rule_splits_and_never_underlines_test() {
  post("前の文\n---\n後の文")
  |> should.equal([line([Plain("前の文")]), Rule, line([Plain("後の文")])])
  post("## 見出し\n---\n本文")
  |> should.equal([Heading(2, [Plain("見出し")]), Rule, line([Plain("本文")])])
  post("見出しにならない文\n---") |> kinds |> should.equal(["Paragraph", "Rule"])
  post("- 一\n---\n- 二")
  |> should.equal([
    Bullets([item([Plain("一")])]),
    Rule,
    Bullets([item([Plain("二")])]),
  ])
  post("***\n___\n----")
  |> should.equal([Paragraph([[Plain("***")], [Plain("___")], [Plain("----")]])])
}

/// 抜粋は区切り線の行を落とし、ほかの行の数と順はそのまま。
pub fn post_plain_drops_rules_and_marks_test() {
  markdown.plain("前\n---\n後", markdown.post()) |> should.equal("前\n後")
  markdown.plain("## 見出し\n  ---  \n**太字**\n----", markdown.post())
  |> should.equal("見出し\n太字\n----")
  markdown.plain("---", markdown.post()) |> should.equal("")
  markdown.plain("## 見出し\n**太字**の文", markdown.post())
  |> should.equal("見出し\n太字の文")
  // 番号の印は字のまま、箇条の印とリンクの記法は落とす
  markdown.plain("12. [港](https://e.com/p) へ\n- 一つ目", markdown.post())
  |> should.equal("12. 港 へ\n一つ目")
  markdown.rule("  ---\r", markdown.post()) |> should.be_true
  markdown.rule("----", markdown.post()) |> should.be_false
}

// ── post():見出し・箇条・番号・太字・リンク ─────────────────────────────────

/// `#`・`##` は段 2、`###` は段 3。`####`・`#字`・印の後が空の行は字。`* ` も箇条、番号は始まりの数を残す。
pub fn post_headings_lists_and_numbers_test() {
  post(
    "## 見出し\n前**太字**後\n- 箇条\n[リンク](https://example.com/a)\n# 一つの見出し\n### 小見出し\n* 星\n3. 番号",
  )
  |> should.equal([
    Heading(2, [Plain("見出し")]),
    line([Plain("前"), Strong([Plain("太字")]), Plain("後")]),
    Bullets([item([Plain("箇条")])]),
    line([Link("https://example.com/a", [Plain("リンク")])]),
    Heading(2, [Plain("一つの見出し")]),
    Heading(3, [Plain("小見出し")]),
    Bullets([item([Plain("星")])]),
    Numbered(3, [item([Plain("番号")])]),
  ])
  post("# 大きい見出し\n### 小さい見出し\n* 星の箇条\n* 星の二つ目\n1. 番号\n2. 番号の二つ目\n\n12. 途中から")
  |> should.equal([
    Heading(2, [Plain("大きい見出し")]),
    Heading(3, [Plain("小さい見出し")]),
    Bullets([item([Plain("星の箇条")]), item([Plain("星の二つ目")])]),
    Numbered(1, [item([Plain("番号")]), item([Plain("番号の二つ目")])]),
    Blanks(1),
    Numbered(12, [item([Plain("途中から")])]),
  ])
}

/// 印の後ろの空白・行末の空白と CR は落とす。行頭の空白は落とさない(字下げした印は字)。
pub fn post_spaces_and_carriage_returns_test() {
  post("##   空白の多い見出し  \n-  字下げの箇条\t\n**太字** \r\n[リ](https://e.com/x)\r")
  |> should.equal([
    Heading(2, [Plain("空白の多い見出し")]),
    Bullets([item([Plain("字下げの箇条")])]),
    Paragraph([[Strong([Plain("太字")])], [Link("https://e.com/x", [Plain("リ")])]]),
  ])
  post("  - 字下げの箇条")
  |> should.equal([line([Plain("  - 字下げの箇条")])])
}

/// 読まない記法は字のまま(表・引用・コード・斜体・取り消し線・HTML の直書き・入れ子・4 つの `#`・
/// `javascript:` と空白を含む URL・10 桁の番号)。
pub fn post_leaves_other_marks_as_text_test() {
  let text =
    "| 表 | 表 |\n> 引用\n**閉じない\n`コード`\n*斜体*\n~~消し~~\n[外](javascript:alert(1))\n[空白](https://e.com/a b)\n#### 四つ\n#見出しでない\n-箇条でない\n## \n- \n<b>直書き</b>\n1.番号でない\n1234567890. 桁が多い"
  post(text)
  |> should.equal([
    Paragraph(
      string.split(text, "\n")
      |> list.map(fn(row) { [Plain(string.trim_end(row))] }),
    ),
  ])
  bare_html("<b>直書き</b>", markdown.post())
  |> should.equal("<p>&lt;b&gt;直書き&lt;/b&gt;</p>")
}

/// 太字の中のリンク・リンクの中の太字は読む。太字の頭と尻が空白なら太字にしない。画像の記法はリンクにしない。
pub fn post_strong_and_links_nest_once_test() {
  let url = "https://example.com/a"
  post("**太字の中の[リンク](" <> url <> ")だ**\n[リンクの中の**太字**](" <> url <> ")")
  |> should.equal([
    Paragraph([
      [Strong([Plain("太字の中の"), Link(url, [Plain("リンク")]), Plain("だ")])],
      [Link(url, [Plain("リンクの中の"), Strong([Plain("太字")])])],
    ]),
  ])
  post("** 空白 **\n**空白 **\n****")
  |> should.equal([
    Paragraph([[Plain("** 空白 **")], [Plain("**空白 **")], [Plain("****")]]),
  ])
  post("前 **字** 後")
  |> should.equal([line([Plain("前 "), Strong([Plain("字")]), Plain(" 後")])])
  post("![](blob:a.png) と [写](https://e.com/p.png)")
  |> should.equal([
    line([
      Plain("![](blob:a.png) と "),
      Link("https://e.com/p.png", [Plain("写")]),
    ]),
  ])
  // `[` か `]` を含む字はリンクにしない
  post("【告知】[限定]の案内") |> should.equal([line([Plain("【告知】[限定]の案内")])])
  post("[【告知】](" <> url <> ")[限定]の案内")
  |> should.equal([
    line([Link(url, [Plain("【告知】")]), Plain("[限定]の案内")]),
  ])
}

/// 空行は畳まず数で返す(先頭と末尾も)。
pub fn post_counts_blank_lines_test() {
  post("\n---\n\n") |> should.equal([Blanks(1), Rule, Blanks(2)])
  post("一\n\n\n\n二")
  |> should.equal([line([Plain("一")]), Blanks(3), line([Plain("二")])])
  post("") |> should.equal([Blanks(1)])
}

// ── post() の描き方 ─────────────────────────────────────────────────────────

/// 段落の中の改行は `br`、空行は `aria-hidden` の空き、番号の始まりは先頭の `li` の `value`、リンクの属性は Look から。
pub fn post_renders_breaks_blanks_and_numbers_test() {
  let look =
    markdown.Look(
      ..markdown.bare(),
      link: markdown.Part(css.class([]), [attr.rel("nofollow ugc noopener")]),
      spaces: markdown.KeepSpaces,
    )
  el.to_string(markdown.view(
    "一行目\n  二行目  の  字\n\n3. 三\n4. 四\n[港](https://e.com/p)",
    markdown.post(),
    look,
  ))
  |> should.equal(
    "<p>一行目<br>\u{a0}\u{a0}二行目\u{a0}\u{a0}の\u{a0}\u{a0}字</p><p aria-hidden=\"true\">\u{a0}</p><ol><li value=\"3\">三</li><li>四</li></ol><p><a href=\"https://e.com/p\" rel=\"nofollow ugc noopener\">港</a></p>",
  )
}

// ── outline() ───────────────────────────────────────────────────────────

/// 前書きの `status`、見出し 3 段、段落の行は詰める、箇条と番号。行の中の記法は読まない。
pub fn outline_reads_front_matter_and_joins_lines_test() {
  let document =
    markdown.parse(
      "---\nstatus: 下書き\n---\n# 題\n\n## 第1条\n本文の\n続き\n\n- 一\n- 二\n1. 甲\n2. 乙\n### 小見出し\n",
      markdown.outline(),
    )
  markdown.field(document, "status") |> should.equal(Ok("下書き"))
  document.blocks
  |> should.equal([
    Heading(1, [Plain("題")]),
    Heading(2, [Plain("第1条")]),
    line([Plain("本文の続き")]),
    Bullets([item([Plain("一")]), item([Plain("二")])]),
    Numbered(1, [item([Plain("甲")]), item([Plain("乙")])]),
    Heading(3, [Plain("小見出し")]),
  ])
  let plain = markdown.parse("準備中です。", markdown.outline())
  markdown.field(plain, "status") |> should.equal(Error(Nil))
  plain.blocks |> should.equal([line([Plain("準備中です。")])])
}

/// 字下げした印も印(行の頭と尻を落としてから読む)。番号は始まりの数を残さない。`**` も `[` も字。
/// 閉じの無い前書きは前書きでなく、空の値の欄は無いのと同じ。
pub fn outline_trims_lines_and_reads_no_inline_marks_test() {
  markdown.blocks(
    "  # 題  \n   - 一\n  3. 三\n**太字** と [リンク](https://e.com/)",
    markdown.outline(),
  )
  |> should.equal([
    Heading(1, [Plain("題")]),
    Bullets([item([Plain("一")])]),
    Numbered(1, [item([Plain("三")])]),
    line([Plain("**太字** と [リンク](https://e.com/)")]),
  ])
  let open = markdown.parse("---\nstatus: x\n本文", markdown.outline())
  open.meta |> should.equal([])
  open.blocks |> kinds |> should.equal(["Paragraph"])
  let empty =
    markdown.parse("---\nstatus:\nstatus: 二つ目\n---\n本文", markdown.outline())
  markdown.field(empty, "status") |> should.equal(Ok("二つ目"))
}

// ── document() ──────────────────────────────────────────────────────────

/// 見出し h1〜h6、段落の行はつないで読む、斜体・コード・相対のリンク・自動リンク・`\` と文字参照。
pub fn document_reads_headings_and_inline_marks_test() {
  doc("# 一\n###### 六\n####### 七つは字")
  |> should.equal([
    Heading(1, [Plain("一")]),
    Heading(6, [Plain("六")]),
    line([Plain("####### 七つは字")]),
  ])
  doc(
    "*斜体* と **太字** と `a | b` と [文書](/docs/intro) と <https://gleam.run>\n\\*字\\* &lt;b&gt; &#124;",
  )
  |> should.equal([
    line([
      Emphasis([Plain("斜体")]),
      Plain(" と "),
      Strong([Plain("太字")]),
      Plain(" と "),
      CodeSpan("a | b"),
      Plain(" と "),
      Link("/docs/intro", [Plain("文書")]),
      Plain(" と "),
      Link("https://gleam.run", [Plain("https://gleam.run")]),
      Plain("\n*字* <b> |"),
    ]),
  ])
  // `javascript:` は柵を通らず字のまま(`<a>` を作らない)
  doc("[外](javascript:alert(1)) と <code>x</code> と ``a ` b``")
  |> should.equal([
    line([
      Plain("[外](javascript:alert(1)) と "),
      CodeSpan("x"),
      Plain(" と "),
      CodeSpan("a ` b"),
    ]),
  ])
}

/// コードの塊(言語名)、引用(中も塊)、表(コードの中の `|` は割らない)、区切り線 3 種。
pub fn document_reads_code_quotes_tables_and_rules_test() {
  doc(
    "```gleam\npub fn main() {\n  io.println(\"<hi>\")\n}\n```\n\n> 引用の\n> 続き\n>\n> - 中の箇条\n\n| 名 | 型 |\n|:---|---:|\n| `a | b` | Int |\n| x \\| y | **z** |\n\n***\n- - -\n___",
  )
  |> should.equal([
    Code("gleam", "pub fn main() {\n  io.println(\"<hi>\")\n}"),
    Quote([
      line([Plain("引用の\n続き")]),
      Bullets([item([Plain("中の箇条")])]),
    ]),
    Table([[Plain("名")], [Plain("型")]], [
      [[CodeSpan("a | b")], [Plain("Int")]],
      [[Plain("x | y")], [Strong([Plain("z")])]],
    ]),
    Rule,
    Rule,
    Rule,
  ])
  doc("```\n閉じない") |> should.equal([Code("", "閉じない")])
}

/// 入れ子の箇条と番号、項目の間の空行、項目の中のコードの塊、`)` の番号。
pub fn document_reads_nested_lists_test() {
  doc("- 一\n  - 一の一\n  - 一の二\n\n- 二\n  ```sh\n  gleam run\n  ```\n3) 三\n4) 四")
  |> should.equal([
    Bullets([
      [
        line([Plain("一")]),
        Bullets([item([Plain("一の一")]), item([Plain("一の二")])]),
      ],
      [line([Plain("二")]), Code("sh", "gleam run")],
    ]),
    Numbered(3, [item([Plain("三")]), item([Plain("四")])]),
  ])
}

/// 描き方:見出しは段のタグ、コードの言語名は `data-lang`、表は `scope="col"`、斜体は `em`、項目の先頭の段落は `p` を外す。
pub fn document_renders_with_the_look_test() {
  bare_html(
    "##### 五\n\n- *斜体*\n  - 中\n\n```gleam\nlet x = \"<\"\n```\n\n| a |\n|---|\n| 1 |",
    markdown.document(),
  )
  |> should.equal(
    "<h5>五</h5><ul><li><em>斜体</em><ul><li>中</li></ul></li></ul><pre data-lang=\"gleam\"><code>let x = &quot;&lt;&quot;</code></pre><table><thead><tr><th scope=\"col\">a</th></tr></thead><tbody><tr><td>1</td></tr></tbody></table>",
  )
  let frame = markdown.Part(css.class([css.OverflowX(css.OverflowAuto)]), [])
  let look =
    markdown.Look(
      ..markdown.bare(),
      heading: fn(level) {
        markdown.Part(css.class([]), [attr.data("level", string.inspect(level))])
      },
      code_frame: Some(frame),
      table_frame: None,
    )
  let html =
    el.to_string(markdown.view("# 題\n\n```\nx\n```", markdown.document(), look))
  string.starts_with(html, "<h1 data-level=\"1\">題</h1><div class=\"css-")
  |> should.be_true
  string.ends_with(html, "\"><pre><code>x</code></pre></div>") |> should.be_true
}

/// 木を app の Block で描く道:`render` と `render_inlines` は木から要素を作るだけ。
pub fn render_takes_a_tree_test() {
  markdown.render([Heading(2, [Plain("題")]), Blanks(2)], markdown.bare())
  |> list.map(el.to_string)
  |> should.equal([
    "<h2>題</h2>",
    "<p aria-hidden=\"true\">\u{a0}</p>",
    "<p aria-hidden=\"true\">\u{a0}</p>",
  ])
  markdown.render_inlines(
    [Plain("<"), Link("/a", [Plain("b")])],
    markdown.bare(),
  )
  |> list.map(el.to_string)
  |> should.equal(["&lt;", "<a href=\"/a\">b</a>"])
  markdown.inline_text(markdown.inlines(
    "**太** [リ](https://e.com) `c`",
    markdown.document(),
  ))
  |> should.equal("太 リ c")
}

/// 選び方は替えられる:表を読まない文書。
pub fn options_can_be_changed_test() {
  markdown.blocks(
    "| a |\n|---|",
    markdown.Options(..markdown.document(), tables: False),
  )
  |> should.equal([line([Plain("| a |\n|---|")])])
  markdown.blocks(
    "[文書](/docs) [外](https://e.com)",
    markdown.Options(..markdown.document(), links: markdown.WebLinks),
  )
  |> should.equal([
    line([Plain("[文書](/docs) "), Link("https://e.com", [Plain("外")])]),
  ])
}

// ── 穴 9・10:タグと Style ─────────────────────────────────────────────────

pub fn document_tags_test() {
  [
    html.em_([], [el.text("a")]),
    html.i_([], []),
    html.h5_([], []),
    html.h6_([], []),
    html.kbd_([], []),
    html.del_([], []),
    html.sup_([], []),
    html.caption_([], []),
  ]
  |> list.map(el.to_string)
  |> should.equal([
    "<em>a</em>",
    "<i></i>",
    "<h5></h5>",
    "<h6></h6>",
    "<kbd></kbd>",
    "<del></del>",
    "<sup></sup>",
    "<caption></caption>",
  ])
}

pub fn document_styles_test() {
  let #(css_text, _) =
    el.styled(
      fn() {
        html.div(
          css.class([
            css.Center,
            css.OverflowX(css.OverflowAuto),
            css.Spaces(css.PreWrap),
            css.Slant(css.Italic),
            css.Border(
              edge: css.LeftEdge,
              width: css.Px(4.0),
              style: css.Solid,
              color: css.Hex("#123456"),
            ),
            css.Border(
              edge: css.RightEdge,
              width: css.Px(1.0),
              style: css.Dashed,
              color: css.CurrentColor,
            ),
          ]),
          [],
          [],
        )
      },
      "",
    )
    |> el.to_string
    |> fn(text) { #(text, Nil) }
  [
    "margin-left: auto;",
    "margin-right: auto;",
    "overflow-x: auto;",
    "white-space: pre-wrap;",
    "font-style: italic;",
    "border-left: 4.0px solid #123456;",
    "border-right: 1.0px dashed currentcolor;",
  ]
  |> list.each(fn(rule) { string.contains(css_text, rule) |> should.be_true })
}
