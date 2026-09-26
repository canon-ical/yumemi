//// 0.11.4(yumemi-fix-0114)── musearch を yumemi で止めない最後の patch。
//// H5 BlobCopy の from、H6 attached の body、H7 decodeReport の Split、H8 島の stylesheet、H9 Page 間の client 遷移。

import glance
import gleam/list
import gleam/string
import gleeunit/should
import yumemi_gen/emit/back
import yumemi_gen/emit/front as front_emit
import yumemi_gen/emit/hash
import yumemi_gen/face
import yumemi_gen/reader
import yumemi_gen/reader/front as reader_front
import yumemi_gen/source

const article_fixture = "fixtures/article"

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

fn back_file(units: List(source.Unit), path: String) -> String {
  let assert Ok(app) = reader.read(units)
  let assert Ok(file) =
    back.emit(app, units, hash.of(units), [], []).files
    |> list.find(fn(file) { file.path == path })
  file.text
}

// ── H7 ──────────────────────────────────────────────────────────────

/// Category に `Split` で 2 列に割る record(`Origin`)を足す。
fn split_category() -> source.Unit {
  unit(
    "entity/category",
    "import gen/types/category_name.{type CategoryName}\n"
      <> "import gleam/option.{type Option}\n\n"
      <> "pub type Origin {\n  Origin(chat: String, message: CategoryName)\n}\n\n"
      <> "pub type Category {\n  Category(name: CategoryName, origin: Option(Origin), first: Origin)\n}\n\n"
      <> "pub fn key(it: Category) -> CategoryName {\n  it.name\n}\n\n"
      <> "pub const collection: String = \"categories\"\n",
  )
}

fn split_server() -> source.Unit {
  let assert Ok(units) = source.load(article_fixture)
  let assert Ok(server) = list.find(units, fn(item) { item.path == "server" })
  unit(
    "server",
    string.replace(
      server.text,
      "import framework/server.{",
      "import framework/server.{Split, ",
    )
      <> "\npub const storage: List(server.Storage) = [\n"
      <> "  Split(entity: \"category\", property: \"origin\", columns: [#(\"chat\", \"origin_chat\"), #(\"message\", \"origin_id\")]),\n"
      <> "  Split(entity: \"category\", property: \"first\", columns: [#(\"chat\", \"first_chat\"), #(\"message\", \"first_id\")]),\n"
      <> "]\n",
  )
}

/// H7:`Split` で割った record の欄は、列から欄の object を組み直して読む(未定義の識別子を渡さない)。
pub fn codec_reads_split_record_from_columns_test() {
  let assert Ok(units) = source.load(article_fixture)
  let units = replace(units, [split_category(), split_server()])
  let codec = back_file(units, "src/gen/codec.mjs")
  string.contains(
    codec,
    "option((r.origin_chat==null?null:{chat:r.origin_chat,message:r.origin_id}),v=>new category.Origin(String(v.chat),parse('category_name',String(v.message))))",
  )
  |> should.be_true
  string.contains(
    codec,
    "new category.Origin(String({chat:r.first_chat,message:r.first_id}.chat),parse('category_name',String({chat:r.first_chat,message:r.first_id}.message)))",
  )
  |> should.be_true
  // 割った列の綴り(`a,b`)を JS の式に入れない
  string.contains(codec, "r.origin_chat,origin_id") |> should.be_false
  string.contains(codec, "r.first_chat,first_id") |> should.be_false
}

// ── H10 ─────────────────────────────────────────────────────────────

@external(javascript, "./yumemi_fix_0114_test_ffi.mjs", "driver_read_retry")
fn driver_read_retry() -> String

/// H10:driver は読みだけを timeout で切って 1 回やり直し、DB の外の失敗は本文を log に出す。書きはやり直さない。
pub fn driver_reads_retry_once_on_timeout_test() {
  let out = driver_read_retry()
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  string.split(out, "\n") |> list.length |> should.equal(13)
}

// ── H5 / H6 ─────────────────────────────────────────────────────────

/// back の units と面の units を差し替えて、面の生成物 1 本を返す。
fn face_file(
  back_extra: List(source.Unit),
  face_extra: List(source.Unit),
  path: String,
) -> Result(String, Nil) {
  let assert Ok(back_units) = source.load(article_fixture)
  let back_units = replace(back_units, back_extra)
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
  |> list.find(fn(file) { file.path == path })
  |> result_map(fn(file) {
    // gleam の生成物は gleam の構文として読める
    case string.ends_with(file.path, ".gleam") {
      True -> {
        let assert Ok(_) = glance.module(file.text)
        Nil
      }
      False -> Nil
    }
    file.text
  })
}

fn result_map(value: Result(a, Nil), f: fn(a) -> b) -> Result(b, Nil) {
  case value {
    Ok(inner) -> Ok(f(inner))
    Error(Nil) -> Error(Nil)
  }
}

/// H5:BlobCopy の live は file の upload(`Send`)に加えて、URL の写し(`copy_from`)を持つ。
/// `{from: url}` を JSON で送り、本文の `key` を `Done(Ok(key))` に読む。
pub fn blob_copy_live_copies_from_url_test() {
  let assert Ok(text) = face_file([], [], "public/src/gen/live/blob_copy.gleam")
  string.contains(
    text,
    "pub fn copy_from(model: State, url: String) -> #(State, Effect(Event)) {",
  )
  |> should.be_true
  string.contains(text, "json.object([#(\"from\", json.string(url))]),")
  |> should.be_true
  string.contains(
    text,
    "case decode.run(value, decode.at([\"key\"], decode.string)) {",
  )
  |> should.be_true
  string.contains(
    text,
    "Ok(key) if key != \"\" -> dispatch(live.Done(Ok(key)))",
  )
  |> should.be_true
  // file の upload はそのまま(Args / Field / State は変えない)
  string.contains(text, "pub type Args {\n  Args(file: String)\n}")
  |> should.be_true
  string.contains(text, "pub type Field {\n  File\n}") |> should.be_true
  string.contains(text, "transport_upload(") |> should.be_true
}

fn switch_server() -> source.Unit {
  let assert Ok(units) = source.load(article_fixture)
  let assert Ok(server) = list.find(units, fn(item) { item.path == "server" })
  unit(
    "server",
    server.text
      |> string.replace(
        "import framework/server.{",
        "import framework/server.{SwitchSubject, ",
      )
      |> string.replace(
        "  ReadSession(attached: \"fixture_session\"),\n",
        "  ReadSession(attached: \"fixture_session\"),\n  SwitchSubject(attached: \"fixture_sync\"),\n",
      ),
  )
}

fn sync_component() -> source.Unit {
  unit(
    "components/subject_switch",
    "import framework/front\nimport framework/front/el\nimport framework/front/live as front_live\n"
      <> "import gen/api\nimport gen/live/fixture_sync\nimport lustre\nimport lustre/event\n"
      <> "import sketch/lustre/element/html\n\n"
      <> "pub const target: api.Target = front.Entry(api.FixtureSync)\n\n"
      <> "pub const after_send: front_live.After = front_live.ReloadPage\n\n"
      <> "pub fn view(_it: fixture_sync.State) -> el.Element(fixture_sync.Event) {\n"
      <> "  html.button_([event.on_click(front_live.Send)], [el.text(\"switch\")])\n}\n",
  )
}

/// H6:framework の役が本文を読む attached の口(`SwitchSubject`)の live は、`{kind, id}` を Args に持って body に載せる。
pub fn attached_live_sends_role_body_test() {
  let assert Ok(text) =
    face_file(
      [switch_server()],
      [sync_component()],
      "public/src/gen/live/fixture_sync.gleam",
    )
  string.contains(text, "pub type Field {\n  Kind\n  Id\n}") |> should.be_true
  string.contains(text, "pub type Args {\n  Args(kind: String, id: String)\n}")
  |> should.be_true
  string.contains(text, "args: Args(kind: \"\", id: \"\")") |> should.be_true
  string.contains(text, "live.Set(Kind, value) ->") |> should.be_true
  string.contains(text, "args: Args(..model.args, id: value)") |> should.be_true
  string.contains(text, "request(model.args)") |> should.be_true
  string.contains(text, "#(\"kind\", json.string(args.kind)),")
  |> should.be_true
  string.contains(text, "#(\"id\", json.string(args.id))])") |> should.be_true
  string.contains(text, "    json.null(),\n") |> should.be_false
  // after_send の ReloadPage はそのまま
  string.contains(text, "event.emit(\"yumemi-done\", json.null())")
  |> should.be_true
}

/// 役の無い attached の口の live は 0.11.3 と同じ(Args は空、body は null)。
pub fn attached_live_without_role_body_keeps_null_test() {
  let assert Ok(text) =
    face_file([], [sync_component()], "public/src/gen/live/fixture_sync.gleam")
  string.contains(text, "pub type Field\n") |> should.be_true
  string.contains(text, "pub type Args {\n  Args\n}") |> should.be_true
  string.contains(text, "    live.Set(_, _) -> #(model, effect.none())")
  |> should.be_true
  string.contains(text, "    json.null(),\n    [],") |> should.be_true
  string.contains(text, "fn request() -> Effect(Event) {") |> should.be_true
}

// ── H8 ──────────────────────────────────────────────────────────────

@external(javascript, "./yumemi_fix_0114_test_ffi.mjs", "island_stylesheet")
fn island_stylesheet() -> String

/// H8:生成の client は島を `styled(..)` で包んで登録し、sketch の class 付きの要素を描いても panic しない。
pub fn island_renders_sketch_class_under_stylesheet_test() {
  let out = island_stylesheet()
  string.contains(out, "NG ") |> should.be_false
  string.split(out, "\n") |> list.length |> should.equal(8)
}

// ── H9 ──────────────────────────────────────────────────────────────

fn counting_gate() -> source.Unit {
  unit(
    "gate",
    "import framework/gate.{Exact, Gate, Pageview, SignIn}\n\n"
      <> "pub const gate: gate.Gate = Gate(\n"
      <> "  sign_in: SignIn(path: \"/auth/sign-in\", fallback_origin: \"https://auth.example\"),\n"
      <> "  rules: [],\n  redirects: [],\n  frame_src: [],\n"
      <> "  pageview: Pageview(pages: [Exact(\"/status\")], endpoint: \"/api/pageviews\", source_param: \"r\", storage_key: \"k\"),\n"
      <> ")\n",
  )
}

/// H9:client は島の登録を `boot()` にまとめ、面の Page の route 表で client 遷移を起こす(登録済みの島は登録し直さない)。
pub fn client_starts_navigation_over_page_routes_test() {
  let assert Ok(text) =
    face_file([], [], "public/priv/static/_yumemi/client.mjs")
  string.contains(
    text,
    "import { start as startNavigation } from \"__YUMEMI_BUILD__/yumemi/framework/front/navigate.mjs\";",
  )
  |> should.be_true
  string.contains(text, "function boot() {\n") |> should.be_true
  string.contains(text, "}\n\nboot();\n") |> should.be_true
  string.contains(
    text,
    "startNavigation({ routes: [\"/article/:slug\", \"/status\"], boot });",
  )
  |> should.be_true
  string.contains(
    text,
    "if (!defined(\"like-button\")) lustreRegister(styled(like_button.app()), \"like-button\");",
  )
  |> should.be_true
}

/// pageview を数える Page(と frame-src の CSP を持つ Page)は route 表から外す(頁の読み込みのまま)。
pub fn navigation_skips_counted_pages_test() {
  let assert Ok(text) =
    face_file([], [counting_gate()], "public/priv/static/_yumemi/client.mjs")
  string.contains(
    text,
    "startNavigation({ routes: [\"/article/:slug\"], boot });",
  )
  |> should.be_true
}

@external(javascript, "./yumemi_fix_0114_test_ffi.mjs", "navigation_rules")
fn navigation_rules() -> String

/// navigate.mjs の click の取り方と、差し替えてよい文書の判定。
pub fn navigation_intercepts_only_routed_plain_clicks_test() {
  let out = navigation_rules()
  string.contains(out, "NG ") |> should.be_false
  string.split(out, "\n") |> list.length |> should.equal(14)
}
