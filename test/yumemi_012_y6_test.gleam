//// yumemi-012-y6(0.12 段 C)── publish の前に門・数える口・器・柵を固める。
//// 第 35〜37 条の足した検査は fixture `gen/fixtures/cms` の写しを 1 か所ずつ壊して生成し、停止コードを見る。
//// runtime(node)は `yumemi/server/http.mjs` を偽の spec で、門は fixture cms の生成 `gate.mjs` を起こす。

import gleam/list
import gleam/string
import gleeunit/should
import yumemi/front/attr
import yumemi/front/css
import yumemi/front/el
import yumemi/front/html
import yumemi/front/sketch_css
import yumemi/gen as yumemi_gen
import yumemi/gen/stop

const fixture = "gen/fixtures/cms"

@external(javascript, "./yumemi_s1_test_ffi.mjs", "copy_app")
fn copy_app(from: String) -> String

@external(javascript, "./yumemi_s1_test_ffi.mjs", "remove_app")
fn remove_app(dir: String) -> Nil

@external(javascript, "./yumemi_s1_test_ffi.mjs", "edit")
fn edit(dir: String, path: String, from: String, to: String) -> Bool

/// fixture の写しの `path` の `from` を `to` に替えて生成し、(停止コード, 診断の文の並び, 書いた file)。
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

fn broken(edits: List(#(String, String, String))) -> #(Int, List(String)) {
  let #(code, lines, _) = generated(edits)
  #(code, lines)
}

fn names(lines: List(String), text: String) -> Bool {
  list.any(lines, fn(line) { string.contains(line, text) })
}

const gate = "public/src/gate.gleam"

const store_sink = "sink: Store(
      resolve: Some(\"page_resolve\"),
      rollup_by: [\"section\"],
      exclude_when: [\"own\"],
    ),"

const resolve = "src/service/page_resolve.gleam"

/// 数える口を `ToService("page_resolve")` に替え、page_resolve の Args を `args` に替える。
fn to_service(args: String) -> List(#(String, String, String)) {
  [
    #(gate, store_sink, "sink: ToService(\"page_resolve\"),"),
    #(gate, "Slug, Store,", "Slug, ToService,"),
    #(resolve, "Args(path: String)", args),
    #(
      resolve,
      "import gleam/string",
      "import gleam/option\nimport gleam/string\nimport gen/types/title\nimport yumemi/time\n\npub type NavKind {\n  Initial\n  Reload\n  Spa\n}",
    ),
  ]
}

// ── 第 35 条:FromQuery の name に受け口の event の欄の名を使えない ───────────────

pub fn from_query_name_must_not_be_an_event_field_test() {
  // 同じ名の欄を fields から外し、FromQuery だけがその名を持つ形(「2 つある」の検査には当たらない)
  [
    #("NavKind,\n", "kind"),
    #("ClientAt,\n", "client_at"),
    #("Previous,\n", "prev"),
    #("Referrer,\n", "referrer_host"),
  ]
  |> list.each(fn(pair) {
    let #(field, name) = pair
    let #(code, lines) =
      broken([
        #(gate, "      " <> field, ""),
        #(gate, "name: \"source_key\"", "name: \"" <> name <> "\""),
      ])
    code |> should.equal(4)
    names(
      lines,
      "FromQuery の name `" <> name <> "` は [a-z][a-z0-9_]* で、受け口の event の欄の名",
    )
    |> should.be_true
    names(lines, "が 2 つある") |> should.be_false
  })
}

// ── 第 36 条:ToService の Args の id と型 ──────────────────────────────────

pub fn to_service_args_need_id_test() {
  let #(code, lines) =
    broken(to_service(
      "Args(path: String, kind: String, source_key: option.Option(String))",
    ))
  code |> should.equal(3)
  names(lines, "ToService(\"page_resolve\"): Args に欄 `id` が無い")
  |> should.be_true
}

pub fn to_service_needs_anyone_or_party_clause_test() {
  let args = "Args(id: String, path: String)"
  let #(code, lines) =
    broken(
      list.append(to_service(args), [
        #(resolve, "who: allow.Anyone,", "who: allow.Staff,"),
      ]),
    )
  code |> should.equal(3)
  names(
    lines,
    "ToService(\"page_resolve\"): Service の allow に `Anyone` か `Party` の句が無い",
  )
  |> should.be_true
  // 句が Party なら通る(Anyone は上の Args の test が通している)
  let #(code, lines) =
    broken(
      list.append(to_service(args), [
        #(resolve, "who: allow.Anyone,", "who: allow.Party,"),
      ]),
    )
  code |> should.equal(0)
  names(lines, "の句が無い") |> should.be_false
}

pub fn to_service_args_take_app_types_test() {
  // musearch の pageview_record の形:値型・Datetime・3 値の列挙・Option の値型
  let #(code, lines) =
    broken(to_service(
      "Args(id: title.Title, client_at: time.Datetime, kind: NavKind, path: title.Title, prev: option.Option(title.Title), referrer_path: option.Option(String), referrer_host: option.Option(title.Title), source_key: option.Option(title.Title))",
    ))
  code |> should.equal(0)
  lines
  // 0.12 段 C:ToService は警告の 1 行でなく面の逃げ道の数えの 1 行(Y3)に入る
  |> list.filter(fn(line) { !string.contains(line, "数える口の送り先 ToService") })
  |> should.equal([])
}

pub fn to_service_args_type_must_decode_from_event_test() {
  [
    #("kind: Int", "kind"),
    #("kind: Bool", "kind"),
    #("client_at: time.Date", "client_at"),
    #("path: Int", "path"),
    #("source_key: option.Option(Int)", "source_key"),
  ]
  |> list.each(fn(pair) {
    let #(field, name) = pair
    let base = [
      #("id", "id: String"),
      #("kind", "kind: NavKind"),
      #("client_at", "client_at: time.Datetime"),
      #("path", "path: String"),
      #("source_key", "source_key: option.Option(String)"),
    ]
    let args =
      base
      |> list.map(fn(row) {
        case row.0 == name {
          True -> field
          False -> row.1
        }
      })
      |> string.join(", ")
    let #(code, lines) = broken(to_service("Args(" <> args <> ")"))
    code |> should.equal(4)
    names(lines, "Args の欄 `" <> name <> "` の型を event の値から decode できない")
    |> should.be_true
  })
  // 3 値の全部を持たない列挙は kind を受けられない
  let #(code, lines) =
    broken(
      list.append(
        to_service(
          "Args(id: String, kind: NavKind, client_at: time.Datetime, path: String)",
        ),
        [#(resolve, "  Reload\n  Spa\n", "  Reload\n")],
      ),
    )
  code |> should.equal(4)
  names(lines, "Args の欄 `kind` の型を event の値から decode できない")
  |> should.be_true
}

// ── 第 37 条:Store の fields は Path を持つ ─────────────────────────────────

pub fn store_needs_path_field_test() {
  let #(code, lines) = broken([#(gate, "      Path,\n", "")])
  code |> should.equal(3)
  names(lines, "public/gate: pageview の Store の fields に Path が無い")
  |> should.be_true
}

// ── Args の Color ─────────────────────────────────────────────────────────

pub fn service_args_take_color_test() {
  let #(code, lines, files) =
    generated([
      #(
        "src/service/article_create.gleam",
        "import yumemi/er.{type Key}",
        "import yumemi/er.{type Key}\nimport yumemi/front/color",
      ),
      #(
        "src/service/article_create.gleam",
        "    slug: Slug,\n",
        "    slug: Slug,\n    accent: color.Color,\n",
      ),
    ])
  code |> should.equal(0)
  names(lines, "decode を導けない") |> should.be_false
  let assert Ok(runtime) = list.key_find(files, "src/gen/http_runtime.mjs")
  string.contains(runtime, "['accent',['color']]") |> should.be_true
}

// ── 門・CSP・受け口(node)──────────────────────────────────────────────

@external(javascript, "./yumemi_012_y6_test_ffi.mjs", "gate_checks")
fn gate_checks() -> String

@external(javascript, "./yumemi_012_y6_test_ffi.mjs", "receiver_checks")
fn receiver_checks() -> String

@external(javascript, "./yumemi_012_y6_test_ffi.mjs", "shell_checks")
fn shell_checks() -> String

fn count(text: String, part: String) -> Int {
  list.length(string.split(text, part)) - 1
}

pub fn gate_read_failures_are_not_found_forbidden_or_unavailable_test() {
  let out = gate_checks()
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  count(out, "ok ") |> should.equal(12)
}

pub fn shell_session_read_5xx_is_unavailable_test() {
  let out = shell_checks()
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  count(out, "ok ") |> should.equal(11)
}

pub fn receiver_to_service_requires_cookie_and_logs_test() {
  let out = receiver_checks()
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  count(out, "ok ") |> should.equal(13)
}

pub fn csp_has_self_on_every_declared_directive_test() {
  let #(code, _, files) = generated([])
  code |> should.equal(0)
  let assert Ok(gate_mjs) = list.key_find(files, "public/src/gen/gate.mjs")
  string.contains(
    gate_mjs,
    "\"/article/:slug\": \"frame-src 'self' https://frames.example https://*.video.example; img-src 'self' https://img.example\"",
  )
  |> should.be_true
  string.contains(
    gate_mjs,
    "\"/status\": \"connect-src 'self' https://api.example; media-src 'self' https://media.example\"",
  )
  |> should.be_true
  count(gate_mjs, "'self'") |> should.equal(4)
}

pub fn shell_read_5xx_is_unavailable_test() {
  let #(_, _, files) = generated([])
  let assert Ok(shell) = list.key_find(files, "public/src/gen/shell.mjs")
  string.contains(shell, "if (response.status >= 500) {") |> should.be_true
  string.contains(shell, "return failure(503, \"unavailable\");")
  |> should.be_true
  string.contains(
    shell,
    "console.error(source.root ? \"yumemi shell: root read error\"",
  )
  |> should.be_true
}

// ── 柵 ───────────────────────────────────────────────────────────────────

pub fn form_action_takes_the_url_fence_test() {
  [
    "javascript:alert(1)", "JaVaScript:alert(1)", " javascript:alert(1)",
    "\tjavascript:alert(1)", "data:text/html,x",
  ]
  |> list.each(fn(url) {
    html.form_([attr.action(url)], [])
    |> el.to_string
    |> should.equal("<form></form>")
  })
  ["/search", "search?q=a", "http://example.com/x", "https://example.com/x"]
  |> list.each(fn(url) {
    html.form_([attr.action(url)], [])
    |> el.to_string
    |> should.equal("<form action=\"" <> url <> "\"></form>")
  })
}

pub fn named_font_family_takes_the_fence_test() {
  [
    "x;} body{color:red", "x;}", "a</style><script>",
    "\"Noto Sans JP\"; color: red", "var(--x);}", "var(--X)", "\"a\\\"b\"",
    "url(x)", "a /* c */", "", "a,,b",
  ]
  |> list.each(fn(value) {
    sketch_css.font_family(css.Named(value)) |> should.equal("unset")
  })
  [
    "var(--ma-font-ui)", "var(--ma-article-font)",
    "\"Noto Sans JP\", sans-serif", "'Hiragino Sans', system-ui",
    "\"ヒラギノ角ゴ ProN\", serif", "Noto Sans JP",
  ]
  |> list.each(fn(value) {
    sketch_css.font_family(css.Named(value)) |> should.equal(value)
  })
}
