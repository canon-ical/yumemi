//// block-door(0.14.1)── 断片の口と `yumemi.block` を `Live` でない Block にも開ける。
//// 生成器は頁の sp の `Fixed` の Block に loader の断片の関数 `block_<name>`(`<yumemi-block name>` で包む)・shell の
//// `blocks` の表と断片の口・門の数えない印を書き、逃げ道のある面の client.mjs に `block.mjs` だけを読ませる。
//// client の runtime(`yumemi/front/block.mjs`)は Playwright で回す(`yumemi_block_door_check.mjs`)、生成した shell の
//// 断片の口は node で叩く(`yumemi_block_door_shell_check.mjs`)。

import glance
import gleam/list
import gleam/string
import gleeunit/should
import simplifile
import yumemi/gen/emit/front as front_emit
import yumemi/gen/emit/hash
import yumemi/gen/face
import yumemi/gen/reader
import yumemi/gen/reader/front as reader_front
import yumemi/gen/source

@external(javascript, "./yumemi_block_door_test_ffi.mjs", "browser_check")
fn browser_check() -> String

@external(javascript, "./yumemi_block_door_test_ffi.mjs", "shell_check")
fn shell_check() -> String

const article_fixture = "gen/fixtures/article"

const page_path = "pages/article/arg_slug/page"

fn unit(path: String, text: String) -> source.Unit {
  let assert Ok(module) = glance.module(text)
  source.Unit(path: path, text: text, module: module)
}

fn replace(
  units: List(source.Unit),
  extra: List(source.Unit),
) -> List(source.Unit) {
  let paths = list.map(extra, fn(item) { item.path })
  list.append(
    list.filter(units, fn(item) { !list.contains(paths, item.path) }),
    extra,
  )
}

fn fixture_text(path: String) -> String {
  let assert Ok(text) =
    simplifile.read(article_fixture <> "/public/src/" <> path <> ".gleam")
  text
}

fn page_with(placement: String) -> source.Unit {
  let text =
    fixture_text(page_path)
    |> string.replace(
      "Fixed(area: \"page\", block: blocks.Article, cell: Flow)",
      placement,
    )
    |> string.replace(
      "SubjectHandle, Var, Widget,",
      "SubjectHandle, Var, Widget, Live, Bottom, Span,",
    )
  unit(page_path, text)
}

fn emitted(face_extra: List(source.Unit)) -> List(#(String, String)) {
  let assert Ok(back_units) = source.load(article_fixture)
  let assert Ok(app) = reader.read(back_units)
  let assert Ok(face_units) = source.load(article_fixture <> "/public")
  let face_units = replace(face_units, face_extra)
  let assert Ok(front_model) =
    reader_front.read("public", face_units, app.services)
  let package =
    face.Package(
      name: "public",
      path: article_fixture <> "/public",
      pages: face.UndeclaredPages,
      units: face_units,
    )
  front_emit.emit(app, back_units, package, front_model, hash.of(back_units))
  |> list.map(fn(file) { #(file.path, file.text) })
}

fn text_of(files: List(#(String, String)), path: String) -> String {
  let assert Ok(#(_, text)) = list.find(files, fn(file) { file.0 == path })
  text
}

fn has(text: String, part: String) -> Nil {
  case string.contains(text, part) {
    True -> Nil
    False -> {
      let _ = should.equal(part, "(not found in the emitted text)")
      Nil
    }
  }
}

fn count(text: String, part: String) -> Int {
  list.length(string.split(text, part)) - 1
}

/// `Live` の無い面:頁の `Fixed` の Block ごとに loader の断片の関数(Service を読まない Block は Vars だけ)、
/// 断片だけ `<yumemi-block name>` で包み(頁は包まない)、shell に `blocks` の表と断片の口、門に数えない印。
pub fn fixed_blocks_get_the_door_test() {
  let files = emitted([])
  let loader = text_of(files, "public/src/gen/load/article/arg_slug/page.gleam")
  has(
    loader,
    "pub fn block_summary(vars: Vars, article_read: article_read.Out) -> el.Element {",
  )
  has(loader, "BlockSummary(vars: Vars, article_read: article_read.Out)")
  has(loader, "pub fn block_notice(vars: Vars) -> el.Element {")
  has(loader, "pub fn block_article(")
  // 包みは断片の関数の中だけ(頁の helper は包まない)
  count(loader, "\"yumemi-block\"") |> should.equal(3)
  count(loader, "\"yumemi-live\"") |> should.equal(0)
  let shell = text_of(files, "public/src/gen/shell.mjs")
  has(
    shell,
    "      \"summary\": { service: service.Service$ArticleRead$const, render: pageLoader0.block_summary },\n",
  )
  has(
    shell,
    "      \"notice\": { service: null, render: pageLoader0.block_notice },\n",
  )
  // Widget の Block(row_article・row_summary)と Layout の Block(feed・site_header)は頁の表に無い
  let assert [_, article_table, ..] = string.split(shell, "blocks: {")
  let assert [article_table, ..] = string.split(article_table, "},\n  }")
  string.contains(article_table, "row_") |> should.be_false
  string.contains(article_table, "\"feed\"") |> should.be_false
  string.contains(article_table, "\"site_header\"") |> should.be_false
  has(shell, "const block = request.headers.get(\"x-yumemi-block\");")
  has(shell, "const live = Object.hasOwn(blocks, name) ? blocks[name] : null;")
  has(
    shell,
    "live.service === null ? live.render(vars) : live.render(vars, value)",
  )
  has(shell, "to_string as to_fragment_string")
  string.contains(shell, "withLiveToken") |> should.be_false
  string.contains(shell, "yumemi-live { display: contents; }")
  |> should.be_false
  let gate = text_of(files, "public/src/gen/gate.mjs")
  has(gate, "if (request.headers.has(blockHeader) || !tracksPageview(context)")
}

/// 逃げ道のある面(`Live` 無し)の client.mjs は `block.mjs` だけを読み、`yumemi.block` を渡して `startBlock()`。
pub fn escapes_get_yumemi_block_without_the_live_runtime_test() {
  let client = text_of(emitted([]), "public/priv/static/_yumemi/client.mjs")
  has(
    client,
    "import { block as yumemiBlock, start as startBlock } from \"__YUMEMI_BUILD__/yumemi/yumemi/front/block.mjs\";\n",
  )
  has(client, "  yumemi: { block: yumemiBlock },\n")
  has(client, "});\nstartBlock();\n")
  string.contains(client, "live_block") |> should.be_false
  string.contains(client, "startLive") |> should.be_false
  // 逃げ道の無い面(cms の public)の client.mjs は block.mjs を束ねない(commit した fixture)
  let assert Ok(cms_client) =
    simplifile.read("gen/fixtures/cms/public/priv/static/_yumemi/client.mjs")
  string.contains(cms_client, "yumemi-block") |> should.be_false
  // 逃げ道のある面の束ねた client.mjs は yumemi-block を定め、socket を持たない
  let assert Ok(article_client) =
    simplifile.read(article_fixture <> "/public/priv/static/_yumemi/client.mjs")
  has(article_client, "customElements.define(\"yumemi-block\"")
  string.contains(article_client, "WebSocket") |> should.be_false
}

/// `Live` と同じ頁:`Live` の Block は `lives`(0.14.0 と同じ字)、他の `Fixed` は `blocks`。client は live_block.mjs。
pub fn live_and_fixed_on_one_page_test() {
  let files =
    emitted([
      page_with(
        "Live(area: \"page\", block: blocks.Article, cell: Flow, edge: Bottom)",
      ),
    ])
  let shell = text_of(files, "public/src/gen/shell.mjs")
  has(
    shell,
    "      \"article\": { edge: \"bottom\", service: service.Service$ArticleRead$const, render: pageLoader",
  )
  has(
    shell,
    "      \"summary\": { service: service.Service$ArticleRead$const, render: pageLoader",
  )
  has(shell, ".live_article },\n    },\n    blocks: {\n      \"summary\": {")
  string.contains(shell, ".block_article") |> should.be_false
  has(
    shell,
    "const live = Object.hasOwn(lives, name) ? lives[name] : Object.hasOwn(blocks, name) ? blocks[name] : null;",
  )
  has(shell, "const html = withLiveToken(body, name, token);")
  let loader = text_of(files, "public/src/gen/load/article/arg_slug/page.gleam")
  string.contains(loader, "pub fn block_article(") |> should.be_false
  has(loader, "pub fn live_article(")
  let client = text_of(files, "public/priv/static/_yumemi/client.mjs")
  has(client, "  yumemi: { block: liveBlock },\n")
  string.contains(client, "startBlock();") |> should.be_false
}

/// 同じ Block を 2 か所に `Fixed` で置いた頁は、先の置き場(cell)の 1 つだけが答える。
pub fn the_same_block_twice_answers_once_test() {
  let files =
    emitted([
      page_with(
        "Fixed(area: \"page\", block: blocks.Article, cell: Span(cols: 2, rows: 1)),\n      Fixed(area: \"rail\", block: blocks.Article, cell: Flow)",
      ),
    ])
  let shell = text_of(files, "public/src/gen/shell.mjs")
  count(shell, "\"article\": { service:") |> should.equal(1)
  let loader = text_of(files, "public/src/gen/load/article/arg_slug/page.gleam")
  count(loader, "pub fn block_article(") |> should.equal(1)
  let assert [_, fragment] = string.split(loader, "fn block_article_view(")
  has(fragment, "\"grid-column: span 2; grid-row: span 1;\"")
}

/// client の runtime(Playwright):`Live` の無い面の逃げ道が別の URL の Block を取って置き、同じ URL で取り直す。
pub fn block_runtime_in_the_browser_test() {
  let out = browser_check()
  string.split(out, "\n")
  |> list.filter(fn(line) { !string.starts_with(line, "ok ") })
  |> should.equal([])
  string.split(out, "\n")
  |> list.filter(fn(line) { string.starts_with(line, "ok ") })
  |> list.length
  |> should.equal(17)
}

/// 生成した面(article の写しに門を足す)の shell の断片の口を node で叩く。
pub fn generated_shell_serves_fixed_fragments_test() {
  let out = shell_check()
  string.split(out, "\n")
  |> list.filter(fn(line) { !string.starts_with(line, "ok ") })
  |> should.equal([])
  string.split(out, "\n")
  |> list.filter(fn(line) { string.starts_with(line, "ok ") })
  |> list.length
  |> should.equal(18)
}
