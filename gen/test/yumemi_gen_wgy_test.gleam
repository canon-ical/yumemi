//// WGy(yumemi-gen-8)── `src/server.gleam` の宣言、attached の向き、Route の上書きと対象の解き方、
//// back の生成物(registry / codec / queue / cron / shell)。

import glance
import gleam/list
import gleam/string
import gleeunit/should
import yumemi_gen
import yumemi_gen/emit/back
import yumemi_gen/emit/codec
import yumemi_gen/emit/entry
import yumemi_gen/emit/hash
import yumemi_gen/emit/reads
import yumemi_gen/emit/root
import yumemi_gen/emit/types
import yumemi_gen/emit/verb
import yumemi_gen/reader
import yumemi_gen/reader/server as server_reader
import yumemi_gen/source
import yumemi_gen/stop

const article_fixture = "fixtures/article"

const ambiguous_fixture = "fixtures/route_ambiguous"

fn unit(path: String, text: String) -> source.Unit {
  let assert Ok(module) = glance.module(text)
  source.Unit(path: path, text: text, module: module)
}

fn units_with(app_dir: String, extra: List(source.Unit)) -> List(source.Unit) {
  let assert Ok(units) = source.load(app_dir)
  let paths = list.map(extra, fn(item) { item.path })
  list.append(
    list.filter(units, fn(item) { !list.contains(paths, item.path) }),
    extra,
  )
}

fn without(app_dir: String, path: String) -> List(source.Unit) {
  let assert Ok(units) = source.load(app_dir)
  list.filter(units, fn(item) { item.path != path })
}

fn back_files(units: List(source.Unit)) -> List(#(String, String)) {
  let assert Ok(app) = reader.read(units)
  back.emit(app, units, hash.of(units), [], []).files
  |> list.map(fn(file) { #(file.path, file.text) })
}

fn file(files: List(#(String, String)), path: String) -> String {
  let assert Ok(#(_, text)) = list.find(files, fn(item) { item.0 == path })
  text
}

fn server(text: String) -> source.Unit {
  unit(
    "server",
    "import framework/server.{Alias, Anyone, ApiKey, Attached, AttachedAlias, Cron, Delete, DurableObject, EachDue, Get, Hook, Hooked, Internal, Party, Post, Put, Route, RouteVia, Session}\n\n"
      <> text,
  )
}

// ── 向き ────────────────────────────────────────────────────────────────────

/// attached は `src/server.gleam` から読む。`api/src/gen/http_runtime.mjs` は入力でない(fixture から消した)。
pub fn attached_is_read_from_the_server_declaration_test() {
  let assert Ok(units) = source.load(article_fixture)
  let assert Ok(app) = reader.read(units)
  app.attached
  |> list.map(fn(route) {
    route.name <> " " <> route.method <> " " <> route.who
  })
  |> should.equal([
    "FixtureBrowser GET anyone", "FixtureSync POST party", "BlobCopy POST party",
    "FixtureSession GET anyone",
  ])
  let assert Ok(bare) = reader.read(without(article_fixture, "server"))
  bare.attached |> should.equal([])
  bare.server.declared |> should.be_false
}

/// 宣言の形が読めない項は reader が止める(黙って口を落とさない)。
pub fn unreadable_server_declaration_stops_the_reader_test() {
  let units =
    units_with(article_fixture, [
      server(
        "pub const routes: List(server.Route) = [Route(service: \"article_list\", method: Patch, path: \"/x\")]\n",
      ),
    ])
  let assert Error(reader.Unsupported(where: "server", detail: detail)) =
    reader.read(units)
  string.contains(detail, "method が Get / Post / Put / Delete でない")
  |> should.be_true
}

/// 名が Service / attached / hooks に無い行は exit 4 で名指し。
pub fn unknown_names_in_the_server_declaration_are_exit_four_test() {
  let units =
    units_with(article_fixture, [
      server(
        "pub const routes: List(server.Route) = [Internal(service: \"ghost\"), Internal(service: \"article_list\"), Internal(service: \"article_list\")]\n"
        <> "pub const aliases: List(server.Alias) = [AttachedAlias(name: \"x_v1\", attached: \"nope\", method: Post, path: \"/v1/x\", credential: ApiKey, who: Party)]\n"
        <> "pub const cron: List(server.Cron) = [Cron(schedule: \"0 1 * * *\", jobs: [Hooked(service: \"article_list\", hook: \"missing\")])]\n",
      ),
    ])
  let assert Ok(app) = reader.read(units)
  let notes = server_reader.notes(app)
  list.length(notes) |> should.equal(4)
  list.all(notes, fn(note) { note.class == stop.Conflict }) |> should.be_true
  [
    "routes に Service が無い: ghost", "routes に同じ Service が 2 行: article_list",
    "attached が無い: nope", "hook が hooks に無い: missing",
  ]
  |> list.each(fn(text) {
    list.any(notes, fn(note) { string.contains(note.text, text) })
    |> should.be_true
  })
}

// ── Route ───────────────────────────────────────────────────────────────────

/// 上書きは導出の (method, path) を替え、媒体の合う入口だけが持つ。`Internal` は口を持たない。
pub fn route_override_replaces_the_derived_route_test() {
  let units =
    units_with(article_fixture, [
      server(
        "pub const routes: List(server.Route) = [\n"
        <> "  Route(service: \"article_list\", method: Get, path: \"/api/listing/:page\"),\n"
        <> "  RouteVia(service: \"article_read\", method: Get, path: \"/api/v1/articles/:slug\", credential: ApiKey),\n"
        <> "  Internal(service: \"widget_list\"),\n"
        <> "]\n",
      ),
    ])
  let assert Ok(app) = reader.read(units)
  let routes = entry.routes(app)
  let of = fn(service) {
    routes
    |> list.filter(fn(route) { route.service == service })
    |> list.map(fn(route) {
      route.face <> " " <> route.method <> " " <> route.path
    })
  }
  of("article_list")
  |> should.equal([
    "admin GET /api/listing/{page}",
    "public GET /api/listing/{page}",
  ])
  // fixture の入口は両方 Session ── ApiKey の上書きは口を持たない。
  of("article_read") |> should.equal([])
  of("widget_list") |> should.equal([])
  let assert Ok(route) =
    list.find(routes, fn(route) { route.service == "article_list" })
  route.path_keys |> should.equal(["page"])
}

/// 名前の前置きが曖昧でも、allow の Entity(またはそれを held で指す候補)で解く。改名しない。
pub fn ambiguous_target_resolves_by_the_allow_entity_test() {
  let units =
    units_with(ambiguous_fixture, [
      unit(
        "entity/muse",
        "pub type Muse {\n  Muse(id: String)\n}\n\npub fn key(it: Muse) -> String {\n  it.id\n}\n\npub const collection: String = \"muses\"\n",
      ),
      unit(
        "entity/muse_schedule",
        "import entity/muse.{type Muse}\nimport framework/er.{type Held}\n\npub type MuseSchedule {\n  MuseSchedule(id: String, muse: Held(Muse))\n}\n\npub fn key(it: MuseSchedule) -> String {\n  it.id\n}\n\npub const collection: String = \"muse_schedules\"\n",
      ),
      unit(
        "service/schedule_add",
        "import framework/effect.{type Effect, Write}\nimport framework/step.{type Start, type Step}\nimport gen/allow/muse as allow\nimport gen/face.{type Face, Test}\nimport gen/root/schedule_add.{type Actor, type Root, type Service, Service}\n\npub const effect: Effect = Write\n\npub const faces: List(Face) = [Test]\n\npub type Args {\n  Args\n}\n\npub type Error\n\npub const service: Service(Args, Nil, Error) = Service(allow: [allow.Anyone], logic: logic)\n\npub fn logic(_by: Actor, _it: Root, _args: Args) -> Step(Nil, Error, Start) {\n  todo\n}\n",
      ),
    ])
  let assert Ok(app) = reader.read(units)
  let assert [route] =
    entry.routes(app)
    |> list.filter(fn(route) { route.service == "schedule_add" })
  route.method |> should.equal("POST")
  route.path |> should.equal("/test/muse_schedules")
}

// ── back の生成物 ───────────────────────────────────────────────────────────

/// registry は Service ごとに 1 行。上書き・媒体・入口 1 つ・別名・attached の別名を持つ。
pub fn registry_rows_follow_the_declarations_test() {
  let units =
    units_with(article_fixture, [
      server(
        "pub const routes: List(server.Route) = [RouteVia(service: \"article_read\", method: Get, path: \"/api/v1/articles/:slug\", credential: ApiKey), Internal(service: \"widget_list\")]\n"
        <> "pub const aliases: List(server.Alias) = [\n"
        <> "  Alias(name: \"article_publish_v1\", service: \"article_publish\", method: Put, path: \"/api/v1/articles/:external_id/publish\", credential: ApiKey, external_id: True),\n"
        <> "  AttachedAlias(name: \"blob_copy_v1\", attached: \"blob_copy\", method: Post, path: \"/api/v1/blobs\", credential: ApiKey, who: Party),\n"
        <> "]\n"
        <> "pub const attached: List(server.Attached) = [Attached(name: \"blob_copy\", method: Post, path: \"/api/blobs\", who: Party)]\n",
      ),
    ])
  let registry = file(back_files(units), "src/gen/registry.mjs")
  string.starts_with(registry, "//// GENERATED from ") |> should.be_true
  string.contains(registry, "[sha256:") |> should.be_true
  [
    "{ name: 'article_read', module: article_read, root: root_article_read, method: 'GET', path: '/api/v1/articles/:slug', fields: ['slug'], folded: null, credential: 'api_key' },",
    "{ name: 'widget_list', module: widget_list, root: root_widget_list, method: null, path: null,",
    "{ name: 'article_retract', module: article_retract, root: root_article_retract, method: 'POST', path: '/api/admin/articles/:slug/retract', fields: ['slug'], folded: null, entry: 'admin' },",
    "{ name: 'article_publish_v1', module: article_publish, root: root_article_publish, method: 'PUT', path: '/api/v1/articles/:external_id/publish', fields: ['slug'], folded: null, credential: 'api_key', target: 'article_publish', externalId: true },",
    "{ name: 'blob_copy_v1', module: null, root: null, method: 'POST', path: '/api/v1/blobs', fields: [], folded: null, credential: 'api_key', target: 'blob_copy', who: 'party' },",
    // 面ごとに prefix が違う Session の口は、2 本目を `<service>_<入口>` の別名の行にする。
    "{ name: 'article_list_public', module: article_list, root: root_article_list, method: 'GET', path: '/api/articles', fields: ['limit', 'cursor'], folded: null, target: 'article_list' },",
    "import { validateWho } from '../../yumemi/framework/server/contracts.mjs';",
  ]
  |> list.each(fn(row) { string.contains(registry, row) |> should.be_true })
}

/// 宣言の無い app には back の束を出さない。
pub fn no_server_declaration_means_no_back_files_test() {
  back_files(without(article_fixture, "server")) |> should.equal([])
}

/// codec は Entity の Property の型から decoder を導き、`decode_*` の hook は名指しで re-export して導出より勝つ。
pub fn codec_derives_decoders_and_reexports_hooks_test() {
  let units =
    units_with(article_fixture, [
      server(
        "pub const hooks: List(server.Hook) = [Hook(name: \"decode_staff\", module: \"hooks\"), Hook(name: \"decode_totals\", module: \"hooks\")]\n",
      ),
    ])
  let codec = file(back_files(units), "src/gen/codec.mjs")
  string.contains(codec, "export function decodeCategory(r) {")
  |> should.be_true
  // 規則で導けない Property(Multi)を持つ Entity は出さず、頭に名指しする。
  string.contains(codec, "宣言から導けない decoder(hook も無い): article(tags が Multi)")
  |> should.be_true
  string.contains(codec, "export function decodeStaff(r) {") |> should.be_false
  string.contains(codec, "export { decodeStaff } from '../hooks.mjs';")
  |> should.be_true
  string.contains(codec, "export { decodeTotals } from '../hooks.mjs';")
  |> should.be_true
  string.contains(
    codec,
    "import { codec } from '../../yumemi/framework/server/codec.mjs';",
  )
  |> should.be_true
  string.contains(codec, "export const scalar = {") |> should.be_true
  string.contains(codec, "parse('category_name',String(r.name))")
  |> should.be_true
}

/// cron の仕事の JS の名と、shell の式ごとの分岐・DO の class は宣言から。hook は名を宣言したものだけを import する。
pub fn cron_and_shell_follow_the_declarations_test() {
  let units =
    units_with(article_fixture, [
      server(
        "pub const cron: List(server.Cron) = [Cron(schedule: \"0 16 * * *\", jobs: [Hooked(service: \"article_list\", hook: \"list_args\"), EachDue(service: \"article_publish\", query: \"due\")])]\n"
        <> "pub const durable_objects: List(server.DurableObject) = [DurableObject(class: \"AppDo\", module: \"app_do\", adapter: \"AppDoAdapter\", methods: [\"fetch\", \"alarm\"])]\n"
        <> "pub const hooks: List(server.Hook) = [Hook(name: \"list_args\", module: \"hooks\")]\n",
      ),
    ])
  let files = back_files(units)
  let cron = file(files, "src/gen/cron_runtime.mjs")
  string.contains(cron, "export async function listArticle(") |> should.be_true
  string.contains(cron, "export async function publishDue(") |> should.be_true
  string.contains(cron, "query:'article_publish/due',idKey:'slug'")
  |> should.be_true
  string.contains(cron, "import { listArgs } from '../hooks.mjs';")
  |> should.be_true
  let shell = file(files, "src/gen/shell.mjs")
  string.contains(
    shell,
    "if(controller.cron==='0 16 * * *') execution.waitUntil(Promise.all([listArticle(db,env),publishDue(db,env)]));",
  )
  |> should.be_true
  string.contains(shell, "execution.waitUntil(sweep(db,env));")
  |> should.be_true
  string.contains(
    shell,
    "export const AppDo=durableObject(AppDoAdapter,['fetch','alarm']);",
  )
  |> should.be_true
  string.contains(shell, "import { AppDoAdapter } from '../app_do.mjs';")
  |> should.be_true
}

/// sql.mjs は app の db/queries に、生成した SQL のうち app に無い道を足す(同じ道は app が勝つ)。
pub fn sql_bundle_keeps_the_app_file_on_the_same_key_test() {
  let assert Ok(units) = source.load(article_fixture)
  let assert Ok(app) = reader.read(units)
  let out =
    back.emit(
      app,
      units,
      hash.of(units),
      [#("article_list/items", "-- app\nSELECT 1;\n")],
      [
        model_file("db/queries/article_list/items.sql", "-- generated\n"),
        model_file("db/queries/article_read/root.sql", "SELECT 2;\n"),
      ],
    )
  let assert Ok(sql) =
    list.find(out.files, fn(item) { item.path == "src/gen/sql.mjs" })
  string.contains(
    sql.text,
    "\"article_list/items\": \"-- app\\nSELECT 1;\\n\",",
  )
  |> should.be_true
  string.contains(sql.text, "\"article_read/root\": \"SELECT 2;\\n\",")
  |> should.be_true
  string.contains(sql.text, "-- generated") |> should.be_false
}

fn model_file(path: String, text: String) -> types.File {
  types.File(path: path, text: text)
}

/// 入口の検査が引く attached の表も同じ宣言から出す(実行時に手書きの表を持たない)。
pub fn attached_table_for_the_runtime_comes_from_the_declaration_test() {
  let assert Ok(units) = source.load(article_fixture)
  let attached = file(back_files(units), "src/gen/attached.mjs")
  [
    " {name:'fixture_browser',method:'GET',path:'/fixture/browser',who:'anyone'},",
    " {name:'fixture_sync',method:'POST',path:'/fixture/sync',who:'party'},",
    " {name:'blob_copy',method:'POST',path:'/api/blobs',who:'party'},",
  ]
  |> list.each(fn(row) { string.contains(attached, row) |> should.be_true })
}

// ── connector(r2、鷹野の裁定 2)────────────────────────────────────────────

/// connector の宣言から FFI の口だけを出す。型は ★ の包みが決める(引数と戻りは型変数)。
pub fn connector_ports_follow_the_declaration_test() {
  let units =
    units_with(article_fixture, [
      server(
        "pub const connectors = [
  Connector(name: \"heaven\", ports: [
    Pure(name: \"is_girl_page\", module: \"heaven_ffi\", js: \"isGirlPage\", arity: 1),
    Fetch(name: \"resolve\", module: \"heaven_ffi\", js: \"resolve\", arity: 2),
  ]),
  Connector(name: \"idp\", ports: [
    Call(name: \"invite\", op: \"invite\"),
    Send(name: \"notify\", op: \"notify\"),
    Enqueue(name: \"article_index\", kind: \"article_index\"),
  ]),
]",
      ),
    ])
  let files = back_files(units)
  let heaven = file(files, "src/gen/connector/heaven.gleam")
  string.starts_with(
    heaven,
    "//// GENERATED from server.connectors.heaven [sha256:",
  )
  |> should.be_true
  string.contains(
    heaven,
    "@external(javascript, \"../../heaven_ffi.mjs\", \"isGirlPage\")\npub fn is_girl_page(a1: a1) -> r",
  )
  |> should.be_true
  string.contains(
    heaven,
    "fn resolve_raw(ctx: Context, a1: a1, a2: a2) -> Promise(r)",
  )
  |> should.be_true
  string.contains(heaven, "pub fn resolve(a1: a1, a2: a2) -> connector.Read(r)")
  |> should.be_true
  string.contains(heaven, "operations_ffi") |> should.be_false
  let idp = file(files, "src/gen/connector/idp.gleam")
  string.contains(
    idp,
    "connector.read(fn(ctx) { call(ctx, \"invite\", input) })",
  )
  |> should.be_true
  string.contains(
    idp,
    "pub fn notify(input: a) -> connector.Write(Nil) {\n  connector.write(fn(ctx) { call(ctx, \"notify\", input) })",
  )
  |> should.be_true
  string.contains(
    idp,
    "connector.write(fn(ctx) { enqueue(ctx, \"article_index\", input) })",
  )
  |> should.be_true
}

/// 口の構成子が違う項は reader が止める。
pub fn unreadable_connector_port_stops_the_reader_test() {
  let units =
    units_with(article_fixture, [
      server(
        "pub const connectors = [Connector(name: \"x\", ports: [Other(name: \"y\")])]",
      ),
    ])
  let assert Error(_) = reader.read(units)
}

// ── 器と列の写像(r3、鷹野の裁定)──────────────────────────────────────────

fn storage_units(storage: String) -> List(source.Unit) {
  units_with(article_fixture, [
    unit(
      "server",
      "import framework/server.{Array, Column, DurableObject, InObject, Split, Text}\n\n"
        <> "pub const durable_objects: List(server.DurableObject) = [DurableObject(class: \"TagDo\", module: \"tag_do\", adapter: \"TagDoAdapter\", methods: [])]\n"
        <> "pub const storage: List(server.Storage) = "
        <> storage
        <> "\n",
    ),
  ])
}

/// `InObject` の Entity は PG の verb SQL を出さず、`Column` は INSERT / RETURNING / UPDATE の列名を替える。
/// 穴の数は変えない(Property 1 つに穴 1 つ)。
pub fn storage_moves_entities_and_renames_columns_test() {
  let units =
    storage_units(
      "[InObject(entity: \"tag\", object: \"TagDo\"), Column(entity: \"article\", property: \"title\", column: \"headline\")]",
    )
  let assert Ok(app) = reader.read(units)
  server_reader.notes(app) |> should.equal([])
  let files =
    verb.sql(app, hash.of(units))
    |> list.map(fn(file) { #(file.path, file.text) })
  list.any(files, fn(item) { string.ends_with(item.0, "_tag.sql") })
  |> should.be_false
  let create = file(files, "db/queries/verb/create_article.sql")
  string.contains(create, "headline") |> should.be_true
  string.contains(create, ",title,") |> should.be_false
  let assert Ok(plain) = reader.read(without(article_fixture, "server"))
  let before =
    verb.sql(plain, hash.of(units))
    |> list.map(fn(file) { #(file.path, file.text) })
    |> file("db/queries/verb/create_article.sql")
  string.split(create, "$")
  |> list.length
  |> should.equal(string.split(before, "$") |> list.length)
}

/// `Text` は構成子の snake 名を列の値へ写し、`Split` は穴 1 つを列に割って UPDATE を組の代入にする。
/// 無い Entity / Property / 器は exit 4 で名指し。
pub fn storage_text_split_and_unknown_names_test() {
  let units =
    storage_units(
      "[Text(entity: \"article\", property: \"body\", values: [#(\"Short\", \"s\")]), Split(entity: \"article\", property: \"slug\", columns: [#(\"a\", \"slug_a\"), #(\"b\", \"slug_b\")]), Array(entity: \"ghost\", property: \"x\", element: \"uuid\"), Column(entity: \"article\", property: \"nope\", column: \"y\"), InObject(entity: \"tag\", object: \"Missing\")]",
    )
  let assert Ok(app) = reader.read(units)
  let files =
    verb.sql(app, hash.of(units))
    |> list.map(fn(file) { #(file.path, file.text) })
  let create = file(files, "db/queries/verb/create_article.sql")
  string.contains(create, "slug_a,slug_b") |> should.be_true
  string.contains(create, "::jsonb->>'a')") |> should.be_true
  string.contains(create, "WHEN 'short' THEN 's'") |> should.be_true
  let notes = server_reader.notes(app)
  list.length(notes) |> should.equal(3)
  [
    "storage の Entity が無い: ghost", "storage article に Property が無い: nope",
    "器が durable_objects に無い: Missing",
  ]
  |> list.each(fn(text) {
    list.any(notes, fn(note) { string.contains(note.text, text) })
    |> should.be_true
  })
}

// ── 手書きの SQL の読み(r3)──────────────────────────────────────────────

/// `ManualRead` は `gen/reads/<service>.gleam` に型付きの口を書く(引数が 2 つ以上なら組で渡す)。
/// 無い Service・hooks に無い hook は exit 4。
pub fn manual_read_writes_the_typed_port_test() {
  let units =
    units_with(article_fixture, [
      unit(
        "server",
        "import framework/server.{Hook, ManualRead}\n\n"
          <> "pub const hooks: List(server.Hook) = [Hook(name: \"read_counts\", module: \"hooks\")]\n"
          <> "pub const reads: List(server.ManualRead) = [\n"
          <> "  ManualRead(service: \"article_create\", query: \"counts\", args: [#(\"muse\", \"String\"), #(\"since\", \"Date\")], returns: \"List(#(String, Int))\", imports: [\"framework/time.{type Date}\"], hook: \"read_counts\"),\n"
          <> "  ManualRead(service: \"ghost\", query: \"x\", args: [#(\"a\", \"String\")], returns: \"Int\", imports: [], hook: \"missing\"),\n"
          <> "]\n",
      ),
    ])
  let assert Ok(app) = reader.read(units)
  let files =
    reads.emit(app, hash.of(units))
    |> list.map(fn(file) { #(file.path, file.text) })
  let text = file(files, "src/gen/reads/article_create.gleam")
  string.contains(text, "import framework/time.{type Date}\n") |> should.be_true
  string.contains(
    text,
    "fn query(ctx: Context, name: String, input: a) -> Promise(b)",
  )
  |> should.be_true
  string.contains(text, "then then: fn(List(#(String, Int))) -> Step(")
  |> should.be_true
  string.contains(text, "query(ctx, \"counts\", #(muse, since))")
  |> should.be_true
  let notes = server_reader.notes(app)
  list.any(notes, fn(note) {
    string.contains(note.text, "reads ghost/x の Service が無い")
  })
  |> should.be_true
  list.any(notes, fn(note) {
    string.contains(note.text, "hook が hooks に無い: missing")
  })
  |> should.be_true
}

// ── root の形(r3)──────────────────────────────────────────────────────────

/// `Rootless` は Entity の行を持たない root、`WithVersion` は `version: Int`、`Carried` は入口の値を載せる
/// (Option の綴りなら gleam/option を import する)。宣言した Service は名との違いを警告しない。
pub fn root_shapes_follow_the_declaration_test() {
  let units =
    units_with(article_fixture, [
      unit(
        "server",
        "import framework/server.{Carried, Rootless, WithVersion}\n\n"
          <> "pub const roots: List(server.RootShape) = [\n"
          <> "  Rootless(service: \"article_read\"),\n"
          <> "  WithVersion(service: \"article_publish\"),\n"
          <> "  Carried(service: \"article_read\", name: \"browser\", type_: \"Option(BrowserId)\", import_: \"gen/types/browser_id.{type BrowserId}\"),\n"
          <> "  Rootless(service: \"ghost\"),\n"
          <> "]\n",
      ),
    ])
  let assert Ok(app) = reader.read(units)
  let files =
    root.emit(app, hash.of(units))
    |> list.map(fn(file) { #(file.path, file.text) })
  let read = file(files, "src/gen/root/article_read.gleam")
  string.contains(read, "browser: Option(BrowserId),\n    at: Datetime,")
  |> should.be_true
  string.contains(read, "import gleam/option.{type Option}") |> should.be_true
  string.contains(read, "article.Article") |> should.be_false
  let publish = file(files, "src/gen/root/article_publish.gleam")
  string.contains(publish, "    version: Int,\n") |> should.be_true
  server_reader.notes(app)
  |> list.any(fn(note) {
    string.contains(note.text, "roots の Service が無い: ghost")
  })
  |> should.be_true
}

// ── runtime と http_runtime の表(r3)──────────────────────────────────────

/// runtime.mjs は framework の機関に宣言からの表を渡すだけ ── verb の穴の並び(create は新しい鍵と draft の欄、
/// advance は Step の辺)、読みの穴と戻りの形、actor の決め方。Service の名ごとの分岐を持たない。
pub fn runtime_tables_follow_the_declarations_test() {
  let files = back_files(without(article_fixture, "noop"))
  let text = file(files, "src/gen/runtime.mjs")
  string.starts_with(
    text,
    "//// GENERATED from service Logic / verb / reads / outbox contracts [sha256:",
  )
  |> should.be_true
  string.contains(text, "from '../../yumemi/framework/server/runtime.mjs';")
  |> should.be_true
  string.contains(
    text,
    " create_article:{key:'verb/create_article',tuple:false,params:[['id'],['f','title','title']",
  )
  |> should.be_true
  string.contains(text, "['from',2],['to',2],['at']],transitions:{")
  |> should.be_true
  string.contains(text, " article_create:{kind:'direct',subject:'staff'},")
  |> should.be_true
  string.contains(
    text,
    "'article_list/items':{key:'article_list/items',args:[['enc'],['cursor']],allow:[",
  )
  |> should.be_true
  // 名ごとの分岐(`name===` / `record.name===`)を書かない
  string.contains(text, "name===") |> should.be_false
}

/// http_runtime.mjs は Args の型から decode の語彙を導く(値型・Entity の鍵・その List)。入口の host は
/// `<NAME>_HOST`。attached の口の実装は宣言した hook を名で引く。
pub fn http_tables_follow_the_args_types_test() {
  let files = back_files(without(article_fixture, "noop"))
  let text = file(files, "src/gen/http_runtime.mjs")
  string.contains(
    text,
    " article_create:[['slug',['scalar','slug']],['title',['scalar','title']],['body',['scalar','body']],['category',['key']],['tags',['list',['key']]]],",
  )
  |> should.be_true
  string.contains(text, "from '../../yumemi/framework/server/http.mjs';")
  |> should.be_true
  string.contains(
    text,
    "import { attachedBlobCopy as h_attachedBlobCopy } from '../hooks.mjs';",
  )
  |> should.be_true
  string.contains(text, "blob_copy:h_attachedBlobCopy") |> should.be_true
  string.contains(text, "name===") |> should.be_false
}

/// `Text` の宣言は codec の decoder でも逆に写す(列の値 -> 構成子の snake 名 -> 構成子)。
/// hook(`decode_<entity>`)を持たない Entity の decoder が宣言だけで列の形に合う。
pub fn text_storage_is_reversed_in_the_codec_test() {
  let units =
    units_with(article_fixture, [
      unit(
        "entity/memo",
        "import gen/types/title.{type Title}

pub type Mode {
  Draft
  Final
}

pub type Memo {
  Memo(title: Title, mode: Mode)
}

pub fn key(it: Memo) -> Title {
  it.title
}

pub const collection: String = \"memos\"
",
      ),
      unit(
        "server",
        "import framework/server.{Text}\n\n"
          <> "pub const storage: List(server.Storage) = [Text(entity: \"memo\", property: \"mode\", values: [#(\"Draft\", \"d\"), #(\"Final\", \"f\")])]\n",
      ),
    ])
  let assert Ok(app) = reader.read(units)
  let text = codec.text(app, units, "x")
  string.contains(
    text,
    "phase(memo,({'d':'draft','f':'final'}[r.mode]??r.mode))",
  )
  |> should.be_true
}

fn gate_service(name: String, who: String) -> source.Unit {
  unit("service/" <> name, "import entity/article
import framework/effect.{type Effect, Read}
import framework/step.{type Start, type Step}
import gen/allow/article as allow
import gen/face.{type Face, Public}
import gen/query as q
import gen/root/" <> name <> ".{type Actor, type Root, type Service, Service}

pub const effect: Effect = Read

pub const faces: List(Face) = [Public]

pub type Args {
  Args(title: String)
}

pub type Out {
  Out
}

pub type Error

pub type P {
  Title
}

pub const items: q.Select(P) = q.Select(
  from: q.Article,
  join: [],
  where: [q.Eq(q.ArticleTitle, q.Param(Title))],
  group: [],
  having: [],
  agg: [],
  along: [],
  with: [],
  order: [],
  limit: q.NoLimit,
)

pub const service: Service(Args, Out, Error) = Service(
  allow: [allow.Clause(who: allow." <> who <> ", at: allow.Only([article.Published]), owner: allow.NoOwner)],
  logic: logic,
)

pub fn logic(_by: Actor, _it: Root, _args: Args) -> Step(Out, Error, Start) {
  step.done(Out)
}
")
}

/// 入口の相の門(`phaseGates`)は、root を持たず `As<X>` の X が allow の Entity そのものの句だけで閉じる
/// (WGy r4)。`Only` は allow の Entity の相なので、X が別の Entity(`gen/allow/article` × `AsStaff`)の
/// Service は主体の相で門を閉じない(相は読みの SQL が allow の行で照らす)。
pub fn phase_gate_is_only_for_the_allow_entity_as_subject_test() {
  let units =
    units_with(article_fixture, [
      gate_service("article_gate_own", "AsArticle"),
      gate_service("article_gate_other", "AsStaff"),
    ])
    |> list.filter(fn(item) { item.path != "noop" })
  let assert Ok(gates) =
    file(back_files(units), "src/gen/http_runtime.mjs")
    |> string.split("\n")
    |> list.find(fn(line) { string.starts_with(line, "const phaseGates=") })
  string.contains(gates, "article_gate_own:['published']") |> should.be_true
  string.contains(gates, "article_gate_other") |> should.be_false
}

/// 出力先が app そのもののとき、`db/queries` へは既に在る `-- GENERATED` の file だけを書く(WGy r4、鷹野の
/// 裁定 1 (c))。生成器だけが出す SQL は `sql.mjs` に束ねるだけで app に増やさず、★ の手書きも上書きしない。
/// 出力先が別の dir なら全部を書く。
pub fn into_app_writes_only_existing_generated_queries_test() {
  let files = [
    types.File(path: "db/queries/a/old.sql", text: "-- GENERATED\nSELECT 1;"),
    types.File(path: "db/queries/a/new.sql", text: "-- GENERATED\nSELECT 2;"),
    types.File(path: "db/queries/a/star.sql", text: "-- GENERATED\nSELECT 3;"),
    types.File(path: "src/gen/sql.mjs", text: "export const SQL = {};"),
  ]
  let generated = fn(path) { path == "db/queries/a/old.sql" }
  yumemi_gen.into_app(files, True, generated)
  |> list.map(fn(file) { file.path })
  |> should.equal(["db/queries/a/old.sql", "src/gen/sql.mjs"])
  yumemi_gen.into_app(files, False, generated)
  |> list.length
  |> should.equal(4)
}

/// 機関を framework が持つ attached の口の役と browser の署名 cookie は宣言から渡す(WGy r4)── framework の
/// JS は口の名も cookie の名も知らない。framework の役の口は ★ hook `attached_<name>` を要らない。
pub fn attached_roles_and_browser_cookie_follow_the_declaration_test() {
  let units =
    units_with(article_fixture, [
      server(
        "pub const attached: List(server.Attached) = [Attached(name: \"adult\", method: Post, path: \"/api/adult\", who: Anyone), Attached(name: \"me\", method: Get, path: \"/api/me\", who: Anyone), Attached(name: \"asset\", method: Get, path: \"/asset/:key\", who: Anyone)]\n"
        <> "pub const hooks: List(server.Hook) = [Hook(name: \"attached_asset\", module: \"hooks\")]\n"
        <> "pub const attached_roles: List(server.AttachedRole) = [DeclareBrowser(attached: \"adult\"), ReadSession(attached: \"me\"), TailPath(attached: \"asset\"), NeedsBrowser(attached: \"asset\")]\n"
        <> "pub const browser: server.BrowserCookie = BrowserCookie(cookie: \"_fx\", key_binding: \"FX_KEY\", claim: \"declared_at\", max_age_days: 30)\n",
      ),
    ])
    |> list.filter(fn(item) { item.path != "noop" })
  let assert Ok(app) = reader.read(units)
  server_reader.notes(app) |> should.equal([])
  let text = file(back_files(units), "src/gen/http_runtime.mjs")
  string.contains(
    text,
    "const roles={adult:['declare_browser'],me:['read_session'],asset:['tail_path','needs_browser']};",
  )
  |> should.be_true
  string.contains(
    text,
    "const browserCookie={cookie:'_fx',binding:'FX_KEY',claim:'declared_at',maxAgeDays:30};",
  )
  |> should.be_true
  string.contains(text, "const ports={asset:h_attachedAsset};")
  |> should.be_true
  string.contains(text, "roles,browserCookie,") |> should.be_true
}

/// 役の名が attached に無い行と、browser の宣言の無い `DeclareBrowser` は exit 4 で名指し。
/// 宣言が無ければ browser は null(framework は申告を常に無いと見る)。
pub fn attached_roles_without_their_attached_are_exit_four_test() {
  let units =
    units_with(article_fixture, [
      server(
        "pub const attached: List(server.Attached) = [Attached(name: \"adult\", method: Post, path: \"/api/adult\", who: Anyone)]\n"
        <> "pub const attached_roles: List(server.AttachedRole) = [DeclareBrowser(attached: \"adult\"), ReadSession(attached: \"ghost\")]\n",
      ),
    ])
  let assert Ok(app) = reader.read(units)
  let notes = server_reader.notes(app)
  list.length(notes) |> should.equal(2)
  [
    "attached_roles の attached が無い: ghost",
    "attached_roles の DeclareBrowser に browser の宣言が無い: adult",
  ]
  |> list.each(fn(text) {
    list.any(notes, fn(note) { string.contains(note.text, text) })
    |> should.be_true
  })
  let text =
    file(
      back_files(list.filter(units, fn(item) { item.path != "noop" })),
      "src/gen/http_runtime.mjs",
    )
  string.contains(text, "const browserCookie=null;") |> should.be_true
}

// ── queue の consumer の party(gate-1 r2)────────────────────────────────────

fn queue_units(server_text: String) -> List(source.Unit) {
  let assert Ok(units) = source.load(article_fixture)
  let assert Ok(publish) =
    list.find(units, fn(item) { item.path == "service/article_publish" })
  units_with(article_fixture, [
    unit(
      "service/article_publish",
      publish.text <> "\n// step.call_write(queue.article_retract(args))\n",
    ),
    unit("server", server_text),
  ])
}

fn queue_runtime(units: List(source.Unit)) -> String {
  let assert Ok(app) = reader.read(units)
  back.emit(
    app,
    units,
    hash.of(units),
    [#("article_publish/root", "SELECT 1")],
    [],
  ).files
  |> list.map(fn(file) { #(file.path, file.text) })
  |> file("src/gen/queue_runtime.mjs")
}

/// 借りた root を読む party は `roots` の `QueueParty` から。framework の outbox は主体の名を知らない
/// (前は生成器が who の `Staff` を見て `staffRoot` を出し、outbox が Staff の行を作っていた)。
pub fn queue_consumer_party_follows_the_declaration_test() {
  let declared =
    queue_units(
      "import framework/server.{QueueParty}\n\n"
      <> "pub const roots: List(server.RootShape) = [\n"
      <> "  QueueParty(service: \"article_retract\", party: \"queue\"),\n"
      <> "]\n",
    )
    |> queue_runtime
  string.contains(
    declared,
    " article_retract:{base:'article_publish',module:articleRetract,root:rootArticleRetract,actor:()=>new allowArticle.SystemActor(),field:'article',party:'queue'},\n",
  )
  |> should.be_true
  string.contains(declared, "staffRoot") |> should.be_false
  let bare =
    queue_units("pub const roots = []\n")
    |> queue_runtime
  string.contains(bare, "field:'article'},\n") |> should.be_true
  string.contains(bare, "party:") |> should.be_false
}

// ── 出力先が app を含む dir のときの置き場(gate-1 r2、WGy r4 の積み残し)─────────────────

/// `-- <root>/api <root>` なら back は `api/..`、面は面の package(`www/..`)へ。`-- <root>/api <root>/api` なら
/// back はそのまま、面は `../www/..`。別の dir に出すなら従来どおり(`src/gen/..`・`<面>/..`)。
pub fn place_puts_back_and_faces_where_they_live_test() {
  let root =
    yumemi_gen.Placement(app: "api", faces: [
      #("www", "www"),
      #("console", "console"),
    ])
  yumemi_gen.place(root, "src/gen/runtime.mjs")
  |> should.equal("api/src/gen/runtime.mjs")
  yumemi_gen.place(root, "db/queries/allow/ledger.sql")
  |> should.equal("api/db/queries/allow/ledger.sql")
  yumemi_gen.place(root, "www/src/gen/gate.mjs")
  |> should.equal("www/src/gen/gate.mjs")
  yumemi_gen.place(root, "_diagnostics.txt") |> should.equal("_diagnostics.txt")
  let app = yumemi_gen.Placement(app: "", faces: [#("console", "../console")])
  yumemi_gen.place(app, "src/gen/runtime.mjs")
  |> should.equal("src/gen/runtime.mjs")
  yumemi_gen.place(app, "console/priv/static/_yumemi/client.mjs")
  |> should.equal("../console/priv/static/_yumemi/client.mjs")
  let apart = yumemi_gen.Placement(app: "", faces: [])
  yumemi_gen.place(apart, "console/src/gen/gate.mjs")
  |> should.equal("console/src/gen/gate.mjs")
}

// ── subject_free(gate-1 r2)──────────────────────────────────────────────────

/// 入口の主体の集合の検査を外す Service は宣言から `subjectFree` へ(framework の http.mjs は Service の名を
/// 知らない)。Service に無い名は exit 4。宣言が無ければ空。
pub fn subject_free_follows_the_declaration_test() {
  let units =
    units_with(article_fixture, [
      server("pub const subject_free = [\"article_read\", \"ghost\"]\n"),
    ])
    |> list.filter(fn(item) { item.path != "noop" })
  let assert Ok(app) = reader.read(units)
  app.server.subject_free |> should.equal(["article_read", "ghost"])
  server_reader.notes(app)
  |> list.map(fn(note) { note.text })
  |> should.equal(["server.gleam: subject_free の Service が無い: ghost"])
  let text = file(back_files(units), "src/gen/http_runtime.mjs")
  string.contains(text, "const subjectFree=['article_read','ghost'];")
  |> should.be_true
  string.contains(text, "browserCookie,subjectFree,apiKeyPattern")
  |> should.be_true
  let bare =
    file(
      back_files(without(article_fixture, "noop")),
      "src/gen/http_runtime.mjs",
    )
  string.contains(bare, "const subjectFree=[];") |> should.be_true
}
