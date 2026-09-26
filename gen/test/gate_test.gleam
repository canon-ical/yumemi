//// yumemi-gate-1 ── 面の門の宣言(`src/gate.gleam`)の読みと `gen/gate.mjs` の出力、route 表の literal-first。

import glance
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import simplifile
import yumemi_gen/emit/front as front_emit
import yumemi_gen/emit/gate as gate_emit
import yumemi_gen/emit/hash
import yumemi_gen/face
import yumemi_gen/model
import yumemi_gen/reader
import yumemi_gen/reader/front as reader_front
import yumemi_gen/reader/gate
import yumemi_gen/source
import yumemi_gen/stop

fn unit(path: String, text: String) -> source.Unit {
  let assert Ok(module) = glance.module(text)
  source.Unit(path: path, text: text, module: module)
}

const www_routes = [
  "/", "/about/external", "/claim/:code", "/for_stores/api/v1", "/me",
  "/me/chats", "/me/chats/:id", "/muse/:handle", "/muse/:handle/article",
  "/search",
]

const www_gate = "
import framework/gate.{
  Adult, Deny, Exact, Gate, Pageview, Prefix, Redirect, Rule, SafeParam,
  SignIn, SignedIn, ToSignIn, WhenAdult,
}

pub const gate: gate.Gate = Gate(
  sign_in: SignIn(path: \"/auth/sign-in\", fallback_origin: \"https://auth.example\"),
  rules: [
    Rule(pages: [Prefix(\"/me\")], except: [], checks: [
      SignedIn(fail: ToSignIn(status: 302, back: False)),
      Adult(fail: Deny(status: 403, body: \"adult declaration required\")),
    ]),
    Rule(pages: [Exact(\"/claim/:code\")], except: [], checks: [
      SignedIn(fail: ToSignIn(status: 303, back: True)),
    ]),
  ],
  redirects: [
    Redirect(pages: [Exact(\"/\")], when: WhenAdult, to: SafeParam(param: \"returnTo\", fallback: \"/search\")),
  ],
  frame_src: [Exact(\"/\"), Exact(\"/about/external\")],
  pageview: Pageview(
    pages: [Exact(\"/search\"), Prefix(\"/muse\")],
    endpoint: \"/api/pageviews\",
    source_param: \"r\",
    storage_key: \"app:last-pageview\",
  ),
)
"

const entry_source = "
pub const entries = [
  Http(name: \"www\", hosts: [Www], prefix: \"/api\", admit: Anonymous, subject: AnySubject, services: All, pages: AllPages, frame_src: [\"frames.example\"]),
  Http(name: \"muses\", hosts: [Muses], prefix: \"/api\", admit: Authenticated, subject: Subjects([Muse]), services: All, pages: AllPages, frame_src: []),
]
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
    model.Entry(
      name: "muses",
      prefix: "/api",
      admit: model.AuthenticatedAdmit,
      subject: model.NamedEntrySubjects(["Muse"]),
      services: model.AllServices,
      credential: model.SessionCredential,
    ),
  ]
}

fn read_www(text: String) -> #(gate.Gate, List(stop.Note)) {
  gate.read(
    "www",
    [unit("gate", text)],
    [unit("entry", entry_source)],
    entries(),
    www_routes,
    Some("/api/session"),
  )
}

// ── route 表の順 ───────────────────────────────────────────────────────────

pub fn route_order_puts_literal_before_param_test() {
  [
    "/rosters/:id/remove", "/rosters/:id", "/rosters/new", "/rosters", "/",
    "/articles/:id", "/articles/new", "/page/widget/:id", "/page/widget/new",
  ]
  |> list.sort(front_emit.route_order)
  |> should.equal([
    "/", "/articles/new", "/articles/:id", "/page/widget/new",
    "/page/widget/:id", "/rosters", "/rosters/new", "/rosters/:id",
    "/rosters/:id/remove",
  ])
}

// ── 宣言の読み ─────────────────────────────────────────────────────────────

pub fn gate_declaration_reads_prefix_rules_and_redirects_test() {
  let #(read, notes) = read_www(www_gate)
  notes |> should.equal([])
  read.declared |> should.be_true
  read.sign_in_fallback |> should.equal("https://auth.example")
  read.frame_hosts |> should.equal(["frames.example"])
  read.rules
  |> should.equal([
    gate.Rule(pages: [gate.Prefix("/me")], except: [], checks: [
      gate.SignedIn(gate.ToSignIn(302, False)),
      gate.Adult(gate.Deny(403, "adult declaration required")),
    ]),
    gate.Rule(pages: [gate.Exact("/claim/:code")], except: [], checks: [
      gate.SignedIn(gate.ToSignIn(303, True)),
    ]),
  ])
  read.redirects
  |> should.equal([
    gate.Redirect(
      pages: [gate.Exact("/")],
      when_adult: True,
      to: gate.SafeParam("returnTo", "/search"),
    ),
  ])
}

pub fn gate_match_outside_routes_is_conflict_test() {
  let text =
    string.replace(www_gate, "Exact(\"/about/external\")", "Exact(\"/nope\")")
  let text = string.replace(text, "Prefix(\"/me\")", "Prefix(\"/you\")")
  let #(_, notes) = read_www(text)
  notes
  |> list.map(fn(note) { note.class })
  |> should.equal([stop.Conflict, stop.Conflict])
  notes
  |> list.all(fn(note) { string.starts_with(note.text, "www/gate: ") })
  |> should.be_true
}

pub fn gate_bad_fail_status_is_conflict_test() {
  let text =
    string.replace(
      www_gate,
      "ToSignIn(status: 303, back: True)",
      "ToSignIn(status: 200, back: True)",
    )
  let #(read, notes) = read_www(text)
  notes |> list.map(fn(note) { note.class }) |> should.equal([stop.Conflict])
  gate.is_empty(read) |> should.be_true
}

pub fn gate_without_const_is_missing_test() {
  let #(_, notes) = read_www("pub const other = 1\n")
  notes |> list.map(fn(note) { note.class }) |> should.equal([stop.Missing])
}

pub fn authenticated_face_without_declaration_gets_admit_gate_test() {
  let #(read, notes) =
    gate.read(
      "muses",
      [],
      [unit("entry", entry_source)],
      entries(),
      ["/"],
      Some("/api/session"),
    )
  notes |> should.equal([])
  read.declared |> should.be_false
  read.rules
  |> should.equal([
    gate.Rule(pages: [gate.Every], except: [], checks: [gate.Admitted(["muse"])]),
  ])
}

pub fn anonymous_face_without_declaration_has_no_gate_test() {
  let #(read, notes) =
    gate.read(
      "www",
      [],
      [unit("entry", entry_source)],
      entries(),
      www_routes,
      None,
    )
  notes |> should.equal([])
  gate.is_empty(read) |> should.be_true
  read.frame_hosts |> should.equal(["frames.example"])
}

// ── gate.mjs ───────────────────────────────────────────────────────────────

pub fn gate_mjs_carries_rules_csp_and_expanded_pageview_routes_test() {
  let #(read, _) = read_www(www_gate)
  let text = gate_emit.text("// header", read, www_routes)
  text |> string.contains("{type: \"prefix\", path: \"/me\"}") |> should.be_true
  text
  |> string.contains("const frameSrc = \"frame-src https://frames.example\";")
  |> should.be_true
  // Prefix("/muse") は生成時に route の表へ展開する(client の判定も同じ表)
  text
  |> string.contains(
    "const pageviewRoutes = [\"/muse/:handle\", \"/muse/:handle/article\", \"/search\"];",
  )
  |> should.be_true
  text |> string.contains("\"app:last-pageview\"") |> should.be_true
  text |> string.contains("searchParams.get(\"r\")") |> should.be_true
  text
  |> string.contains("export async function before_route(request, env)")
  |> should.be_true
  text
  |> string.contains(
    "export async function after_response(request, env, response)",
  )
  |> should.be_true
  text |> string.contains("const readsSession = true;") |> should.be_true
  text
  |> string.contains("const sessionPath = \"/api/session\";")
  |> should.be_true
  text |> string.contains("\"/api/session\", request.url") |> should.be_false
}

/// 門が session を読むのに `attached_roles` の `ReadSession` が無ければ exit 3(口の名を framework は知らない)。
pub fn gate_reading_session_without_read_session_role_is_missing_test() {
  let #(read, notes) =
    gate.read(
      "muses",
      [],
      [unit("entry", entry_source)],
      entries(),
      ["/"],
      None,
    )
  notes |> list.map(fn(note) { note.class }) |> should.equal([stop.Missing])
  gate_emit.text("// header", read, ["/"])
  |> string.contains("const sessionPath = null;")
  |> should.be_true
}

pub fn empty_gate_mjs_does_not_read_session_test() {
  let #(read, _) = gate.read("www", [], [], entries(), www_routes, None)
  let text = gate_emit.text("// header", read, www_routes)
  text |> string.contains("const readsSession = false;") |> should.be_true
  text |> string.contains("const pageviewScript = null;") |> should.be_true
  text |> string.contains("const frameSrc = null;") |> should.be_true
}

// ── fixture の生成物 ───────────────────────────────────────────────────────

pub fn fixture_shell_is_served_through_gate_hooks_test() {
  let assert Ok(shell) =
    simplifile.read("fixtures/article/public/src/gen/shell.mjs")
  shell
  |> string.contains("import * as gate from \"./gate.mjs\";")
  |> should.be_true
  shell
  |> string.contains(
    "export default gate.serve(async (request, env, before) => {",
  )
  |> should.be_true
  // 空の query と空白だけの query(`?q=%20`)は None(値が無いのと同じ)で送る
  shell
  |> string.contains(
    "value = found === null || found.trim() === \"\" ? Option$None$const : new Some(found);",
  )
  |> should.be_true
  let assert Ok(admin_gate) =
    simplifile.read("fixtures/article/admin/src/gen/gate.mjs")
  admin_gate
  |> string.contains("checks: [{type: \"admitted\", kinds: [\"staff\"]}]")
  |> should.be_true
  // session の口は fixture の `ReadSession(attached: "fixture_session")` の path
  admin_gate
  |> string.contains("const sessionPath = \"/fixture/session\";")
  |> should.be_true
}

// ── client の入口 ─────────────────────────────────────────────────────────

const copy_link_source = "
import lustre

pub fn app() {
  lustre.element(Nil)
}
"

const no_app_source = "
import framework/front
import gen/service

pub const calls: List(front.Target(service.Service, Nil)) = [
  front.Of(service.ArticleCreate),
]

pub fn view(it) {
  it
}
"

fn client_fixture() -> #(List(stop.Note), String) {
  let assert Ok(back_units) = source.load("fixtures/article")
  let assert Ok(app) = reader.read(back_units)
  let assert Ok(face_units) = source.load("fixtures/article/public")
  let face_units =
    list.append(face_units, [
      unit("components/copy_link", copy_link_source),
      unit("components/no_app", no_app_source),
    ])
  let assert Ok(front_model) =
    reader_front.read("public", face_units, app.services)
  let package =
    face.Package(
      name: "public",
      path: "fixtures/article/public",
      pages: face.UndeclaredPages,
      units: face_units,
    )
  let files =
    front_emit.emit(app, back_units, package, front_model, hash.of(back_units))
  let assert Ok(client) =
    list.find(files, fn(file) {
      file.path == "public/priv/static/_yumemi/client.mjs"
    })
  #(front_emit.client_notes(package, front_model), client.text)
}

pub fn client_registers_every_app_component_and_flags_missing_app_test() {
  let #(notes, client) = client_fixture()
  // calls の無い島も app() があれば登録する
  client
  |> string.contains(
    "if (!defined(\"copy-link\")) lustreRegister(styled(copy_link.app()), \"copy-link\");",
  )
  |> should.be_true
  // 既存の島(calls と app() を持つ)はそのまま
  client
  |> string.contains(
    "if (!defined(\"like-button\")) lustreRegister(styled(like_button.app()), \"like-button\");",
  )
  |> should.be_true
  // app() の無い島は登録せず、exit 3 で名指す
  client |> string.contains("no-app") |> should.be_false
  notes
  |> should.equal([
    stop.Note(
      stop.Missing,
      "public/components/no_app: `pub fn app()` が無い(client の入口は島を `app()` で登録する)",
    ),
  ])
}

// ── Attached Entry の live module(musearch の ▲ browser_adult を生成物に戻す形)────────────

const attached_entry_source = "
import framework/front
import gen/api

pub const calls: List(api.Target) = [front.Entry(api.FixtureBrowser)]

pub fn app() {
  Nil
}
"

/// `transport_send` の外部宣言は `transport_ffi.mjs` の `send`(6 引数)と同じ数、呼び出しは `blob_fields` に `[]`。
pub fn attached_entry_live_sends_blob_fields_test() {
  let assert Ok(back_units) = source.load("fixtures/article")
  let assert Ok(app) = reader.read(back_units)
  let assert Ok(face_units) = source.load("fixtures/article/public")
  let face_units =
    list.append(face_units, [
      unit("components/browser_fixture", attached_entry_source),
    ])
  let assert Ok(front_model) =
    reader_front.read("public", face_units, app.services)
  let package =
    face.Package(
      name: "public",
      path: "fixtures/article/public",
      pages: face.UndeclaredPages,
      units: face_units,
    )
  let files =
    front_emit.emit(app, back_units, package, front_model, hash.of(back_units))
  let assert Ok(live) =
    list.find(files, fn(file) {
      file.path == "public/src/gen/live/fixture_browser.gleam"
    })
  live.text
  |> string.contains(
    "fn transport_send(method: String, path: String, body: json.Json, blob_fields: List(String), on_ok: fn(Dynamic) -> Nil, on_error: fn(Dynamic) -> Nil) -> Nil",
  )
  |> should.be_true
  live.text
  |> string.contains(
    "    \"/fixture/browser\",\n    json.null(),\n    [],\n    fn(value) { dispatch(live.Done(Ok(value))) },",
  )
  |> should.be_true
  let assert Ok(ffi) =
    list.find(files, fn(file) {
      file.path == "public/src/gen/live/transport_ffi.mjs"
    })
  ffi.text
  |> string.contains(
    "export function send(method, path, body, blobFields, onOk, onError) {",
  )
  |> should.be_true
}

@external(javascript, "./yumemi_fix_0114_test_ffi.mjs", "gate_marks_navigation_fetch")
fn gate_marks_navigation_fetch(text: String) -> String

/// 0.11.4 r2:client 遷移の fetch(`x-yumemi-navigate: 1`)には、pageview の script でなく数える印の meta を head に
/// 差す(adult の session・200 の HTML・pageview の Page だけ)。頁の読み込みは今までどおり script。
pub fn gate_marks_navigation_fetch_instead_of_script_test() {
  let #(read, _) = read_www(www_gate)
  let out =
    gate_marks_navigation_fetch(gate_emit.text("// header", read, www_routes))
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  string.split(out, "\n") |> list.length |> should.equal(5)
}
