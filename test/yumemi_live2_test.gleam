//// yumemi-live-2(0.14)── `Live` の Block を取り直して当てる(面と client の側)。
//// ★ は Page の placements に `Live(area:, block:, cell:, edge:)` と書くだけ。生成器は loader の断片の関数・shell の
//// 断片の口(`x-yumemi-block`)・`<yumemi-live>` の包み・門の数えない印・client.mjs の起こしを書き、宣言の矛盾を止める。
//// client の runtime(`yumemi/front/live_block.mjs`)は Playwright で回す(`yumemi_live2_check.mjs`)。

import glance
import gleam/list
import gleam/string
import gleeunit/should
import simplifile
import yumemi/front/css
import yumemi/front/el
import yumemi/front/html
import yumemi/gen/emit/front as front_emit
import yumemi/gen/emit/hash
import yumemi/gen/face
import yumemi/gen/reader
import yumemi/gen/reader/front as reader_front
import yumemi/gen/source
import yumemi/gen/stop

@external(javascript, "./yumemi_live2_test_ffi.mjs", "browser_check")
fn browser_check() -> String

@external(javascript, "./yumemi_live2_test_ffi.mjs", "shell_check")
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

/// article の頁の `Fixed(area: "page", block: blocks.Article, ..)` を `Live` に替えた頁。
fn live_page(edge: String) -> source.Unit {
  let text =
    fixture_text(page_path)
    |> string.replace(
      "Fixed(area: \"page\", block: blocks.Article, cell: Flow)",
      "Live(area: \"page\", block: blocks.Article, cell: Flow, edge: "
        <> edge
        <> ")",
    )
    |> string.replace(
      "SubjectHandle, Var, Widget,",
      "SubjectHandle, Var, Widget, Live, Bottom, Top,",
    )
  unit(page_path, text)
}

fn emitted(
  face_extra: List(source.Unit),
) -> #(List(#(String, String)), List(stop.Note)) {
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
  let files =
    front_emit.emit(app, back_units, package, front_model, hash.of(back_units))
    |> list.map(fn(file) { #(file.path, file.text) })
  #(files, front_emit.live_notes(app, package, front_model))
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

fn texts(notes: List(stop.Note)) -> List(String) {
  list.map(notes, stop.line)
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
      "SubjectHandle, Var, Widget, Live, Bottom, Top, Anywhere,",
    )
  unit(page_path, text)
}

fn article_block_with(extra: String) -> source.Unit {
  unit("blocks/article", fixture_text("blocks/article") <> extra)
}

const fresh_fn =
  "\npub fn mark() -> el.Element {\n  el.fresh(css.class([]), [el.text(\"新着\")])\n}\n"

/// `Live` の Block:loader に断片の関数、置き場の要素を `<yumemi-live name edge>` で包み、shell に Page の `lives` の
/// 表・断片の口・札の差し、門に数えない印、client.mjs に runtime の起こしと逃げ道の `yumemi.block`。
pub fn live_emits_the_fragment_and_the_wrapper_test() {
  let #(files, notes) = emitted([live_page("Bottom")])
  let loader = text_of(files, "public/src/gen/load/article/arg_slug/page.gleam")
  has(
    loader,
    "pub fn live_article(vars: Vars, article_read: article_read.Out) -> el.Element {",
  )
  has(loader, "LiveArticle(vars: Vars, article_read: article_read.Out)")
  has(
    loader,
    "[el.attribute(\"name\", \"article\"), el.attribute(\"edge\", \"bottom\")]",
  )
  // 頁の置き場も同じ包み(2 か所:頁の helper と断片の関数)
  string.split(loader, "\"yumemi-live\"") |> list.length |> should.equal(3)
  // 生成の Gleam が compile できることは `yumemi_live2_shell_check.mjs` が面を build して見る
  let shell = text_of(files, "public/src/gen/shell.mjs")
  has(
    shell,
    "\"article\": { edge: \"bottom\", service: service.Service$ArticleRead$const, render: pageLoader",
  )
  has(shell, ".live_article },\n    },\n")
  has(
    shell,
    "async function renderBlock(request, env, matched, gateSession, name) {",
  )
  has(shell, "const block = request.headers.get(\"x-yumemi-block\");")
  has(shell, "if (token) tokens.set(source.service, token);")
  has(shell, "to_string as to_fragment_string")
  has(shell, "yumemi-live { display: contents; }")
  // Live の無い頁(/status)は lives の表を持たない
  string.split(shell, "lives: {") |> list.length |> should.equal(2)
  let gate = text_of(files, "public/src/gen/gate.mjs")
  has(gate, "const blockHeader = \"x-yumemi-block\";")
  has(gate, "if (request.headers.has(blockHeader) || !tracksPageview(context)")
  let client = text_of(files, "public/priv/static/_yumemi/client.mjs")
  has(
    client,
    "import { block as liveBlock, start as startLive } from \"__YUMEMI_BUILD__/yumemi/yumemi/front/live_block.mjs\";",
  )
  has(client, "  yumemi: { block: liveBlock },\n")
  has(
    client,
    "startLive({ socket: \"/api/_yumemi/live\", reload: reloadPage });",
  )
  // 止めるものは無い(警告は el.fresh の無いことだけ)
  list.filter(notes, fn(note) { note.class != stop.Warning })
  |> should.equal([])
}

/// 端の名は生成物で小文字(`top`・`anywhere`)。
pub fn live_edges_test() {
  let #(top, _) = emitted([live_page("Top")])
  has(
    text_of(top, "public/src/gen/load/article/arg_slug/page.gleam"),
    "el.attribute(\"edge\", \"top\")",
  )
  let #(anywhere, _) = emitted([live_page("Anywhere")])
  has(
    text_of(anywhere, "public/src/gen/shell.mjs"),
    "\"article\": { edge: \"anywhere\",",
  )
}

/// 断片も置き場の cell で包む(r2、柏木 P2-1):`Span` / `At` の `Live` は頁と断片の HTML の形が同じ。
pub fn live_fragment_keeps_the_cell_test() {
  let text =
    fixture_text(page_path)
    |> string.replace(
      "Fixed(area: \"page\", block: blocks.Article, cell: Flow)",
      "Live(area: \"page\", block: blocks.Article, cell: Span(cols: 2, rows: 1), edge: Bottom)",
    )
    |> string.replace(
      "SubjectHandle, Var, Widget,",
      "SubjectHandle, Var, Widget, Live, Bottom, Span,",
    )
  let #(files, _) = emitted([unit(page_path, text)])
  let loader = text_of(files, "public/src/gen/load/article/arg_slug/page.gleam")
  // 頁の helper と断片の関数の 2 か所で同じ包み
  string.split(loader, "\"grid-column: span 2; grid-row: span 1;\"")
  |> list.length
  |> should.equal(3)
  let assert [_, fragment] = string.split(loader, "fn live_article_view(")
  has(fragment, "\"grid-column: span 2; grid-row: span 1;\"")
}

/// `Live` の無い面は札・socket・`<yumemi-live>` を持たない。0.14.1 から断片の口(`Fixed` の Block の
/// `x-yumemi-block`)と門の数えない印は `Live` の無い面にもある(`yumemi_block_door_test.gleam`)。
pub fn faces_without_live_are_unchanged_test() {
  let #(files, notes) = emitted([])
  let shell = text_of(files, "public/src/gen/shell.mjs")
  string.contains(shell, "yumemi-live") |> should.be_false
  string.contains(shell, "withLiveToken") |> should.be_false
  string.contains(shell, "lives: {") |> should.be_false
  string.contains(
    text_of(files, "public/priv/static/_yumemi/client.mjs"),
    "live_block",
  )
  |> should.be_false
  notes |> should.equal([])
  // 生成の shell と門は commit した fixture と同じ
  let assert Ok(fixture_shell) =
    simplifile.read(article_fixture <> "/public/src/gen/shell.mjs")
  shell |> should.equal(fixture_shell)
  let assert Ok(fixture_gate) =
    simplifile.read(article_fixture <> "/public/src/gen/gate.mjs")
  text_of(files, "public/src/gen/gate.mjs") |> should.equal(fixture_gate)
}

/// 停止コード 4:Layout の Live・Block が Service の Out を受けない・書きの Service・root の Entity の無い Service・
/// 同じ Block の Live が 2 つ・pc の Frame の Live。
pub fn live_contradictions_stop_test() {
  let conflicts = fn(units) {
    let #(_, notes) = emitted(units)
    list.filter(notes, fn(note) { note.class == stop.Conflict }) |> texts
  }
  // Block が Service の Out を受けない(Notice は Nil を受ける)
  let notice =
    conflicts([
      page_with(
        "Fixed(area: \"page\", block: blocks.Article, cell: Flow),\n      Live(area: \"page\", block: blocks.Notice, cell: Flow, edge: Top)",
      ),
    ])
  list.any(notice, fn(line) {
    string.contains(
      line,
      "Live(block: Notice) の Block が読みの Service の Out を受けない",
    )
  })
  |> should.be_true
  // root の Entity の無い Service(Feed は widget_list、宛先が導けない)
  let feed =
    conflicts([
      page_with(
        "Fixed(area: \"page\", block: blocks.Article, cell: Flow),\n      Live(area: \"page\", block: blocks.Feed, cell: Flow, edge: Anywhere)",
      ),
    ])
  list.any(feed, fn(line) {
    string.contains(
      line,
      "Live(block: Feed) の Block の Service widget_list の allow に Entity が無い",
    )
  })
  |> should.be_true
  // 書きの Service の Out を受ける Block
  let created =
    unit(
      "blocks/created",
      "import gen/out/article_create\nimport yumemi/front/el\n\npub type In =\n  article_create.Out\n\npub fn view(_it: In) -> el.Element {\n  el.none()\n}\n",
    )
  let write =
    conflicts([
      created,
      page_with(
        "Fixed(area: \"page\", block: blocks.Article, cell: Flow),\n      Live(area: \"page\", block: blocks.Created, cell: Flow, edge: Bottom)",
      ),
    ])
  list.any(write, fn(line) {
    string.contains(
      line,
      "Live(block: Created) の Block の Service article_create が書き",
    )
  })
  |> should.be_true
  // 同じ Block の Live が 2 つ
  let twice =
    conflicts([
      page_with(
        "Live(area: \"page\", block: blocks.Article, cell: Flow, edge: Bottom),\n      Live(area: \"rail\", block: blocks.Article, cell: Flow, edge: Top)",
      ),
    ])
  list.any(twice, fn(line) {
    string.contains(line, "同じ Block Article の Live が 2 つある")
  })
  |> should.be_true
  // Layout の Live
  let assert Ok(layout_text) =
    simplifile.read(article_fixture <> "/public/src/layout.gleam")
  let layout =
    unit(
      "layout",
      layout_text
        |> string.replace("Fixed(", "Live(edge: Top, ")
        |> string.replace(
          "import yumemi/front.{",
          "import yumemi/front.{Live, Top, ",
        ),
    )
  let in_layout = conflicts([layout])
  list.any(in_layout, fn(line) { string.contains(line, "は Layout に置けない") })
  |> should.be_true
}

/// 警告(停止コード 0):鍵の無い並び(`el.each`・`list.map`)の要素が interactive Component か素の `details` を持つ
/// (関数を名で辿る)、`edge: Bottom` に `el.fresh`
/// が無い。`el.each_keyed` と `el.fresh` があれば出ない。
pub fn live_warnings_test() {
  let warnings = fn(units) {
    let #(_, notes) = emitted(units)
    list.filter(notes, fn(note) { note.class == stop.Warning }) |> texts
  }
  let unkeyed =
    warnings([
      live_page("Bottom"),
      article_block_with(
        fresh_fn
        <> "\npub fn likes(slugs: List(String)) -> el.Element {\n  el.each(slugs, like_row)\n}\n\nfn like_row(slug: String) -> el.Element {\n  like(slug)\n}\n\nfn like(slug: String) -> el.Element {\n  interactive.like_button(article_publish.Args(slug: slug))\n}\n",
      ),
    ])
  list.any(unkeyed, fn(line) {
    string.contains(
      line,
      "Live(block: Article) の Block の鍵の無い並び(el.each・list.map)の要素が interactive Component か details を持つ",
    )
  })
  |> should.be_true
  // r2(柏木 P1-4):`list.map` の並びと、Component の無い素の `details` も見る
  let state_warning = fn(lines) {
    list.any(lines, fn(line) {
      string.contains(line, "Live(block: Article) の Block の鍵の無い並び")
    })
  }
  warnings([
    live_page("Bottom"),
    article_block_with(
      fresh_fn
      <> "\npub fn likes(slugs: List(String)) -> el.Element {\n  el.fragment(list.map(slugs, fn(slug) {\n    interactive.like_button(article_publish.Args(slug: slug))\n  }))\n}\n",
    ),
  ])
  |> state_warning
  |> should.be_true
  warnings([
    live_page("Bottom"),
    article_block_with(
      fresh_fn
      <> "\npub fn reports(slugs: List(String)) -> el.Element {\n  el.each(slugs, report)\n}\n\nfn report(slug: String) -> el.Element {\n  html.details_([], [el.text(slug)])\n}\n",
    ),
  ])
  |> state_warning
  |> should.be_true
  warnings([
    live_page("Bottom"),
    article_block_with(
      fresh_fn
      <> "\npub fn names(slugs: List(String)) -> el.Element {\n  el.fragment(list.map(slugs, fn(slug) { el.text(slug) }))\n}\n",
    ),
  ])
  |> state_warning
  |> should.be_false
  list.any(unkeyed, fn(line) { string.contains(line, "el.fresh が無い") })
  |> should.be_false
  let keyed =
    warnings([
      live_page("Bottom"),
      article_block_with(
        fresh_fn
        <> "\npub fn likes(slugs: List(String)) -> el.Element {\n  el.each_keyed(slugs, fn(slug) { slug }, fn(slug) {\n    interactive.like_button(article_publish.Args(slug: slug))\n  })\n}\n\npub fn names(slugs: List(String)) -> el.Element {\n  el.each(slugs, fn(slug) { el.text(slug) })\n}\n",
      ),
    ])
  list.any(keyed, fn(line) { string.contains(line, "Live(block: Article)") })
  |> should.be_false
  let no_fresh = warnings([live_page("Bottom")])
  list.any(no_fresh, fn(line) {
    string.contains(
      line,
      "Live(block: Article) は edge: Bottom で、Block に el.fresh が無い",
    )
  })
  |> should.be_true
  // Top は el.fresh が無くても警告しない
  warnings([live_page("Top")])
  |> list.any(fn(line) { string.contains(line, "Live(block: Article)") })
  |> should.be_false
}

/// `el.each_keyed` は各要素の根に `data-yumemi-key`、根が要素でなければ付けない。`el.fresh` は hidden の button。
pub fn each_keyed_and_fresh_render_test() {
  el.each_keyed(["a", "b"], fn(item) { "k-" <> item }, fn(item) {
    html.li_([], [el.text(item)])
  })
  |> el.to_string
  |> should.equal(
    "<li data-yumemi-key=\"k-a\">a</li><li data-yumemi-key=\"k-b\">b</li>",
  )
  el.each_keyed(["a"], fn(item) { item }, fn(item) { el.text(item) })
  |> el.to_string
  |> should.equal("a")
  let fresh = el.to_string(el.fresh(css.class([]), [el.text("新着")]))
  string.contains(fresh, " data-yumemi-fresh") |> should.be_true
  string.contains(fresh, " hidden") |> should.be_true
  string.contains(fresh, "type=\"button\"") |> should.be_true
  string.starts_with(fresh, "<button") |> should.be_true
}

/// client の runtime(Playwright、Chromium と WebKit)。2 者の IME・details・3 つの edge・断片の CSS・stale・門・
/// JS 無し・繋ぎ直し・期限・畳み・yumemi.block。r2:時計のずれ・倍々の待ち・5xx と通信の失敗・遷移をまたぐ CSS・
/// 前へ探す照合の守る節・別の URL の Block・開くたびの取り直し・揺らぎ。
pub fn live_runtime_in_browsers_test() {
  let out = browser_check()
  string.split(out, "\n")
  |> list.filter(fn(line) { !string.starts_with(line, "ok ") })
  |> should.equal([])
  string.contains(out, "STDERR") |> should.be_false
  string.split(out, "\n")
  |> list.filter(fn(line) { string.starts_with(line, "ok ") })
  |> list.length
  |> should.equal(48)
}

/// 生成した面(article の写しの頁を Live に)の shell の断片の口を node で叩く。
pub fn generated_shell_serves_the_fragment_test() {
  let out = shell_check()
  string.split(out, "\n")
  |> list.filter(fn(line) { !string.starts_with(line, "ok ") })
  |> should.equal([])
  string.contains(out, "STDERR") |> should.be_false
  string.split(out, "\n")
  |> list.filter(fn(line) { string.starts_with(line, "ok ") })
  |> list.length
  |> should.equal(22)
}
