//// yumemi-0121(0.12.1)── 0.12.0 の生成物の 5 つの穴。★ の書き方は変えない。
//// 1 生成の form が JS 無しで本文を URL に載せない、2 同じ名の読みを 2 本 import しても取り違えない、
//// 3 閉じた dialog に作り手の display が勝たない、4 `when(Failed)` が断りで出ない、5 要件の符号が Refused に乗る。

import gleam/list
import gleam/string
import gleeunit/should
import yumemi/front/attr
import yumemi/front/el
import yumemi/front/html
import yumemi/front/live as front_live
import yumemi/gen as yumemi_gen
import yumemi/gen/emit/hash
import yumemi/gen/emit/reads
import yumemi/gen/reader
import yumemi/gen/source
import yumemi/gen/stop

const fixture = "gen/fixtures/article"

@external(javascript, "./yumemi_s1_test_ffi.mjs", "copy_app")
fn copy_app(from: String) -> String

@external(javascript, "./yumemi_s1_test_ffi.mjs", "remove_app")
fn remove_app(dir: String) -> Nil

@external(javascript, "./yumemi_s1_test_ffi.mjs", "edit")
fn edit(dir: String, path: String, from: String, to: String) -> Bool

@external(javascript, "./yumemi_0121_test_ffi.mjs", "runtime_read")
fn runtime_read() -> String

@external(javascript, "./yumemi_0121_test_ffi.mjs", "runtime_states")
fn runtime_states() -> String

/// fixture の写しを `edits` で替えて生成し、(停止コード, 診断の文の並び, 書いた file)。
fn generated(
  edits: List(#(String, String, String)),
) -> #(Int, List(String), List(#(String, String))) {
  let dir = copy_app(fixture)
  list.each(edits, fn(item) {
    let #(path, from, to) = item
    edit(dir, path, from, to) |> should.be_true
  })
  let assert Ok(#(files, notes)) = yumemi_gen.generate(dir)
  remove_app(dir)
  #(
    stop.worst(notes),
    list.map(notes, fn(note) { stop.line(note) }),
    list.map(files, fn(file) { #(file.path, file.text) }),
  )
}

fn text_of(files: List(#(String, String)), suffix: String) -> String {
  let assert Ok(#(_, text)) =
    list.find(files, fn(file) { string.ends_with(file.0, suffix) })
  text
}

fn ok_lines(out: String, count: Int) -> Nil {
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  string.split(out, "\n") |> list.length |> should.equal(count)
}

// ── 1 生成の form ────────────────────────────────────────────────────────

/// interactive Component の form は `method="dialog"` ── runtime が submit を取らない送りは何も外へ出さない
/// (method の無い form は GET で本文を URL に載せた)。
pub fn component_form_sends_nothing_without_the_runtime_test() {
  front_live.component(
    "reply-form",
    "{}",
    html.textarea_([attr.name("reply_post.body")], []),
  )
  |> el.to_string
  |> string.contains("<form method=\"dialog\"><fieldset><textarea")
  |> should.be_true
}

/// ★ が書く GET の頁送りの form は書いた method のまま(POST にも dialog にもならない)。
pub fn star_get_form_keeps_its_method_test() {
  let text =
    html.form_([attr.method("get")], [
      html.input_([attr.name("page"), attr.value("2")]),
    ])
    |> el.to_string
  string.contains(text, "<form method=\"get\">") |> should.be_true
  string.contains(text, "dialog") |> should.be_false
  string.contains(text, "post") |> should.be_false
}

const summary = "public/src/blocks/summary.gleam"

const like = "interactive.like_button(article_publish.Args(slug: it.article.slug)),\n"

fn stops_on_component_in_form(lines: List(String)) -> Bool {
  list.any(lines, fn(line) {
    string.contains(line, "[exit 4") && string.contains(line, "第 44 条")
  })
}

/// ★ の `html.form` の中の Component は止める(第 44 条)── HTML の parser が Component の form を捨て、欄が ★ の
/// form の method で送られる(GET なら本文が URL に載る)。直に・pipe で・同じ module の関数を通しても。
pub fn component_inside_a_star_form_stops_test() {
  let #(code, lines, _) =
    generated([
      #(
        summary,
        like,
        "html.form_([attr.method(\"get\")], [\n        "
          <> like
          <> "      ]),\n",
      ),
    ])
  code |> should.equal(4)
  stops_on_component_in_form(lines) |> should.be_true
  list.any(lines, string.contains(_, "public/blocks/summary: ★ の html.form"))
  |> should.be_true
  // pipe と同じ module の関数を通す
  let #(code, lines, _) =
    generated([
      #(
        summary,
        like,
        "[liked(it.article.slug)] |> html.form_([attr.method(\"get\")], _),\n",
      ),
      #(
        summary,
        "pub fn view(",
        "fn liked(slug: String) -> el.Element {\n  interactive.like_button(article_publish.Args(slug: slug))\n}\n\npub fn view(",
      ),
    ])
  code |> should.equal(4)
  stops_on_component_in_form(lines) |> should.be_true
}

/// 他の module の関数を通して置くのも辿る(Component に届く関数を module をまたいで)。
pub fn component_through_another_module_inside_a_form_stops_test() {
  let #(code, lines, _) =
    generated([
      #(
        summary,
        "pub fn view(",
        "pub fn liked(slug: String) -> el.Element {\n  interactive.like_button(article_publish.Args(slug: slug))\n}\n\npub fn view(",
      ),
      #(
        "public/src/blocks/article.gleam",
        "import gen/escapes\n",
        "import gen/escapes\nimport blocks/summary as summary_block\n",
      ),
      #(
        "public/src/blocks/article.gleam",
        "      html.div_([], [\n        interactive.like_button(",
        "      html.form_([attr.method(\"get\")], [summary_block.liked(\"x\")]),\n      html.div_([], [\n        interactive.like_button(",
      ),
    ])
  code |> should.equal(4)
  list.any(lines, fn(line) {
    string.contains(line, "public/blocks/article: ★ の html.form")
  })
  |> should.be_true
}

/// form の隣に置く Component と、Component の無い ★ の form は止めない。
pub fn component_beside_a_star_form_passes_test() {
  let #(code, lines, _) =
    generated([
      #(
        summary,
        like,
        "html.form_([attr.method(\"get\")], [html.input_([attr.name(\"page\")])]),\n      "
          <> like,
      ),
    ])
  code |> should.equal(0)
  stops_on_component_in_form(lines) |> should.be_false
}

// ── 2 同じ名の読み ──────────────────────────────────────────────────────

/// 生成の読みの口は名と持ち主の Service を運ぶ(`read_of`)── 名だけだと、同じ名の読みを 2 本 import した Service で
/// runtime が取り違えた。名は今までどおり運ぶ(名だけで引く ★ の ctx を壊さない)。
pub fn generated_reads_carry_the_owner_test() {
  let assert Ok(units) = source.load(fixture)
  let assert Ok(app) = reader.read(units)
  let files = reads.emit(app, hash.of(units))
  let with_query =
    list.filter(files, fn(file) { string.contains(file.text, "query(ctx, \"") })
  { with_query != [] } |> should.be_true
  list.each(files, fn(file) {
    let service =
      file.path
      |> string.replace("src/gen/reads/", "")
      |> string.replace(".gleam", "")
    let calls = string.split(file.text, "query(ctx, \"") |> list.drop(1)
    // 矢印だけの module(関係の読み)は query を持たない
    case calls {
      [] -> Nil
      _ ->
        string.contains(
          file.text,
          "@external(javascript, \"../operations_ffi.mjs\", \"read_of\")\nfn query(ctx: Context, owner: String, name: String, input: a) -> Promise(b)\n",
        )
        |> should.be_true
    }
    list.each(calls, fn(rest) {
      string.starts_with(rest, service <> "\", \"") |> should.be_true
    })
  })
}

/// runtime は持ち主の Service の表を直に引く。添えの無い口・名だけで引く ctx は今までどおり。
pub fn runtime_reads_the_qualified_query_test() {
  ok_lines(runtime_read(), 9)
}

// ── 3 閉じた dialog ─────────────────────────────────────────────────────

/// 生成の CSS(style.css と SSR の頁の `<style>`)が閉じた dialog を `!important` で、`@layer` の中にも隠す。
pub fn closed_dialog_stays_hidden_test() {
  let #(code, _, files) = generated([])
  code |> should.equal(0)
  let rule = "dialog:not([open]) { display: none !important; }"
  let layered = "@layer yumemi-closed-dialog { " <> rule <> " }"
  let style = text_of(files, "public/priv/static/_yumemi/style.css")
  string.contains(style, rule <> "\n" <> layered) |> should.be_true
  let shell = text_of(files, "public/src/gen/shell.mjs")
  string.contains(shell, layered) |> should.be_true
}

// ── 4 Failed と Refused ─────────────────────────────────────────────────

/// `when(Failed)` の枝は `failed` で出る(`error` は断りでも立つ)。runtime は、断りの枝(`when(Refused(..))`)が
/// Component にある断りで `failed` を立てない。枝の無い断りは今までどおり Failed で出す。
pub fn failed_branch_is_not_shown_on_a_refusal_test() {
  let #(_, _, files) = generated([])
  let style = text_of(files, "public/priv/static/_yumemi/style.css")
  string.contains(
    style,
    "article-manage:not(:state(failed):state(sent-article_publish)) [data-yumemi-when~=\"article_publish.failed\"] { display: none; }",
  )
  |> should.be_true
  string.contains(
    style,
    "article-manage:not([data-yumemi-state~=\"failed\"][data-yumemi-state~=\"sent-article_publish\"]) [data-yumemi-when~=\"article_publish.failed\"] { display: none; }",
  )
  |> should.be_true
  string.contains(style, ":not(:state(error):state(sent-") |> should.be_false
  ok_lines(runtime_states(), 9)
}

// ── 5 要件の符号 ────────────────────────────────────────────────────────

const publish = "src/service/article_publish.gleam"

/// `requires` の `Consented` は live module の `Error` に `ConsentMissing` を足し、client の表の `requires` と
/// 状態の CSS に `consent_missing` / `refused-consent-missing` が載る(★ の Component は書き換えない)。表の
/// `refused` は Service の `Error` の符号のまま。
pub fn requirement_codes_ride_on_refused_test() {
  let #(code, lines, files) =
    generated([
      #(
        publish,
        "import gen/verb\n",
        "import gen/verb\nimport yumemi/require.{type Requirement, Consented}\n",
      ),
      #(
        publish,
        "pub const faces: List(Face) = [Public, Admin]\n",
        "pub const faces: List(Face) = [Public, Admin]\n\npub const requires: List(Requirement(Args)) = [Consented(\"use\"), Consented(\"handling\")]\n",
      ),
      #(
        "src/server.gleam",
        "pub const attached: List(server.Attached) = [",
        "pub const consents: List(String) = [\"use\", \"handling\"]\n\npub const attached: List(server.Attached) = [",
      ),
    ])
  let _ = lines
  code |> should.equal(0)
  let live = text_of(files, "public/src/gen/live/article_publish.gleam")
  string.contains(
    live,
    "pub type Error {\n  AlreadyPublished\n  AlreadyRetracted\n  ConsentMissing\n}\n",
  )
  |> should.be_true
  string.contains(live, "    ConsentMissing -> \"consent-missing\"\n")
  |> should.be_true
  // 2 つの Consented でも構成子は 1 つ
  string.split(live, "  ConsentMissing\n") |> list.length |> should.equal(2)
  string.contains(live, "DeclarationMissing") |> should.be_false
  let client = text_of(files, "public/priv/static/_yumemi/client.mjs")
  string.contains(
    client,
    "\"refused\": [\"already_published\", \"already_retracted\"], \"requires\": [\"consent_missing\"]",
  )
  |> should.be_true
  let style = text_of(files, "public/priv/static/_yumemi/style.css")
  string.contains(
    style,
    "article-manage:not(:state(refused-consent-missing):state(sent-article_publish)) [data-yumemi-when~=\"article_publish.refused-consent-missing\"] { display: none; }",
  )
  |> should.be_true
  // 要件の無い Service には足さない
  let create = text_of(files, "public/src/gen/live/article_create.gleam")
  string.contains(create, "ConsentMissing") |> should.be_false
}

/// `Declared` は `DeclarationMissing`。★ が同じ名の構成子を書いていればそれを使い、重ねない。
pub fn declared_and_a_star_constructor_of_the_same_name_test() {
  let #(code, _, files) =
    generated([
      #(
        publish,
        "import gen/verb\n",
        "import gen/verb\nimport yumemi/require.{type Requirement, Consented, Declared}\n",
      ),
      #(
        publish,
        "pub const faces: List(Face) = [Public, Admin]\n",
        "pub const faces: List(Face) = [Public, Admin]\n\npub const requires: List(Requirement(Args)) = [Declared(\"adult\"), Consented(\"use\")]\n",
      ),
      #(
        publish,
        "  AlreadyRetracted\n}",
        "  AlreadyRetracted\n  ConsentMissing\n}",
      ),
      #(
        "src/server.gleam",
        "Anyone, Attached, Get, Hook, ImageVariant, Media, Party, Post, ReadSession,",
        "Anyone, Attached, BrowserCookie, Declaration, Get, Hook, ImageVariant, Media, Party, Post, ReadSession,",
      ),
      #(
        "src/server.gleam",
        "pub const attached: List(server.Attached) = [",
        "pub const consents: List(String) = [\"use\"]\n\npub const browser: server.BrowserCookie = BrowserCookie(cookie: \"_fx\", key_binding: \"FX_KEY\", max_age_days: 30, declarations: [Declaration(kind: \"adult\", claim: \"declared_at\", max_age_days: 30)])\n\npub const attached: List(server.Attached) = [",
      ),
    ])
  let live = text_of(files, "public/src/gen/live/article_publish.gleam")
  string.contains(
    live,
    "pub type Error {\n  AlreadyPublished\n  AlreadyRetracted\n  ConsentMissing\n  DeclarationMissing\n}\n",
  )
  |> should.be_true
  code |> should.equal(0)
  // ★ の構成子は Service の `Error` の符号なので `refused` に入り、`requires` には重ねない
  let client = text_of(files, "public/priv/static/_yumemi/client.mjs")
  string.contains(
    client,
    "\"refused\": [\"already_published\", \"already_retracted\", \"consent_missing\"], \"requires\": [\"declaration_missing\"]",
  )
  |> should.be_true
}

/// attached の口の `NeedsDeclared` は `DeclarationMissing`。
pub fn needs_declared_attached_route_test() {
  let #(_, _, files) =
    generated([
      #(
        "src/server.gleam",
        "  ReadSession(attached: \"fixture_session\"),\n",
        "  ReadSession(attached: \"fixture_session\"),\n  NeedsDeclared(attached: \"blob_copy\", kind: \"adult\"),\n",
      ),
      #(
        "src/server.gleam",
        "Anyone, Attached, Get, Hook, ImageVariant, Media, Party, Post, ReadSession,",
        "Anyone, Attached, Get, Hook, ImageVariant, Media, NeedsDeclared, Party, Post, ReadSession,",
      ),
    ])
  let live = text_of(files, "public/src/gen/live/blob_copy.gleam")
  string.contains(live, "pub type Error {\n  DeclarationMissing\n}\n")
  |> should.be_true
  let client = text_of(files, "public/priv/static/_yumemi/client.mjs")
  string.contains(
    client,
    "\"refused\": [], \"requires\": [\"declaration_missing\"]",
  )
  |> should.be_true
}
