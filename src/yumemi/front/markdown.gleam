//// 実行時の Markdown(0.13.1)。DB に置いた本文の Markdown を木(`Block` と `Inline`)に読み、yumemi の要素で描く
//// Component。`el` は生の HTML を受けないので、面は Markdown を木に読んで `html` の要素で組むしかない ── その読みと
//// 組みを app ごとに書き直さずに済むよう、yumemi が持つ。
////
//// - 読む記法の範囲と読み方は `Options` で選ぶ。`document()`(文書:見出し h1〜h6・段落・コードの塊・表・引用・
////   入れ子の箇条・区切り線、行の中のコード・太字・斜体・リンク)、`post()`(書き手の投稿:見出し 2 段・段落と改行・
////   太字・箇条・番号・リンク・`---`、空行は数のまま)、`outline()`(規約のような文:見出し 3 段・箇条・番号・
////   段落の行を詰める・前書き、行の中は読まない)の 3 つを置く。`Options(..document(), tables: False)` のように替えてよい
//// - 読まない記法は字のまま返す。HTML の直書きも字で、描くときに escape される(生の HTML を通す口は無い)
//// - リンクの `href` は `Links` の柵を通ったものだけが `Link` になる。通らないリンクの記法は字のまま
//// - 描き方は `Look`(要素の種類ごとの class と属性)で選ぶ。`view` は塊の並びを 1 つの断片で返し、包む要素は
////   app が置く。木を app の Block で描くなら `parse` / `blocks` だけを使う
//// - 構文の色付けはしない。コードの塊の言語名は `pre` の `data-lang` に残す

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import yumemi/front/attr
import yumemi/front/css
import yumemi/front/el.{type Attribute, type Element}
import yumemi/front/html

// ── 木 ────────────────────────────────────────────────────────────────────

/// 読んだ本文。`meta` は前書き(`Options.front_matter`)の `key: value` を書いた順に。
pub type Document {
  Document(meta: List(#(String, String)), blocks: List(Block))
}

pub type Block {
  /// 段は `Options.headings` の対で `#` の数から写したもの(1〜6)。
  Heading(level: Int, inlines: List(Inline))
  /// 段落。`BreakLines` は書いた行ごと(描くと行の間に `br`)、`JoinLines` は行をつないだ 1 行。
  Paragraph(lines: List(List(Inline)))
  /// フェンス(```)のコードの塊。`lang` は開きの行の最初の語(無ければ "")。中身は字のまま。
  Code(lang: String, text: String)
  Quote(blocks: List(Block))
  /// 箇条。項目は塊の並び(1 行の項目は 1 つの `Paragraph`)。
  Bullets(items: List(List(Block)))
  /// 番号の箇条。`start` は最初の項目の番号(`Options.number_start` が False なら 1)。
  Numbered(start: Int, items: List(List(Block)))
  /// 表。セルは行の中の記法の並び。
  Table(header: List(List(Inline)), rows: List(List(List(Inline))))
  Rule
  /// 空行の連なり(`Options.count_blanks`)。`count` は行の数 ── 畳まない。
  Blanks(count: Int)
}

pub type Inline {
  Plain(String)
  Strong(List(Inline))
  Emphasis(List(Inline))
  CodeSpan(String)
  Link(href: String, label: List(Inline))
}

// ── 読み方 ────────────────────────────────────────────────────────────────

pub type Options {
  Options(
    /// 先頭の `---` の行から次の `---` の行までを前書きとして読み、`Document.meta` に入れる(本文から外す)。
    /// 閉じの `---` が無ければ前書きは無い。
    front_matter: Bool,
    /// 行の頭と尻の空白を落としてから読む(字下げした印も印になる。入れ子は読めない)。
    trim_lines: Bool,
    /// 空行の連なりを `Blanks(数)` で返す。False は塊の区切りとして捨てる。
    count_blanks: Bool,
    /// `#` の数と見出しの段の対。対に無い数の `#` の行は字(段落)。`#` の後に空白が要る。
    headings: List(#(Int, Int)),
    rules: Rules,
    /// 箇条の印(`"-"`・`"*"`・`"+"`)。印の後に空白が要る。
    bullets: List(String),
    /// 番号の後の印(`"."`・`")"`)。番号は 1〜9 桁の数字、印の後に空白が要る。空なら番号の箇条を読まない。
    number_marks: List(String),
    /// 番号の箇条の始まりの数を残す。False は 1 から。
    number_start: Bool,
    /// 箇条の項目の中を塊として読む(字下げで入れ子・コードの塊、項目の間の空行、字下げの無い続きの行)。
    /// False は 1 行 1 項目で、印は行頭に詰めて書いたものだけ。
    nesting: Bool,
    /// ``` で囲んだコードの塊。
    code_blocks: Bool,
    /// `>` の引用(中は同じ読み方で塊に読む)。
    quotes: Bool,
    /// `|` の表(2 行目が `|---|` の区切り)。
    tables: Bool,
    line_breaks: LineBreaks,
    /// 行の中で読む記法。
    marks: List(Mark),
    links: Links,
  )
}

pub type Rules {
  NoRules
  /// 前後の空白を除いて `---` だけの行。`***`・`___`・`----` は字。
  OnlyDashes
  /// 空白を除いて `-`・`*`・`_` の 1 種が 3 つ以上の行。
  ThematicBreaks
}

pub type LineBreaks {
  /// 段落の中の改行を残す(描くと `br`)。行の中の記法は行ごとに読む。
  BreakLines
  /// 段落の行を `separator` でつないでから読む(`"\n"` は描くと空白に見える、`""` は詰める)。
  JoinLines(separator: String)
}

pub type Mark {
  /// `**太字**`。中身は空でなく、頭と尻が空白でない。太字は重ねない。
  StrongMark
  /// `*斜体*`。
  EmphasisMark
  /// `` `コード` ``(逆引用符の数を合わせる)と `<code>…</code>`。
  CodeMark
  /// `\` の次の字を字のまま。
  EscapeMark
  /// `&lt;`・`&gt;`・`&amp;`・`&quot;`・`&#数;` を字に戻す。
  EntityMark
  /// `<http…>` の自動リンク(`links` の柵を通る)。
  AutolinkMark
}

/// リンクの柵。柵を通らない `[字](URL)` は字のまま(`Link` にしない)。
pub type Links {
  NoLinks
  /// `http://`・`https://` の後に字があり、空白・`"`・`<`・`>` を含まない URL だけ。
  WebLinks
  /// `attr.safe_url` を通る URL(http・https・mailto・tel と scheme の無い相対)。前後の空白は落とす。
  SafeLinks
}

/// 文書の読み方 ── 見出し h1〜h6・段落(行はつないで読む)・コードの塊・表・引用・入れ子の箇条と番号(`.`・`)`)・
/// 区切り線、行の中のコード・太字・斜体・リンク(相対も通す)・自動リンク・`\` と文字参照。
pub fn document() -> Options {
  Options(
    front_matter: False,
    trim_lines: False,
    count_blanks: False,
    headings: [#(1, 1), #(2, 2), #(3, 3), #(4, 4), #(5, 5), #(6, 6)],
    rules: ThematicBreaks,
    bullets: ["-", "*", "+"],
    number_marks: [".", ")"],
    number_start: True,
    nesting: True,
    code_blocks: True,
    quotes: True,
    tables: True,
    line_breaks: JoinLines("\n"),
    marks: [
      EscapeMark,
      CodeMark,
      StrongMark,
      EmphasisMark,
      AutolinkMark,
      EntityMark,
    ],
    links: SafeLinks,
  )
}

/// 書き手の投稿の読み方 ── `#`・`##` は段 2、`###` は段 3、空行は数のまま(`Blanks`)、段落の中の改行は `br`、
/// `- `・`* ` の箇条と `1. ` の番号(1 行 1 項目、行頭に詰めて書いたものだけ)、前後の空白を除いて `---` だけの行は
/// 区切り線、行の中は太字と `http(s)` のリンクだけ。それ以外(表・引用・コード・斜体・入れ子)は字のまま。
pub fn post() -> Options {
  Options(
    front_matter: False,
    trim_lines: False,
    count_blanks: True,
    headings: [#(1, 2), #(2, 2), #(3, 3)],
    rules: OnlyDashes,
    bullets: ["-", "*"],
    number_marks: ["."],
    number_start: True,
    nesting: False,
    code_blocks: False,
    quotes: False,
    tables: False,
    line_breaks: BreakLines,
    marks: [StrongMark],
    links: WebLinks,
  )
}

/// 規約のような文の読み方 ── 前書き(`status: …` ほか)、行の頭と尻の空白を落とし、`#`〜`###` は段 1〜3、`- ` の
/// 箇条と `1. ` の番号(始まりの数は残さない)、段落の行は詰めて 1 行に。行の中の記法は読まない。
pub fn outline() -> Options {
  Options(
    front_matter: True,
    trim_lines: True,
    count_blanks: False,
    headings: [#(1, 1), #(2, 2), #(3, 3)],
    rules: NoRules,
    bullets: ["-"],
    number_marks: ["."],
    number_start: False,
    nesting: False,
    code_blocks: False,
    quotes: False,
    tables: False,
    line_breaks: JoinLines(""),
    marks: [],
    links: NoLinks,
  )
}

// ── 読む口 ────────────────────────────────────────────────────────────────

/// 本文を読む。`\r` は落とす。
pub fn parse(text: String, options: Options) -> Document {
  let lines =
    text
    |> string.replace("\r", "")
    |> string.split("\n")
  let #(meta, lines) = case options.front_matter {
    True -> front_matter(lines)
    False -> #([], lines)
  }
  let lines = case options.trim_lines {
    True -> list.map(lines, string.trim)
    False -> lines
  }
  Document(meta: meta, blocks: read(lines, options, []))
}

/// 本文を塊の並びに読む(前書きは捨てる)。
pub fn blocks(text: String, options: Options) -> List(Block) {
  parse(text, options).blocks
}

/// 前書きの欄。同じ名の欄は値の空でない最初のもの。
pub fn field(document: Document, name: String) -> Result(String, Nil) {
  list.find_map(document.meta, fn(pair) {
    case pair.0 == name && pair.1 != "" {
      True -> Ok(pair.1)
      False -> Error(Nil)
    }
  })
}

/// 行の中の記法を読む。
pub fn inlines(text: String, options: Options) -> List(Inline) {
  scan(string.to_graphemes(text), "", [], Scope(options, True, True))
}

/// 行の中の字だけ(記法の印を落とす。リンクは字、コードは中身)。
pub fn inline_text(items: List(Inline)) -> String {
  list.map(items, fn(item) {
    case item {
      Plain(value) | CodeSpan(value) -> value
      Strong(children) | Emphasis(children) -> inline_text(children)
      Link(_, label) -> inline_text(label)
    }
  })
  |> string.concat
}

/// 区切り線の行か(`Options.rules`)。
pub fn rule(line: String, options: Options) -> Bool {
  is_rule(string.trim(string.replace(line, "\r", "")), options.rules)
}

/// 記法の印を落とした字(一覧の抜粋)。行ごとに読み、行の数と順を変えない ── 区切り線の行だけを落とす。
/// 見出しの `#`・箇条の印・行の中の記法を落とし、番号の箇条の `1. ` は字のまま残す。それ以外の行は
/// 書いたまま(行の中の記法だけを落とす)。コードの塊も行として読む。
pub fn plain(text: String, options: Options) -> String {
  string.split(text, "\n")
  |> list.filter(fn(line) { !rule(line, options) })
  |> list.map(plain_line(_, options))
  |> string.join("\n")
}

fn plain_line(line: String, options: Options) -> String {
  let clean = clean_line(line, options)
  case heading_of(clean, options) {
    Ok(#(_, text)) -> inline_text(inlines(text, options))
    Error(_) ->
      case marker_of(clean, options) {
        Ok(Marker(indent: 0, ordered: False, ..) as marker) ->
          inline_text(inlines(item_text(clean, marker), options))
        Ok(Marker(indent: 0, ordered: True, width: width, ..) as marker) ->
          string.slice(clean, 0, width)
          <> inline_text(inlines(item_text(clean, marker), options))
        _ -> inline_text(inlines(line, options))
      }
  }
}

fn clean_line(line: String, options: Options) -> String {
  let line = string.replace(line, "\r", "")
  case options.trim_lines {
    True -> string.trim(line)
    False -> string.trim_end(line)
  }
}

// ── 前書き ──────────────────────────────────────────────────────────────

fn front_matter(
  lines: List(String),
) -> #(List(#(String, String)), List(String)) {
  case lines {
    [first, ..rest] ->
      case string.trim(first) == "---" {
        True ->
          case list.split_while(rest, fn(line) { string.trim(line) != "---" }) {
            #(head, [_, ..body]) -> #(list.filter_map(head, meta_pair), body)
            #(_, []) -> #([], lines)
          }
        False -> #([], lines)
      }
    [] -> #([], [])
  }
}

fn meta_pair(line: String) -> Result(#(String, String), Nil) {
  case string.split_once(line, ":") {
    Ok(#(key, value)) -> Ok(#(string.trim(key), string.trim(value)))
    Error(_) -> Error(Nil)
  }
}

// ── 塊 ──────────────────────────────────────────────────────────────────

fn read(lines: List(String), o: Options, acc: List(Block)) -> List(Block) {
  case lines {
    [] -> list.reverse(acc)
    [line, ..rest] ->
      case is_blank(line) {
        True ->
          case o.count_blanks {
            True -> {
              let #(count, after) = take_blanks(lines, 0)
              read(after, o, [Blanks(count), ..acc])
            }
            False -> read(rest, o, acc)
          }
        False -> {
          let #(block, after) = block_at(line, rest, o)
          read(after, o, [block, ..acc])
        }
      }
  }
}

fn is_blank(line: String) -> Bool {
  string.trim(line) == ""
}

fn take_blanks(lines: List(String), count: Int) -> #(Int, List(String)) {
  case lines {
    [line, ..rest] ->
      case is_blank(line) {
        True -> take_blanks(rest, count + 1)
        False -> #(count, lines)
      }
    [] -> #(count, lines)
  }
}

/// 空でない行から始まる塊を 1 つ読む。
fn block_at(
  line: String,
  rest: List(String),
  o: Options,
) -> #(Block, List(String)) {
  let clean = string.trim_end(line)
  case fence_open(line, o) {
    Ok(lang) -> {
      let #(body, after) = take_fenced(rest, [])
      #(Code(lang, string.join(body, "\n")), after)
    }
    Error(_) ->
      case heading_of(clean, o) {
        Ok(#(level, text)) -> #(Heading(level, inlines(text, o)), rest)
        Error(_) ->
          case is_rule(string.trim(clean), o.rules) {
            True -> #(Rule, rest)
            False ->
              case quote_start(line, o) {
                True -> {
                  let #(quoted, after) = take_quote([line, ..rest], [])
                  #(Quote(read(quoted, o, [])), after)
                }
                False ->
                  case table_start([line, ..rest], o) {
                    True -> take_table(line, rest, o)
                    False ->
                      case marker_of(clean, o) {
                        Ok(marker) -> take_list([line, ..rest], marker, o)
                        Error(_) -> take_paragraph([line, ..rest], [], o)
                      }
                  }
              }
          }
      }
  }
}

/// その行から塊が始まるか(段落を閉じる・項目の続きを止める)。
fn starts_block(lines: List(String), o: Options) -> Bool {
  case lines {
    [] -> False
    [line, ..] -> {
      let clean = string.trim_end(line)
      result_ok(fence_open(line, o))
      || result_ok(heading_of(clean, o))
      || is_rule(string.trim(clean), o.rules)
      || quote_start(line, o)
      || table_start(lines, o)
      || result_ok(marker_of(clean, o))
    }
  }
}

fn result_ok(value: Result(a, b)) -> Bool {
  case value {
    Ok(_) -> True
    Error(_) -> False
  }
}

/// ``` で始まる行(前に空白があってよい)。言語名は最初の語。
fn fence_open(line: String, o: Options) -> Result(String, Nil) {
  case o.code_blocks, string.trim_start(line) {
    True, "```" <> rest ->
      case string.split(string.trim(rest), " ") {
        [first, ..] -> Ok(first)
        [] -> Ok("")
      }
    _, _ -> Error(Nil)
  }
}

/// 閉じの ``` の行まで。閉じが無ければ最後まで。
fn take_fenced(
  lines: List(String),
  acc: List(String),
) -> #(List(String), List(String)) {
  case lines {
    [] -> #(list.reverse(acc), [])
    [line, ..rest] ->
      case string.starts_with(string.trim_start(line), "```") {
        True -> #(list.reverse(acc), rest)
        False -> take_fenced(rest, [line, ..acc])
      }
  }
}

/// 行頭の `#` の数(対に在るもの)、空白、字。戻りは #(段, 字)。
fn heading_of(clean: String, o: Options) -> Result(#(Int, String), Nil) {
  let count = count_hashes(clean, 0)
  case count, list.key_find(o.headings, count) {
    0, _ -> Error(Nil)
    _, Ok(level) -> {
      let rest = string.drop_start(clean, count)
      case string.starts_with(rest, " ") {
        True ->
          case string.trim(rest) {
            "" -> Error(Nil)
            text -> Ok(#(level, text))
          }
        False -> Error(Nil)
      }
    }
    _, Error(_) -> Error(Nil)
  }
}

fn count_hashes(text: String, count: Int) -> Int {
  case text {
    "#" <> rest -> count_hashes(rest, count + 1)
    _ -> count
  }
}

fn is_rule(trimmed: String, rules: Rules) -> Bool {
  case rules {
    NoRules -> False
    OnlyDashes -> trimmed == "---"
    ThematicBreaks -> {
      let compact = string.replace(trimmed, " ", "")
      let size = string.length(compact)
      size >= 3
      && list.any(["-", "*", "_"], fn(char) {
        compact == string.repeat(char, size)
      })
    }
  }
}

fn quote_start(line: String, o: Options) -> Bool {
  o.quotes && string.starts_with(string.trim_start(line), ">")
}

fn take_quote(
  lines: List(String),
  acc: List(String),
) -> #(List(String), List(String)) {
  case lines {
    [line, ..rest] ->
      case string.trim_start(line) {
        ">" <> inner -> {
          let inner = case inner {
            " " <> more -> more
            _ -> inner
          }
          take_quote(rest, [inner, ..acc])
        }
        _ -> #(list.reverse(acc), lines)
      }
    [] -> #(list.reverse(acc), [])
  }
}

fn take_paragraph(
  lines: List(String),
  acc: List(String),
  o: Options,
) -> #(Block, List(String)) {
  let done = fn(after) {
    let lines = list.reverse(acc)
    let block = case o.line_breaks {
      BreakLines -> Paragraph(list.map(lines, inlines(_, o)))
      JoinLines(separator) ->
        Paragraph([inlines(string.join(lines, separator), o)])
    }
    #(block, after)
  }
  case lines {
    [] -> done([])
    [line, ..rest] ->
      case is_blank(line) || { acc != [] && starts_block(lines, o) } {
        True -> done(lines)
        False -> take_paragraph(rest, [string.trim_end(line), ..acc], o)
      }
  }
}

// ── 表 ──────────────────────────────────────────────────────────────────

fn table_start(lines: List(String), o: Options) -> Bool {
  case o.tables, lines {
    True, [head, separator, ..] ->
      string.starts_with(string.trim(head), "|") && is_separator(separator)
    _, _ -> False
  }
}

fn is_separator(line: String) -> Bool {
  let trimmed = string.trim(line)
  string.starts_with(trimmed, "|")
  && string.contains(trimmed, "-")
  && list.all(string.to_graphemes(trimmed), fn(char) {
    char == "|" || char == "-" || char == ":" || char == " "
  })
}

fn take_table(
  head: String,
  rest: List(String),
  o: Options,
) -> #(Block, List(String)) {
  let rest = list.drop(rest, 1)
  let #(rows, after) =
    list.split_while(rest, fn(line) {
      string.starts_with(string.trim(line), "|")
    })
  #(Table(row_cells(head, o), list.map(rows, row_cells(_, o))), after)
}

/// 行を `|` で割ってセルにする。コードの中の `|` と `\|` は割らない。
fn row_cells(line: String, o: Options) -> List(List(Inline)) {
  let trimmed = string.trim(line)
  let inner = case trimmed {
    "|" <> more -> more
    _ -> trimmed
  }
  let inner = case
    string.ends_with(inner, "|") && !string.ends_with(inner, "\\|")
  {
    True -> string.drop_end(inner, 1)
    False -> inner
  }
  split_cells(string.to_graphemes(inner), "", False, [])
  |> list.map(fn(cell) { inlines(string.trim(cell), o) })
}

fn split_cells(
  chars: List(String),
  buffer: String,
  in_code: Bool,
  acc: List(String),
) -> List(String) {
  case chars {
    [] -> list.reverse([buffer, ..acc])
    ["\\", "|", ..rest] -> split_cells(rest, buffer <> "|", in_code, acc)
    ["`", ..rest] -> split_cells(rest, buffer <> "`", !in_code, acc)
    ["|", ..rest] ->
      case in_code {
        True -> split_cells(rest, buffer <> "|", in_code, acc)
        False -> split_cells(rest, "", in_code, [buffer, ..acc])
      }
    [char, ..rest] -> split_cells(rest, buffer <> char, in_code, acc)
  }
}

// ── 箇条 ────────────────────────────────────────────────────────────────

/// 行頭の印。`indent` は印の前の空白、`width` は印と後ろの空白 1 つの幅(項目の字の始まりまで)。
type Marker {
  Marker(indent: Int, width: Int, ordered: Bool, number: Int)
}

fn marker_of(clean: String, o: Options) -> Result(Marker, Nil) {
  let stripped = string.trim_start(clean)
  let indent = string.length(clean) - string.length(stripped)
  case o.nesting || indent == 0 {
    False -> Error(Nil)
    True ->
      case
        list.any(o.bullets, fn(mark) {
          string.starts_with(stripped, mark <> " ")
        })
      {
        True -> Ok(Marker(indent, 2, False, 0))
        False -> number_marker(stripped, indent, o)
      }
  }
}

fn number_marker(
  stripped: String,
  indent: Int,
  o: Options,
) -> Result(Marker, Nil) {
  let digits = take_digits(string.to_graphemes(stripped), "")
  let size = string.length(digits)
  case size >= 1 && size <= 9 {
    False -> Error(Nil)
    True -> {
      let after = string.drop_start(stripped, size)
      case
        list.find(o.number_marks, fn(mark) {
          string.starts_with(after, mark <> " ")
        }),
        int.parse(digits)
      {
        Ok(mark), Ok(number) ->
          Ok(Marker(indent, size + string.length(mark) + 1, True, number))
        _, _ -> Error(Nil)
      }
    }
  }
}

fn take_digits(chars: List(String), acc: String) -> String {
  case chars {
    [char, ..rest] ->
      case string.contains("0123456789", char) {
        True -> take_digits(rest, acc <> char)
        False -> acc
      }
    [] -> acc
  }
}

/// 1 行の項目の字(印の後ろ、頭と尻の空白を落とす)。
fn item_text(clean: String, marker: Marker) -> String {
  string.trim(string.drop_start(clean, marker.indent + marker.width))
}

fn take_list(
  lines: List(String),
  marker: Marker,
  o: Options,
) -> #(Block, List(String)) {
  let #(items, after) = case o.nesting {
    True -> {
      let #(items, after) = collect_items(lines, marker, o, [])
      #(list.map(items, read(_, o, [])), after)
    }
    False -> flat_items(lines, marker, o, [])
  }
  let start = case o.number_start {
    True -> marker.number
    False -> 1
  }
  case marker.ordered {
    True -> #(Numbered(start, items), after)
    False -> #(Bullets(items), after)
  }
}

/// 1 行 1 項目。同じ種類(箇条か番号か)の印の行が続く間。
fn flat_items(
  lines: List(String),
  marker: Marker,
  o: Options,
  acc: List(List(Block)),
) -> #(List(List(Block)), List(String)) {
  case lines {
    [line, ..rest] -> {
      let clean = string.trim_end(line)
      case marker_of(clean, o) {
        Ok(found) if found.ordered == marker.ordered -> {
          let text = item_text(clean, found)
          flat_items(rest, marker, o, [[Paragraph([inlines(text, o)])], ..acc])
        }
        _ -> #(list.reverse(acc), lines)
      }
    }
    [] -> #(list.reverse(acc), [])
  }
}

/// 同じ深さの印の並びを 1 つの箇条にする。項目の中身は、印の幅だけ字下げを戻した行の並び。
fn collect_items(
  lines: List(String),
  marker: Marker,
  o: Options,
  acc: List(List(String)),
) -> #(List(List(String)), List(String)) {
  case lines {
    [line, ..rest] ->
      case marker_of(string.trim_end(line), o) {
        Ok(found)
          if found.indent == marker.indent && found.ordered == marker.ordered
        -> {
          let first = string.drop_start(string.trim_start(line), found.width)
          let #(more, after) =
            take_item_body(rest, marker.indent + found.width, o, [])
          collect_items(skip_blank_before_marker(after, marker, o), marker, o, [
            [first, ..more],
            ..acc
          ])
        }
        _ -> #(list.reverse(acc), lines)
      }
    [] -> #(list.reverse(acc), [])
  }
}

/// 項目と項目の間の空行は、次の行が同じ深さの印のときだけ飛ばす。
fn skip_blank_before_marker(
  lines: List(String),
  marker: Marker,
  o: Options,
) -> List(String) {
  case lines {
    [line, ..rest] ->
      case is_blank(line) {
        True ->
          case next_nonblank(rest) {
            Ok(next) ->
              case marker_of(string.trim_end(next), o) {
                Ok(found)
                  if found.indent == marker.indent
                  && found.ordered == marker.ordered
                -> skip_blank_before_marker(rest, marker, o)
                _ -> lines
              }
            Error(_) -> lines
          }
        False -> lines
      }
    [] -> []
  }
}

fn next_nonblank(lines: List(String)) -> Result(String, Nil) {
  case lines {
    [] -> Error(Nil)
    [line, ..rest] ->
      case is_blank(line) {
        True -> next_nonblank(rest)
        False -> Ok(line)
      }
  }
}

/// 項目の続き:空行と、字の始まり(`content_indent`)以上に字下げした行。字下げを戻して返す。空行の後に
/// 字下げの無い行が来たら項目は終わり。字下げの無い行は、前が字の行で、塊の始まりでなければ続き。
fn take_item_body(
  lines: List(String),
  content_indent: Int,
  o: Options,
  acc: List(String),
) -> #(List(String), List(String)) {
  case lines {
    [] -> #(list.reverse(acc), [])
    [line, ..rest] ->
      case is_blank(line) {
        True ->
          case next_nonblank(rest) {
            Ok(next) ->
              case indent_of(next) >= content_indent {
                True -> take_item_body(rest, content_indent, o, ["", ..acc])
                False -> #(list.reverse(acc), lines)
              }
            Error(_) -> #(list.reverse(acc), lines)
          }
        False ->
          case indent_of(line) >= content_indent {
            True ->
              take_item_body(rest, content_indent, o, [
                string.drop_start(line, content_indent),
                ..acc
              ])
            False ->
              case starts_block(lines, o), acc {
                True, _ | _, [] -> #(list.reverse(acc), lines)
                False, [previous, ..] ->
                  case is_blank(previous) {
                    True -> #(list.reverse(acc), lines)
                    False ->
                      take_item_body(rest, content_indent, o, [
                        string.trim_start(line),
                        ..acc
                      ])
                  }
              }
          }
      }
  }
}

fn indent_of(line: String) -> Int {
  string.length(line) - string.length(string.trim_start(line))
}

// ── 行の中 ──────────────────────────────────────────────────────────────

/// 読んでいる所。太字の中では太字を、リンクの字の中ではリンクを読まない(読む字は必ず短くなり、回り続けない)。
type Scope {
  Scope(options: Options, strong: Bool, link: Bool)
}

fn has(scope: Scope, mark: Mark) -> Bool {
  list.contains(scope.options.marks, mark)
}

fn flush(acc: List(Inline), buffer: String) -> List(Inline) {
  case buffer {
    "" -> acc
    _ -> [Plain(buffer), ..acc]
  }
}

/// 左から読む。開いた印が閉じなければ印を字として出し、その後ろから読み直す。
fn scan(
  chars: List(String),
  buffer: String,
  acc: List(Inline),
  scope: Scope,
) -> List(Inline) {
  case chars {
    [] -> list.reverse(flush(acc, buffer))
    ["\\", next, ..rest] ->
      case has(scope, EscapeMark) {
        True -> scan(rest, buffer <> next, acc, scope)
        False -> scan([next, ..rest], buffer <> "\\", acc, scope)
      }
    // 画像の記法(`![`)はリンクとして読まない
    ["!", "[", ..rest] -> scan(rest, buffer <> "![", acc, scope)
    ["`", ..rest] ->
      case has(scope, CodeMark) {
        True -> code_span(rest, buffer, acc, scope)
        False -> scan(rest, buffer <> "`", acc, scope)
      }
    ["*", "*", ..rest] ->
      case scope.strong && has(scope, StrongMark) {
        True ->
          case split_at(rest, ["*", "*"], has(scope, EscapeMark)) {
            Ok(#(inner, after)) ->
              case
                inner != []
                && string.trim(string.concat(inner)) == string.concat(inner)
              {
                True ->
                  scan(
                    after,
                    "",
                    [
                      Strong(scan(inner, "", [], Scope(..scope, strong: False))),
                      ..flush(acc, buffer)
                    ],
                    scope,
                  )
                False -> scan(rest, buffer <> "**", acc, scope)
              }
            Error(_) -> scan(rest, buffer <> "**", acc, scope)
          }
        False ->
          case has(scope, EmphasisMark) {
            True -> scan(rest, buffer <> "**", acc, scope)
            False -> scan(["*", ..rest], buffer <> "*", acc, scope)
          }
      }
    ["*", next, ..rest] if next != " " && next != "*" ->
      case has(scope, EmphasisMark) {
        True ->
          case split_at([next, ..rest], ["*"], has(scope, EscapeMark)) {
            Ok(#(inner, after)) ->
              scan(
                after,
                "",
                [Emphasis(scan(inner, "", [], scope)), ..flush(acc, buffer)],
                scope,
              )
            Error(_) -> scan([next, ..rest], buffer <> "*", acc, scope)
          }
        False -> scan([next, ..rest], buffer <> "*", acc, scope)
      }
    ["[", ..rest] ->
      case scope.link && scope.options.links != NoLinks {
        True ->
          case anchor(rest, scope) {
            Ok(#(label, href, after)) ->
              scan(
                after,
                "",
                [
                  Link(href, scan(label, "", [], Scope(..scope, link: False))),
                  ..flush(acc, buffer)
                ],
                scope,
              )
            Error(_) -> scan(rest, buffer <> "[", acc, scope)
          }
        False -> scan(rest, buffer <> "[", acc, scope)
      }
    ["<", "c", "o", "d", "e", ">", ..rest] ->
      case
        has(scope, CodeMark),
        split_at(rest, string.to_graphemes("</code>"), has(scope, EscapeMark))
      {
        True, Ok(#(inner, after)) ->
          scan(
            after,
            "",
            [CodeSpan(pipe_entity(string.concat(inner))), ..flush(acc, buffer)],
            scope,
          )
        True, Error(_) -> scan(rest, buffer <> "<code>", acc, scope)
        False, _ ->
          scan(["c", "o", "d", "e", ">", ..rest], buffer <> "<", acc, scope)
      }
    ["<", "h", "t", "t", "p", ..rest] -> {
      let after_angle = ["h", "t", "t", "p", ..rest]
      case has(scope, AutolinkMark) && scope.link {
        True ->
          case split_at(after_angle, [">"], has(scope, EscapeMark)) {
            Ok(#(url, after)) -> {
              let href = string.concat(url)
              case !string.contains(href, " ") && link_allowed(href, scope) {
                True ->
                  scan(
                    after,
                    "",
                    [Link(href, [Plain(href)]), ..flush(acc, buffer)],
                    scope,
                  )
                False -> scan(after_angle, buffer <> "<", acc, scope)
              }
            }
            Error(_) -> scan(after_angle, buffer <> "<", acc, scope)
          }
        False -> scan(after_angle, buffer <> "<", acc, scope)
      }
    }
    ["&", ..rest] ->
      case has(scope, EntityMark) {
        True ->
          case entity(rest) {
            Ok(#(text, after)) -> scan(after, buffer <> text, acc, scope)
            Error(_) -> scan(rest, buffer <> "&", acc, scope)
          }
        False -> scan(rest, buffer <> "&", acc, scope)
      }
    [char, ..rest] -> scan(rest, buffer <> char, acc, scope)
  }
}

fn code_span(
  rest: List(String),
  buffer: String,
  acc: List(Inline),
  scope: Scope,
) -> List(Inline) {
  let #(ticks, after_ticks) = take_ticks(rest, 1)
  case split_at(after_ticks, list.repeat("`", ticks), has(scope, EscapeMark)) {
    Ok(#(inner, after)) ->
      scan(
        after,
        "",
        [
          CodeSpan(pipe_entity(trim_code(string.concat(inner)))),
          ..flush(acc, buffer)
        ],
        scope,
      )
    Error(_) ->
      scan(after_ticks, buffer <> string.repeat("`", ticks), acc, scope)
  }
}

fn take_ticks(chars: List(String), count: Int) -> #(Int, List(String)) {
  case chars {
    ["`", ..rest] -> take_ticks(rest, count + 1)
    _ -> #(count, chars)
  }
}

/// 表の中の `|` は `&#124;` と書く(コードの中でも)。コードの中でも `|` に戻す。
fn pipe_entity(text: String) -> String {
  string.replace(text, "&#124;", "|")
}

/// コードの前後の空白は 1 つだけ落とす(`` ` `` を含むコードを書くための空白)。
fn trim_code(text: String) -> String {
  case
    string.starts_with(text, " ")
    && string.ends_with(text, " ")
    && string.trim(text) != ""
  {
    True -> text |> string.drop_start(1) |> string.drop_end(1)
    False -> text
  }
}

/// `[` の後ろ:`字](URL)`。字は空白だけでなく、`[`・`]` を含まない。URL は `links` の柵を通るもの。
fn anchor(
  rest: List(String),
  scope: Scope,
) -> Result(#(List(String), String, List(String)), Nil) {
  let escapes = has(scope, EscapeMark)
  case split_at(rest, ["]", "("], escapes) {
    Error(_) -> Error(Nil)
    Ok(#(label, after)) -> {
      let text = string.concat(label)
      case
        string.trim(text) != ""
        && !string.contains(text, "[")
        && !string.contains(text, "]")
      {
        False -> Error(Nil)
        True ->
          case split_at(after, [")"], escapes) {
            Error(_) -> Error(Nil)
            Ok(#(url, tail)) -> {
              let href = case scope.options.links {
                SafeLinks -> string.trim(string.concat(url))
                _ -> string.concat(url)
              }
              case link_allowed(href, scope) {
                True -> Ok(#(label, href, tail))
                False -> Error(Nil)
              }
            }
          }
      }
    }
  }
}

fn link_allowed(href: String, scope: Scope) -> Bool {
  case scope.options.links {
    NoLinks -> False
    WebLinks -> web_url(href)
    SafeLinks -> attr.safe_url(href)
  }
}

/// `http://`・`https://` の後ろに字があり、空白と `"` `<` `>` を含まない。
fn web_url(href: String) -> Bool {
  let rest = case string.lowercase(href) {
    "https://" <> rest -> Ok(rest)
    "http://" <> rest -> Ok(rest)
    _ -> Error(Nil)
  }
  case rest {
    Ok("") | Error(_) -> False
    Ok(_) ->
      list.all(string.to_graphemes(href), fn(char) {
        !string.contains(forbidden, char)
      })
  }
}

const forbidden: String = " \t\n\r\u{0B}\u{0C}\u{A0}\u{3000}\u{2028}\u{2029}\u{FEFF}\"<>"

/// `&lt;` `&gt;` `&amp;` `&quot;` と `&#数;` を字に戻す。
fn entity(chars: List(String)) -> Result(#(String, List(String)), Nil) {
  case split_at(list.take(chars, 8), [";"], False) {
    Ok(#(name, _)) -> {
      let after = list.drop(chars, list.length(name) + 1)
      case string.concat(name) {
        "lt" -> Ok(#("<", after))
        "gt" -> Ok(#(">", after))
        "amp" -> Ok(#("&", after))
        "quot" -> Ok(#("\"", after))
        "#" <> digits ->
          case int.parse(digits) {
            Ok(code) ->
              case string.utf_codepoint(code) {
                Ok(point) -> Ok(#(string.from_utf_codepoints([point]), after))
                Error(_) -> Error(Nil)
              }
            Error(_) -> Error(Nil)
          }
        _ -> Error(Nil)
      }
    }
    Error(_) -> Error(Nil)
  }
}

/// `marker`(字の並び)が最初に現れる所で割る。前と、印の後ろ。`escapes` なら `\` の次の字は印と見ない。
fn split_at(
  chars: List(String),
  marker: List(String),
  escapes: Bool,
) -> Result(#(List(String), List(String)), Nil) {
  split_loop(chars, marker, escapes, [])
}

fn split_loop(
  chars: List(String),
  marker: List(String),
  escapes: Bool,
  before: List(String),
) -> Result(#(List(String), List(String)), Nil) {
  case starts_with_list(chars, marker) {
    True -> Ok(#(list.reverse(before), list.drop(chars, list.length(marker))))
    False ->
      case chars, escapes {
        [], _ -> Error(Nil)
        ["\\", next, ..rest], True ->
          split_loop(rest, marker, escapes, [next, "\\", ..before])
        [char, ..rest], _ -> split_loop(rest, marker, escapes, [char, ..before])
      }
  }
}

fn starts_with_list(chars: List(String), marker: List(String)) -> Bool {
  case chars, marker {
    _, [] -> True
    [char, ..rest], [mark, ..more] if char == mark ->
      starts_with_list(rest, more)
    _, _ -> False
  }
}

// ── 描き方 ──────────────────────────────────────────────────────────────

/// 要素に付ける class と属性。
pub type Part {
  Part(class: css.Class, attributes: List(Attribute))
}

/// 要素の種類ごとの `Part`。`bare()` から替えたい欄だけを替える(`Look(..markdown.bare(), paragraph: ..)`)。
pub type Look {
  Look(
    /// 段(1〜6)ごとの見出し。タグは `h1`〜`h6`。
    heading: fn(Int) -> Part,
    paragraph: Part,
    /// 空行 1 行分の空き(`Blanks`)。`aria-hidden` の `p` に U+00A0 を 1 つ。
    blank: Part,
    /// コードの塊の `pre`(中に `code`)。言語名は `data-lang`。
    code: Part,
    /// `pre` を包む `div`(横に送る枠など)。None は包まない。
    code_frame: Option(Part),
    quote: Part,
    bullets: Part,
    numbered: Part,
    item: Part,
    table: Part,
    /// `table` を包む `div`。None は包まない。
    table_frame: Option(Part),
    /// 見出しのセル(`th`、`scope="col"`)。
    header_cell: Part,
    cell: Part,
    rule: Part,
    strong: Part,
    emphasis: Part,
    code_span: Part,
    /// リンクの `a`(`href` は木の値)。`rel` などはここに。
    link: Part,
    spaces: Spaces,
  )
}

pub type Spaces {
  /// 字はそのまま(HTML が空白の連なりを 1 つに畳む)。
  CollapseSpaces
  /// 行頭の半角の空白の連なりと、行の中の 2 つ以上の連なりを U+00A0 にして見た目に残す(1 つの空白はそのまま)。
  KeepSpaces
}

fn no_part() -> Part {
  Part(class: css.class([]), attributes: [])
}

/// class も属性も付けない描き方。
pub fn bare() -> Look {
  Look(
    heading: fn(_) { no_part() },
    paragraph: no_part(),
    blank: no_part(),
    code: no_part(),
    code_frame: None,
    quote: no_part(),
    bullets: no_part(),
    numbered: no_part(),
    item: no_part(),
    table: no_part(),
    table_frame: None,
    header_cell: no_part(),
    cell: no_part(),
    rule: no_part(),
    strong: no_part(),
    emphasis: no_part(),
    code_span: no_part(),
    link: no_part(),
    spaces: CollapseSpaces,
  )
}

/// 本文を読んで描く Component。塊の並びを 1 つの断片で返す(包む要素は app が置く)。
pub fn view(text: String, options: Options, look: Look) -> Element {
  el.fragment(render(blocks(text, options), look))
}

/// 読んだ木を描く。
pub fn render(items: List(Block), look: Look) -> List(Element) {
  list.flat_map(items, render_block(_, look))
}

fn render_block(block: Block, look: Look) -> List(Element) {
  case block {
    Heading(level, inlines) -> {
      let part = look.heading(level)
      let make = case level {
        1 -> html.h1
        2 -> html.h2
        3 -> html.h3
        4 -> html.h4
        5 -> html.h5
        _ -> html.h6
      }
      [make(part.class, part.attributes, render_inlines(inlines, look))]
    }
    Paragraph(lines) -> [
      html.p(
        look.paragraph.class,
        look.paragraph.attributes,
        lines_view(lines, look),
      ),
    ]
    Blanks(count) ->
      list.repeat(
        html.p(
          look.blank.class,
          [attr.aria_hidden(True), ..look.blank.attributes],
          [el.text("\u{a0}")],
        ),
        count,
      )
    Code(lang, text) -> {
      let lang_attribute = case lang {
        "" -> []
        _ -> [attr.data("lang", lang)]
      }
      let pre =
        html.pre(
          look.code.class,
          list.append(look.code.attributes, lang_attribute),
          [html.code_([], [el.text(text)])],
        )
      [framed(pre, look.code_frame)]
    }
    Quote(items) -> [
      html.blockquote(
        look.quote.class,
        look.quote.attributes,
        render(items, look),
      ),
    ]
    Bullets(items) -> [
      html.ul(
        look.bullets.class,
        look.bullets.attributes,
        list.map(items, item_view(_, [], look)),
      ),
    ]
    Numbered(start, items) -> [
      html.ol(
        look.numbered.class,
        look.numbered.attributes,
        // 始まりの数は先頭の `li` の `value` で持つ
        list.index_map(items, fn(item, index) {
          case index, start {
            0, 1 -> item_view(item, [], look)
            0, _ -> item_view(item, [attr.value(int.to_string(start))], look)
            _, _ -> item_view(item, [], look)
          }
        }),
      ),
    ]
    Table(header, rows) -> {
      let head =
        html.thead_([], [
          html.tr_(
            [],
            list.map(header, fn(cell) {
              html.th(
                look.header_cell.class,
                [attr.scope("col"), ..look.header_cell.attributes],
                render_inlines(cell, look),
              )
            }),
          ),
        ])
      let body =
        html.tbody_(
          [],
          list.map(rows, fn(row) {
            html.tr_(
              [],
              list.map(row, fn(cell) {
                html.td(
                  look.cell.class,
                  look.cell.attributes,
                  render_inlines(cell, look),
                )
              }),
            )
          }),
        )
      [
        framed(
          html.table(look.table.class, look.table.attributes, [head, body]),
          look.table_frame,
        ),
      ]
    }
    Rule -> [html.hr(look.rule.class, look.rule.attributes)]
  }
}

fn framed(element: Element, frame: Option(Part)) -> Element {
  case frame {
    Some(part) -> html.div(part.class, part.attributes, [element])
    None -> element
  }
}

/// 項目の先頭が段落なら、段落の `p` を外して字を直に置く(1 行の項目は `li` の中に字だけ)。
fn item_view(item: List(Block), extra: List(Attribute), look: Look) -> Element {
  let children = case item {
    [Paragraph(lines), ..rest] ->
      list.append(lines_view(lines, look), render(rest, look))
    _ -> render(item, look)
  }
  html.li(look.item.class, list.append(look.item.attributes, extra), children)
}

/// 行ごとに描いて、行の間に `br` を置く。
fn lines_view(lines: List(List(Inline)), look: Look) -> List(Element) {
  list.index_map(lines, fn(line, index) {
    case index {
      0 -> render_inlines(line, look)
      _ -> [html.br_([]), ..render_inlines(line, look)]
    }
  })
  |> list.flatten
}

/// 行の中を描く。字は必ず `el.text`(escape される)。
pub fn render_inlines(items: List(Inline), look: Look) -> List(Element) {
  list.index_map(items, fn(item, index) { inline_view(item, index == 0, look) })
}

fn inline_view(item: Inline, at_line_start: Bool, look: Look) -> Element {
  case item {
    Plain(value) ->
      el.text(case look.spaces {
        CollapseSpaces -> value
        KeepSpaces -> keep_spaces(value, at_line_start)
      })
    Strong(children) ->
      html.strong(
        look.strong.class,
        look.strong.attributes,
        render_inlines(children, look),
      )
    Emphasis(children) ->
      html.em(
        look.emphasis.class,
        look.emphasis.attributes,
        render_inlines(children, look),
      )
    CodeSpan(value) ->
      html.code(look.code_span.class, look.code_span.attributes, [
        el.text(value),
      ])
    Link(href, label) ->
      html.a(
        look.link.class,
        [attr.href(href), ..look.link.attributes],
        render_inlines(label, look),
      )
  }
}

/// HTML は空白の連なりを 1 つに畳み、行頭の空白を消す。行頭の連なりと行の中の 2 つ以上の連なりは U+00A0 に
/// 置き換える(1 つの空白はそのまま)。全角の空白はもとから畳まれないので触らない。
fn keep_spaces(text: String, at_line_start: Bool) -> String {
  let graphemes = string.to_graphemes(text)
  let #(lead, rest) = case at_line_start {
    True -> list.split_while(graphemes, fn(char) { char == " " })
    False -> #([], graphemes)
  }
  let acc = case lead {
    [] -> []
    many -> [string.repeat(nbsp, list.length(many))]
  }
  keep_runs(rest, acc)
  |> list.reverse
  |> string.concat
}

fn keep_runs(graphemes: List(String), acc: List(String)) -> List(String) {
  case graphemes {
    [] -> acc
    _ -> {
      let #(spaces, after_spaces) =
        list.split_while(graphemes, fn(char) { char == " " })
      let #(word, rest) =
        list.split_while(after_spaces, fn(char) { char != " " })
      let acc = case spaces {
        [] -> acc
        [_] -> [" ", ..acc]
        many -> [string.repeat(nbsp, list.length(many)), ..acc]
      }
      let acc = case word {
        [] -> acc
        _ -> [string.concat(word), ..acc]
      }
      keep_runs(rest, acc)
    }
  }
}

const nbsp: String = "\u{a0}"
