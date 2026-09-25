//// WGy(yumemi-gen-8)── `src/server.gleam` の宣言、attached の向き、Route の上書きと対象の解き方、
//// back の生成物(registry / codec / queue / cron / shell)。

import glance
import gleam/list
import gleam/string
import gleeunit/should
import yumemi_gen/emit/back
import yumemi_gen/emit/entry
import yumemi_gen/emit/hash
import yumemi_gen/emit/types
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
