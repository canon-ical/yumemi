//// failure-page(0.14.3)── 面の失敗の頁。面が `src/failure.gleam` に `pub const page: Page(..)` を宣言すると、
//// 生成の shell と門が、頁を求める要求の失敗(403・404・5xx・例外)をその頁で、元の状態コードのまま返す。
//// 宣言の無い面の生成物は 0.14.2 と同じ字。生成した shell・門・navigate は Chromium と node で回す
//// (`yumemi_failure_check.mjs`)、宣言の無い fixture を生成し直して commit した字と比べる
//// (`yumemi_failure_unchanged_check.mjs`)。

import glance
import gleam/list
import gleam/option.{None}
import gleam/string
import gleeunit/should
import simplifile
import yumemi/gen/emit/front as front_emit
import yumemi/gen/emit/hash
import yumemi/gen/face
import yumemi/gen/reader
import yumemi/gen/reader/front as reader_front
import yumemi/gen/source
import yumemi/gen/stop

@external(javascript, "./yumemi_failure_test_ffi.mjs", "failure_check")
fn failure_check() -> String

@external(javascript, "./yumemi_failure_test_ffi.mjs", "unchanged_check")
fn unchanged_check() -> String

const article_fixture = "gen/fixtures/article"

const failure_page =
  "import yumemi/front.{type Page, Area, CurrentRoute, Failure, Fixed, Flow, Frame, Page, Var}
import yumemi/front/css
import gen/blocks
import gen/service
import gleam/option.{None}
import layout
import style

pub const page: Page(service.Service, blocks.Block) = Page(
  of: None,
  layout: layout.public,
  theme: None,
  vars: [Var(\"failure\", Failure), Var(\"route\", CurrentRoute)],
  sp: Frame(
    areas: [
      Area(name: \"page\", flow: css.Stack(gap: style.s2), pin: css.NoPin, style: style.page),
    ],
    placements: [Fixed(area: \"page\", block: blocks.FailureNote, cell: Flow)],
    cols: [],
    rows: [],
    template: [],
  ),
  pc: None,
  tablet: None,
)
"

const failure_note =
  "import yumemi/front/el

pub type In =
  Nil

pub type Arg {
  Arg(failure: String, route: String)
}

pub fn view(_it: In, arg: Arg) -> el.Element {
  el.text(arg.failure <> arg.route)
}
"

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

fn declared(page: String) -> List(source.Unit) {
  [unit("failure", page), unit("blocks/failure_note", failure_note)]
}

fn model(
  face_extra: List(source.Unit),
) -> #(List(#(String, String)), List(stop.Note), reader_front.Front) {
  let assert Ok(back_units) = source.load(article_fixture)
  let assert Ok(app) = reader.read(back_units)
  let assert Ok(face_units) = source.load(article_fixture <> "/public")
  let face_units = replace(face_units, face_extra)
  let assert Ok(front_model) =
    reader_front.read_with_package_and_entries(
      "public",
      "public",
      face_units,
      app.services,
      app.entries,
    )
  let package =
    face.Package(
      name: "public",
      path: article_fixture <> "/public",
      pages: face.UndeclaredPages,
      units: face_units,
    )
  let files =
    front_emit.emit(app, back_units, package, front_model, hash.of(back_units))
    |> list.map(fn(file) { #(file.path, file.text) })
  #(files, reader_front.notes(front_model, app.services), front_model)
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

/// 第 45 条の行(と、失敗の頁を Page の検査に通した今の条の行)。
fn failure_lines(notes: List(stop.Note)) -> List(String) {
  notes
  |> list.filter(fn(note) { note.class != stop.Warning })
  |> list.map(stop.line)
}

fn stops_with(extra: List(source.Unit), part: String) -> Nil {
  let #(_, notes, _) = model(extra)
  let lines = failure_lines(notes)
  case list.any(lines, fn(line) { string.contains(line, part) }) {
    True -> Nil
    False -> {
      let _ = should.equal(lines, [part])
      Nil
    }
  }
}

/// 宣言の無い面:失敗の頁の道具を 1 つも出さず、shell と門は commit した fixture(0.14.2 の字)と同じ。
pub fn faces_without_a_failure_page_are_unchanged_test() {
  let #(files, notes, front) = model([])
  front.failure |> should.equal(None)
  failure_lines(notes) |> should.equal([])
  let shell = text_of(files, "public/src/gen/shell.mjs")
  string.contains(shell, "failurePage") |> should.be_false
  string.contains(shell, "failureSpec") |> should.be_false
  string.contains(shell, "gate.plain") |> should.be_false
  string.contains(shell, "guarded") |> should.be_false
  let gate = text_of(files, "public/src/gen/gate.mjs")
  string.contains(gate, "wantsPage") |> should.be_false
  string.contains(gate, "plainFailures") |> should.be_false
  has(
    gate,
    "  if (!matched) return {request, route: null, session: undefined};\n",
  )
  has(gate, "export function serve(dispatch) {\n")
  list.any(files, fn(file) { string.contains(file.0, "load/failure") })
  |> should.be_false
  let assert Ok(fixture_shell) =
    simplifile.read(article_fixture <> "/public/src/gen/shell.mjs")
  shell |> should.equal(fixture_shell)
  let assert Ok(fixture_gate) =
    simplifile.read(article_fixture <> "/public/src/gen/gate.mjs")
  gate |> should.equal(fixture_gate)
  let assert Ok(fixture_style) =
    simplifile.read(article_fixture <> "/public/priv/static/_yumemi/style.css")
  text_of(files, "public/priv/static/_yumemi/style.css")
  |> should.equal(fixture_style)
}

/// 宣言のある面:loader `gen/load/failure.gleam`(断片の口の関数は持たない)、shell の `failureSpec`・失敗の頁の
/// runtime・export、門の失敗の口。
pub fn a_declared_failure_page_reaches_the_shell_and_the_gate_test() {
  let #(files, notes, front) = model(declared(failure_page))
  failure_lines(notes) |> should.equal([])
  { front.failure != None } |> should.be_true
  let loader = text_of(files, "public/src/gen/load/failure.gleam")
  has(
    loader,
    "pub type Vars {\n  Vars(\n    failure: String,\n    route: String,\n    www_origin: String,\n    auth_origin: String,\n  )\n}\n",
  )
  has(loader, "pub fn render(it: Data) -> el.Element {")
  // r2:門が返す失敗の外枠なしの描画(中身の Block だけ)
  has(loader, "pub fn render_bare(it: Data) -> el.Element {")
  has(
    loader,
    "fn bare_view(it: Data) -> el.Element {\n  html.div_([el.attribute(\"data-yumemi-failure\", \"bare\")], page_children(it))\n}\n",
  )
  string.contains(loader, "yumemi-block") |> should.be_false
  let shell = text_of(files, "public/src/gen/shell.mjs")
  has(
    shell,
    "{gen/route.gleam,gen/load/**,pages/**,layout.gleam,shell.gleam,failure.gleam}",
  )
  has(shell, "import * as failureLoader from \"./load/failure.mjs\";")
  has(
    shell,
    "const failureSpec = {\n  definition: failureDefinition.page,\n  loader: failureLoader,\n",
  )
  has(
    shell,
    "    { name: \"failure\", optional: false, from: { type: \"failure\" } },\n",
  )
  has(
    shell,
    "    { name: \"route\", optional: false, from: { type: \"route\", value: \"\" } },\n",
  )
  has(
    shell,
    "function failure(status, body) {\n  return gate.plain(status, body);\n}\n",
  )
  has(
    shell,
    "  if (!gate.isPlain(response) || !gate.wantsPage(request)) return response;\n",
  )
  has(
    shell,
    "    return failurePage(request, env, failure(404, \"not found\"));\n",
  )
  has(
    shell,
    "  if (block !== null) return guarded(() => renderBlock(request, env, matched, before.session, block));\n",
  )
  // r2:門で止めた失敗は外枠なし、門を通った後(dispatch の中)の失敗は外枠つき
  has(shell, "}, gateFailurePage);\n\n")
  has(
    shell,
    "function gateFailurePage(request, env, response) {\n  return failurePage(request, env, response, false);\n}\n",
  )
  has(
    shell,
    "async function failurePage(request, env, response, framed = true) {\n",
  )
  has(shell, "export {failureFor as failure};\n")
  // 頁の表と route 表に失敗の頁は入らない
  string.contains(text_of(files, "public/src/gen/route.gleam"), "failure")
  |> should.be_false
  let gate = text_of(files, "public/src/gen/gate.mjs")
  has(gate, "export function serve(dispatch, failure = null) {")
  has(
    gate,
    "        return withPolicy(request, await failure(request, env, before.response));\n",
  )
  has(
    gate,
    "    if (readsSession && wantsPage(request) && rules.some(coversEvery)) {\n",
  )
  has(gate, "export {text as plain};\n")
  // r2:route に当たらない path の失敗の頁にも `Every` の CSP(この fixture の門は CSP を宣言しない)
  has(gate, "const cspUnmatched = null;\n")
  has(
    gate,
    "      if (before.route === null && response.headers.has(\"x-yumemi-failure\")) return withPolicy(before.request, response);\n",
  )
  // 失敗の頁の格子の CSS は style.css にも出る
  has(
    text_of(files, "public/priv/static/_yumemi/style.css"),
    "[data-yumemi-grid=\"page:failure\"]",
  )
}

/// 停止コード 4(第 45 条):`of`・Widget・Live・読む Block・Path / Query / Session の Var。
pub fn failure_page_contradictions_stop_test() {
  stops_with(
    declared(
      string.replace(
        failure_page,
        "of: None,",
        "of: option.Some(service.ArticleRead),",
      )
      |> string.replace("import gleam/option.{None}", "import gleam/option")
      |> string.replace("None", "option.None"),
    ),
    "[exit 4 宣言の矛盾] public/failure: [第 45 条 失敗の頁] of: Some(ArticleRead)",
  )
  stops_with(
    declared(
      string.replace(
        failure_page,
        "placements: [Fixed(area: \"page\", block: blocks.FailureNote, cell: Flow)],",
        "placements: [Fixed(area: \"page\", block: blocks.FailureNote, cell: Flow), Widget(area: \"page\", of: service.WidgetList, render: One(blocks.Feed))],",
      )
      |> string.replace("Page, Var}", "Page, Var, Widget, One}"),
    ),
    "[第 45 条 失敗の頁] Widget(of: WidgetList) ── 失敗の頁の placements は Fixed だけ",
  )
  stops_with(
    declared(
      string.replace(
        failure_page,
        "Fixed(area: \"page\", block: blocks.FailureNote, cell: Flow)",
        "Live(area: \"page\", block: blocks.FailureNote, cell: Flow, edge: Bottom)",
      )
      |> string.replace("Page, Var}", "Page, Var, Live, Bottom}"),
    ),
    "[第 45 条 失敗の頁] Live(block: FailureNote) ── 失敗の頁の placements は Fixed だけ",
  )
  stops_with(
    declared(string.replace(
      failure_page,
      "Fixed(area: \"page\", block: blocks.FailureNote, cell: Flow)",
      "Fixed(area: \"page\", block: blocks.FailureNote, cell: Flow), Fixed(area: \"page\", block: blocks.Summary, cell: Flow)",
    )),
    "[第 45 条 失敗の頁] Fixed(block: Summary) の Block が Service の Out を受ける",
  )
  stops_with(
    declared(
      string.replace(
        failure_page,
        "Var(\"route\", CurrentRoute)",
        "Var(\"route\", CurrentRoute), Var(\"term\", Query(\"term\"))",
      )
      |> string.replace("Page, Var}", "Page, Var, Query}"),
    ),
    "[第 45 条 失敗の頁] Var.term ── 失敗の頁の Var は Failure・CurrentRoute だけ",
  )
}

/// `Failure` は失敗の頁の外(Page・Layout)に置けない。`src/failure.gleam` に Page が無ければ宣言の不足。
/// Layout の `Fixed` の Block が読むなら、失敗の頁を宣言した面では止める。
pub fn failure_outside_and_missing_declarations_stop_test() {
  let status =
    fixture_text("pages/status/page")
    |> string.replace(
      "vars: [Var(\"widget\", Query(\"widget\"))],",
      "vars: [Var(\"widget\", Query(\"widget\")), Var(\"oops\", Failure)],",
    )
    |> string.replace("Query, Var}", "Query, Var, Failure}")
  stops_with(
    [unit("pages/status/page", status)],
    "public/pages/status/page: [第 45 条 失敗の頁] Var.oops の Failure は失敗の頁(src/failure.gleam)にだけ置ける",
  )
  stops_with(
    [unit("failure", "pub const nothing = 1\n")],
    "[exit 3 宣言の不足] public/failure: [第 45 条 失敗の頁] src/failure.gleam に `pub const page: Page(..)`",
  )
  let layout =
    fixture_text("layout")
    |> string.replace(
      "Fixed(area: \"header\", block: blocks.SiteHeader, cell: Flow)",
      "Fixed(area: \"header\", block: blocks.Summary, cell: Flow)",
    )
  stops_with(
    [unit("layout", layout), ..declared(failure_page)],
    "public/layout: [第 45 条 失敗の頁] Fixed(block: Summary) の Block が Service の Out を受ける",
  )
  // 同じ Layout でも、失敗の頁の無い面は今の規則のまま(第 45 条は出ない)
  let #(_, notes, _) = model([unit("layout", layout)])
  list.any(failure_lines(notes), fn(line) { string.contains(line, "第 45 条") })
  |> should.be_false
}

/// 宣言のある面を生成・build して、shell・門を node で、client 遷移を Chromium で回す。
pub fn generated_failure_page_serves_test() {
  let out = failure_check()
  string.split(out, "\n")
  |> list.filter(fn(line) { !string.starts_with(line, "ok ") })
  |> should.equal([])
  string.split(out, "\n")
  |> list.filter(fn(line) { string.starts_with(line, "ok ") })
  |> list.length
  |> should.equal(63)
}

/// 宣言の無い fixture(article・cms)を生成器で生成し直すと、commit した fixture と 1 字も違わない。
pub fn regenerated_fixtures_without_a_failure_page_match_test() {
  let out = unchanged_check()
  string.split(out, "\n")
  |> list.filter(fn(line) { !string.starts_with(line, "ok ") })
  |> should.equal([])
  string.split(out, "\n")
  |> list.filter(fn(line) { string.starts_with(line, "ok ") })
  |> list.length
  |> should.equal(4)
}
