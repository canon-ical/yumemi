//// yumemi-012-y5(0.12 段 B)── 門と業務付き CMS の機能:申告・同意・数える口と器・CSP・media の variant・失敗の文言。
//// 第 32〜40 条は fixture `gen/fixtures/cms` の写しを 1 か所ずつ壊して生成し、停止コードを見る。runtime(node)は
//// `yumemi/server/http.mjs` を偽の spec で起こし、送り手は `yumemi/front/pageview.mjs` を偽の window で起こす。

import gleam/list
import gleam/string
import gleeunit/should
import simplifile
import yumemi/gen as yumemi_gen
import yumemi/gen/stop

const fixture = "gen/fixtures/cms"

@external(javascript, "./yumemi_s1_test_ffi.mjs", "copy_app")
fn copy_app(from: String) -> String

@external(javascript, "./yumemi_s1_test_ffi.mjs", "remove_app")
fn remove_app(dir: String) -> Nil

@external(javascript, "./yumemi_s1_test_ffi.mjs", "edit")
fn edit(dir: String, path: String, from: String, to: String) -> Bool

/// fixture の写しの `path` の `from` を `to` に替えて生成し、(停止コード, 診断の文の並び)。
fn broken(edits: List(#(String, String, String))) -> #(Int, List(String)) {
  let dir = copy_app(fixture)
  list.each(edits, fn(item) {
    let #(path, from, to) = item
    edit(dir, path, from, to) |> should.be_true
  })
  let assert Ok(#(_, notes)) = yumemi_gen.generate(dir)
  remove_app(dir)
  #(stop.worst(notes), list.map(notes, fn(note) { stop.line(note) }))
}

fn names(lines: List(String), text: String) -> Bool {
  list.any(lines, fn(line) { string.contains(line, text) })
}

const gate = "public/src/gate.gleam"

const server = "src/server.gleam"

// ── fixture ───────────────────────────────────────────────────────────────

pub fn cms_fixture_generates_without_notes_test() {
  let assert Ok(#(files, notes)) = yumemi_gen.generate(fixture)
  notes |> should.equal([])
  let paths = list.map(files, fn(file) { file.path })
  list.contains(paths, "db/framework/pageview.sql") |> should.be_true
  list.contains(paths, "public/src/gen/media.gleam") |> should.be_true
  list.contains(paths, "public/priv/static/_yumemi/client.mjs")
  |> should.be_true
}

// ── 第 32 条:申告の kind が browser.declarations に無い・browser の宣言が無い ─────────────

pub fn declared_kind_outside_browser_declarations_is_exit_four_test() {
  let #(code, lines) =
    broken([
      #(
        gate,
        "only: [WhenDeclared(\"adult\")]",
        "only: [WhenDeclared(\"teen\")]",
      ),
    ])
  code |> should.equal(4)
  names(
    lines,
    "public/gate の申告 \"teen\" が src/server.gleam の browser.declarations に無い",
  )
  |> should.be_true
  let #(code, lines) =
    broken([
      #(
        "src/service/article_read.gleam",
        "[Declared(\"adult\")]",
        "[Declared(\"aldut\")]",
      ),
    ])
  code |> should.equal(4)
  names(lines, "service.article_read requires の申告 \"aldut\"") |> should.be_true
  let #(code, lines) =
    broken([
      #(
        server,
        "kind: \"adult\"),\n  NeedsDeclared",
        "kind: \"adlt\"),\n  NeedsDeclared",
      ),
    ])
  code |> should.equal(4)
  names(lines, "attached_roles の fixture_declare の申告 \"adlt\"")
  |> should.be_true
}

pub fn declared_without_browser_is_exit_four_test() {
  let #(code, lines) =
    broken([
      #(
        server,
        "pub const browser: server.BrowserCookie",
        "const browser_off: server.BrowserCookie",
      ),
    ])
  // 申告が門・要件・役にあるのに browser の宣言が無い(第 32 条 exit 4)、器 Store の印も焼けない(第 37 条 exit 3)
  code |> should.equal(4)
  names(lines, "に src/server.gleam の `browser` の宣言が無い") |> should.be_true
  names(lines, "[exit 3 宣言の不足] public/gate: pageview の Store に")
  |> should.be_true
}

// ── 第 33 条:Declaration の重なり・綴り・期間 ─────────────────────────────

pub fn declaration_duplicate_spelling_and_period_are_exit_four_test() {
  let #(code, lines) =
    broken([
      #(
        server,
        "kind: \"region\", claim: \"region_declared_at\"",
        "kind: \"adult\", claim: \"adult_declared_at\"",
      ),
    ])
  code |> should.equal(4)
  names(lines, "申告の kind \"adult\" が 2 つある") |> should.be_true
  names(lines, "申告の claim \"adult_declared_at\" が 2 つある") |> should.be_true
  let #(code, lines) =
    broken([#(server, "kind: \"region\"", "kind: \"Region\"")])
  code |> should.equal(4)
  names(lines, "申告の kind \"Region\" が [a-z][a-z0-9_]* でない") |> should.be_true
  let #(code, lines) =
    broken([#(server, "max_age_days: 395", "max_age_days: 401")])
  code |> should.equal(4)
  names(lines, "max_age_days 401 が 1〜cookie の max_age_days(400)の外")
  |> should.be_true
}

// ── 第 34・35 条:数える口の Page と欄 ─────────────────────────────────────

pub fn pageview_page_outside_routes_is_exit_four_test() {
  let #(code, lines) =
    broken([
      #(
        gate,
        "pages: [Prefix(\"/article\"), Exact(\"/status\")]",
        "pages: [Prefix(\"/article\"), Exact(\"/nope\")]",
      ),
    ])
  code |> should.equal(4)
  names(lines, "public/gate: Exact(\"/nope\") の Page が面の route に無い")
  |> should.be_true
}

pub fn pageview_fields_overlap_and_spelling_are_exit_four_test() {
  let #(code, lines) =
    broken([
      #(
        gate,
        "      ClientAt,\n      Path,",
        "      ClientAt,\n      Path,\n      Path,",
      ),
    ])
  code |> should.equal(4)
  names(lines, "pageview の欄 `path` が 2 つある") |> should.be_true
  let #(code, lines) =
    broken([#(gate, "name: \"source_key\"", "name: \"path\"")])
  code |> should.equal(4)
  names(lines, "pageview の欄 `path` が 2 つある") |> should.be_true
  let #(code, lines) = broken([#(gate, "param: \"r\"", "param: \"r-x\"")])
  code |> should.equal(4)
  names(lines, "FromQuery の param `r-x` が [A-Za-z0-9_]+ でない") |> should.be_true
  let #(code, lines) = broken([#(gate, "Slug(max: 16)", "Slug(max: 65)")])
  code |> should.equal(4)
  names(lines, "Slug(max: 65) が 1〜64 の外") |> should.be_true
}

/// 欄は閉じた語彙 ── 正規表現の文字列を受ける口は無く、`FromQuery` の `pattern` に文字列を書けば止まる。
pub fn pageview_field_with_regex_string_is_exit_four_test() {
  let #(code, lines) =
    broken([#(gate, "pattern: Slug(max: 16)", "pattern: \"[a-z]+\"")])
  code |> should.equal(4)
  names(lines, "FromQuery の `pattern` は Slug(max:)") |> should.be_true
}

// ── 第 36 条:ToService の Service と Args ─────────────────────────────────

const store_sink = "sink: Store(
      resolve: Some(\"page_resolve\"),
      rollup_by: [\"section\"],
      exclude_when: [\"own\"],
    ),"

pub fn to_service_missing_or_args_mismatch_is_exit_four_test() {
  let #(code, lines) =
    broken([
      #(gate, store_sink, "sink: ToService(\"ghost\"),"),
      #(gate, "Slug, Store,", "Slug, ToService,"),
    ])
  code |> should.equal(4)
  names(lines, "ToService(\"ghost\") の Service が無い") |> should.be_true
  // article_read の Args(slug) は fields から組めない
  let #(code, lines) =
    broken([
      #(gate, store_sink, "sink: ToService(\"article_read\"),"),
      #(gate, "Slug, Store,", "Slug, ToService,"),
    ])
  code |> should.equal(4)
  names(lines, "Args の欄 `slug` が fields から組む欄に無い") |> should.be_true
}

/// `ToService` は名前付きの逃げ道 ── 通れば停止コード 0 の警告で面ごとに数える。
pub fn to_service_is_counted_as_escape_with_warning_test() {
  let #(code, lines) =
    broken([
      #(gate, store_sink, "sink: ToService(\"page_resolve\"),"),
      #(gate, "Slug, Store,", "Slug, ToService,"),
      #(
        "src/service/page_resolve.gleam",
        "Args(path: String)",
        "Args(path: String, kind: String, source_key: option.Option(String))",
      ),
      #(
        "src/service/page_resolve.gleam",
        "import gleam/string",
        "import gleam/option\nimport gleam/string",
      ),
    ])
  code |> should.equal(0)
  lines
  |> should.equal([
    // 0.12 段 C:ToService の数は面ごとの逃げ道の 1 行に入った(期待を別の警告の行から替えた)
    "[exit 0 警告] public: 逃げ道 ── escape 0 種 0 か所(うち interactive Component の中 0)、生の CSS 0 file 0 規則、数える口の送り先 ToService 1",
  ])
  // 載らないことがある欄(source_key)を Option で受けなければ止まる
  let #(code, lines) =
    broken([
      #(gate, store_sink, "sink: ToService(\"page_resolve\"),"),
      #(gate, "Slug, Store,", "Slug, ToService,"),
      #(
        "src/service/page_resolve.gleam",
        "Args(path: String)",
        "Args(path: String, source_key: String)",
      ),
    ])
  code |> should.equal(4)
  names(lines, "Args の欄 `source_key` は載らないことがあるので Option で受ける")
  |> should.be_true
}

// ── 第 37 条:Store の resolve と欄 ────────────────────────────────────────

pub fn store_resolve_and_columns_are_checked_test() {
  let #(code, lines) =
    broken([#(gate, "Some(\"page_resolve\")", "Some(\"ghost\")")])
  code |> should.equal(4)
  names(lines, "Store の resolve の Service が無い: ghost") |> should.be_true
  let #(code, lines) =
    broken([#(gate, "rollup_by: [\"section\"]", "rollup_by: [\"shop\"]")])
  code |> should.equal(4)
  names(lines, "Store の rollup_by `shop` が service.page_resolve の Out に無い")
  |> should.be_true
  let #(code, lines) =
    broken([#(gate, "exclude_when: [\"own\"]", "exclude_when: [\"section\"]")])
  code |> should.equal(4)
  names(lines, "Store の exclude_when `section` が Bool でない") |> should.be_true
}

// ── 第 38 条:CSP の Page と host ──────────────────────────────────────────

pub fn csp_page_and_host_spelling_are_exit_four_test() {
  let #(code, lines) =
    broken([
      #(
        gate,
        "Csp(pages: [Exact(\"/status\")]",
        "Csp(pages: [Exact(\"/gone\")]",
      ),
    ])
  code |> should.equal(4)
  names(lines, "Exact(\"/gone\") の Page が面の route に無い") |> should.be_true
  let #(code, lines) =
    broken([
      #(
        gate,
        "ImgSrc([\"img.example\"])",
        "ImgSrc([\"https://img.example/x\"])",
      ),
    ])
  code |> should.equal(4)
  names(lines, "csp の host \"https://img.example/x\" が host の綴りでない")
  |> should.be_true
}

// ── 第 39 条:media の variant ─────────────────────────────────────────────

pub fn media_variant_names_and_background_are_exit_four_test() {
  let #(code, lines) = broken([#(server, "name: \"w800\"", "name: \"thumb\"")])
  code |> should.equal(4)
  names(lines, "variant の名 \"thumb\" が 2 つある") |> should.be_true
  let #(code, lines) =
    broken([
      #(server, "theme_background: \"w1600\"", "theme_background: \"w2400\""),
    ])
  code |> should.equal(4)
  names(lines, "theme_background \"w2400\" が variants に無い") |> should.be_true
  let #(code, lines) = broken([#(server, "name: \"w800\"", "name: \"W800\"")])
  code |> should.equal(4)
  names(lines, "variant の名 \"W800\" が [a-z][a-z0-9_]* でない") |> should.be_true
}

pub fn media_module_builds_url_per_segment_test() {
  let assert Ok(text) =
    simplifile.read(fixture <> "/public/src/gen/media.gleam")
  text |> string.contains("pub type Variant {") |> should.be_true
  text |> string.contains("  Thumb\n") |> should.be_true
  text
  |> string.contains("pub const theme_background: Variant = W1600")
  |> should.be_true
  text
  |> string.contains("\"/media/\" <> key <> \"?v=\" <> name(variant)")
  |> should.be_true
}

// ── 第 40 条:同意の kind が consents に無い ───────────────────────────────

pub fn consent_kind_outside_consents_is_exit_four_test() {
  let #(code, lines) =
    broken([
      #(
        "src/service/article_publish.gleam",
        "Consented(\"handling\")",
        "Consented(\"terms\")",
      ),
    ])
  code |> should.equal(4)
  names(
    lines,
    "service.article_publish requires の同意 \"terms\" が src/server.gleam の `consents` に無い",
  )
  |> should.be_true
  let #(code, lines) =
    broken([#(gate, "Consented(kind: \"use\"", "Consented(kind: \"tos\"")])
  code |> should.equal(4)
  names(lines, "public/gate の同意 \"tos\"") |> should.be_true
  // 0.11 の要件の名は読めない
  let #(code, lines) =
    broken([
      #("src/service/article_publish.gleam", "Consented(\"use\"), ", "Use, "),
    ])
  code |> should.equal(4)
  names(lines, "の項 `Use` は Declared / Consented / ConsentedFor でない")
  |> should.be_true
}

// ── 生成物:門は印の meta だけ、送り手は client.mjs 1 つ、失敗の文言は 2 つ ─────────────

pub fn generated_gate_has_no_inline_script_and_two_texts_test() {
  let assert Ok(gate_mjs) =
    simplifile.read(fixture <> "/public/src/gen/gate.mjs")
  gate_mjs |> string.contains("<script") |> should.be_false
  gate_mjs |> string.contains("adult declaration") |> should.be_false
  gate_mjs |> string.contains("muse not found") |> should.be_false
  gate_mjs |> string.contains("session read failed") |> should.be_false
  gate_mjs
  |> string.contains(
    "return read.status === 404 ? text(404, \"not found\") : text(403, \"forbidden\");",
  )
  |> should.be_true
  let assert Ok(shell) = simplifile.read(fixture <> "/public/src/gen/shell.mjs")
  shell |> string.contains("failure(403, \"forbidden\")") |> should.be_true
  shell |> string.contains("failure(404, \"not found\")") |> should.be_true
  shell |> string.contains("adult declaration") |> should.be_false
  let assert Ok(client) =
    simplifile.read(fixture <> "/public/priv/static/_yumemi/client.mjs")
  // 送り手は 1 つ:pageview.mjs の start を 1 回、navigate.mjs には pageview の設定を渡さない
  count(client, "\"/api/_yumemi/pageviews\"") |> should.equal(1)
  client |> string.contains("pageview: {") |> should.be_false
}

fn count(text: String, part: String) -> Int {
  list.length(string.split(text, part)) - 1
}

/// framework・runtime・生成器・README に `adult` の綴りが残らない(fixture と test の app の値は除く)。
pub fn adult_is_gone_from_framework_test() {
  adult_spellings() |> should.equal("")
}

// ── runtime(node)──────────────────────────────────────────────────────────

@external(javascript, "./yumemi_012_y5_test_ffi.mjs", "runtime_checks")
fn runtime_checks() -> String

@external(javascript, "./yumemi_012_y5_test_ffi.mjs", "sender_checks")
fn sender_checks() -> String

@external(javascript, "./yumemi_012_y5_test_ffi.mjs", "adult_spellings")
fn adult_spellings() -> String

pub fn runtime_declarations_consents_and_session_test() {
  let out = runtime_checks()
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  count(out, "ok ") |> should.equal(20)
}

pub fn sender_sends_once_per_load_and_navigation_test() {
  let out = sender_checks()
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  count(out, "ok ") |> should.equal(9)
}

@external(javascript, "./yumemi_012_y5_test_ffi.mjs", "gate_checks")
fn gate_checks() -> String

pub fn gate_passes_declared_consent_and_marks_counted_pages_test() {
  let out = gate_checks()
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  count(out, "ok ") |> should.equal(7)
}
