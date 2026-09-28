//// yumemi-s-1(0.11.5)── 門の戻り先(`RedirectBack`)と query を保つ `FixedKeep`、root.sql の欠けを生成で止める、
//// 面の部分集合を実行時の門にする(registry の `entries`)。

import glance
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleeunit/should
import yumemi_gen
import yumemi_gen/emit/gate as gate_emit
import yumemi_gen/model
import yumemi_gen/reader/gate
import yumemi_gen/source
import yumemi_gen/stop

fn unit(path: String, text: String) -> source.Unit {
  let assert Ok(module) = glance.module(text)
  source.Unit(path: path, text: text, module: module)
}

const routes = [
  "/", "/about/external", "/me", "/me/chats", "/search", "/:handle/:page",
]

const entry_source = "
pub const entries = [
  Http(name: \"www\", hosts: [Www], prefix: \"/api\", admit: Anonymous, subject: AnySubject, services: All, pages: AllPages, frame_src: []),
]
"

const back_gate = "
import framework/gate.{
  Adult, Exact, Fixed, FixedKeep, Gate, NoPageview, Prefix, Redirect, RedirectBack,
  Rule, SignIn, SignedIn, WhenSignedIn,
}

pub const gate: gate.Gate = Gate(
  sign_in: SignIn(path: \"/auth/sign-in\", fallback_origin: \"https://auth.example\"),
  rules: [
    Rule(pages: [Prefix(\"/me\")], except: [], checks: [
      SignedIn(fail: RedirectBack(location: \"/\", param: \"returnTo\")),
      Adult(fail: RedirectBack(location: \"/about/external?kind=adult\", param: \"next\")),
    ]),
    Rule(pages: [Exact(\"/:handle/:page\")], except: [], checks: [
      SignedIn(fail: RedirectBack(location: \"/\", param: \"returnTo\")),
    ]),
  ],
  redirects: [
    Redirect(pages: [Exact(\"/search\")], when: WhenSignedIn, to: FixedKeep(location: \"/me/chats\")),
    Redirect(pages: [Exact(\"/about/external\")], when: WhenSignedIn, to: Fixed(location: \"/search\")),
  ],
  frame_src: [],
  pageview: NoPageview,
)
"

fn entries() -> List(model.Entry) {
  [
    model.Entry(
      name: "www",
      prefix: "/api",
      admit: model.AnonymousAdmit,
      subject: model.AnyEntrySubject,
      services: model.AllServices,
      credential: model.SessionCredential,
    ),
  ]
}

fn read(text: String) -> #(gate.Gate, List(stop.Note)) {
  gate.read(
    "www",
    [unit("gate", text)],
    [unit("entry", entry_source)],
    entries(),
    routes,
    Some("/api/session"),
  )
}

// ── 1・2 宣言の読み ─────────────────────────────────────────────────────────

pub fn redirect_back_and_fixed_keep_are_read_test() {
  let #(read, notes) = read(back_gate)
  notes |> should.equal([])
  read.rules
  |> should.equal([
    gate.Rule(pages: [gate.Prefix("/me")], except: [], checks: [
      gate.SignedIn(gate.RedirectBack("/", "returnTo")),
      gate.Adult(gate.RedirectBack("/about/external?kind=adult", "next")),
    ]),
    gate.Rule(pages: [gate.Exact("/:handle/:page")], except: [], checks: [
      gate.SignedIn(gate.RedirectBack("/", "returnTo")),
    ]),
  ])
  read.redirects
  |> list.map(fn(redirect) { redirect.to })
  |> should.equal([gate.FixedKeep("/me/chats"), gate.Fixed("/search")])
}

/// 外の origin・`//` の path・`#` 付き・符号化の要る param・`?` 付きの FixedKeep は宣言で止める(exit 4)。
pub fn redirect_back_outside_face_is_conflict_test() {
  [
    #(
      "RedirectBack(location: \"/\", param: \"returnTo\")",
      "RedirectBack(location: \"https://evil.example/\", param: \"returnTo\")",
    ),
    #(
      "RedirectBack(location: \"/\", param: \"returnTo\")",
      "RedirectBack(location: \"//evil.example/\", param: \"returnTo\")",
    ),
    #(
      "RedirectBack(location: \"/\", param: \"returnTo\")",
      "RedirectBack(location: \"/#top\", param: \"returnTo\")",
    ),
    #(
      "RedirectBack(location: \"/\", param: \"returnTo\")",
      "RedirectBack(location: \"/\", param: \"a=b\")",
    ),
    #(
      "RedirectBack(location: \"/\", param: \"returnTo\")",
      "RedirectBack(location: \"/\", param: \"\")",
    ),
    #("FixedKeep(location: \"/me/chats\")", "FixedKeep(location: \"/me?x=1\")"),
    #(
      "FixedKeep(location: \"/me/chats\")",
      "FixedKeep(location: \"//evil.example\")",
    ),
  ]
  |> list.each(fn(pair) {
    let #(from, to) = pair
    let text = string.replace(back_gate, from, to)
    { text != back_gate } |> should.be_true
    let #(read, notes) = read(text)
    notes |> list.map(fn(note) { note.class }) |> should.equal([stop.Conflict])
    gate.is_empty(read) |> should.be_true
  })
}

// ── 1・2 gate.mjs ─────────────────────────────────────────────────────────

/// 新しい語を使わない門の runtime は 0.11.4 と同じ字(足した関数も分岐も出ない)。
pub fn gate_without_new_words_keeps_runtime_test() {
  let plain =
    back_gate
    |> string.replace(
      "RedirectBack(location: \"/\", param: \"returnTo\")",
      "RedirectTo(location: \"/\")",
    )
    |> string.replace(
      "RedirectBack(location: \"/about/external?kind=adult\", param: \"next\")",
      "RedirectTo(location: \"/about/external\")",
    )
    |> string.replace(
      "FixedKeep(location: \"/me/chats\")",
      "Fixed(location: \"/me/chats\")",
    )
    |> string.replace("Redirect, RedirectBack,", "Redirect, RedirectTo,")
  let #(read, notes) = read(plain)
  notes |> should.equal([])
  let text = gate_emit.text("// header", read, routes)
  string.contains(text, "redirectBack") |> should.be_false
  string.contains(text, "redirect-back") |> should.be_false
  string.contains(text, "fixed-keep") |> should.be_false
  // 0.11.4 の runtime の字そのまま(redirectFor の分岐は fixed と safeParam の 2 つだけ)
  string.contains(
    text,
    "  const location = redirect.to.type === \"fixed\"\n    ? redirect.to.location\n    : safeParam(",
  )
  |> should.be_true
  string.contains(
    text,
    "  if (fail.type === \"deny\") return text(fail.status, fail.body);\n  return redirectTo(302, fail.location);\n}\n",
  )
  |> should.be_true
}

@external(javascript, "./yumemi_s1_test_ffi.mjs", "gate_redirect_back")
fn gate_redirect_back(text: String) -> String

/// 面の中 / 外(`//` の path)/ 符号化 / 既に query を持つ location / client 遷移の fetch / FixedKeep / Fixed。
pub fn gate_redirect_back_runtime_test() {
  let #(read, _) = read(back_gate)
  let out = gate_redirect_back(gate_emit.text("// header", read, routes))
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  string.split(out, "\n") |> list.length |> should.equal(10)
}

// ── 3 root.sql の欠け ───────────────────────────────────────────────────────

@external(javascript, "./yumemi_s1_test_ffi.mjs", "copy_app")
fn copy_app(from: String) -> String

@external(javascript, "./yumemi_s1_test_ffi.mjs", "remove_app")
fn remove_app(dir: String) -> Nil

@external(javascript, "./yumemi_s1_test_ffi.mjs", "edit")
fn edit(dir: String, path: String, from: String, to: String) -> Bool

@external(javascript, "./yumemi_s1_test_ffi.mjs", "remove")
fn remove(dir: String, path: String) -> Nil

fn notes_of(dir: String) -> List(stop.Note) {
  let assert Ok(#(_, notes)) = yumemi_gen.generate(dir)
  notes
}

fn registry_of(dir: String) -> String {
  let assert Ok(#(files, _)) = yumemi_gen.generate(dir)
  let assert Ok(file) =
    list.find(files, fn(file) { file.path == "src/gen/registry.mjs" })
  file.text
}

/// root を持つ Service の root.sql を 1 本抜くと、その Service の名で exit 3。
pub fn missing_root_sql_stops_generation_test() {
  let dir = copy_app("fixtures/article")
  remove(dir, "db/queries/article_read/root.sql")
  let notes = notes_of(dir)
  remove_app(dir)
  notes
  |> should.equal([
    stop.Note(
      class: stop.Missing,
      text: "service.article_read: root(article)を読む db/queries/article_read/root.sql が無い(実行時に 503)",
    ),
  ])
  stop.worst(notes) |> should.equal(3)
}

/// ★ の口で応える Service(hook `service_<name>`、DO の器の port)は root の 1 文を持たなくても止めない。
pub fn port_service_without_root_sql_is_not_stopped_test() {
  let dir = copy_app("fixtures/article")
  remove(dir, "db/queries/article_read/root.sql")
  edit(
    dir,
    "src/server.gleam",
    "  Hook(name: \"attached_blob_copy\", module: \"hooks\"),\n",
    "  Hook(name: \"attached_blob_copy\", module: \"hooks\"),\n  Hook(name: \"service_article_read\", module: \"hooks\"),\n",
  )
  |> should.be_true
  let notes = notes_of(dir)
  remove_app(dir)
  notes |> should.equal([])
}

// ── 4 面の部分集合 ─────────────────────────────────────────────────────────

const row_read = "{ name: 'article_read', module: article_read, root: root_article_read, method: 'GET', path: '/api/admin/articles/:slug', fields: ['slug'], folded: null"

/// 入口が面の数と同じ(public・admin)なら 0.11.4 と同じ行(`entries` を付けない)。
pub fn every_face_service_has_no_entries_test() {
  let text = registry_of("fixtures/article")
  string.contains(text, "entries:") |> should.be_false
  string.contains(text, row_read <> " },") |> should.be_true
}

/// 当たりうる入口(同じ媒体、ReadOnly なら Read の Service)が面の外に残ると `entries`。面 1 つは今までどおり `entry`。
pub fn subset_faces_get_entries_test() {
  let dir = copy_app("fixtures/article")
  edit(
    dir,
    "src/entry.gleam",
    "  AdminHost\n}",
    "  AdminHost\n  OpsHost\n  ApiHost\n}",
  )
  |> should.be_true
  edit(
    dir,
    "src/entry.gleam",
    "    services: All,\n  ),\n]",
    "    services: All,\n  ),\n  Http(name: \"ops\", hosts: [OpsHost], prefix: \"/api\", admit: Authenticated, subject: Subjects([Staff]), services: ReadOnly, pages: NoPages, frame_src: []),\n  HttpApi(name: \"api\", hosts: [ApiHost], prefix: \"/api/v1\", admit: Authenticated, subject: Subjects([Staff]), services: All, credential: ApiKey(per_minute: 60), pages: NoPages, frame_src: []),\n]",
  )
  |> should.be_true
  edit(
    dir,
    "src/entry.gleam",
    "Http, ReadOnly,",
    "ApiKey, Http, HttpApi, NoPages, ReadOnly,",
  )
  |> should.be_true
  let text = registry_of(dir)
  remove_app(dir)
  // Read の Service([Public, Admin])は ReadOnly の ops から当たる → entries
  string.contains(text, row_read <> ", entries: ['public', 'admin'] },")
  |> should.be_true
  // Write の Service([Public, Admin])は ops から当たらず、api は媒体が違う → 付けない
  string.contains(
    text,
    "{ name: 'article_publish', module: article_publish, root: root_article_publish, method: 'POST', path: '/api/admin/articles/:slug/publish', fields: ['slug'], folded: null },",
  )
  |> should.be_true
  // 面 1 つは entry のまま
  string.contains(text, "entry: 'admin' },") |> should.be_true
  string.contains(text, "entry: 'public' },") |> should.be_true
}

@external(javascript, "./yumemi_s1_test_ffi.mjs", "entries_check")
fn entries_check() -> String

/// 検査 7:`entries` の外の入口は 403、中は通す。`entries` も `entry` も無い行(4 面全部)は通す。
pub fn runtime_rejects_entries_outside_test() {
  let out = entries_check()
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  string.split(out, "\n") |> list.length |> should.equal(6)
}
