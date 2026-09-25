//// リポ内 fixture ── 20-programming-model「まず実物から」の Article アプリ(★ 11 ファイル)。
//// 本文から機械的に写したもので、手を入れていない。生成が通ることと、
//// 20 が本文で名指しした ▲ の形(From / Arrow / 戻りの型)が出ることを見る。

import framework/blob
import framework/time
import glance
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleam/uri
import gleeunit
import gleeunit/should
import simplifile
import yumemi_gen
import yumemi_gen/digest
import yumemi_gen/emit/front as front_emit
import yumemi_gen/emit/hash
import yumemi_gen/emit/query
import yumemi_gen/emit/static as static_emit
import yumemi_gen/face
import yumemi_gen/markdown
import yumemi_gen/model
import yumemi_gen/naming
import yumemi_gen/reader
import yumemi_gen/reader/front
import yumemi_gen/source
import yumemi_gen/static_source
import yumemi_gen/stop

const fixture = "fixtures/article"

@external(javascript, "./yumemi_gen_test_ffi.mjs", "bundle_uses_generated_module")
fn bundle_uses_generated_module() -> String

@external(javascript, "./yumemi_gen_test_ffi.mjs", "bundle_rejects_undefined_import")
fn bundle_rejects_undefined_import() -> String

@external(javascript, "./yumemi_gen_test_ffi.mjs", "path_manifest_keeps_other_versions")
fn path_manifest_keeps_other_versions() -> String

/// 本便(gen-2)で置いた fixture ── 20 の写しではない。
const flag_fixture = "fixtures/flag"

const advance_all_fixture = "fixtures/flag_advance_all"

const parent_delete_fixture = "fixtures/flag_parent"

const no_key_fixture = "fixtures/flag_no_key"

const root_warning_fixture = "fixtures/root_warning"

const phase_collision_fixture = "fixtures/flag_phase_collision"

/// gen-3b で置いた fixture ── 矢印 3 形(Held / Link / Multi)と値域つき順序列。
const relation_fixture = "fixtures/relation"

const relation_text_order_fixture = "fixtures/relation_text_order"

const relation_option_order_fixture = "fixtures/relation_option_order"

const ordered_fixture = "fixtures/ordered_create"

const ordered_negative_fixture = "fixtures/ordered_create_negative"

const entry_prefix_fixture = "fixtures/entry_prefix_validation"

const faces_missing_entry_fixture = "fixtures/faces_missing_entry"

const faces_empty_entries_fixture = "fixtures/faces_empty_entries"

const faces_unknown_fixture = "fixtures/faces_unknown"

const composite_root_route_fixture = "fixtures/composite_root_route"

const sql_unsupported_fixture = "fixtures/sql_unsupported"

const route_suffix_fixture = "fixtures/route_suffix"

const route_ambiguous_fixture = "fixtures/route_ambiguous"

const route_methods_fixture = "fixtures/route_methods"

const route_external_fixture = "fixtures/route_external"

const route_nested_fixture = "fixtures/route_nested"

const verb_fixture = "fixtures/verb_features"

const value_prop_column_fixture = "fixtures/value_prop_column"

const front_overlay_negative_fixture = "fixtures/front_overlay_negative"

pub fn main() {
  gleeunit.main()
}

fn app() -> model.App {
  let assert Ok(units) = source.load(fixture)
  let assert Ok(loaded) = reader.read(units)
  loaded
}

fn value_prop_column(prop: String) -> String {
  let assert Ok(units) = source.load(value_prop_column_fixture)
  let assert Ok(loaded) = reader.read(units)
  let assert Some(example) = model.entity_by_name(loaded.entities, "Example")
  let assert Some(field) = model.field_for_prop(example, prop)
  field.column
}

fn files_of(app_dir: String) -> List(#(String, String)) {
  let assert Ok(#(generated, _)) = yumemi_gen.generate(app_dir)
  list.map(generated, fn(file) { #(file.path, file.text) })
}

fn notes_of(app_dir: String) -> List(stop.Note) {
  let assert Ok(#(_, notes)) = yumemi_gen.generate(app_dir)
  notes
}

fn files() -> List(#(String, String)) {
  files_of(fixture)
}

fn text(path: String) -> String {
  text_of(fixture, path)
}

fn text_of(app_dir: String, path: String) -> String {
  let assert Ok(#(_, found)) =
    list.find(files_of(app_dir), fn(entry) { entry.0 == path })
  found
}

fn synthetic_out(
  module: String,
  service_source: String,
  extra_units: List(source.Unit),
) -> String {
  synthetic_out_for(app(), module, service_source, extra_units)
}

fn synthetic_decoder_out() -> String {
  let assert Ok(back_units) = source.load(fixture)
  let back_units =
    list.filter(back_units, fn(unit) { unit.path != "service/widget_list" })
  let service_unit =
    source_unit(
      "service/widget_list",
      "import entity/article\n"
        <> "import framework/blob.{type Blob}\n"
        <> "import framework/time.{type Time}\n\n"
        <> "pub type Phase {\n  Draft\n  Published\n}\n\n"
        <> "pub type Row {\n"
        <> "  Article(article: article.Article, phase: Phase, icon: Blob, at: Time)\n"
        <> "}\n\n"
        <> "pub type Out {\n  Out(rows: List(Row))\n}\n\n"
        <> "pub const service: Service(Args, Out, Error) = Nil",
    )
  let units = list.append(back_units, [service_unit])
  let service =
    model.Service(
      module: "widget_list",
      out_type: None,
      params: [],
      queries: [],
      args: [],
      allow_module: None,
      subjects: [],
      effect: model.ReadEffect,
      faces: [],
      faces_declared: True,
    )
  let test_app = model.App(..app(), services: [service])
  let assert Ok(face_units) = source.load("fixtures/article/public")
  let model_ = front_from_units_named("public", face_units, [service])
  let package =
    face.Package(
      name: "public",
      path: "fixtures/article/public",
      pages: face.UndeclaredPages,
      units: face_units,
    )
  let generated =
    front_emit.emit(test_app, units, package, model_, hash.of(units))
  let assert Ok(file) =
    list.find(generated, fn(file) {
      file.path == "public/src/gen/out/widget_list.gleam"
    })
  file.text
}

fn synthetic_multi_decoder_out(service_source: String) -> String {
  let assert Ok(back_units) = source.load(fixture)
  let back_units =
    list.filter(back_units, fn(unit) { unit.path != "service/widget_list" })
  let service_unit = source_unit("service/widget_list", service_source)
  let units = list.append(back_units, [service_unit])
  let service =
    model.Service(
      module: "widget_list",
      out_type: None,
      params: [],
      queries: [],
      args: [],
      allow_module: None,
      subjects: [],
      effect: model.ReadEffect,
      faces: [],
      faces_declared: True,
    )
  let test_app = model.App(..app(), services: [service])
  let assert Ok(face_units) = source.load("fixtures/article/public")
  let model_ = front_from_units_named("public", face_units, [service])
  let package =
    face.Package(
      name: "public",
      path: "fixtures/article/public",
      pages: face.UndeclaredPages,
      units: face_units,
    )
  let generated =
    front_emit.emit(test_app, units, package, model_, hash.of(units))
  let assert Ok(file) =
    list.find(generated, fn(file) {
      file.path == "public/src/gen/out/widget_list.gleam"
    })
  file.text
}

fn synthetic_out_for(
  base: model.App,
  module: String,
  service_source: String,
  extra_units: List(source.Unit),
) -> String {
  let assert Ok(back_units) = source.load(fixture)
  let back_units =
    list.filter(back_units, fn(unit) { unit.path != "service/" <> module })
  let assert Ok(face_units) = source.load("fixtures/article/public")
  let service_unit = source_unit("service/" <> module, service_source)
  let units = list.append(back_units, [service_unit, ..extra_units])
  let service =
    model.Service(
      module: module,
      out_type: None,
      params: [],
      queries: [],
      args: [],
      allow_module: None,
      subjects: [],
      effect: model.ReadEffect,
      faces: [],
      faces_declared: True,
    )
  let test_app = model.App(..base, services: [service])
  let model_ = front_from_units_named("public", face_units, [service])
  let package =
    face.Package(
      name: "public",
      path: "fixtures/article/public",
      pages: face.UndeclaredPages,
      units: face_units,
    )
  let generated =
    front_emit.emit(test_app, units, package, model_, hash.of(units))
  let assert Ok(file) =
    list.find(generated, fn(file) {
      file.path == "public/src/gen/out/" <> module <> ".gleam"
    })
  file.text
}

fn api_for_entry(entry_text: String) -> String {
  let assert Ok(loaded_units) = source.load(fixture)
  let back_units =
    loaded_units
    |> list.filter(fn(unit) { unit.path != "entry" })
    |> list.append([source_unit("entry", entry_text)])
  let assert Ok(test_app) = reader.read(back_units)
  let assert Ok(face_units) = source.load("fixtures/article/public")
  let model_ = front_from_units_named("public", face_units, test_app.services)
  let package =
    face.Package(
      name: "public",
      path: "fixtures/article/public",
      pages: face.UndeclaredPages,
      units: face_units,
    )
  let generated =
    front_emit.emit(test_app, back_units, package, model_, hash.of(back_units))
  let assert Ok(file) =
    list.find(generated, fn(file) { file.path == "public/src/gen/api.gleam" })
  file.text
}

fn synthetic_empty_layout_load() -> String {
  let assert Ok(back_units) = source.load(fixture)
  let face_units = [
    source_unit(
      "layout",
      "pub const public: Layout(service.Service, blocks.Block) = Layout(sp: Frame(areas: [], placements: []))",
    ),
  ]
  let base = app()
  let model_ = front_from_units_named("public", face_units, base.services)
  let package =
    face.Package(
      name: "public",
      path: "fixtures/article/public",
      pages: face.UndeclaredPages,
      units: face_units,
    )
  let generated =
    front_emit.emit(base, back_units, package, model_, hash.of(back_units))
  let assert Ok(file) =
    list.find(generated, fn(file) {
      file.path == "public/src/gen/load/layout.gleam"
    })
  file.text
}

// ── 入力 ────────────────────────────────────────────────────────────────────

pub fn collection_id_value_prop_uses_id_column_test() {
  value_prop_column("ledger_store") |> should.equal("ledger_store_id")
}

pub fn framework_party_id_value_prop_keeps_property_column_test() {
  value_prop_column("party") |> should.equal("party")
}

pub fn gen_types_value_prop_keeps_property_column_test() {
  value_prop_column("title") |> should.equal("title")
}

pub fn fixture_gleam_files_parse_including_trailing_spread_test() {
  let assert Ok(units) = source.load(fixture)
  list.length(units) |> should.equal(15)
  list.any(units, fn(unit) { unit.path == "trailing_spread" })
  |> should.be_true
}

pub fn types_entities_services_counted_test() {
  let loaded = app()
  list.length(loaded.value_types) |> should.equal(5)
  list.length(loaded.entities) |> should.equal(4)
  list.length(loaded.services) |> should.equal(7)
}

pub fn lifecycle_read_from_edges_test() {
  let assert Some(article) = model.entity_by_name(app().entities, "Article")
  article.phases
  |> should.equal(["Draft", "Scheduled", "Published", "Retracted"])
  article.key_prop |> should.equal("slug")
  article.collection |> should.equal("articles")
}

pub fn article_http_route_table_has_twelve_rows_test() {
  let face = text("src/gen/face.gleam")
  string.contains(face, "pub type Face {\n  Public\n  Admin\n}")
  |> should.be_true
  let http = text("src/gen/entry/http.gleam")
  [
    "Route(face: \"public\", method: \"POST\", path: \"/api/articles\", service: \"article_create\", path_keys: [], credential: Session),",
    "Route(face: \"public\", method: \"POST\", path: \"/api/articles/{slug}/blob_save\", service: \"article_blob_save\", path_keys: [\"slug\"], credential: Session),",
    "Route(face: \"admin\", method: \"POST\", path: \"/api/admin/articles\", service: \"article_create\", path_keys: [], credential: Session),",
    "Route(face: \"public\", method: \"GET\", path: \"/api/articles\", service: \"article_list\", path_keys: [], credential: Session),",
    "Route(face: \"admin\", method: \"GET\", path: \"/api/admin/articles\", service: \"article_list\", path_keys: [], credential: Session),",
    "Route(face: \"public\", method: \"GET\", path: \"/api/articles/{slug}\", service: \"article_read\", path_keys: [\"slug\"], credential: Session),",
    "Route(face: \"admin\", method: \"GET\", path: \"/api/admin/articles/{slug}\", service: \"article_read\", path_keys: [\"slug\"], credential: Session),",
    "Route(face: \"public\", method: \"POST\", path: \"/api/articles/{slug}/publish\", service: \"article_publish\", path_keys: [\"slug\"], credential: Session),",
    "Route(face: \"admin\", method: \"POST\", path: \"/api/admin/articles/{slug}/publish\", service: \"article_publish\", path_keys: [\"slug\"], credential: Session),",
    "Route(face: \"admin\", method: \"POST\", path: \"/api/admin/articles/{slug}/retract\", service: \"article_retract\", path_keys: [\"slug\"], credential: Session),",
    "Route(face: \"public\", method: \"GET\", path: \"/api/widgets\", service: \"widget_list\", path_keys: [], credential: Session),",
    "Route(face: \"admin\", method: \"GET\", path: \"/api/admin/widgets\", service: \"widget_list\", path_keys: [], credential: Session),",
  ]
  |> list.each(fn(row) { string.contains(http, row) |> should.be_true })
  http
  |> string.split("\n")
  |> list.filter(fn(line) {
    string.starts_with(line, "  Route(face:")
    && string.contains(line, "path: \"")
  })
  |> list.length
  |> should.equal(12)
}

pub fn entry_prefix_is_required_named_and_one_word_test() {
  let notes = notes_of(entry_prefix_fixture)
  stop.worst(notes) |> should.equal(4)
  list.length(notes) |> should.equal(3)
  notes
  |> list.any(fn(note) {
    note.class == stop.Conflict
    && string.contains(note.text, "entry.missing")
    && string.contains(note.text, "prefix が無い")
  })
  |> should.be_true
  notes
  |> list.any(fn(note) {
    string.contains(note.text, "entry.invalid")
    && string.contains(note.text, "prefix が不正")
  })
  |> should.be_true
  notes
  |> list.any(fn(note) {
    string.contains(note.text, "entry.spaced")
    && string.contains(note.text, "prefix が不正")
  })
  |> should.be_true
  notes
  |> list.any(fn(note) { string.contains(note.text, "entry.valid") })
  |> should.be_false
}

pub fn faces_is_required_without_entry_module_test() {
  let notes = notes_of(faces_missing_entry_fixture)
  stop.worst(notes) |> should.equal(4)
  notes
  |> list.any(fn(note) {
    note.class == stop.Conflict
    && string.contains(note.text, "service.example_read")
    && string.contains(note.text, "faces const が無い")
  })
  |> should.be_true
}

pub fn faces_is_required_when_entries_is_empty_test() {
  let notes = notes_of(faces_empty_entries_fixture)
  stop.worst(notes) |> should.equal(4)
  notes
  |> list.any(fn(note) {
    string.contains(note.text, "service.example_read")
    && string.contains(note.text, "faces const が無い")
  })
  |> should.be_true
}

pub fn unknown_face_is_rejected_by_name_test() {
  let notes = notes_of(faces_unknown_fixture)
  stop.worst(notes) |> should.equal(4)
  notes
  |> list.any(fn(note) {
    string.contains(note.text, "service.example_read")
    && string.contains(note.text, "未知の面名: Missing")
  })
  |> should.be_true
}

pub fn composite_root_counts_each_key_component_in_route_test() {
  let root =
    text_of(composite_root_route_fixture, "src/gen/root/child_read.gleam")
  string.contains(root, "parent: parent.Parent") |> should.be_true

  let http = text_of(composite_root_route_fixture, "src/gen/entry/http.gleam")
  string.contains(
    http,
    "Route(face: \"test\", method: \"GET\", path: \"/test/parents/{a}/{b}/children\", service: \"child_list\", path_keys: [\"a\", \"b\"], credential: Session),",
  )
  |> should.be_true
  string.contains(http, "service: \"child_read\"") |> should.be_false

  let notes = notes_of(composite_root_route_fixture)
  stop.worst(notes) |> should.equal(4)
  notes
  |> list.any(fn(note) {
    string.contains(note.text, "service.child_read face Test")
    && string.contains(note.text, "パス変数が3個以上")
  })
  |> should.be_true
}

pub fn route_target_uses_longest_entity_suffix_and_keeps_residue_test() {
  let http = text_of(route_suffix_fixture, "src/gen/entry/http.gleam")
  string.contains(
    http,
    "Route(face: \"test\", method: \"POST\", path: \"/test/free_spaces\", service: \"space_add\", path_keys: [], credential: Session),",
  )
  |> should.be_true
  string.contains(
    http,
    "Route(face: \"test\", method: \"GET\", path: \"/test/muse_heavens/embed_code\", service: \"heaven_embed_code\", path_keys: [], credential: Session),",
  )
  |> should.be_true
  let notes = notes_of(route_suffix_fixture)
  stop.worst(notes) |> should.equal(4)
  notes
  |> list.any(fn(note) {
    note.class == stop.Conflict
    && string.contains(note.text, "space_")
    && string.contains(note.text, "動詞が空")
  })
  |> should.be_true
}

pub fn route_method_mapping_covers_all_eight_verbs_test() {
  let http = text_of(route_methods_fixture, "src/gen/entry/http.gleam")
  [
    "Route(face: \"test\", method: \"POST\", path: \"/test/things\", service: \"thing_create\", path_keys: [], credential: Session),",
    "Route(face: \"test\", method: \"GET\", path: \"/test/things/{id}\", service: \"thing_read\", path_keys: [\"id\"], credential: Session),",
    "Route(face: \"test\", method: \"GET\", path: \"/test/things\", service: \"thing_list\", path_keys: [], credential: Session),",
    "Route(face: \"test\", method: \"DELETE\", path: \"/test/things/{id}\", service: \"thing_delete\", path_keys: [\"id\"], credential: Session),",
    "Route(face: \"test\", method: \"PUT\", path: \"/test/things/{id}\", service: \"thing_put\", path_keys: [\"id\"], credential: Session),",
    "Route(face: \"test\", method: \"POST\", path: \"/test/things\", service: \"thing_add\", path_keys: [], credential: Session),",
    "Route(face: \"test\", method: \"PUT\", path: \"/test/things/{id}\", service: \"thing_edit\", path_keys: [\"id\"], credential: Session),",
    "Route(face: \"test\", method: \"DELETE\", path: \"/test/things/{id}\", service: \"thing_remove\", path_keys: [\"id\"], credential: Session),",
  ]
  |> list.each(fn(row) { string.contains(http, row) |> should.be_true })
}

pub fn route_add_with_key_argument_uses_collection_path_test() {
  let http = text_of(route_methods_fixture, "src/gen/entry/http.gleam")
  string.contains(
    http,
    "Route(face: \"test\", method: \"POST\", path: \"/test/things\", service: \"thing_add\", path_keys: [], credential: Session),",
  )
  |> should.be_true
  string.contains(http, "service: \"thing_add\", path_keys: [\"id\"]")
  |> should.be_false
}

pub fn route_method_overlap_is_exit_four_test() {
  let notes = notes_of(route_methods_fixture)
  stop.worst(notes) |> should.equal(4)
  let overlaps =
    list.filter(notes, fn(note) {
      note.class == stop.Conflict
      && string.contains(note.text, "HTTP route が重複")
    })
  list.length(overlaps) |> should.equal(3)
  [
    #("POST /test/things", "thing_create", "thing_add"),
    #("PUT /test/things/{id}", "thing_put", "thing_edit"),
    #("DELETE /test/things/{id}", "thing_delete", "thing_remove"),
  ]
  |> list.each(fn(item) {
    let #(route, left, right) = item
    overlaps
    |> list.any(fn(note) {
      string.contains(note.text, route)
      && string.contains(note.text, left)
      && string.contains(note.text, right)
    })
    |> should.be_true
  })
}

pub fn route_target_stops_on_same_length_suffix_ambiguity_test() {
  let notes = notes_of(route_ambiguous_fixture)
  stop.worst(notes) |> should.equal(4)
  notes
  |> list.any(fn(note) {
    note.class == stop.Conflict
    && string.contains(note.text, "schedule_add")
    && string.contains(note.text, "muse_schedule")
    && string.contains(note.text, "store_schedule")
  })
  |> should.be_true
}

pub fn route_target_reads_external_collection_and_rejects_item_verbs_test() {
  let assert Ok(units) = source.load(route_external_fixture)
  let assert Ok(loaded) = reader.read(units)
  let assert Ok(collection) =
    list.find(loaded.collections, fn(item) { item.module == "ledger_store" })
  collection.collection |> should.equal("ledger_stores")

  let http = text_of(route_external_fixture, "src/gen/entry/http.gleam")
  string.contains(
    http,
    "Route(face: \"test\", method: \"GET\", path: \"/test/ledger_stores/search\", service: \"ledger_store_search\", path_keys: [], credential: Session),",
  )
  |> should.be_true
  string.contains(
    http,
    "Route(face: \"test\", method: \"GET\", path: \"/test/ledger_stores\", service: \"ledger_store_list\", path_keys: [], credential: Session),",
  )
  |> should.be_true
  string.contains(
    http,
    "Route(face: \"test\", method: \"POST\", path: \"/test/ledger_stores\", service: \"ledger_store_create\", path_keys: [], credential: Session),",
  )
  |> should.be_true
  let notes = notes_of(route_external_fixture)
  stop.worst(notes) |> should.equal(4)
  notes
  |> list.any(fn(note) {
    string.contains(note.text, "ledger_store_read")
    && string.contains(note.text, "個体レベル")
  })
  |> should.be_true
  notes
  |> list.any(fn(note) {
    string.contains(note.text, "ghost_search")
    && string.contains(note.text, "対象が無い")
  })
  |> should.be_true
  notes
  |> list.any(fn(note) {
    string.contains(note.text, "store_search")
    && string.contains(note.text, "対象が無い")
  })
  |> should.be_true
}

pub fn route_target_stops_nested_entity_reserved_name_but_keeps_counterexamples_test() {
  let http = text_of(route_nested_fixture, "src/gen/entry/http.gleam")
  [
    "service: \"store_link_ledger\"",
    "path: \"/test/ledger_stores/search\"",
    "service: \"ledger_store_search\"",
    "service: \"store_api_key_issue\"",
    "service: \"muse_heaven_list\"",
  ]
  |> list.each(fn(service) { string.contains(http, service) |> should.be_true })
  let notes = notes_of(route_nested_fixture)
  list.length(notes) |> should.equal(1)
  let assert [note] = notes
  note.class |> should.equal(stop.Conflict)
  string.contains(note.text, "store_roster_list") |> should.be_true
  string.contains(note.text, "roster") |> should.be_true
  string.contains(note.text, "予約動詞") |> should.be_true
}

// ── 束1 Type の値 ───────────────────────────────────────────────────────────

pub fn one_module_per_spec_test() {
  let paths = list.map(files(), fn(entry) { entry.0 })
  ["slug", "title", "body", "category_name", "tag_name"]
  |> list.each(fn(name) {
    list.contains(paths, "src/gen/types/" <> name <> ".gleam")
    |> should.be_true
  })
}

pub fn generated_type_wraps_the_spec_test() {
  let found = text("src/gen/types/slug.gleam")
  string.starts_with(found, "//// GENERATED from types.slug [sha256:")
  |> should.be_true
  string.contains(found, "] — 手で編集しない\n") |> should.be_true
  string.contains(found, "pub opaque type Slug {") |> should.be_true
  string.contains(found, "spec.validate(raw, types.slug)") |> should.be_true
}

// ── 束2 読みの語彙 ──────────────────────────────────────────────────────────

pub fn from_has_one_variant_per_entity_test() {
  let found = text("src/gen/query/from.gleam")
  string.contains(
    found,
    "pub type From {\n  Article\n  Category\n  Staff\n  Tag\n}",
  )
  |> should.be_true
}

pub fn arrow_has_one_variant_per_relation_test() {
  let found = text("src/gen/query.gleam")
  string.contains(
    found,
    "pub type Arrow {\n  ArticleToCategory\n  ArticleToTags\n}",
  )
  |> should.be_true
}

pub fn to_many_relation_is_not_a_column_test() {
  let found = text("src/gen/query/field.gleam")
  // multi(Tag) は中間表に居るので Field にしない。矢印にだけ出る。
  string.contains(found, "ArticleTags\n") |> should.be_false
  string.contains(found, "ArticleCategory\n") |> should.be_true
}

pub fn phase_and_arrival_columns_are_generated_test() {
  let found = text("src/gen/query/field.gleam")
  [
    "ArticlePhase",
    "ArticleEnteredDraft",
    "ArticleEnteredScheduled",
    "ArticleEnteredPublished",
    "ArticleEnteredRetracted",
  ]
  |> list.each(fn(name) { string.contains(found, name) |> should.be_true })
}

// ── 束3 読みの器 ────────────────────────────────────────────────────────────

pub fn reads_are_emitted_for_queries_and_root_arrows_test() {
  let paths = list.map(files(), fn(entry) { entry.0 })
  // article_list / widget_list は名前付きクエリ、他の4本は root Article の矢印。
  list.filter(paths, string.starts_with(_, "src/gen/reads/"))
  |> should.equal([
    "src/gen/reads/article_create.gleam",
    "src/gen/reads/article_list.gleam",
    "src/gen/reads/article_publish.gleam",
    "src/gen/reads/article_read.gleam",
    "src/gen/reads/article_retract.gleam",
    "src/gen/reads/widget_list.gleam",
  ])
}

pub fn read_return_type_comes_from_the_query_value_test() {
  let found = text("src/gen/reads/article_list.gleam")
  // Paged + Lifecycle -> Page(#(Article, Phase))
  string.contains(found, "Page(#(article.Article, article.Phase))")
  |> should.be_true
  // group Via + agg Count -> List(#(Category, Int))
  string.contains(found, "List(#(category.Category, Int))") |> should.be_true
}

pub fn param_labels_come_from_p_variants_test() {
  let found = text("src/gen/reads/article_list.gleam")
  string.contains(found, "limit limit: Int,") |> should.be_true
  string.contains(found, "cursor cursor: Option(Cursor),") |> should.be_true
}

pub fn root_bundle_uses_allow_and_args_key_test() {
  let read = text("src/gen/root/article_read.gleam")
  string.contains(read, "Root(") |> should.be_true
  string.contains(read, "article: article.Article,") |> should.be_true
  string.contains(read, "phase: article.Phase,") |> should.be_true
  string.contains(read, "at: Datetime,") |> should.be_true
  string.contains(read, "seed: String,") |> should.be_true
  string.contains(read, "pub type Actor =\n  allow.Actor") |> should.be_true
  string.contains(read, "Anonymous") |> should.be_false
  string.contains(read, "AsStaff(staff.Staff)") |> should.be_false

  let publish = text("src/gen/root/article_publish.gleam")
  string.contains(publish, "logic: fn(staff.Staff, Root, args)")
  |> should.be_true

  let list_root = text("src/gen/root/article_list.gleam")
  string.contains(list_root, "Root(at: Datetime, seed: String)")
  |> should.be_true
}

pub fn root_relative_arrows_are_emitted_test() {
  let found = text("src/gen/reads/article_read.gleam")
  string.contains(found, "pub fn to_category(") |> should.be_true
  string.contains(found, "then: fn(category.Category)") |> should.be_true
  string.contains(found, "pub fn to_tags(") |> should.be_true
  string.contains(found, "then: fn(List(tag.Tag))") |> should.be_true
}

/// gen-3b ── 矢印の read は framework の Context 契約 `relation` を、宣言の名前で呼ぶ。
/// root の欄と関係 Property は型付きで参照する(`it.article.category`)── 名前推測は無い。
pub fn root_relative_arrows_use_framework_relation_contract_test() {
  let found = text("src/gen/reads/article_read.gleam")
  string.contains(found, "import framework/io.{type Context, type Promise}")
  |> should.be_true
  string.contains(found, "import framework/er") |> should.be_true
  string.contains(found, "io.root_arrow(") |> should.be_false
  string.contains(found, "operations_ffi.mjs\", \"rootArrow\"")
  |> should.be_false
  string.contains(
    found,
    "const to_category_relation = io.Relation(\n"
      <> "  service: \"article_read\",\n"
      <> "  query: \"to_category\",\n"
      <> "  arrow: \"ArticleToCategory\",\n"
      <> "  from: \"article\",\n"
      <> "  prop: \"category\",\n"
      <> "  target: \"category\",\n"
      <> ")",
  )
  |> should.be_true
  // Has -> relation_one、Multi -> relation_many
  string.contains(
    found,
    "io.relation_one(\n        ctx,\n        to_category_relation,\n"
      <> "        er.to_string(er.of(it.article.category)),\n      )",
  )
  |> should.be_true
  string.contains(
    found,
    "io.relation_many(\n        ctx,\n        to_labels_relation,",
  )
  |> should.be_false
  string.contains(
    found,
    "io.relation_many(\n        ctx,\n        to_tags_relation,\n"
      <> "        list.map(er.of_multi(it.article.tags), er.to_string),\n      )",
  )
  |> should.be_true
}

/// gen-3b ── 3 形が出力型に一致する:Held -> `album.Album`、Link -> `Option(shelf.Shelf)`、
/// Multi -> `List(label.Label)`。鍵の取り出しも形ごとに違う。
pub fn root_relative_arrows_cover_one_option_many_test() {
  let found = text_of(relation_fixture, "src/gen/reads/photo_read.gleam")
  string.contains(found, "then: fn(album.Album) -> Step(out, err, state)")
  |> should.be_true
  string.contains(
    found,
    "io.relation_one(\n        ctx,\n        to_album_relation,\n"
      <> "        er.to_string(er.of_held(it.photo.album)),\n      )",
  )
  |> should.be_true
  string.contains(
    found,
    "then: fn(Option(shelf.Shelf)) -> Step(out, err, state)",
  )
  |> should.be_true
  string.contains(
    found,
    "io.relation_option(\n        ctx,\n        to_shelf_relation,\n"
      <> "        option.map(it.photo.shelf, er.to_string),\n      )",
  )
  |> should.be_true
  string.contains(found, "then: fn(List(label.Label)) -> Step(out, err, state)")
  |> should.be_true
  string.contains(
    found,
    "io.relation_many(\n        ctx,\n        to_labels_relation,\n"
      <> "        list.map(er.of_multi(it.photo.labels), er.to_string),\n      )",
  )
  |> should.be_true
  string.contains(found, "import gleam/option.{type Option}") |> should.be_true
  string.contains(found, "import gleam/list") |> should.be_true
}

// ── 束4 読みの SQL ──────────────────────────────────────────────────────────

pub fn one_statement_per_named_query_test() {
  let paths = list.map(files(), fn(entry) { entry.0 })
  list.filter(paths, fn(path) {
    string.starts_with(path, "db/queries/")
    && !string.starts_with(path, "db/queries/verb/")
    && !string.contains(path, "/to_")
  })
  |> list.sort(string.compare)
  |> should.equal([
    "db/queries/article_list/counts.sql",
    "db/queries/article_list/items.sql",
    "db/queries/widget_list/items.sql",
  ])
}

pub fn relation_presence_and_with_become_sql_test() {
  let related = text_of(relation_fixture, "db/queries/photo_filter/related.sql")
  string.contains(
    related,
    "WHERE EXISTS(\n"
      <> "  SELECT 1 FROM app.album a\n"
      <> "  WHERE a.id=p.album_id\n"
      <> "    AND a.id=$1::uuid",
  )
  |> should.be_true
  string.contains(
    related,
    "NOT EXISTS(\n"
      <> "  SELECT 1 FROM app.shelf s\n"
      <> "  WHERE s.id=p.shelf_id\n"
      <> "    AND s.id=$2::uuid",
  )
  |> should.be_true

  let with_photos =
    text_of(relation_fixture, "db/queries/photo_filter/album_photos.sql")
  string.contains(
    with_photos,
    "COALESCE((SELECT jsonb_agg(to_jsonb(p) ORDER BY p.\"order\",p.id)",
  )
  |> should.be_true
  string.contains(with_photos, "FROM app.photo p\nWHERE p.album_id=a.id")
  |> should.be_true
  string.contains(with_photos, "),'[]'::jsonb) AS photos")
  |> should.be_true
}

pub fn forward_with_stops_as_unimplemented_test() {
  let notes = notes_of(sql_unsupported_fixture)
  let assert Ok(note) =
    list.find(notes, fn(note) {
      string.contains(note.text, "article_list/items")
    })
  note.class |> should.equal(stop.NotImplemented)
  stop.worst(notes) |> should.equal(1)
  string.contains(note.text, "with の順方向は未対応: ArticleToCategory")
  |> should.be_true
  files_of(sql_unsupported_fixture)
  |> list.any(fn(file) { file.0 == "db/queries/article_list/items.sql" })
  |> should.be_false
}

pub fn multi_has_stops_as_unimplemented_test() {
  let notes = notes_of(sql_unsupported_fixture)
  let assert Ok(note) =
    list.find(notes, fn(note) {
      string.contains(note.text, "photo_filter/related")
    })
  note.class |> should.equal(stop.NotImplemented)
  stop.worst(notes) |> should.equal(1)
  string.contains(note.text, "Has / HasNone は Multi の矢印に未対応")
  |> should.be_true
  files_of(sql_unsupported_fixture)
  |> list.any(fn(file) { file.0 == "db/queries/photo_filter/related.sql" })
  |> should.be_false
}

/// gen-3b ── 矢印 1 本につき SQL 1 文(`db/queries/<service>/to_<prop>.sql`)。
/// root Article を持つ 4 Service × 矢印 2 本 = 8 本。
pub fn one_statement_per_root_arrow_test() {
  let paths = list.map(files(), fn(entry) { entry.0 })
  list.filter(paths, fn(path) {
    string.starts_with(path, "db/queries/") && string.contains(path, "/to_")
  })
  |> list.sort(string.compare)
  |> should.equal([
    "db/queries/article_create/to_category.sql",
    "db/queries/article_create/to_tags.sql",
    "db/queries/article_publish/to_category.sql",
    "db/queries/article_publish/to_tags.sql",
    "db/queries/article_read/to_category.sql",
    "db/queries/article_read/to_tags.sql",
    "db/queries/article_retract/to_category.sql",
    "db/queries/article_retract/to_tags.sql",
  ])
  let found = text("db/queries/article_read/to_category.sql")
  string.starts_with(
    found,
    "-- GENERATED from service.article_read / ArticleToCategory",
  )
  |> should.be_true
  string.contains(
    found,
    "FROM jsonb_array_elements_text($1::jsonb) WITH ORDINALITY AS keys(value,ord)",
  )
  |> should.be_true
  string.contains(found, "JOIN app.category t ON t.name=keys.value::text")
  |> should.be_true
  string.contains(found, "ORDER BY keys.ord;") |> should.be_true
  // uuid の鍵は uuid に寄せる
  let album = text_of(relation_fixture, "db/queries/photo_read/to_album.sql")
  string.contains(album, "JOIN app.album t ON t.id=keys.value::uuid")
  |> should.be_true
}

pub fn keyset_uses_the_order_columns_and_the_key_test() {
  let found = text("db/queries/article_list/items.sql")
  string.contains(found, "(a.entered_published,a.slug)<") |> should.be_true
  string.contains(found, "ORDER BY a.entered_published DESC,a.slug DESC")
  |> should.be_true
  // Paged は size + 1 件取って次の頁が在るかを見る
  string.contains(found, "LIMIT $1 + 1") |> should.be_true
}

pub fn group_becomes_group_by_test() {
  let found = text("db/queries/article_list/counts.sql")
  string.contains(found, "GROUP BY a.category_id") |> should.be_true
  string.contains(found, "count(*)::integer AS count") |> should.be_true
}

pub fn every_file_carries_the_generated_header_test() {
  files()
  |> list.filter_map(fn(entry) {
    let #(path, found) = entry
    let valid = case string.ends_with(path, ".sql") {
      True -> string.starts_with(found, "-- GENERATED ")
      False ->
        case string.ends_with(path, ".mjs") {
          True -> string.starts_with(found, "// GENERATED ")
          False ->
            case string.ends_with(path, ".css") {
              True -> string.starts_with(found, "/* GENERATED ")
              False -> string.starts_with(found, "//// GENERATED ")
            }
        }
    }
    case valid {
      True -> Error(Nil)
      False -> Ok(path)
    }
  })
  |> should.equal([])
}

// ── 名前の変換 ──────────────────────────────────────────────────────────────

pub fn naming_round_trip_test() {
  naming.pascal("article_id") |> should.equal("ArticleId")
  naming.pascal("visits_2plus") |> should.equal("Visits2Plus")
  naming.snake("ArticleId") |> should.equal("article_id")
  naming.initial("free_space") |> should.equal("s")
  naming.initial("article") |> should.equal("a")
}

pub fn no_stray_none_test() {
  // option を使っているので未使用 import で落ちないことの確認だけ。
  None |> should.equal(None)
}

// ── 束2 の module 分割(2026-09-16 人見裁定) ──────────────────────────────────

pub fn query_is_three_modules_test() {
  let paths = list.map(files(), fn(entry) { entry.0 })
  [
    "src/gen/query.gleam",
    "src/gen/query/from.gleam",
    "src/gen/query/field.gleam",
  ]
  |> list.each(fn(path) { list.contains(paths, path) |> should.be_true })
}

pub fn from_and_field_are_not_in_the_same_namespace_test() {
  // 語彙の残りは query.gleam。From / Field の構成子はそこに無い。
  let found = text("src/gen/query.gleam")
  string.contains(found, "pub type From =\n  from.From") |> should.be_true
  string.contains(found, "pub type Field =\n  field.Field") |> should.be_true
  string.contains(found, "\n  ArticleSlug\n") |> should.be_false
  // From / Field の module は語彙の残りを持たない。
  string.contains(text("src/gen/query/from.gleam"), "pub type Select")
  |> should.be_false
  string.contains(text("src/gen/query/field.gleam"), "pub type Cond")
  |> should.be_false
}

pub fn no_collision_after_the_split_test() {
  // Article アプリには衝突が無い。割ったあとも module ごとに数えている。
  let assert Ok(units) = source.load(fixture)
  let assert Ok(loaded) = reader.read(units)
  query.collisions(loaded) |> should.equal([])
}

// ── 束5 verb / phase ────────────────────────────────────────────────────────

pub fn verb_bundle_covers_declared_actions_test() {
  let paths = list.map(files(), fn(entry) { entry.0 })
  [
    "src/gen/verb.gleam",
    "src/gen/phase.gleam",
    "db/queries/verb/pin_article.sql",
    "db/queries/verb/delete_article_by_title.sql",
    "db/queries/verb/create_articles.sql",
    "db/queries/verb/reorder_articles.sql",
    "db/queries/verb/put_article.sql",
  ]
  |> list.each(fn(path) { list.contains(paths, path) |> should.be_true })
  let found = text("src/gen/verb.gleam")
  string.contains(found, "pub fn pin_article(") |> should.be_true
  string.contains(found, "pub fn update_article_title(") |> should.be_false
  string.contains(found, "pub fn advance_article(") |> should.be_true
}

pub fn verb_fixture_reads_handwritten_sealed_and_external_declarations_test() {
  let assert Ok(units) = source.load(verb_fixture)
  let assert Ok(loaded) = reader.read(units)
  let assert Ok(external) =
    list.find(loaded.collections, fn(item) { item.module == "ledger" })
  external.collection |> should.equal("ledger_rows")
  let assert Ok(handwritten) =
    list.find(loaded.entities, fn(item) { item.module == "handwritten" })
  handwritten.handwritten_verbs
  |> should.equal([
    "create_handwritten",
    "create_feature",
    "unknown_handwritten",
  ])
}

pub fn handwritten_verbs_suppress_matching_output_and_warn_once_per_miss_test() {
  let paths = list.map(files_of(verb_fixture), fn(entry) { entry.0 })
  list.contains(paths, "db/queries/verb/create_handwritten.sql")
  |> should.be_false
  let found = text_of(verb_fixture, "src/gen/verb.gleam")
  string.contains(found, "//// handwritten: ") |> should.be_true
  string.contains(found, "create_handwritten") |> should.be_true
  string.contains(found, "external_handwritten") |> should.be_true
  let notes = notes_of(verb_fixture)
  stop.worst(notes) |> should.equal(0)
  notes
  |> list.filter(fn(note) { string.contains(note.text, "unknown_handwritten") })
  |> list.length
  |> should.equal(1)
  notes
  |> list.filter(fn(note) { string.contains(note.text, "external_handwritten") })
  |> list.length
  |> should.equal(1)
}

pub fn entity_handwritten_foreign_name_warns_without_suppressing_test() {
  let paths = list.map(files_of(verb_fixture), fn(entry) { entry.0 })
  list.contains(paths, "db/queries/verb/create_feature.sql")
  |> should.be_true
  let found = text_of(verb_fixture, "src/gen/verb.gleam")
  string.contains(found, "pub fn create_feature(") |> should.be_true
  notes_of(verb_fixture)
  |> list.filter(fn(note) {
    string.contains(
      note.text,
      "handwritten: handwritten_verbs に生成名が無い: create_feature",
    )
  })
  |> list.length
  |> should.equal(1)
}

pub fn entity_handwritten_own_name_suppresses_function_and_sql_test() {
  let paths = list.map(files_of(verb_fixture), fn(entry) { entry.0 })
  list.contains(paths, "db/queries/verb/create_handwritten.sql")
  |> should.be_false
  let found = text_of(verb_fixture, "src/gen/verb.gleam")
  string.contains(found, "pub fn create_handwritten(") |> should.be_false
  notes_of(verb_fixture)
  |> list.filter(fn(note) { string.contains(note.text, "create_handwritten") })
  |> list.length
  |> should.equal(0)
}

pub fn verb_fixture_emits_phase_gate_casts_sealed_and_multi_scope_test() {
  let create = text_of(verb_fixture, "db/queries/verb/create_feature.sql")
  string.contains(create, "phase,entered_draft") |> should.be_true
  string.contains(create, "'draft'") |> should.be_true
  string.contains(create, "::timestamptz") |> should.be_true

  let update = text_of(verb_fixture, "db/queries/verb/rename_feature.sql")
  string.contains(update, "SET title=$2") |> should.be_true
  string.contains(update, "phase='draft'") |> should.be_true

  let reorder = text_of(verb_fixture, "db/queries/verb/reorder_features.sql")
  string.contains(reorder, "$3::jsonb") |> should.be_true
  string.contains(reorder, "owner_id=$1::uuid") |> should.be_true
  string.contains(reorder, "space_id IS NOT DISTINCT FROM $2::uuid")
  |> should.be_true

  let sealed = text_of(verb_fixture, "db/queries/verb/create_sealed_record.sql")
  string.contains(sealed, "body_key_id") |> should.be_true
  string.contains(sealed, "decode($2,'hex')") |> should.be_true
}

pub fn put_does_not_update_keys_versions_or_phase_gated_fields_test() {
  let found = text("db/queries/verb/put_article.sql")
  string.contains(found, "body=EXCLUDED.body") |> should.be_true
  string.contains(found, "WHERE target.version=$6") |> should.be_true
  string.contains(found, "version=target.version+1") |> should.be_true
  string.contains(found, "framework.require_rows(count(*),'conflict')")
  |> should.be_true
  string.contains(found, "slug=EXCLUDED.slug") |> should.be_false
  string.contains(found, "title=EXCLUDED.title") |> should.be_false
  string.contains(found, "version=EXCLUDED.version") |> should.be_false
}

pub fn reorder_uses_declared_order_column_and_returning_alias_test() {
  let found = text("db/queries/verb/reorder_articles.sql")
  string.contains(found, "AS new_order,ord") |> should.be_true
  string.contains(found, "RETURNING e.slug,e.\"order\"")
  |> should.be_true
  string.contains(found, "FROM changed ORDER BY changed.\"order\",changed.slug")
  |> should.be_true
  let stage = text("db/queries/verb/reorder_articles_stage.sql")
  string.contains(stage, "\"order\"=(-t.ord)::integer") |> should.be_false
  string.contains(stage, "\"order\"=f.candidate") |> should.be_true
  string.contains(stage, "c.expected=c.matched") |> should.be_true
  let verb = text("src/gen/verb.gleam")
  string.contains(verb, "verb.compound(") |> should.be_true
  string.contains(verb, "reorder_articles_stage") |> should.be_true
}

pub fn ordered_create_locks_parent_and_assigns_next_order_test() {
  let found = text_of(relation_fixture, "db/queries/verb/create_photo.sql")
  string.contains(found, "FROM app.album") |> should.be_true
  string.contains(found, "WHERE id=$2::uuid FOR UPDATE NOWAIT")
  |> should.be_true
  string.contains(
    found,
    "framework.require_rows((SELECT count(*) FROM parent_lock),'conflict')",
  )
  |> should.be_true
  string.contains(found, "COALESCE(max(existing.\"order\")+1,1)")
  |> should.be_true
  string.contains(found, "existing.album_id IS NOT DISTINCT FROM $2::uuid")
  |> should.be_true
  string.contains(
    found,
    "SELECT $1::uuid,$2::uuid,$3::uuid,$4,next_order.next_order",
  )
  |> should.be_true
}

pub fn ordered_create_lock_files_have_one_update_argument_test() {
  let relation_paths = files_of(relation_fixture)
  let relation_paths = list.map(relation_paths, fn(entry) { entry.0 })
  list.contains(relation_paths, "db/queries/verb/create_photo_lock.sql")
  |> should.be_true
  let article_paths = files_of(fixture)
  let article_paths = list.map(article_paths, fn(entry) { entry.0 })
  list.contains(article_paths, "db/queries/verb/create_articles_lock.sql")
  |> should.be_true

  let single_lock =
    text_of(relation_fixture, "db/queries/verb/create_photo_lock.sql")
  let many_lock = text_of(fixture, "db/queries/verb/create_articles_lock.sql")
  string.contains(single_lock, "UPDATE app.album SET id=id WHERE id=$1::uuid;")
  |> should.be_true
  string.contains(
    many_lock,
    "UPDATE app.category SET name=name WHERE name IN (",
  )
  |> should.be_true
  string.contains(many_lock, "SELECT DISTINCT (item->>'category')")
  |> should.be_true
  string.contains(many_lock, "ORDER BY name\n FOR UPDATE") |> should.be_true
  string.contains(single_lock, "SELECT") |> should.be_false
  string.contains(single_lock, "FOR UPDATE") |> should.be_false
  string.contains(single_lock, "$2") |> should.be_false
  string.contains(many_lock, "$2") |> should.be_false

  let flag_paths = files_of(flag_fixture)
  let flag_paths = list.map(flag_paths, fn(entry) { entry.0 })
  list.contains(flag_paths, "db/queries/verb/create_widget_lock.sql")
  |> should.be_false
  list.contains(flag_paths, "db/queries/verb/create_widgets_lock.sql")
  |> should.be_false
}

pub fn ordered_create_many_lock_requires_create_many_rule_test() {
  let relation_paths = files_of(relation_fixture)
  let relation_paths = list.map(relation_paths, fn(entry) { entry.0 })
  list.contains(relation_paths, "db/queries/verb/create_photo_lock.sql")
  |> should.be_true
  list.contains(relation_paths, "db/queries/verb/create_photos.sql")
  |> should.be_false
  list.contains(relation_paths, "db/queries/verb/create_photos_lock.sql")
  |> should.be_false
}

pub fn handwritten_create_suppresses_ordered_lock_test() {
  let paths = files_of(verb_fixture)
  let paths = list.map(paths, fn(entry) { entry.0 })
  list.contains(paths, "db/queries/verb/create_ordered_handwritten.sql")
  |> should.be_false
  list.contains(paths, "db/queries/verb/create_ordered_handwritten_lock.sql")
  |> should.be_false
}

pub fn ordered_create_many_lock_orders_parent_rows_before_update_test() {
  let many_lock = text("db/queries/verb/create_articles_lock.sql")
  string.contains(
    many_lock,
    "WITH locked AS (\n SELECT name\n FROM app.category",
  )
  |> should.be_true
  string.contains(
    many_lock,
    "ORDER BY name\n FOR UPDATE\n)\nUPDATE app.category SET name=name WHERE name IN (SELECT name FROM locked);",
  )
  |> should.be_true
  string.contains(many_lock, "ORDER BY 1") |> should.be_false
}

pub fn ordered_create_many_uses_gate_and_keeps_return_order_test() {
  let found = text("db/queries/verb/create_articles.sql")
  string.contains(found, "framework.require_rows(CASE WHEN NOT EXISTS (")
  |> should.be_true
  string.contains(found, "SELECT 1 FROM scopes AS scope") |> should.be_true
  string.contains(found, "SELECT 1 FROM parent_lock AS p") |> should.be_true
  string.contains(found, "count(scopes)") |> should.be_false
  string.contains(found, "JOIN parent_lock") |> should.be_false
  string.contains(found, "COALESCE(max(existing.\"order\")+1,0)")
  |> should.be_true
  string.contains(found, "ORDER BY numbered.ord\nRETURNING") |> should.be_true

  let no_parent = text("db/queries/verb/create_article.sql")
  string.contains(no_parent, "FOR UPDATE NOWAIT") |> should.be_true
  string.contains(
    no_parent,
    "framework.require_rows((SELECT count(*) FROM parent_lock),'conflict')",
  )
  |> should.be_true
  string.contains(no_parent, "COALESCE(max(existing.\"order\")+1,0)")
  |> should.be_true
}

pub fn ordered_create_negative_range_is_accepted_and_starts_at_zero_test() {
  let assert Ok(units) = source.load(ordered_negative_fixture)
  let assert Ok(loaded) = reader.read(units)
  list.length(loaded.entities) |> should.equal(2)
  let found =
    text_of(ordered_negative_fixture, "db/queries/verb/create_child.sql")
  string.contains(found, "COALESCE(max(existing.\"order\")+1,0)")
  |> should.be_true
}

/// Draft の欄は呼び手の入力、create SQL の呼び手入力 placeholder はその数で揃える。
/// ordered_by の採番欄を Draft に残す、または SQL 側だけ入力を増やすとこの比較が落ちる。
pub fn draft_fields_match_create_sql_placeholders_test() {
  [
    #(relation_fixture, "photo", "PhotoDraft"),
    #(fixture, "article", "ArticleDraft"),
    #(verb_fixture, "feature", "FeatureDraft"),
    #(ordered_fixture, "child", "ChildDraft"),
    #(flag_fixture, "widget", "WidgetDraft"),
  ]
  |> list.each(fn(entry) {
    let #(app_dir, module, draft_name) = entry
    let draft = text_of(app_dir, "src/gen/draft/" <> module <> ".gleam")
    let create = text_of(app_dir, "db/queries/verb/create_" <> module <> ".sql")
    draft_field_count(draft, draft_name)
    |> should.equal(create_sql_input_placeholder_count(create))
  })
}

/// CreateMany の JSON 入力は Draft の Property 名だけを読む。
/// DB 採番の order や system 入力の phase / entered_* が混ざると落ちる。
pub fn create_many_json_fields_match_draft_fields_test() {
  let draft = text("src/gen/draft/article.gleam")
  let create_many = text("db/queries/verb/create_articles.sql")
  draft_field_names(draft, "ArticleDraft")
  |> list.sort(string.compare)
  |> should.equal(
    create_many_json_field_names(create_many)
    |> list.sort(string.compare),
  )
  string.contains(create_many, "item->>'order'") |> should.be_false
  string.contains(create_many, "'draft',$2::timestamptz") |> should.be_true
  let verb = text("src/gen/verb.gleam")
  string.contains(verb, "  at: Datetime,") |> should.be_true
  string.contains(verb, "stage(ctx, \"create_articles\", #(input, at))")
  |> should.be_true
}

/// gen-3b(P0-3)── 退避の一時値は負値でなく、**宣言の値域の上端から下へ、範囲に無い値**を選ぶ。
/// `Int` は int4 の全域、確定値は 0 から。範囲は FOR UPDATE で押さえる。
pub fn reorder_stage_picks_free_values_inside_declared_int_bounds_test() {
  let stage = text("db/queries/verb/reorder_articles_stage.sql")
  string.contains(stage, "FROM app.article e WHERE e.category_id=$1 FOR UPDATE")
  |> should.be_true
  string.contains(
    stage,
    "generate_series(2147483647::bigint,GREATEST(-2147483648::bigint,"
      <> "2147483647::bigint-(c.held+2*c.expected)),-1)",
  )
  |> should.be_true
  string.contains(
    stage,
    "WHERE NOT EXISTS (SELECT 1 FROM scope s WHERE s.current=candidate)",
  )
  |> should.be_true
  string.contains(
    stage,
    "AND candidate NOT BETWEEN 0::bigint AND 0::bigint+c.expected-1",
  )
  |> should.be_true
  string.contains(
    stage,
    "AND (SELECT count(*) FROM free)=(SELECT expected FROM counts)",
  )
  |> should.be_true
  string.contains(stage, "'conflict'") |> should.be_true
  let apply = text("db/queries/verb/reorder_articles.sql")
  string.contains(apply, "(0+ord-1)::integer AS new_order") |> should.be_true
}

/// gen-3b(P0-3)── `Range(min: 1, max: 10)` の順序列は、一時値が 10 から下へ、確定値が 1 から。
pub fn reorder_uses_range_bounds_of_the_order_type_test() {
  let stage =
    text_of(relation_fixture, "db/queries/verb/reorder_photos_stage.sql")
  string.contains(
    stage,
    "generate_series(10::bigint,GREATEST(1::bigint,10::bigint-(c.held+2*c.expected)),-1)",
  )
  |> should.be_true
  string.contains(
    stage,
    "AND candidate NOT BETWEEN 1::bigint AND 1::bigint+c.expected-1",
  )
  |> should.be_true
  string.contains(
    stage,
    "FROM app.photo e WHERE e.album_id=$1::uuid FOR UPDATE",
  )
  |> should.be_true
  let apply = text_of(relation_fixture, "db/queries/verb/reorder_photos.sql")
  string.contains(apply, "(1+ord-1)::integer AS new_order") |> should.be_true
  string.contains(apply, "SELECT value::uuid AS id") |> should.be_true
}

/// gen-3b(P0-3)── 順序列が整数でない宣言、Option の宣言は名指しで止まる(exit 4)。
pub fn reorder_on_non_integer_order_is_exit_four_test() {
  let error = reader_error(relation_text_order_fixture)
  case error {
    reader.Unsupported(where: where, detail: detail) -> {
      where |> should.equal("entity/photo")
      stop.code(stop.Conflict) |> should.equal(4)
      string.contains(detail, "ordered_by.field が整数の列でない: caption")
      |> should.be_true
    }
    _ -> should.fail()
  }
}

pub fn reorder_on_optional_order_is_exit_four_test() {
  let error = reader_error(relation_option_order_fixture)
  case error {
    reader.Unsupported(where: where, detail: detail) -> {
      where |> should.equal("entity/photo")
      string.contains(detail, "ordered_by.field が Option の列: order")
      |> should.be_true
    }
    _ -> should.fail()
  }
}

/// gen-3b ── Range の両端は types.gleam から読む(桁区切り `_` も)。
pub fn value_type_range_bounds_are_read_test() {
  let assert Ok(units) = source.load(relation_fixture)
  let assert Ok(loaded) = reader.read(units)
  let assert Some(order) =
    model.value_type_by_name(loaded.value_types, "PhotoOrder")
  order.range |> should.equal(Some(#(1, 10)))
  let assert Some(title) =
    model.value_type_by_name(loaded.value_types, "AlbumTitle")
  title.range |> should.equal(None)
}

pub fn lifecycle_steps_are_entity_qualified_test() {
  let phase = text_of(phase_collision_fixture, "src/gen/phase.gleam")
  string.contains(phase, "pub type FanStep {\n  FanOnboardedToRetiring\n}")
  |> should.be_true
  string.contains(phase, "pub type MuseStep {\n  MuseOnboardedToRetiring\n}")
  |> should.be_true
  string.contains(phase, "\n  OnboardedToRetiring\n") |> should.be_false
  string.contains(phase, "FanOnboardedToRetiring -> fan.Onboarded")
  |> should.be_true
  string.contains(phase, "MuseOnboardedToRetiring -> muse.Onboarded")
  |> should.be_true

  let verb = text_of(phase_collision_fixture, "src/gen/verb.gleam")
  string.contains(
    verb,
    "pub fn advance_fan(\n  id: String,\n  step: FanStep,\n)",
  )
  |> should.be_true
  string.contains(
    verb,
    "pub fn advance_muse(\n  id: String,\n  step: MuseStep,\n)",
  )
  |> should.be_true
}

pub fn advance_sql_has_no_service_argument_test() {
  let found = text("db/queries/verb/advance_article.sql")
  string.contains(found, "CASE WHEN $3='scheduled' AND $4='draft' THEN 0")
  |> should.be_true
  string.contains(found, "$5") |> should.be_true
  string.contains(found, "$6") |> should.be_false
  [
    "article_create",
    "article_publish",
    "article_retract",
    "article_list",
  ]
  |> list.each(fn(service) {
    string.contains(found, service) |> should.be_false
  })
}

pub fn verb_sql_uses_entity_only_headers_test() {
  files()
  |> list.filter(fn(entry) { string.starts_with(entry.0, "db/queries/verb/") })
  |> list.each(fn(entry) {
    string.starts_with(entry.1, "-- GENERATED from entity.")
    |> should.be_true
    string.contains(entry.1, "service.")
    |> should.be_false
  })
}

pub fn composite_key_is_present_in_signature_where_and_returning_test() {
  let update = text_of(flag_fixture, "db/queries/verb/update_chunk_text.sql")
  let delete = text_of(flag_fixture, "db/queries/verb/delete_chunk.sql")
  string.contains(update, "WHERE a=$1 AND b=$2 AND c=$3")
  |> should.be_true
  string.contains(update, "RETURNING a,b,c") |> should.be_true
  string.contains(delete, "WHERE a=$1 AND b=$2 AND c=$3")
  |> should.be_true
  string.contains(delete, "RETURNING") |> should.be_false
  let verb = text_of(flag_fixture, "src/gen/verb.gleam")
  string.contains(
    verb,
    "pub fn update_chunk_text(\n  a: Int,\n  b: Int,\n  c: Int,",
  )
  |> should.be_true
}

pub fn draft_keeps_input_keys_and_create_sql_arguments_test() {
  let chunk = text_of(flag_fixture, "src/gen/draft/chunk.gleam")
  string.contains(chunk, "ChunkDraft(\n    a: Int,\n    b: Int,\n    c: Int,")
  |> should.be_true
  let create = text_of(flag_fixture, "db/queries/verb/create_chunk.sql")
  string.contains(
    create,
    "INSERT INTO app.chunk(a,b,c,text)\nVALUES($1,$2,$3,$4)",
  )
  |> should.be_true

  let article = text("src/gen/draft/article.gleam")
  string.contains(article, "ArticleDraft(\n    slug: Slug,") |> should.be_true
  let article_create = text("db/queries/verb/create_article.sql")
  string.contains(
    article_create,
    "INSERT INTO app.article(slug,title,body,version,\"order\",category_id,phase,entered_draft)",
  )
  |> should.be_true
}

pub fn auto_key_is_excluded_only_by_explicit_declaration_test() {
  let draft = text_of(flag_fixture, "src/gen/draft/widget.gleam")
  string.contains(draft, "WidgetDraft(\n    name: WidgetName,")
  |> should.be_true
  string.contains(draft, "WidgetDraft(\n    id: WidgetId") |> should.be_false
  let created = text_of(flag_fixture, "db/queries/verb/create_widget.sql")
  string.contains(
    created,
    "INSERT INTO app.widget(name,place,visible,\"order\")",
  )
  |> should.be_true
}

fn reader_error(app_dir: String) -> reader.Error {
  let assert Ok(units) = source.load(app_dir)
  let assert Error(error) = reader.read(units)
  error
}

fn draft_field_count(source: String, draft_name: String) -> Int {
  count_draft_fields(
    string.split(source, "\n"),
    "  " <> draft_name <> "(",
    False,
    0,
  )
}

fn draft_field_names(source: String, draft_name: String) -> List(String) {
  collect_draft_field_names(
    string.split(source, "\n"),
    "  " <> draft_name <> "(",
    False,
    [],
  )
}

fn collect_draft_field_names(
  lines: List(String),
  marker: String,
  inside: Bool,
  found: List(String),
) -> List(String) {
  case lines {
    [] -> list.reverse(found)
    [line, ..rest] ->
      case inside {
        False ->
          case line == marker {
            True -> collect_draft_field_names(rest, marker, True, [])
            False -> collect_draft_field_names(rest, marker, False, found)
          }
        True ->
          case line == "  )" {
            True -> list.reverse(found)
            False ->
              case string.split(string.trim(line), ":") {
                [name, ..] ->
                  collect_draft_field_names(rest, marker, True, [name, ..found])
                _ -> collect_draft_field_names(rest, marker, True, found)
              }
          }
      }
  }
}

fn create_many_json_field_names(sql: String) -> List(String) {
  case string.split(sql, "item->>'") {
    [_prefix, ..pieces] ->
      pieces
      |> list.filter_map(fn(piece) {
        case string.split(piece, "'") {
          [name, ..] -> Ok(name)
          _ -> Error(Nil)
        }
      })
      |> list.unique
    _ -> []
  }
}

fn count_draft_fields(
  lines: List(String),
  marker: String,
  inside: Bool,
  count: Int,
) -> Int {
  case lines {
    [] -> count
    [line, ..rest] ->
      case inside {
        False ->
          case line == marker {
            True -> count_draft_fields(rest, marker, True, 0)
            False -> count_draft_fields(rest, marker, False, count)
          }
        True ->
          case line == "  )" {
            True -> count
            False -> count_draft_fields(rest, marker, True, count + 1)
          }
      }
  }
}

fn create_sql_input_placeholder_count(sql: String) -> Int {
  let assert Ok(values) =
    sql
    |> string.split("\n")
    |> list.find(fn(line) {
      string.contains(line, "SELECT $1") || string.contains(line, "VALUES($1")
    })
  // 呼び手の入力は最初の文字列 literal(初期の相 `'<phase>'`)より前。相の綴りに依らない。
  let input_values = case string.split(values, "'") {
    [before, ..] -> before
    [] -> values
  }
  let pieces = string.split(input_values, "$")
  list.length(pieces) - 1
}

pub fn advance_all_is_exit_five_with_reason_test() {
  let error = reader_error(advance_all_fixture)
  case error {
    reader.Vocabulary(where: where, detail: detail) -> {
      where |> should.equal("entity/bulk")
      stop.code(stop.Vocabulary) |> should.equal(5)
      string.contains(detail, "System Service") |> should.be_true
    }
    _ -> should.fail()
  }
}

pub fn delete_where_parent_is_exit_four_test() {
  let error = reader_error(parent_delete_fixture)
  case error {
    reader.Unsupported(where: where, detail: detail) -> {
      where |> should.equal("entity/child")
      stop.code(stop.Conflict) |> should.equal(4)
      string.contains(detail, "親の列") |> should.be_true
    }
    _ -> should.fail()
  }
}

pub fn no_key_entity_keeps_create_only_test() {
  let verb = text_of(no_key_fixture, "src/gen/verb.gleam")
  string.contains(verb, "pub fn create_no_key(") |> should.be_true
  string.contains(verb, "pub fn update_no_key_") |> should.be_false
  string.contains(verb, "pub fn delete_no_key") |> should.be_false
  string.contains(verb, "pub fn advance_no_key") |> should.be_false

  let create = text_of(no_key_fixture, "db/queries/verb/create_no_key.sql")
  string.contains(create, "INSERT INTO app.no_key") |> should.be_true
  string.contains(create, "RETURNING name,value")
  |> should.be_true
}

pub fn no_key_generation_writes_bundles_and_reports_entity_test() {
  let paths = list.map(files_of(no_key_fixture), fn(entry) { entry.0 })
  [
    "src/gen/types/no_key_name.gleam",
    "src/gen/query.gleam",
    "src/gen/query/from.gleam",
    "src/gen/query/field.gleam",
    "src/gen/phase.gleam",
    "src/gen/verb.gleam",
    "db/queries/verb/create_no_key.sql",
    "src/gen/root/path_only_lookup.gleam",
    "_diagnostics.txt",
  ]
  |> list.each(fn(path) { list.contains(paths, path) |> should.be_true })

  let notes = notes_of(no_key_fixture)
  list.length(notes) |> should.equal(2)
  stop.worst(notes) |> should.equal(3)
  notes
  |> list.any(fn(note) {
    note.class == stop.Missing
    && string.contains(note.text, "entity/no_key")
    && string.contains(note.text, "key")
  })
  |> should.be_true
}

pub fn path_key_is_used_for_keyed_verbs_test() {
  let verb = text_of(no_key_fixture, "src/gen/verb.gleam")
  string.contains(verb, "pub fn update_path_only_value(") |> should.be_true
  string.contains(verb, "pub fn delete_path_only(") |> should.be_true
  notes_of(no_key_fixture)
  |> list.any(fn(note) {
    string.contains(note.text, "path_only")
    && string.contains(note.text, "key 関数が無い")
  })
  |> should.be_false
}

pub fn path_key_is_used_for_root_lookup_test() {
  let found = text_of(no_key_fixture, "src/gen/root/path_only_lookup.gleam")
  string.contains(found, "path_only: path_only.PathOnly") |> should.be_true
  string.contains(found, "logic: fn(path_only.PathOnly, Root, args)")
  |> should.be_true
}

pub fn root_module_mismatch_is_a_nonblocking_warning_test() {
  let paths = list.map(files_of(root_warning_fixture), fn(entry) { entry.0 })
  list.contains(paths, "src/gen/root/store_check.gleam") |> should.be_true
  let found = text_of(root_warning_fixture, "src/gen/root/store_check.gleam")
  string.contains(found, "widget: widget.Widget") |> should.be_true
  let notes = notes_of(root_warning_fixture)
  list.length(notes) |> should.equal(2)
  stop.worst(notes) |> should.equal(4)
  notes
  |> list.any(fn(note) {
    note.class == stop.Warning
    && string.contains(note.text, "store_check")
    && string.contains(note.text, "widget")
  })
  |> should.be_true
  notes
  |> list.any(fn(note) {
    note.class == stop.Conflict
    && string.contains(note.text, "store_check")
    && string.contains(note.text, "対象が無い")
  })
  |> should.be_true
}

// ── header の入力ハッシュ(20 の規約①、柏木 P2-5) ────────────────────────────

pub fn every_header_carries_the_input_hash_test() {
  files()
  |> list.each(fn(entry) {
    let #(path, found) = entry
    case string.contains(path, "_diagnostics") {
      True -> Nil
      False -> {
        string.contains(found, " [sha256:") |> should.be_true
        Nil
      }
    }
  })
}

pub fn the_hash_is_twelve_hex_and_input_shaped_test() {
  digest.short("a") |> string.length |> should.equal(12)
  { digest.short("a") == digest.short("b") } |> should.be_false
  { digest.short("a") == digest.short("a") } |> should.be_true
}

pub fn types_and_entities_hash_differ_test() {
  let assert Ok(units) = source.load(fixture)
  let hashes = hash.of(units)
  { hashes.types == hashes.entities } |> should.be_false
  // Service ごとの入力は Service + types + entity なので、Service ごとに違う。
  {
    hash.service(hashes, "article_list") == hash.service(hashes, "article_read")
  }
  |> should.be_false
}

// ── 旗の列と「穴が NULL」── fixtures/flag(20:710 の IsTrue / EqOrNull) ───────

pub fn is_true_and_eq_or_null_become_sql_test() {
  let found = text_of(flag_fixture, "db/queries/widget_list/shown.sql")
  string.contains(found, "w.visible IS TRUE") |> should.be_true
  string.contains(found, "w.place IS NOT DISTINCT FROM $1") |> should.be_true
  // 2つは AND で交わる。穴は1つだけ(IsTrue は穴を取らない)。
  string.contains(
    found,
    "WHERE w.visible IS TRUE AND w.place IS NOT DISTINCT FROM $1",
  )
  |> should.be_true
  string.contains(found, "$2") |> should.be_false
}

pub fn eq_or_null_param_is_optional_test() {
  let found = text_of(flag_fixture, "src/gen/reads/widget_list.gleam")
  // 穴が NULL になりうるので Option。列の基底型は WidgetPlace。
  string.contains(found, "place place: Option(WidgetPlace),") |> should.be_true
}

pub fn empty_order_falls_back_to_the_key_test() {
  let found = text_of(flag_fixture, "db/queries/widget_list/all.sql")
  string.contains(found, "ORDER BY w.id ASC") |> should.be_true
}

pub fn optional_column_asc_gets_nulls_last_test() {
  let found = text_of(flag_fixture, "db/queries/widget_list/first_place.sql")
  string.contains(found, "ORDER BY w.place ASC NULLS LAST,w.id ASC")
  |> should.be_true
  string.contains(found, "LIMIT 1") |> should.be_true
}

pub fn first_one_returns_option_and_agg_returns_option_test() {
  let found = text_of(flag_fixture, "src/gen/reads/widget_list.gleam")
  string.contains(found, "fn(Option(widget.Widget))") |> should.be_true
  // Max の戻りは対象 Property の Type をそのまま引き継いだ Option。
  string.contains(found, "fn(Option(Int))") |> should.be_true
}

// ── 向きの混じった keyset は SQL を出して停止しない(G1) ────────────────

pub fn mixed_direction_keyset_is_generated_test() {
  let paths = list.map(files_of(flag_fixture), fn(entry) { entry.0 })
  // mixed order でも SQL と reads が両方出る。
  list.contains(paths, "src/gen/reads/widget_page.gleam") |> should.be_true
  list.contains(paths, "db/queries/widget_page/paged.sql")
  |> should.be_true
  list.contains(paths, "_diagnostics.txt") |> should.be_false
  let found = text_of(flag_fixture, "db/queries/widget_page/paged.sql")
  string.contains(
    found,
    "($3 IS NOT NULL AND (w.place IS NULL OR (w.place IS NOT NULL AND w.place>$3::integer)))",
  )
  |> should.be_true
  string.contains(found, "COALESCE(w.place,2147483647)") |> should.be_false
  string.contains(found, "IS NOT DISTINCT FROM") |> should.be_true
  string.contains(found, "w.name<$4::text") |> should.be_true
}

pub fn mixed_direction_keyset_has_no_generator_note_test() {
  let notes = notes_of(flag_fixture)
  notes |> should.equal([])
  stop.worst(notes) |> should.equal(0)
}

pub fn a_clean_app_has_no_notes_test() {
  notes_of(fixture) |> should.equal([])
  stop.worst([]) |> should.equal(0)
}

pub fn escalating_notes_win_over_generator_notes_test() {
  // 人へ上げる側(5 / 6)を先に返す。CI は exit code だけを見て振り分ける。
  stop.worst([
    stop.Note(class: stop.NotImplemented, text: "x"),
    stop.Note(class: stop.Vocabulary, text: "y"),
  ])
  |> should.equal(5)
  stop.worst([
    stop.Note(class: stop.Conflict, text: "x"),
    stop.Note(class: stop.Missing, text: "y"),
  ])
  |> should.equal(4)
  stop.worst([stop.Note(class: stop.Irreversible, text: "x")])
  |> should.equal(6)
  stop.worst([stop.Note(class: stop.NotImplemented, text: "x")])
  |> should.equal(1)
}

// ── 段A: 面の発見と front model ─────────────────────────────────────────────

pub fn face_selection_requires_package_and_layout_and_is_shallow_test() {
  let selected =
    face.select([face.HttpEntry(name: "public", pages: face.UndeclaredPages)], [
      face.Candidate(
        name: "public",
        path: "public",
        has_package: True,
        has_layout: True,
      ),
      face.Candidate(
        name: "no_package",
        path: "no_package",
        has_package: False,
        has_layout: True,
      ),
      face.Candidate(
        name: "no_layout",
        path: "no_layout",
        has_package: True,
        has_layout: False,
      ),
    ])
  list.length(selected.packages) |> should.equal(1)
  let assert [candidate] = selected.packages
  candidate.name |> should.equal("public")
  selected.notes |> should.equal([])
}

pub fn http_api_does_not_create_a_face_test() {
  let unit =
    source_unit(
      "entry",
      "pub const entries = [HttpApi(name: \"api\", pages: AllPages)]",
    )
  face.http_entries([unit]) |> should.equal([])
}

pub fn missing_all_pages_folder_and_orphan_folder_are_missing_test() {
  let selected =
    face.select([face.HttpEntry(name: "public", pages: face.AllPages)], [
      face.Candidate(
        name: "ghost",
        path: "ghost",
        has_package: True,
        has_layout: True,
      ),
    ])
  stop.worst(selected.notes) |> should.equal(3)
  selected.notes
  |> list.map(fn(note) { note.text })
  |> should.equal([
    "entry.public: フォルダの無い Http 入口",
    "face.ghost: 入口の無いフォルダ",
  ])
}

pub fn undeclared_pages_and_no_pages_do_not_make_missing_notes_test() {
  let candidates = [
    face.Candidate(
      name: "public",
      path: "public",
      has_package: True,
      has_layout: True,
    ),
  ]
  face.select(
    [face.HttpEntry(name: "public", pages: face.UndeclaredPages)],
    candidates,
  ).notes
  |> should.equal([])
  face.select([face.HttpEntry(name: "public", pages: face.NoPages)], []).notes
  |> should.equal([])
}

pub fn front_model_reads_url_blocks_widgets_components_and_style_test() {
  let value = article_front()
  let assert Ok(page) =
    list.find(value.pages, fn(page) {
      page.module == "pages/article/arg_slug/page"
    })
  page.url |> should.equal("/article/{slug}")
  page.of |> should.equal(Some("ArticleRead"))
  list.map(value.blocks, fn(block) { block.name })
  |> should.equal([
    "Article",
    "Feed",
    "Notice",
    "RowArticle",
    "RowSummary",
    "SiteHeader",
    "Summary",
  ])
  value.services
  |> should.equal([
    "WidgetList",
    "ArticleRead",
    "ArticleBlobSave",
    "ArticlePublish",
    "ArticleCreate",
    "ArticleList",
  ])
  let assert Ok(page_args) =
    list.find(value.page_service_args, fn(page_args) {
      page_args.page == page.module
    })
  let assert Ok(widget_args) =
    list.find(page_args.services, fn(service) {
      service.service == "widget_list"
    })
  widget_args.args
  |> should.equal([
    front.ResolvedArg(
      name: "widget",
      source: front.VariableSource(name: "widget", from: front.Query("widget")),
    ),
    front.ResolvedArg(
      name: "slug",
      source: front.VariableSource(name: "slug", from: front.Path("slug")),
    ),
  ])
  let assert Ok(article_args) =
    list.find(page_args.services, fn(service) {
      service.service == "article_read"
    })
  article_args.args
  |> should.equal([
    front.ResolvedArg(
      name: "slug",
      source: front.VariableSource(name: "slug", from: front.Path("slug")),
    ),
  ])
  value.style.tokens
  |> should.equal([
    "ink",
    "paper",
    "accent",
    "muted",
    "body",
    "heading",
    "s0",
    "s1",
    "s2",
    "s3",
    "sp",
    "pc",
    "tablet",
    "bar",
    "page",
  ])
  let assert [media] = value.style.media_variants
  media.0 |> should.equal("MediaVariant")
  media.1 |> should.equal(["Thumb", "W800", "W1600", "Cast"])
  value.blocks
  |> list.map(fn(block) { block.has_sample })
  |> should.equal([True, True, False, True, True, False, True])
  value.components
  |> list.map(fn(component) { component.after_send })
  |> should.equal([None, None, Some("Stay"), Some("ReloadPage")])
}

pub fn front_emit_overlay_area_and_badge_use_generator_css_test() {
  let page = text("public/src/gen/load/article/arg_slug/page.gleam")
  [
    "overlay_area(\"article-dialog\", [],",
    "attribute.attribute(\"id\", el.overlay_id_prefix <> name)",
    "attribute.attribute(\"popover\", \"\")",
    "attribute.attribute(\"data-yumemi-overlay\", \"\")",
  ]
  |> list.each(fn(row) { string.contains(page, row) |> should.be_true })

  let css = text("public/priv/static/_yumemi/style.css")
  [
    "grid-template-areas: \"page\" \"rail\";",
    "[data-yumemi-badge] {",
    "position: absolute;",
    "[data-yumemi-badge][data-count=\"\"]",
    "[data-yumemi-badge][data-count=\"0\"] { display: none; }",
    "[popover]::backdrop { background: rgba(0, 0, 0, 0.45); }",
  ]
  |> list.each(fn(row) { string.contains(css, row) |> should.be_true })
  string.contains(css, "article-dialog") |> should.be_false
}

pub fn front_overlay_missing_area_opener_is_exit_four_test() {
  let notes =
    overlay_negative_notes(
      "missing_area",
      "Area(name: \"page\", flow: css.Stack(gap: css.Px(0.0)), pin: css.NoPin, style: [])",
      "Fixed(area: \"page\", block: blocks.Open, cell: Flow)",
      "[]",
    )
  assert_overlay_exit_four(
    notes,
    "el.opener が同じ Page / Layout に無い area \"missing-dialog\" を名指している",
  )
}

pub fn front_overlay_non_overlay_area_opener_is_exit_four_test() {
  let notes =
    overlay_negative_notes(
      "non_overlay_area",
      "Area(name: \"page\", flow: css.Stack(gap: css.Px(0.0)), pin: css.NoPin, style: []), Area(name: \"plain-dialog\", flow: css.Stack(gap: css.Px(0.0)), pin: css.NoPin, style: [])",
      "Fixed(area: \"page\", block: blocks.Open, cell: Flow)",
      "[]",
    )
  assert_overlay_exit_four(
    notes,
    "el.opener の area \"plain-dialog\" は pin: Overlay ではない",
  )
}

pub fn front_overlay_dynamic_opener_area_is_exit_four_test() {
  let notes =
    overlay_negative_notes(
      "dynamic_area",
      "Area(name: \"page\", flow: css.Stack(gap: css.Px(0.0)), pin: css.NoPin, style: []), Area(name: \"article-dialog\", flow: css.Stack(gap: css.Px(0.0)), pin: css.Overlay, style: [])",
      "Fixed(area: \"page\", block: blocks.Open, cell: Flow)",
      "[]",
    )
  assert_overlay_exit_four(notes, "el.opener の area は文字列リテラルでなければならない")
}

pub fn front_overlay_explicit_template_is_exit_four_test() {
  let assert Ok(fixture_units) =
    source.load(front_overlay_negative_fixture <> "/explicit_template")
  let units =
    list.append(
      [source_unit("layout", overlay_negative_layout())],
      fixture_units,
    )
  let notes = front.notes(front_from_units_named("negative", units, []), [])
  assert_overlay_exit_four(
    notes,
    "明示 template に Overlay area \"article-dialog\" を指定できない",
  )
}

pub fn front_overlay_dynamic_each_modal_scope_is_exit_four_test() {
  let notes =
    overlay_negative_notes(
      "dynamic_scope",
      "Area(name: \"page\", flow: css.Stack(gap: css.Px(0.0)), pin: css.NoPin, style: [])",
      "Fixed(area: \"page\", block: blocks.Listing, cell: Flow)",
      "[]",
    )
  assert_overlay_exit_four(notes, "el.each_modal の scope は文字列リテラルでなければならない")
}

pub fn front_overlay_duplicate_each_modal_scope_is_exit_four_test() {
  let notes =
    overlay_negative_notes(
      "duplicate_scope",
      "Area(name: \"page\", flow: css.Stack(gap: css.Px(0.0)), pin: css.NoPin, style: [])",
      "Fixed(area: \"page\", block: blocks.First, cell: Flow), Fixed(area: \"page\", block: blocks.Second, cell: Flow)",
      "[]",
    )
  assert_overlay_exit_four(
    notes,
    "el.each_modal の scope \"shared-row\" が同じ Page + Layout 内で重複している",
  )
}

pub fn front_emit_route_uses_page_only_and_colon_arguments_test() {
  let route = text("public/src/gen/route.gleam")
  string.contains(route, "PageRoute(path: \"/article/:slug\")")
  |> should.be_true
  string.contains(route, "Route(service:") |> should.be_false
}

pub fn front_route_path_keeps_arg_dash_and_reserved_rules_test() {
  front.route_path(["arg_case_", "_", "type_"])
  |> should.equal("/:case/-/type")
}

pub fn front_emit_api_is_filtered_by_face_services_test() {
  let api =
    api_for_entry(
      "import framework/entry.{type Entry, Anonymous, AnySubject, Http, ReadOnly}\n\npub type Subject {\n  Staff\n}\n\npub type Host {\n  PublicHost\n}\n\npub const entries: List(Entry(Subject, Host)) = [\n  Http(name: \"public\", hosts: [PublicHost], prefix: \"/api\", admit: Anonymous, subject: AnySubject, services: ReadOnly),\n]",
    )
  [
    "service.ArticleList",
    "service.ArticleRead",
    "service.WidgetList",
    "path: \"/api/articles/:slug\"",
  ]
  |> list.each(fn(row) { string.contains(api, row) |> should.be_true })
  ["service.ArticleCreate", "service.ArticlePublish", "service.ArticleRetract"]
  |> list.each(fn(row) { string.contains(api, row) |> should.be_false })
  string.contains(api, "import framework/front as front") |> should.be_true
  string.contains(api, "pub type Attached {") |> should.be_true
  string.contains(api, "  BlobCopy") |> should.be_true
  string.contains(
    api,
    "pub type Target = front.Target(service.Service, Attached)",
  )
  |> should.be_true
  string.contains(api, "pub type AttachedRoute {") |> should.be_true
  string.contains(api, "pub const attached: List(AttachedRoute) = [")
  |> should.be_true
  string.contains(api, "  Of(service.Service)") |> should.be_false
  string.contains(api, "  Entry(Attached)") |> should.be_false
}

pub fn attached_runtime_table_matches_generated_face_api_test() {
  let assert Ok(runtime) =
    simplifile.read("fixtures/article/api/src/gen/http_runtime.mjs")
  let api = text("public/src/gen/api.gleam")
  let runtime_rows =
    runtime |> string.split("name:'") |> list.length |> int.subtract(1)
  let face_rows =
    api
    |> string.split("AttachedRoute(entry:")
    |> list.length
    |> int.subtract(1)
    |> int.subtract(1)
  runtime_rows |> should.equal(3)
  face_rows |> should.equal(runtime_rows)
  [
    "AttachedRoute(entry: FixtureBrowser, method: Get, path: \"/fixture/browser\")",
    "AttachedRoute(entry: FixtureSync, method: Post, path: \"/fixture/sync\")",
    "AttachedRoute(entry: BlobCopy, method: Post, path: \"/api/blobs\")",
  ]
  |> list.each(fn(route) { string.contains(api, route) |> should.be_true })
}

pub fn front_emit_live_contains_literal_transport_route_and_decoder_test() {
  let live = text("public/src/gen/live/article_publish.gleam")
  string.contains(live, "transport_send(") |> should.be_true
  string.contains(live, "\"POST\"") |> should.be_true
  string.contains(live, "\"/api/articles/\" <> args.slug <> \"/publish\"")
  |> should.be_true
  string.contains(live, "article_publish.decoder()") |> should.be_true

  let out = text("public/src/gen/out/article_list.gleam")
  string.contains(out, "pub fn decoder() -> decode.Decoder(Out)")
  |> should.be_true
  string.contains(out, "decode.field(\"counts\"") |> should.be_true
}

pub fn front_emit_live_send_runs_validate_test() {
  let live = text("public/src/gen/live/article_create.gleam")
  string.contains(live, "live.Send ->\n      case model.waiting")
  |> should.be_true
  string.contains(live, "case validate(model) {") |> should.be_true
  string.contains(
    live,
    "Ok(args) -> #(live.State(..model, waiting: True), send(args))",
  )
  |> should.be_true
  string.contains(live, "pub fn validate(model: State)") |> should.be_true
}

pub fn front_emit_validate_errors_name_the_failed_constraint_test() {
  let live = text("public/src/gen/live/article_create.gleam")
  [
    "must contain 1 to 64 characters and match /^[a-z0-9]+(-[a-z0-9]+)*$/",
    "must contain 1 to 120 characters",
    "must be valid Markdown",
    "Error(_) -> [#(field, message)]",
  ]
  |> list.each(fn(row) { string.contains(live, row) |> should.be_true })
  string.contains(live, "#(field, \"invalid\")") |> should.be_false

  let publish = text("public/src/gen/live/article_publish.gleam")
  string.contains(
    publish,
    "must contain 1 to 64 characters and match /^[a-z0-9]+(-[a-z0-9]+)*$/",
  )
  |> should.be_true
  string.contains(publish, "#(field, \"invalid\")") |> should.be_false
}

pub fn front_emit_shell_carries_language_title_and_theme_test() {
  let page = text("public/src/gen/load/article/arg_slug/page.gleam")
  [
    "attribute.attribute(\"lang\", \"ja\")",
    "raw_html.title([], \"yumemi front fixture\")",
    "option_string(background, \"#FAF7F0\")",
    "option_string(text, \"#3D2419\")",
    "option_string(accent, \"#A93632\")",
    "option_background(background_image)",
  ]
  |> list.each(fn(row) { string.contains(page, row) |> should.be_true })
}

pub fn front_emit_shell_includes_viewport_meta_test() {
  let page = text("public/src/gen/load/article/arg_slug/page.gleam")
  string.contains(page, "attribute.attribute(\"name\", \"viewport\")")
  |> should.be_true
  string.contains(
    page,
    "attribute.attribute(\"content\", \"width=device-width, initial-scale=1, viewport-fit=cover\")",
  )
  |> should.be_true
}

pub fn front_emit_blocks_preview_places_layout_blocks_by_area_test() {
  let files =
    synthetic_front_files_with_layout(
      "Layout(\n"
      <> "  sp: Frame(areas: [], placements: [], cols: [], rows: [], template: []),\n"
      <> "  pc: Some(Frame(\n"
      <> "    areas: [\n"
      <> "      Area(name: \"header\", flow: css.Stack(gap: style.s0), pin: css.Top, style: []),\n"
      <> "      Area(name: \"nav\", flow: css.Stack(gap: style.s0), pin: css.NoPin, style: []),\n"
      <> "      Area(name: \"footer\", flow: css.Stack(gap: style.s0), pin: css.Bottom, style: []),\n"
      <> "    ],\n"
      <> "    placements: [\n"
      <> "      Fixed(area: \"header\", block: blocks.SiteHeader, cell: Flow),\n"
      <> "      Fixed(area: \"nav\", block: blocks.Feed, cell: Flow),\n"
      <> "      Fixed(area: \"footer\", block: blocks.Summary, cell: Flow),\n"
      <> "    ],\n"
      <> "    cols: [],\n"
      <> "    rows: [],\n"
      <> "    template: [],\n"
      <> "  )),\n"
      <> "  tablet: None,\n"
      <> "  vars: [],\n"
      <> ")",
    )
  let assert Ok(#(_, preview)) =
    list.find(files, fn(file) {
      file.0 == "public/src/gen/blocks_preview.gleam"
    })
  [
    "html.header_([attribute.attribute(\"data-yumemi-area\", \"header\")], [",
    "site_header.view(Nil)",
    "html.nav_([attribute.attribute(\"data-yumemi-area\", \"nav\")], [",
    "feed.view(feed.sample)",
    "html.footer_([attribute.attribute(\"data-yumemi-area\", \"footer\")], [",
    "summary.view(summary.sample, summary.Arg(slug: \"preview\"))",
  ]
  |> list.each(fn(row) { string.contains(preview, row) |> should.be_true })
  ["el.text(\"header\")", "el.text(\"nav\")", "el.text(\"footer\")"]
  |> list.each(fn(row) { string.contains(preview, row) |> should.be_false })

  let fixture_preview = text("public/src/gen/blocks_preview.gleam")
  string.contains(fixture_preview, "site_header.view(Nil)") |> should.be_true
  string.contains(fixture_preview, "el.text(\"header\")") |> should.be_false
}

pub fn front_emit_blocks_preview_defaults_imported_service_out_and_page_imports_only_referenced_blocks_test() {
  let assert Ok(face_units) = source.load("fixtures/article/public")
  let face_units =
    face_units
    |> list.filter(fn(unit) {
      unit.path != "layout" && unit.path != "blocks/article"
    })
    |> list.append([
      source_unit(
        "layout",
        layout_source(
          "Layout(sp: Frame(areas: [Area(name: \"page\", flow: css.Stack(gap: style.s0), pin: css.NoPin, style: [])], placements: [Fixed(area: \"page\", block: blocks.Article, cell: Flow)], cols: [], rows: [], template: []), pc: None, tablet: None, vars: [])",
        ),
      ),
      source_unit(
        "blocks/article",
        "import framework/front/el\n"
          <> "import gen/out/article_read\n"
          <> "pub type In = article_read.Out\n"
          <> "pub fn view(it: In) -> el.Element(Nil) {\n"
          <> "  el.text(it.article.slug)\n}",
      ),
      source_unit(
        "blocks/orphan",
        "import framework/front/el\n"
          <> "pub type In = Nil\n"
          <> "pub fn view(_it: In) -> el.Element(Nil) { el.text(\"orphan\") }",
      ),
    ])
  let assert Ok(#(_, preview)) =
    synthetic_front_files(face_units)
    |> list.find(fn(file) { file.0 == "public/src/gen/blocks_preview.gleam" })
  string.contains(preview, "article.view(article_read.Out(")
  |> should.be_true
  string.contains(preview, "article.view(Nil)") |> should.be_false
  let assert Ok(#(_, page)) =
    synthetic_front_files(face_units)
    |> list.find(fn(file) {
      file.0 == "public/src/gen/load/article/arg_slug/page.gleam"
    })
  string.contains(page, "import blocks/article") |> should.be_true
  string.contains(page, "import blocks/orphan") |> should.be_false
  string.contains(page, "import framework/front/el") |> should.be_true
}

pub fn front_emit_blob_theme_wraps_image_in_quoted_css_url_test() {
  let files = synthetic_front_files_with_blob_theme()
  let assert Ok(#(_, page)) =
    list.find(files, fn(file) {
      file.0 == "public/src/gen/load/article/arg_slug/page.gleam"
    })
  string.contains(
    page,
    "Some(value) -> \"url(\\\"\" <> media.url(value, media.W1600) <> \"\\\")\"",
  )
  |> should.be_true
  string.contains(page, "import media") |> should.be_true
  string.contains(page, "framework/blob.{type Blob}") |> should.be_true
}

pub fn front_blob_theme_media_url_matches_segment_encoding_test() {
  let key = "season one+猫/夏祭り 2026+top.jpg"
  let encoded =
    key
    |> string.split("/")
    |> list.map(fn(segment) {
      segment
      |> uri.percent_encode
      |> string.replace("+", "%2B")
    })
    |> string.join("/")

  let url = "/media/" <> encoded <> "?v=w1600"
  url
  |> should.equal(
    "/media/season%20one%2B%E7%8C%AB/%E5%A4%8F%E7%A5%AD%E3%82%8A%202026%2Btop.jpg?v=w1600",
  )
}

pub fn missing_shell_is_exit_three_test() {
  let assert Ok(units) = source.load("fixtures/article/public")
  let units = list.filter(units, fn(unit) { unit.path != "shell" })
  let assert Ok(model_) =
    front.read_with_package("public", "public", units, app().services)
  let notes = front.notes(model_, app().services)
  notes
  |> list.filter(fn(note) { note.class == stop.Missing })
  |> list.length
  |> should.equal(1)
  let assert [missing] =
    notes |> list.filter(fn(note) { note.class == stop.Missing })
  string.contains(missing.text, "shell.gleam") |> should.be_true
  stop.code(missing.class) |> should.equal(3)
  model_.shell.lang |> should.equal("")
  model_.shell.title |> should.equal("")
}

pub fn present_shell_missing_consts_are_exit_three_test() {
  let assert Ok(units) = source.load("fixtures/article/public")
  let units =
    units
    |> list.filter(fn(unit) { unit.path != "shell" })
    |> list.append([source_unit("shell", "pub type Empty { Empty }")])
  let model_ = front_from_units_named("public", units, app().services)
  let missing =
    front.notes(model_, app().services)
    |> list.filter(fn(note) { note.class == stop.Missing })
  list.length(missing) |> should.equal(3)
  let report = stop.report(missing)
  string.contains(report, "shell.gleam: lang が無い") |> should.be_true
  string.contains(report, "shell.gleam: title が無い") |> should.be_true
  string.contains(report, "shell.gleam: theme が無い") |> should.be_true
  stop.worst(missing) |> should.equal(3)
}

pub fn present_shell_missing_theme_field_is_exit_three_test() {
  let assert Ok(units) = source.load("fixtures/article/public")
  let assert Ok(shell) = list.find(units, fn(unit) { unit.path == "shell" })
  let partial =
    string.replace(shell.text, "  background_image: \"none\",\n", "")
  let units =
    units
    |> list.filter(fn(unit) { unit.path != "shell" })
    |> list.append([source_unit("shell", partial)])
  let model_ = front_from_units_named("public", units, app().services)
  let missing =
    front.notes(model_, app().services)
    |> list.filter(fn(note) { note.class == stop.Missing })
  assert_one_note(missing, stop.Missing, "theme.background_image が無い")
  stop.worst(missing) |> should.equal(3)
}

pub fn static_material_sources_are_required_and_classified_test() {
  let assert Error(static_source.Missing(path)) =
    static_source.load("fixtures/no_static_materials")
  string.contains(path, "external_hosts.mjs") |> should.be_true
  let missing = static_source.note(static_source.Missing(path))
  missing.class |> should.equal(stop.Missing)
  stop.code(missing.class) |> should.equal(3)

  let assert Error(error) =
    static_source.parse_external_hosts_at(
      "fixture/src/external_hosts.mjs",
      "export const EXTERNAL_HOSTS = Object.freeze([ { host: 'bad' } ]);",
    )
  let unreadable = static_source.note(error)
  unreadable.class |> should.equal(stop.Syntax)
  stop.code(unreadable.class) |> should.equal(2)
}

pub fn static_material_copy_keeps_front_four_names_and_markdown_structure_test() {
  let assert Ok(sources) = static_source.load(fixture)
  list.length(sources.hosts) |> should.equal(3)
  let external =
    static_emit.external_text("article", sources.hosts, sources.hosts_hash)
  string.contains(external, "[sha256:") |> should.be_true
  string.contains(external, "pub type Side {") |> should.be_true
  string.contains(external, "pub type Host {") |> should.be_true
  string.contains(external, "pub const hosts: List(Host)") |> should.be_true

  let document = static_emit.api_v1_text(sources.api_v1, sources.api_v1_hash)
  string.contains(document, "pub fn nodes() -> List(el.Element(Nil))")
  |> should.be_true
  string.contains(document, "heading1(\"Fixture API\")") |> should.be_true
  string.contains(document, "html.table(") |> should.be_true
  string.contains(document, "html.pre(") |> should.be_false
  string.contains(document, string.inspect(sources.api_v1)) |> should.be_false
  string.contains(document, "import gleam/list") |> should.be_false
  text_occurrences(document, "\n    heading") |> should.equal(3)
  text_occurrences(document, "html.table(") |> should.equal(2)
  text_occurrences(document, "table_row([") |> should.equal(4)
  let inline_code_count = text_occurrences(document, "inline_code(") - 1
  inline_code_count |> should.equal(4)
  text_occurrences(document, "html.pre(") |> should.equal(0)
  [
    "heading3",
    "heading4",
    "heading5",
    "heading6",
    "unordered_list",
    "fenced_code",
  ]
  |> list.each(fn(name) {
    string.contains(document, "fn " <> name <> "(") |> should.be_false
  })
  text_occurrences(document, "unordered_list(") |> should.equal(0)

  let list_document =
    static_emit.api_v1_text("# Fixture API\n\n- one item", "same-hash")
  string.contains(list_document, "import gleam/list") |> should.be_true
  string.contains(list_document, "fn unordered_list(") |> should.be_true
}

pub fn static_api_v1_source_change_changes_generated_structure_test() {
  let assert Ok(sources) = static_source.load(fixture)
  let changed_source =
    string.replace(sources.api_v1, "Fixture API", "Fixture API!")
  let original_document = static_emit.api_v1_text(sources.api_v1, "same-hash")
  let changed_document = static_emit.api_v1_text(changed_source, "same-hash")
  let different = original_document != changed_document
  different |> should.be_true
  string.contains(changed_document, "Fixture API!") |> should.be_true
}

pub fn static_api_v1_parser_rejects_unhandled_markdown_test() {
  let source = "# Title\n\n> A block quote is not supported."
  case markdown.parse(source) {
    Ok(_) -> should.be_false
    Error(_) -> should.be_true
  }
}

pub fn one_character_host_source_change_changes_the_generated_copy_test() {
  let assert Ok(source_text) =
    simplifile.read(fixture <> "/src/external_hosts.mjs")
  let changed_source =
    source_text
    |> string.split("images.example.test")
    |> string.join("images.example.tesT")
  let assert Ok(original) = static_source.external_hosts(source_text)
  let assert Ok(changed) = static_source.external_hosts(changed_source)
  let original_text =
    static_emit.external_text("article", original, "same-hash")
  let changed_text = static_emit.external_text("article", changed, "same-hash")
  let same = original_text == changed_text
  same |> should.be_false
  string.contains(changed_text, "host: \"images.example.tesT\"")
  |> should.be_true
}

fn text_occurrences(source: String, needle: String) -> Int {
  string.split(source, needle) |> list.length |> int.subtract(1)
}

pub fn front_emit_grid_css_has_breakpoint_pin_and_hidden_area_rules_test() {
  let css = text("public/priv/static/_yumemi/style.css")
  string.contains(css, "grid-template-areas: \"header\" \"page\" \"footer\";")
  |> should.be_true
  string.contains(css, "@media (min-width: 1024px)") |> should.be_true
  string.contains(css, "grid-area: aside;") |> should.be_true
  string.contains(css, "display: none;") |> should.be_true
  string.contains(css, "position: sticky;") |> should.be_true
}

pub fn front_emit_grid_tracks_template_and_fixed_cells_test() {
  let files =
    synthetic_front_files_with_layout(
      "Layout(\n"
      <> "  sp: Frame(\n"
      <> "    areas: [\n"
      <> "      Area(name: \"hero\", flow: css.Stack(gap: style.s0), pin: css.NoPin, style: []),\n"
      <> "      Area(name: \"rail\", flow: css.GridTracks(cols: [track.Fr(2), track.Fr(1)], gap: css.Rem(0.5)), pin: css.NoPin, style: []),\n"
      <> "    ],\n"
      <> "    placements: [\n"
      <> "      Fixed(area: \"hero\", block: blocks.Article, cell: Span(cols: 2, rows: 1)),\n"
      <> "      Fixed(area: \"rail\", block: blocks.Summary, cell: At(col: 1, row: 2, span: CellSpan(cols: 2, rows: 3))),\n"
      <> "    ],\n"
      <> "    cols: [track.Fr(2), track.Minmax(min: track.RemSize(12.0), max: track.AutoSize)],\n"
      <> "    rows: [track.Rem(10.0), track.Px(240.0), track.Auto],\n"
      <> "    template: [[\"hero\", \"hero\"], [\"rail\", \"rail\"]],\n"
      <> "  ),\n"
      <> "  pc: None,\n"
      <> "  tablet: None,\n"
      <> "  vars: [],\n"
      <> ")",
    )
  list.any(files, fn(file) { file.0 == "public/src/gen/widgets.gleam" })
  |> should.be_false
  let assert Ok(#(_, css)) =
    list.find(files, fn(file) {
      file.0 == "public/priv/static/_yumemi/style.css"
    })
  [
    "grid-template-columns: 2fr minmax(12rem, auto);",
    "grid-template-rows: 10rem 240px auto;",
    "grid-template-areas: \"hero hero\" \"rail rail\";",
    "grid-template-columns: 2fr 1fr;",
    "gap: 0.5rem;",
  ]
  |> list.each(fn(row) { string.contains(css, row) |> should.be_true })

  let assert Ok(#(_, page)) =
    list.find(files, fn(file) {
      file.0 == "public/src/gen/load/article/arg_slug/page.gleam"
    })
  string.contains(page, "grid-column: span 2; grid-row: span 1;")
  |> should.be_true
  string.contains(page, "grid-column: 1 / 3; grid-row: 2 / 5;")
  |> should.be_true
  string.contains(page, "layout: layout.load(article_read)")
  |> should.be_true
}

pub fn front_emit_page_frame_grid_and_widget_derived_sources_test() {
  let files =
    synthetic_front_files_with_layout_and_page(
      "Layout(vars: [], sp: Frame(areas: [], placements: [], cols: [], rows: [], template: []), pc: None, tablet: None)",
      "Page(\n"
        <> "  of: Some(service.ArticleRead),\n"
        <> "  layout: layout.public,\n"
        <> "  theme: None,\n"
        <> "  vars: [],\n"
        <> "  sp: Frame(\n"
        <> "    areas: [Area(name: \"feature\", flow: css.Stack(gap: style.s0), pin: css.NoPin, style: [])],\n"
        <> "    placements: [Fixed(area: \"feature\", block: blocks.Article, cell: Span(cols: 2, rows: 1)), Widget(area: \"feature\", of: service.WidgetList, render: One(blocks.Feed))],\n"
        <> "    cols: [track.Fr(1), track.Fr(2)],\n"
        <> "    rows: [],\n"
        <> "    template: [[\"feature\", \"feature\"]],\n"
        <> "  ),\n"
        <> "  pc: None,\n"
        <> "  tablet: None,\n"
        <> ")",
    )
  let assert Ok(#(_, css)) =
    list.find(files, fn(file) {
      file.0 == "public/priv/static/_yumemi/style.css"
    })
  string.contains(
    css,
    "[data-yumemi-grid=\"page:pages/article/arg_slug/page\"] {",
  )
  |> should.be_true
  string.contains(css, "grid-template-columns: 1fr 2fr;") |> should.be_true
  string.contains(css, "grid-template-areas: \"feature feature\";")
  |> should.be_true

  let assert Ok(#(_, page)) =
    list.find(files, fn(file) {
      file.0 == "public/src/gen/load/article/arg_slug/page.gleam"
    })
  string.contains(
    page,
    "data-yumemi-grid\", \"page:pages/article/arg_slug/page\"",
  )
  |> should.be_true
  string.contains(page, "widget_list: Option(widget_list.Out)")
  |> should.be_true
  string.contains(page, "article_read: article_read.Out") |> should.be_true
  string.contains(page, "grid-column: span 2; grid-row: span 1;")
  |> should.be_true
}

pub fn fixed_in_and_widget_of_services_are_derived_test() {
  let files =
    synthetic_front_files_with_layout(
      "Layout(\n"
      <> "  vars: [],\n"
      <> "  sp: Frame(areas: [], placements: [Fixed(area: \"main\", block: blocks.Article, cell: Flow), Widget(area: \"main\", of: service.WidgetList, render: One(blocks.Feed))], cols: [], rows: [], template: []),\n"
      <> "  pc: None,\n"
      <> "  tablet: None,\n"
      <> ")",
    )
  let assert Ok(#(_, layout)) =
    list.find(files, fn(file) { file.0 == "public/src/gen/load/layout.gleam" })
  [
    string.contains(layout, "article_read: article_read.Out"),
    string.contains(layout, "widget_list: Option(widget_list.Out)"),
  ]
  |> should.equal([True, True])

  let assert Ok(#(_, page)) =
    list.find(files, fn(file) {
      file.0 == "public/src/gen/load/article/arg_slug/page.gleam"
    })
  [
    string.contains(page, "article_read: article_read.Out"),
    string.contains(page, "widget_list: Option(widget_list.Out)"),
    string.contains(page, "widget_list: Option(widget_list.Out)"),
  ]
  |> should.equal([True, True, True])

  let face_units = [
    layout_unit(
      "Layout(vars: [], sp: Frame(areas: [], placements: [Fixed(area: \"main\", block: blocks.Article, cell: Flow)], cols: [], rows: [], template: []), pc: None, tablet: None)",
    ),
    source_unit(
      "blocks/article",
      "import gen/out/article_read\npub type In { In(article: article_read.Out) }\npub fn view(it: In) -> el.Element(Nil) { it }",
    ),
  ]
  let notes = front_notes(face_units, app().services)
  stop.worst(notes) |> should.equal(4)
  notes
  |> list.any(fn(note) {
    note.class == stop.Conflict
    && string.contains(note.text, "[変数 6]")
    && string.contains(note.text, "Block Article In In")
  })
  |> should.be_true
}

pub fn front_calls_parse_framework_target_of_and_entry_test() {
  let assert Ok(face_units) = source.load("fixtures/article/public")
  let face_units =
    face_units
    |> list.filter(fn(unit) { unit.path != "components/pick_tag" })
    |> list.append([
      source_unit(
        "components/pick_tag",
        "pub const calls: List(front.Target(service.Service, api.Attached)) = [\n"
          <> "  front.Of(service.ArticleCreate),\n"
          <> "]\n"
          <> "pub const target: api.Target = api.Entry(api.BrowserAdult)",
      ),
    ])
  let assert Ok(front_model) =
    front.read_with_package("public", "public", face_units, app().services)
  let assert Ok(component) =
    list.find(front_model.components, fn(component) {
      component.name == "PickTag"
    })
  component.calls
  |> should.equal([
    front.ServiceCall("ArticleCreate"),
    front.AttachedCall("BrowserAdult"),
  ])
  list.contains(front_model.services, "ArticleCreate") |> should.be_true

  let assert Ok(#(_, generated_api)) =
    synthetic_front_files(face_units)
    |> list.find(fn(file) { file.0 == "public/src/gen/api.gleam" })
  string.contains(generated_api, "  BrowserAdult\n")
  |> should.be_true
  string.contains(
    generated_api,
    "pub type Target = front.Target(service.Service, Attached)",
  )
  |> should.be_true
}

pub fn front_emit_generates_service_and_static_attached_live_modules_test() {
  let assert Ok(face_units) = source.load("fixtures/article/public")
  let face_units =
    face_units
    |> list.filter(fn(unit) { unit.path != "components/pick_tag" })
    |> list.append([
      source_unit(
        "components/pick_tag",
        "pub const calls: List(front.Target(service.Service, api.Attached)) = [\n"
          <> "  front.Of(service.ArticleCreate),\n"
          <> "]\n"
          <> "pub const target: api.Target = api.Entry(api.FixtureBrowser)",
      ),
    ])
  let base_app = app()
  let app =
    model.App(..base_app, attached: [
      model.AttachedRoute(
        name: "FixtureBrowser",
        method: "GET",
        path: "/fixture/browser",
      ),
    ])
  let assert Ok(back_units) = source.load(fixture)
  let assert Ok(front_model) =
    front.read_with_package("public", "public", face_units, app.services)
  let package =
    face.Package(
      name: "public",
      path: "fixtures/article/public",
      pages: face.UndeclaredPages,
      units: face_units,
    )
  let files =
    front_emit.emit(app, back_units, package, front_model, hash.of(back_units))
  let assert Ok(service_live) =
    list.find(files, fn(file) {
      file.path == "public/src/gen/live/article_create.gleam"
    })
  string.contains(service_live.text, "\"/api/articles\"")
  |> should.be_true
  let assert Ok(attached_live) =
    list.find(files, fn(file) {
      file.path == "public/src/gen/live/fixture_browser.gleam"
    })
  string.contains(attached_live.text, "\"/fixture/browser\"")
  |> should.be_true
  string.contains(attached_live.text, "live.State(Args, Nil, Dynamic, Failure)")
  |> should.be_true
}

pub fn front_emit_decoder_only_uses_declared_constructors_test() {
  let out = synthetic_decoder_out()
  string.contains(out, "pub type ArticleRow(") |> should.be_false
  string.contains(out, "ArticleRow(") |> should.be_true
  string.contains(out, "decode.success(ArticleRow(") |> should.be_true
  string.contains(out, "\"draft\" -> decode.success(Draft)") |> should.be_true
  string.contains(out, "parse(\"placeholder\")") |> should.be_true
  string.contains(out, "decode.new_primitive_decoder(\"Blob\"")
  |> should.be_true
}

pub fn front_emit_opaque_decoders_reject_invalid_input_without_assert_test() {
  let out =
    synthetic_multi_decoder_out(
      "import framework/blob.{type Blob}\n"
      <> "import framework/time.{type Time}\n\n"
      <> "pub type Out { Out(blob: Blob, at: Time) }\n\n"
      <> "pub const service: Service(Args, Out, Error) = Nil",
    )
  string.contains(out, "decode.new_primitive_decoder(\"Blob\"")
  |> should.be_true
  string.contains(out, "decode.new_primitive_decoder(\"Time\"")
  |> should.be_true
  string.contains(out, "let parsed = case decode.run(value, decode.string)")
  |> should.be_true
  string.contains(out, "case parse(\"placeholder\")") |> should.be_true
  string.contains(out, "case time(\"00:00\")") |> should.be_true
  string.contains(out, "let assert Ok(default_value)") |> should.be_false

  let blob_decoder =
    decode.new_primitive_decoder("Blob", fn(value) {
      let parsed = case decode.run(value, decode.string) {
        Ok(raw) -> blob.parse(raw)
        Error(_) -> Error(Nil)
      }
      case parsed {
        Ok(parsed) -> Ok(parsed)
        Error(_) ->
          Error(case blob.parse("placeholder") {
            Ok(default) -> default
            Error(_) -> panic as "valid built-in Blob decoder placeholder"
          })
      }
    })
  let time_decoder =
    decode.new_primitive_decoder("Time", fn(value) {
      let parsed = case decode.run(value, decode.string) {
        Ok(raw) -> time.time(raw)
        Error(_) -> Error(Nil)
      }
      case parsed {
        Ok(parsed) -> Ok(parsed)
        Error(_) ->
          Error(case time.time("00:00") {
            Ok(default) -> default
            Error(_) -> panic as "valid built-in Time decoder placeholder"
          })
      }
    })
  let assert Error(_) = decode.run(dynamic.string(""), blob_decoder)
  let assert Error(_) = decode.run(dynamic.string("not-a-time"), time_decoder)
  let assert Error(_) = decode.run(dynamic.int(42), blob_decoder)
}

pub fn front_emit_decodes_both_fixture_row_variants_test() {
  let out = text("public/src/gen/out/widget_list.gleam")
  [
    "\"Article\" ->",
    "decode.success(ArticleRow(kind: kind, article: article))",
    "\"Summary\" ->",
    "decode.success(Summary(kind: kind, article: article))",
  ]
  |> list.each(fn(row) { string.contains(out, row) |> should.be_true })
}

pub fn widget_list_logic_builds_summary_for_article_kinds_test() {
  let assert Ok(units) = source.load(fixture)
  let assert Ok(widget_list) =
    list.find(units, fn(unit) { unit.path == "service/widget_list" })
  [
    "case args.widget {",
    "Some(\"summary\") ->",
    "Article(kind: \"Article\", article: row.0)",
    "_ ->",
    "Summary(kind: \"Summary\", article: row.0)",
    "step.done(Out(rows: rows))",
  ]
  |> list.each(fn(row) {
    string.contains(widget_list.text, row) |> should.be_true
  })
}

pub fn front_emit_decodes_six_snapshot_style_row_variants_test() {
  let out =
    synthetic_multi_decoder_out(
      "pub type Kind = String\n\n"
      <> "pub type Row {\n"
      <> "  Text(kind: Kind, body: String)\n"
      <> "  Image(kind: Kind, image: String)\n"
      <> "  Articles(kind: Kind, articles: List(String))\n"
      <> "  HeavenDiary(kind: Kind, heaven_public: Option(String))\n"
      <> "  HeavenReview(kind: Kind, heaven_public: Option(String))\n"
      <> "  Links(kind: Kind, links: List(String))\n"
      <> "}\n\n"
      <> "pub type Out { Out(rows: List(Row)) }\n\n"
      <> "pub const service: Service(Args, Out, Error) = Nil",
    )
  [
    "\"Text\" ->",
    "Text(kind: kind, body: body)",
    "\"Image\" ->",
    "Image(kind: kind, image: image)",
    "\"Articles\" ->",
    "Articles(kind: kind, articles: articles)",
    "\"HeavenDiary\" ->",
    "HeavenDiary(kind: kind, heaven_public: heaven_public)",
    "\"HeavenReview\" ->",
    "HeavenReview(kind: kind, heaven_public: heaven_public)",
    "\"Links\" ->",
    "Links(kind: kind, links: links)",
    "decode.field(\"articles\"",
    "decode.field(\"links\"",
    "decode.field(\"heaven_public\"",
  ]
  |> list.each(fn(row) { string.contains(out, row) |> should.be_true })
}

pub fn front_emit_decodes_enum_kind_with_codec_tags_test() {
  let out =
    synthetic_multi_decoder_out(
      "pub type Kind { Articles HeavenDiary }\n\n"
      <> "pub type Row {\n"
      <> "  Articles(kind: Kind, ids: List(String))\n"
      <> "  HeavenDiary(kind: Kind, slug: String)\n"
      <> "}\n\n"
      <> "pub type Out { Out(rows: List(Row)) }\n\n"
      <> "pub const service: Service(Args, Out, Error) = Nil",
    )
  [
    "\"articles\" ->",
    "Articles(kind: kind, ids: ids)",
    "\"heaven_diary\" ->",
    "HeavenDiary(kind: kind, slug: slug)",
    "pub type Kind = String",
  ]
  |> list.each(fn(row) { string.contains(out, row) |> should.be_true })
}

pub fn front_emit_stops_row_when_kind_enum_lacks_constructor_test() {
  let assert Ok(units) = source.load(fixture)
  let units =
    list.filter(units, fn(unit) { unit.path != "service/widget_list" })
  let units =
    list.append(units, [
      source_unit(
        "service/widget_list",
        "pub type Kind { Articles }\n\n"
          <> "pub type Row {\n"
          <> "  Articles(kind: Kind, ids: List(String))\n"
          <> "  Summary(kind: Kind, count: Int)\n"
          <> "}\n\n"
          <> "pub type Out { Out(rows: List(Row)) }\n\n"
          <> "pub const service: Service(Args, Out, Error) = Nil",
      ),
    ])
  let notes = front_emit.decoder_notes(app(), units)
  let assert Ok(note) =
    list.find(notes, fn(note) { string.contains(note.text, "Summary") })
  note.class |> should.equal(stop.Conflict)
  stop.code(note.class) |> should.equal(4)
  string.contains(note.text, "service/widget_list") |> should.be_true
}

pub fn front_emit_stops_union_when_non_kind_discriminator_enum_lacks_constructor_test() {
  let assert Ok(units) = source.load(fixture)
  let units =
    list.filter(units, fn(unit) { unit.path != "service/widget_list" })
  let units =
    list.append(units, [
      source_unit(
        "service/widget_list",
        "pub type Kind { Articles }\n\n"
          <> "pub type Row {\n"
          <> "  Articles(tag: Kind, ids: List(String))\n"
          <> "  Summary(tag: Kind, count: Int)\n"
          <> "}\n\n"
          <> "pub type Out { Out(rows: List(Row)) }\n\n"
          <> "pub const service: Service(Args, Out, Error) = Nil",
      ),
    ])
  let notes = front_emit.decoder_notes(app(), units)
  let assert Ok(note) =
    list.find(notes, fn(note) { string.contains(note.text, "Summary") })
  note.class |> should.equal(stop.Conflict)
  stop.code(note.class) |> should.equal(4)
  string.contains(note.text, "service/widget_list") |> should.be_true
  string.contains(note.text, "Row") |> should.be_true
}

pub fn front_emit_decodes_framework_er_values_from_codec_wire_test() {
  let out =
    synthetic_multi_decoder_out(
      "import framework/er.{type Has, type Held, type Key, type Link, type Multi}\n\n"
      <> "pub type Out {\n"
      <> "  Out(has: Has(String), held: Held(String), multi: Multi(String), key: Key(String), link: Link(String))\n"
      <> "}\n\n"
      <> "pub const service: Service(Args, Out, Error) = Nil",
    )
  [
    "decode.map(decode.string, fn(value) { Has(value: value) })",
    "decode.map(decode.string, fn(value) { Held(value: value) })",
    "decode.field(\"keys\", decode.list(of: decode.string), fn(keys) { decode.success(Multi(values: keys)) })",
    "decode.then(decode.string, fn(raw) { decode.success(key(raw)) })",
    "decode.optional(decode.then(decode.string, fn(raw) { decode.success(key(raw)) }))",
  ]
  |> list.each(fn(row) { string.contains(out, row) |> should.be_true })
  [
    "decode.field(\"value\"",
    "decode.field(\"values\"",
  ]
  |> list.each(fn(row) { string.contains(out, row) |> should.be_false })
}

pub fn front_emit_decodes_non_row_custom_union_test() {
  let out =
    synthetic_multi_decoder_out(
      "pub type Card {\n"
      <> "  Text(kind: String, body: String)\n"
      <> "  Number(kind: String, value: Int)\n"
      <> "}\n\n"
      <> "pub type Out { Out(cards: List(Card)) }\n\n"
      <> "pub const service: Service(Args, Out, Error) = Nil",
    )
  [
    "pub type Card {",
    "\"Text\" ->",
    "Text(kind: kind, body: body)",
    "\"Number\" ->",
    "Number(kind: kind, value: value)",
    "decode.field(\"kind\"",
  ]
  |> list.each(fn(row) { string.contains(out, row) |> should.be_true })
}

pub fn front_emit_decodes_custom_record_with_cross_module_enum_test() {
  let out =
    synthetic_multi_decoder_out(
      "import entity/article\n\n"
      <> "pub type Settings {\n"
      <> "  Settings(phase: article.Phase, title: String)\n"
      <> "}\n\n"
      <> "pub type Out { Out(settings: Settings) }\n\n"
      <> "pub const service: Service(Args, Out, Error) = Nil",
    )
  [
    "pub type Phase {",
    "decode.field(\"settings\"",
    "decode.field(\"phase\", decode.then(decode.string",
    "\"draft\" -> decode.success(Draft)",
    "decode.success(Settings(phase: phase, title: title))",
    "decode.success(Out(settings: settings))",
  ]
  |> list.each(fn(row) { string.contains(out, row) |> should.be_true })
}

pub fn front_emit_decodes_er_key_from_string_test() {
  let out =
    synthetic_multi_decoder_out(
      "import framework/er.{type Key}\n\n"
      <> "pub type Out { Out(id: Key(String)) }\n\n"
      <> "pub const service: Service(Args, Out, Error) = Nil",
    )
  string.contains(out, "import framework/er.{type Key, key}")
  |> should.be_true
  string.contains(
    out,
    "decode.field(\"id\", decode.then(decode.string, fn(raw) { decode.success(key(raw)) }), fn(id)",
  )
  |> should.be_true
}

pub fn front_emit_decodes_nil_out_with_typed_result_test() {
  let out =
    synthetic_multi_decoder_out(
      "pub type Out = Nil\n\n"
      <> "pub const service: Service(Args, Out, Error) = Nil",
    )
  string.contains(out, "pub type Out = Nil") |> should.be_true
  string.contains(out, "decode.new_primitive_decoder(\"Nil\"") |> should.be_true
  string.contains(out, "classify(value)") |> should.be_true
  string.contains(out, "import gleam/dynamic.{classify}") |> should.be_true
}

pub fn front_emit_decodes_party_id_with_parser_test() {
  let out =
    synthetic_multi_decoder_out(
      "import framework/party.{type PartyId}\n\n"
      <> "pub type Out { Out(party: PartyId) }\n\n"
      <> "pub const service: Service(Args, Out, Error) = Nil",
    )
  string.contains(out, "import framework/party.{type PartyId}")
  |> should.be_true
  string.contains(out, "party.parse(\"placeholder\")") |> should.be_true
  string.contains(out, "decode.success(Out(party: party))") |> should.be_true
}

pub fn front_emit_decodes_untagged_custom_union_test() {
  let out =
    synthetic_multi_decoder_out(
      "pub type Source { Tagged(String) External Internal Direct }\n\n"
      <> "pub type Out { Out(source: Source) }\n\n"
      <> "pub const service: Service(Args, Out, Error) = Nil",
    )
  [
    "decode.one_of(\n  ",
    "or: [",
    "decode.failure(External, expected: \"Source\")",
    "decode.field(\"0\", decode.string, fn(arg_0)",
    "decode.success(Tagged(arg_0))",
    "\"external\" -> decode.success(External)",
    "decode.success(Out(source: source))",
  ]
  |> list.each(fn(row) { string.contains(out, row) |> should.be_true })
}

pub fn front_emit_decodes_visit_source_from_generic_codec_test() {
  let out =
    synthetic_out_for(
      app(),
      "widget_list",
      "import entity/visit as visit\n\n"
        <> "pub type Out { Out(source: visit.Source) }\n\n"
        <> "pub const service: Service(Args, Out, Error) = Nil",
      [
        source_unit(
          "entity/visit",
          "pub type Source { Tagged(String) External Internal Direct }",
        ),
      ],
    )
  [
    "decode.field(\"0\", decode.string, fn(arg_0)",
    "decode.success(Tagged(arg_0))",
    "\"external\" -> decode.success(External)",
    "\"internal\" -> decode.success(Internal)",
    "\"direct\" -> decode.success(Direct)",
  ]
  |> list.each(fn(part) { string.contains(out, part) |> should.be_true })
  string.contains(out, "source_kind") |> should.be_false
  string.contains(out, "source_key") |> should.be_false
  string.contains(out, "decode.one_of(") |> should.be_true
}

pub fn front_emit_decodes_value_key_records_and_positional_fields_test() {
  let out =
    synthetic_multi_decoder_out(
      "pub type ValueBox { ValueBox(value: String) }\n"
      <> "pub type KeyBox { KeyBox(key: String) }\n"
      <> "pub type Pair { Pair(String, Int) }\n"
      <> "pub type Out { Out(value_box: ValueBox, key_box: KeyBox, pair: Pair) }\n"
      <> "pub const service: Service(Args, Out, Error) = Nil",
    )
  [
    "decode.map(decode.string, fn(value) { ValueBox(value: value) })",
    "decode.map(decode.string, fn(key) { KeyBox(key: key) })",
    "decode.field(\"0\", decode.string, fn(arg_0)",
    "decode.field(\"1\", decode.int, fn(arg_1)",
    "decode.success(Pair(arg_0, arg_1))",
  ]
  |> list.each(fn(part) { string.contains(out, part) |> should.be_true })
}

pub fn front_emit_nullary_tag_matches_codec_acronym_rule_test() {
  let out =
    synthetic_multi_decoder_out(
      "pub type State { HTTPReady Page2Up }\n"
      <> "pub type Out { Out(state: State) }\n"
      <> "pub const service: Service(Args, Out, Error) = Nil",
    )
  string.contains(out, "\"httpready\" -> decode.success(HTTPReady)")
  |> should.be_true
  string.contains(out, "\"page2_up\" -> decode.success(Page2Up)")
  |> should.be_true
}

/// Node round-trip probe sources. The values are built by the actual framework
/// constructors and the generated gen/types module in a temporary package.
pub fn codec_roundtrip_kind_source() -> String {
  "pub type Kind { Articles HeavenDiary }"
}

pub fn codec_roundtrip_service_source() -> String {
  "import entity/codec_kind as kind\n"
  <> "import framework/blob as blob\n"
  <> "import framework/er as er\n"
  <> "import framework/page as page\n"
  <> "import framework/party as party\n"
  <> "import framework/time as time\n"
  <> "import gen/types/slug as slug\n"
  <> "import gleam/option.{type Option, None, Some}\n\n"
  <> "pub type ValueBox { ValueBox(value: String) }\n"
  <> "pub type KeyBox { KeyBox(key: String) }\n"
  <> "pub type Pair { Pair(String, Int) }\n"
  <> "pub type Status { HTTPReady Offline }\n"
  <> "pub type Row {\n"
  <> "  Articles(kind: kind.Kind, slug: String)\n"
  <> "  HeavenDiary(kind: kind.Kind, slug: String)\n"
  <> "}\n"
  <> "pub type StringRow {\n"
  <> "  Article(kind: String, title: String)\n"
  <> "  Summary(kind: String, count: Int)\n"
  <> "}\n"
  <> "pub type FieldUnion { ByTitle(title: String) ByCount(count: Int) }\n"
  <> "pub type Out {\n"
  <> "  Out(\n"
  <> "    text: Option(String), integer: Option(Int), boolean: Option(Bool), float: Option(Float),\n"
  <> "    maybe: Option(Option(String)), missing: Option(Option(String)), values: Option(List(String)),\n"
  <> "    slug: Option(slug.Slug), blob: Option(blob.Blob), date: Option(time.Date),\n"
  <> "    datetime: Option(time.Datetime), time: Option(time.Time), party: Option(party.PartyId),\n"
  <> "    pagination: Option(page.Page(String)),\n"
  <> "    relation_key: Option(er.Key(String)), link: Option(er.Link(String)), has: Option(er.Has(String)),\n"
  <> "    held: Option(er.Held(String)), multi: Option(er.Multi(String)),\n"
  <> "    value_box: Option(ValueBox), key_box: Option(KeyBox), pair: Option(Pair), status: Option(Status),\n"
  <> "    rows: Option(List(Row)), string_rows: Option(List(StringRow)), choice: Option(FieldUnion),\n"
  <> "  )\n"
  <> "}\n"
  <> "pub type Args\n"
  <> "pub type Error\n"
  <> "pub type Service(args, out, error) { Service }\n"
  <> "pub const service: Service(Args, Out, Error) = Service\n\n"
  <> "@external(javascript, \"./roundtrip_ffi.mjs\", \"row\")\n"
  <> "fn row(key: String) -> er.Row\n\n"
  <> "pub fn sample(field: String) -> Out {\n"
  <> "  let assert Ok(slug_value) = slug.parse(\"roundtrip-slug\")\n"
  <> "  let assert Ok(blob_value) = blob.parse(\"blob-key\")\n"
  <> "  let assert Ok(date_value) = time.date(\"2026-09-25\")\n"
  <> "  let assert Ok(datetime_value) = time.datetime(\"2026-09-25T12:30:00Z\")\n"
  <> "  let assert Ok(time_value) = time.time(\"12:30\")\n"
  <> "  let assert Ok(party_value) = party.parse(\"party-id\")\n"
  <> "  let assert Ok(cursor_value) = page.cursor(\"cursor-value\")\n"
  <> "  let has_value = er.from_row(row(\"has-value\"))\n"
  <> "  let held_value = er.held_from_row(row(\"held-value\"))\n"
  <> "  let multi_value = er.multi_from_rows([row(\"multi-one\"), row(\"multi-two\")])\n"
  <> "  let empty = Out(\n"
  <> "    text: None, integer: None, boolean: None, float: None,\n"
  <> "    maybe: None, missing: None, values: None, slug: None, blob: None,\n"
  <> "    date: None, datetime: None, time: None, party: None,\n"
  <> "    pagination: None, relation_key: None, link: None, has: None, held: None, multi: None,\n"
  <> "    value_box: None, key_box: None, pair: None, status: None, rows: None,\n"
  <> "    string_rows: None, choice: None,\n"
  <> "  )\n"
  <> "  case field {\n"
  <> "    \"string\" -> Out(..empty, text: Some(\"plain\"))\n"
  <> "    \"integer\" -> Out(..empty, integer: Some(42))\n"
  <> "    \"boolean\" -> Out(..empty, boolean: Some(True))\n"
  <> "    \"float\" -> Out(..empty, float: Some(1.5))\n"
  <> "    \"option\" -> Out(..empty, maybe: Some(Some(\"optional\")))\n"
  <> "    \"option_none\" -> Out(..empty, missing: Some(None))\n"
  <> "    \"list\" -> Out(..empty, values: Some([\"one\", \"two\"]))\n"
  <> "    \"gen_type\" -> Out(..empty, slug: Some(slug_value))\n"
  <> "    \"blob\" -> Out(..empty, blob: Some(blob_value))\n"
  <> "    \"date\" -> Out(..empty, date: Some(date_value))\n"
  <> "    \"datetime\" -> Out(..empty, datetime: Some(datetime_value))\n"
  <> "    \"time\" -> Out(..empty, time: Some(time_value))\n"
  <> "    \"party\" -> Out(..empty, party: Some(party_value))\n"
  <> "    \"page\" -> Out(..empty, pagination: Some(page.Page(items: [\"page-one\", \"page-two\"], next: Some(cursor_value))))\n"
  <> "    \"key\" -> Out(..empty, relation_key: Some(er.key(\"key-value\")))\n"
  <> "    \"link\" -> Out(..empty, link: Some(Some(er.key(\"link-value\"))))\n"
  <> "    \"has\" -> Out(..empty, has: Some(has_value))\n"
  <> "    \"held\" -> Out(..empty, held: Some(held_value))\n"
  <> "    \"multi\" -> Out(..empty, multi: Some(multi_value))\n"
  <> "    \"value_record\" -> Out(..empty, value_box: Some(ValueBox(\"boxed-value\")))\n"
  <> "    \"key_record\" -> Out(..empty, key_box: Some(KeyBox(\"boxed-key\")))\n"
  <> "    \"position\" -> Out(..empty, pair: Some(Pair(\"first\", 7)))\n"
  <> "    \"enum\" -> Out(..empty, status: Some(HTTPReady))\n"
  <> "    \"kind_articles\" -> Out(..empty, rows: Some([Articles(kind: kind.Articles, slug: \"articles\")]))\n"
  <> "    \"kind_heaven_diary\" -> Out(..empty, rows: Some([HeavenDiary(kind: kind.HeavenDiary, slug: \"heaven-diary\")]))\n"
  <> "    \"string_kind_article\" -> Out(..empty, string_rows: Some([Article(kind: \"Article\", title: \"article-title\")]))\n"
  <> "    \"string_kind_summary\" -> Out(..empty, string_rows: Some([Summary(kind: \"Summary\", count: 3)]))\n"
  <> "    \"field_union_title\" -> Out(..empty, choice: Some(ByTitle(\"title-value\")))\n"
  <> "    \"field_union_count\" -> Out(..empty, choice: Some(ByCount(7)))\n"
  <> "    _ -> empty\n"
  <> "  }\n"
  <> "}\n"
}

pub fn codec_roundtrip_decoder_source() -> String {
  synthetic_out_for(app(), "widget_list", codec_roundtrip_service_source(), [
    source_unit("entity/codec_kind", codec_roundtrip_kind_source()),
  ])
}

pub fn front_emit_roster_read_qualifies_public_entity_types_test() {
  let out =
    synthetic_out_for(
      app(),
      "roster_read",
      "import entity/muse as muse\n"
        <> "import entity/store as store\n\n"
        <> "import entity/roster as roster\n\n"
        <> "pub type Out {\n"
        <> "  Out(muse: muse.Public, store: store.Public, roster: roster.Public)\n"
        <> "}\n\n"
        <> "pub const service: Service(Args, Out, Error) = Nil",
      [
        source_unit("entity/muse", "pub type Public { Public(handle: String) }"),
        source_unit(
          "entity/store",
          "pub type Public { Public(handle: String) }",
        ),
        source_unit(
          "entity/roster",
          "pub type Public { Public(handle: String) }",
        ),
      ],
    )
  string.contains(out, "pub type MusePublic {") |> should.be_true
  string.contains(out, "pub type StorePublic {") |> should.be_true
  string.contains(out, "pub type RosterPublic {") |> should.be_true
  string.contains(out, "muse: MusePublic") |> should.be_true
  string.contains(out, "store: StorePublic") |> should.be_true
  string.contains(out, "roster: RosterPublic") |> should.be_true
}

pub fn front_emit_aliases_local_service_return_as_out_test() {
  let out =
    synthetic_multi_decoder_out(
      "pub type Applied { Applied(status: String) }\n\n"
      <> "pub const service: Service(Args, Applied, Error) = Nil",
    )
  string.contains(out, "pub type Applied {") |> should.be_true
  string.contains(out, "pub type Out = Applied") |> should.be_true
  string.contains(out, "pub fn decoder() -> decode.Decoder(Out)")
  |> should.be_true
  string.contains(out, "decode.success(Applied(status: status))")
  |> should.be_true
}

pub fn front_emit_undiscriminable_union_has_stop_diagnostic_test() {
  let assert Ok(units) = source.load(fixture)
  let units =
    list.filter(units, fn(unit) { unit.path != "service/widget_list" })
  let units =
    list.append(units, [
      source_unit(
        "entity/visit",
        "pub type Source { Tagged(String) External Internal Direct }",
      ),
      source_unit(
        "service/visit_metrics",
        "import entity/visit as visit\n\n"
          <> "pub type Args\n"
          <> "pub type Out { Out(source: visit.Source) }\n"
          <> "pub type Error\n"
          <> "pub const service: Service(Args, Out, Error) = Nil",
      ),
      source_unit(
        "service/ambiguous",
        "pub type Row { Alpha(title: String) Beta(title: String) }\n\n"
          <> "pub type Out { Out(rows: List(Row)) }\n\n"
          <> "pub const service: Service(Args, Out, Error) = Nil",
      ),
    ])
  let notes = front_emit.decoder_notes(app(), units)
  let assert Ok(note) =
    list.find(notes, fn(note) { string.contains(note.text, "ambiguous.Row") })
  note.class |> should.equal(stop.NotImplemented)
  string.contains(note.text, "複数 variant を判別できない") |> should.be_true
  notes
  |> list.any(fn(note) { string.contains(note.text, "entity/visit.Source") })
  |> should.be_false
}

pub fn front_emit_flattened_and_colliding_tags_stop_test() {
  let assert Ok(units) = source.load(fixture)
  let units =
    list.append(units, [
      source_unit(
        "service/flattened",
        "pub type Choice { ByValue(value: String) ByKey(key: String) }\n"
          <> "pub type Out { Out(choice: Choice) }\n"
          <> "pub const service: Service(Args, Out, Error) = Nil",
      ),
      source_unit(
        "service/tag_collision",
        "pub type Choice { HTTPRequest Httprequest }\n"
          <> "pub type Out { Out(choice: Choice) }\n"
          <> "pub const service: Service(Args, Out, Error) = Nil",
      ),
    ])
  let notes = front_emit.decoder_notes(app(), units)
  notes
  |> list.any(fn(note) { string.contains(note.text, "flattened.Choice") })
  |> should.be_true
  notes
  |> list.any(fn(note) { string.contains(note.text, "tag_collision.Choice") })
  |> should.be_true
}

pub fn front_emit_transport_and_client_are_generic_and_given_safe_test() {
  let transport = text("public/src/gen/live/transport_ffi.mjs")
  string.contains(
    transport,
    "export function send(method, path, body, blobFields, onOk, onError)",
  )
  |> should.be_true
  string.contains(transport, "ArticlePublish") |> should.be_false

  let client = text("public/priv/static/_yumemi/client.mjs")
  string.contains(client, "registerWithGiven") |> should.be_true
  string.contains(client, "data-yumemi-given") |> should.be_true
  string.contains(client, "pick-tag") |> should.be_true
  string.contains(client, "__YUMEMI_BUILD__") |> should.be_true
}

pub fn front_emit_blob_fields_issue_tokens_and_upload_only_registered_tokens_test() {
  let live = text("public/src/gen/live/article_blob_save.gleam")
  [
    "pub fn blob_file_input() -> List(attribute.Attribute(Event))",
    "event.on(\"change\", file_input_event(field))",
    "fn file_token(event: Dynamic) -> String",
    "live.Set(field, file_token(event))",
    "blob_fields: List(String)",
    "[\"blob\", \"existing\"]",
    "case args.existing",
    "\"\" -> json.null()",
  ]
  |> list.each(fn(row) { string.contains(live, row) |> should.be_true })

  let transport = text("public/src/gen/live/transport_ffi.mjs")
  [
    "const selectedFiles = new Map()",
    "const uploadedFiles = new Map()",
    "export function file_token(event)",
    "selectedFiles.set(token, file)",
    "selectedFiles.has(value) || uploadedFiles.has(value)",
  ]
  |> list.each(fn(row) { string.contains(transport, row) |> should.be_true })
  string.contains(transport, "document.addEventListener") |> should.be_false
}

pub fn front_emit_blob_upload_failure_precedes_and_skips_service_request_test() {
  let transport = text("public/src/gen/live/transport_ffi.mjs")
  string.contains(
    transport,
    "if (!response.ok) throw new Error(\"blob upload failed\")",
  )
  |> should.be_true
  let assert [_, after_upload] =
    string.split(transport, "await uploadToken(value)")
  string.contains(after_upload, "const response = await fetch(path")
  |> should.be_true
  string.contains(
    transport,
    "}).catch((error) => onError({ code: error?.message ?? \"network_error\" }))",
  )
  |> should.be_true
}

pub fn front_emit_blob_copy_entry_uses_attached_target_route_test() {
  let api = text("public/src/gen/api.gleam")
  string.contains(api, "  BlobCopy\n") |> should.be_true
  string.contains(
    api,
    "AttachedRoute(entry: BlobCopy, method: Post, path: \"/api/blobs\")",
  )
  |> should.be_true

  let live = text("public/src/gen/live/blob_copy.gleam")
  string.contains(live, "upload_file") |> should.be_true
  string.contains(live, "\"POST\",\n      \"/api/blobs\"") |> should.be_true
  string.contains(live, "live.Done(Ok(key))") |> should.be_true
}

pub fn client_bundle_uses_generated_output_over_input_test() {
  bundle_uses_generated_module() |> should.equal("PASS")
}

pub fn client_bundle_stops_on_undefined_import_test() {
  bundle_rejects_undefined_import() |> should.equal("PASS")
}

pub fn path_manifest_keeps_other_versions_test() {
  path_manifest_keeps_other_versions() |> should.equal("PASS")
}

pub fn client_bundle_failures_remain_per_face_notes_test() {
  let notes =
    yumemi_gen.bundle_notes([
      "www: app が無い",
      "muses: app が無い",
      "www: <bundle-temp>/www/src/gen/load/muse/arg_handle/space/arg_id/page.gleam:204 [space_title.view(it.space_list)]",
    ])
  list.length(notes) |> should.equal(3)
  let assert [www, muses, source] = notes
  www.class |> should.equal(stop.NotImplemented)
  muses.class |> should.equal(stop.NotImplemented)
  source.class |> should.equal(stop.ValueSource)
  string.contains(stop.report(notes), "[exit 1 生成器の不足] www:")
  |> should.be_true
  string.contains(stop.report(notes), "[exit 1 生成器の不足] muses:")
  |> should.be_true
  string.contains(stop.report(notes), "[exit 1 値の出所] www:")
  |> should.be_true
}

pub fn front_calls_without_face_route_are_exit_four_test() {
  let entry_text =
    "import framework/entry.{type Entry, Anonymous, AnySubject, Http, ReadOnly}\n\n"
    <> "pub type Subject {\n  Staff\n}\n\n"
    <> "pub type Host {\n  PublicHost\n}\n\n"
    <> "pub const entries: List(Entry(Subject, Host)) = [\n"
    <> "  Http(name: \"public\", hosts: [PublicHost], prefix: \"/api\", admit: Anonymous, subject: AnySubject, services: ReadOnly),\n"
    <> "]"
  let assert Ok(loaded_units) = source.load(fixture)
  let back_units =
    loaded_units
    |> list.filter(fn(unit) { unit.path != "entry" })
    |> list.append([source_unit("entry", entry_text)])
  let assert Ok(test_app) = reader.read(back_units)
  let assert Ok(face_units) = source.load("fixtures/article/public")
  let model_ = front_from_units_named("public", face_units, test_app.services)
  let notes =
    front_emit.route_notes(test_app, "public", model_, hash.of(back_units))
  stop.worst(notes) |> should.equal(4)
  notes
  |> list.any(fn(note) {
    string.contains(note.text, "article_publish")
    && string.contains(note.text, "api.gleam")
  })
  |> should.be_true
}

pub fn front_emit_live_follows_island_calls_and_reload_out_test() {
  let paths = files() |> list.map(fn(entry) { entry.0 })
  [
    "public/src/gen/live/article_create.gleam",
    "public/src/gen/live/article_publish.gleam",
  ]
  |> list.each(fn(path) { list.contains(paths, path) |> should.be_true })
  list.contains(paths, "public/src/gen/live/article_list.gleam")
  |> should.be_false

  let create = text("public/src/gen/live/article_create.gleam")
  string.contains(
    create,
    "pub type State = live.State(Args, article_list.Out, article_create.Out, Failure)",
  )
  |> should.be_true
  string.contains(create, "live.Set(Tags, value)") |> should.be_true
  string.contains(create, "spec.Pattern(min: 1, max: 64") |> should.be_true
  string.contains(create, "spec.Text(min: 1, max: 120)") |> should.be_true
  string.contains(create, "spec.Markdown") |> should.be_true
  string.contains(create, "#(next, reload_page())") |> should.be_true

  let publish = text("public/src/gen/live/article_publish.gleam")
  string.contains(publish, "pub type Field {\n  Slug\n}")
  |> should.be_true
  string.contains(
    publish,
    "pub type Error {\n  AlreadyPublished\n  AlreadyRetracted\n}",
  )
  |> should.be_true
  string.contains(publish, "  Refused(Error)\n  Broke(String)")
  |> should.be_true
  string.contains(publish, "\"already_published\" -> Refused(AlreadyPublished)")
  |> should.be_true
  string.contains(publish, "pub fn validate(model: State)") |> should.be_true

  let transport = text("public/src/gen/live/transport_ffi.mjs")
  string.contains(transport, "response.json().then(onError)") |> should.be_true
  string.contains(
    transport,
    "onError({ code: error?.message ?? \"network_error\" })",
  )
  |> should.be_true
}

pub fn front_emit_out_redefines_opaque_relations_test() {
  let out = text("public/src/gen/out/article_read.gleam")
  string.contains(out, "pub type Has(entity) {") |> should.be_true
  string.contains(out, "Has(value: String)") |> should.be_true
  string.contains(out, "pub type Multi(entity) {") |> should.be_true
  string.contains(out, "Multi(values: List(String))") |> should.be_true
  string.contains(out, "import framework/er") |> should.be_false
}

pub fn front_emit_out_imports_are_limited_to_face_allowlist_test() {
  files()
  |> list.filter(fn(entry) {
    string.starts_with(entry.0, "public/src/gen/out/")
  })
  |> list.flat_map(fn(entry) {
    entry.1
    |> string.split("\n")
    |> list.filter(string.starts_with(_, "import "))
  })
  |> list.each(fn(row) {
    let imported = string.drop_start(row, 7)
    let path = case string.split(imported, ".") {
      [value, ..] -> value
      [] -> imported
    }
    let allowed =
      string.starts_with(path, "gleam/")
      || string.starts_with(path, "framework/")
      || path == "gen/service"
    allowed |> should.be_true
  })
}

pub fn front_emit_copies_back_module_types_and_imports_blob_test() {
  let draft =
    synthetic_out(
      "draft_result",
      "import gen/draft/article.{type ArticleCreated}\n\npub const service: Service(Args, ArticleCreated, Error) = Nil",
      [],
    )
  string.contains(draft, "import gen/draft/article") |> should.be_false
  string.contains(draft, "pub type ArticleCreated {") |> should.be_true

  let ledger =
    synthetic_out(
      "ledger_result",
      "import ledger_store.{type LedgerStore}\n\npub const service: Service(Args, LedgerStore, Error) = Nil",
      [
        source_unit(
          "ledger_store",
          "pub type LedgerStoreId = String\n\npub type StoreType {\n  Soap\n  Delihel\n}\n\npub type LedgerStore {\n  LedgerStore(id: LedgerStoreId, kind: StoreType)\n}",
        ),
      ],
    )
  string.contains(ledger, "import ledger_store") |> should.be_false
  string.contains(ledger, "pub type LedgerStoreId = String")
  |> should.be_true
  string.contains(ledger, "pub type StoreType {") |> should.be_true
  string.contains(ledger, "pub type LedgerStore {") |> should.be_true

  let blob =
    synthetic_out(
      "blob_result",
      "import framework/blob.{type Blob}\n\npub type Result {\n  Result(blob: Blob)\n}\n\npub const service: Service(Args, Result, Error) = Nil",
      [],
    )
  string.contains(blob, "import framework/blob.{type Blob}") |> should.be_true
  string.contains(blob, "pub type Blob {") |> should.be_false
}

pub fn front_emit_reserves_entity_constructor_over_row_variant_test() {
  let out =
    synthetic_out(
      "row_collision",
      "import entity/article\n\npub type Row {\n  Article(kind: String, article: article.Article)\n}\n\npub type Out {\n  Out(rows: List(Row))\n}\n\npub const service: Service(Args, Out, Error) = Nil",
      [],
    )
  string.contains(out, "pub type Row {\n  ArticleRow(") |> should.be_true
}

pub fn front_emit_drops_enum_constructors_that_collide_with_row_test() {
  let out =
    synthetic_out(
      "enum_collision",
      "import entity/widget.{type Kind}\n\npub type Row {\n  Text(kind: Kind)\n}\n\npub type Out {\n  Out(rows: List(Row))\n}\n\npub const service: Service(Args, Out, Error) = Nil",
      [source_unit("entity/widget", "pub type Kind {\n  Text\n}")],
    )
  string.contains(out, "pub type Kind = String") |> should.be_true
  string.contains(out, "pub type Kind {") |> should.be_false
  string.contains(out, "pub type Row {\n  Text(") |> should.be_true
}

pub fn front_emit_flattens_value_alias_chain_test() {
  let base =
    model.App(..app(), value_types: [
      model.ValueType(
        name: "ledger_store_id",
        type_name: "LedgerStoreId",
        spec: "Uuid",
        backing: model.StringValue,
        range: None,
      ),
    ])
  let out =
    synthetic_out_for(
      base,
      "alias_chain",
      "import ledger_store.{type LedgerStoreId}\n\npub type Out {\n  Out(id: LedgerStoreId)\n}\n\npub const service: Service(Args, Out, Error) = Nil",
      [
        source_unit(
          "ledger_store",
          "import gen/types/ledger_store_id\n\npub type LedgerStoreId = ledger_store_id.LedgerStoreId",
        ),
      ],
    )
  string.contains(out, "pub type LedgerStoreId = String") |> should.be_true
  string.contains(out, "LedgerStoreIdLedgerStoreId") |> should.be_false
  string.contains(out, "LedgerStoreLedgerStoreId") |> should.be_false
}

pub fn front_emit_writes_one_out_file_per_service_test() {
  files()
  |> list.map(fn(entry) { entry.0 })
  |> list.filter(string.starts_with(_, "public/src/gen/out/"))
  |> list.length
  |> should.equal(7)
}

pub fn front_emit_load_layout_without_sources_uses_empty_data_test() {
  let layout = synthetic_empty_layout_load()
  string.contains(layout, "pub type Data {\n  Data\n}") |> should.be_true
  string.contains(layout, "pub fn load() -> Data {\n  Data\n}")
  |> should.be_true
}

pub fn front_emit_load_page_data_orders_root_fixed_and_widgets_test() {
  let page = text("public/src/gen/load/article/arg_slug/page.gleam")
  string.contains(
    page,
    "Data(\n    layout: layout.Data,\n    vars: Vars,\n    article_read: article_read.Out,\n    widget_list: Option(widget_list.Out),",
  )
  |> should.be_true
  string.contains(
    page,
    "vars: Vars,\n  widget_list: Option(widget_list.Out),\n  article_read: article_read.Out,",
  )
  |> should.be_true
}

pub fn front_emit_load_deduplicates_widget_service_sources_test() {
  let page = text("public/src/gen/load/article/arg_slug/page.gleam")
  string.contains(page, "widget_list: Option(widget_list.Out)")
  |> should.be_true
  text_occurrences(page, "widget_list: Option(widget_list.Out)")
  |> should.equal(2)
  string.contains(page, "article_kinds") |> should.be_false
  string.contains(page, "article_feed") |> should.be_false
  string.contains(page, "vars: Vars") |> should.be_true
  let shell = text("public/src/gen/shell.mjs")
  string.contains(shell, "widgetNameFor") |> should.be_false
  string.contains(shell, "widgetKeys") |> should.be_false
}

pub fn front_emit_shell_sends_every_non_path_arg_as_query_test() {
  let shell = text("public/src/gen/shell.mjs")
  string.contains(shell, "    if (used.has(name)) continue;\n")
  |> should.be_true
  string.contains(
    shell,
    "    if (typeof value === \"string\") target.searchParams.set(name, value);\n",
  )
  |> should.be_true
  string.contains(shell, "value instanceof Some) target.searchParams.set")
  |> should.be_false
}

pub fn front_emit_load_by_kind_matches_row_constructors_directly_test() {
  let page = text("public/src/gen/load/article/arg_slug/page.gleam")
  string.contains(page, "widget_list.ArticleRow(..)") |> should.be_true
  string.contains(page, "widget_list.Summary(..)") |> should.be_true
  string.contains(page, "row_article.view(row)") |> should.be_true
  string.contains(page, "page_definition.page") |> should.be_false
}

pub fn page_path_uses_folder_rules_and_reserved_suffix_test() {
  let units = [
    layout_unit("Layout(sp: Frame(areas: [], placements: []))"),
    source_unit(
      "pages/_/type_/arg_id/page",
      "pub const page: Page(service.Service, blocks.Block) = Page(of: None, layout: layout.demo, sp: Frame(areas: [], placements: []))",
    ),
  ]
  let value = front_from_units(units, [])
  let assert [page] = value.pages
  page.url |> should.equal("/-/type/{id}")
}

pub fn sample_presence_is_optional_and_block_variant_is_pascal_test() {
  let value =
    front_from_units(
      [
        layout_unit("Layout(sp: Frame(areas: [], placements: []))"),
        source_unit(
          "blocks/news_card",
          "pub type In = Nil\npub fn view(it: In) -> el.Element(Nil) { it }\npub const sample: In = Nil",
        ),
        source_unit(
          "blocks/empty_card",
          "pub type In = Nil\npub fn view(it: In) -> el.Element(Nil) { it }",
        ),
      ],
      [],
    )
  value.blocks
  |> list.map(fn(block) { #(block.name, block.has_sample) })
  |> should.equal([#("NewsCard", True), #("EmptyCard", False)])
}

pub fn service_variant_references_are_collected_from_page_widget_and_component_test() {
  let value =
    front_from_units(
      [
        layout_unit(
          "Layout(sp: Frame(areas: [], placements: [Widget(area: \"main\", of: service.ArticleList, render: One(blocks.Article))]))",
        ),
        source_unit(
          "pages/article/page",
          "pub const page: Page(service.Service, blocks.Block) = Page(of: None, layout: layout.demo, sp: Frame(areas: [], placements: []))",
        ),
        source_unit(
          "components/search",
          "pub const calls: List(service.Service) = [service.ArticleCreate]\npub const reloads: List(#(Slug, service.ArticleRead)) = [#(Slug, service.ArticleRead)]\npub fn view(it: State) -> el.Element(Event) { it }",
        ),
      ],
      [],
    )
  value.services
  |> should.equal(["ArticleList", "ArticleCreate", "ArticleRead"])
}

pub fn direct_attribute_class_is_exit_four_test() {
  let notes =
    front_notes(
      [
        layout_unit("Layout(sp: Frame(areas: [], placements: []))"),
        source_unit(
          "components/bad",
          "import lustre/attribute\npub fn view(it: State) -> el.Element(Event) { attribute.class(\"x\") }",
        ),
      ],
      [],
    )
  assert_one_note(notes, stop.Conflict, "attribute.class")
  stop.worst(notes) |> should.equal(4)
}

pub fn lustre_internal_import_is_exit_four_test() {
  let notes =
    front_notes(
      [
        layout_unit("Layout(sp: Frame(areas: [], placements: []))"),
        source_unit("components/bad", "import lustre/internals/constants"),
      ],
      [],
    )
  assert_one_note(notes, stop.Conflict, "lustre 内部 module")
  stop.worst(notes) |> should.equal(4)
}

pub fn nested_island_is_exit_four_test() {
  let notes =
    front_notes(
      [
        layout_unit("Layout(sp: Frame(areas: [], placements: []))"),
        source_unit(
          "components/bad",
          "import framework/front/el\npub fn view(it: State) -> el.Element(Event) { el.island(\"outer\", [el.island(\"inner\", [])]) }",
        ),
      ],
      [],
    )
  assert_one_note(notes, stop.Conflict, "島の中に島")
  stop.worst(notes) |> should.equal(4)
}

pub fn duplicate_top_area_is_exit_four_test() {
  let notes =
    front_notes(
      [
        layout_unit(
          "Layout(sp: Frame(areas: [Area(name: \"a\", flow: css.Stack(gap: style.s0), pin: css.Top, style: []), Area(name: \"b\", flow: css.Stack(gap: style.s0), pin: css.Top, style: [])], placements: []))",
        ),
      ],
      [],
    )
  assert_one_note(notes, stop.Conflict, "pin: Top")
  stop.worst(notes) |> should.equal(4)
}

pub fn missing_page_arg_is_exit_four_test() {
  let notes =
    front_notes(
      [
        layout_unit("Layout(sp: Frame(areas: [], placements: []))"),
        source_unit(
          "pages/article/arg_missing/page",
          "pub const page: Page(service.Service, blocks.Block) = Page(of: None, layout: layout.demo, vars: [], sp: Frame(areas: [], placements: []))",
        ),
      ],
      app().services,
    )
  assert_one_note(notes, stop.Conflict, "arg_missing 段を指す Path Var が無い")
  stop.worst(notes) |> should.equal(4)
}

pub fn widget_service_args_are_resolved_from_same_name_vars_test() {
  let value = article_front()
  let assert Ok(page_args) =
    list.find(value.page_service_args, fn(page_args) {
      page_args.page == "pages/article/arg_slug/page"
    })
  let assert Ok(widget_args) =
    list.find(page_args.services, fn(service) {
      service.service == "widget_list"
    })
  widget_args.args
  |> should.equal([
    front.ResolvedArg(
      name: "widget",
      source: front.VariableSource(name: "widget", from: front.Query("widget")),
    ),
    front.ResolvedArg(
      name: "slug",
      source: front.VariableSource(name: "slug", from: front.Path("slug")),
    ),
  ])
}

pub fn positional_and_mixed_var_arguments_and_origin_are_read_test() {
  let value = article_front()
  let assert Ok(page) =
    list.find(value.pages, fn(page) {
      page.module == "pages/article/arg_slug/page"
    })
  page.vars
  |> list.map(fn(var) { #(var.name, var.from) })
  |> should.equal([
    #("widget", front.Query("widget")),
    #("slug", front.Path("slug")),
    #("view_only", front.Path("slug")),
    #("term", front.Query("term")),
    #("subject_handle", front.Session("SubjectHandle")),
  ])
  value.layout.vars
  |> list.map(fn(var) { #(var.name, var.from) })
  |> should.equal([
    #("www_origin", front.Origin("public")),
    #("auth_origin", front.AuthOrigin),
  ])
}

pub fn labelled_origin_argument_is_read_test() {
  let assert Ok(units) = source.load("fixtures/article/public")
  let units =
    units
    |> list.map(fn(unit) {
      case unit.path == "layout" {
        True ->
          source_unit(
            unit.path,
            string.replace(
              unit.text,
              "Origin(\"public\")",
              "Origin(face: \"public\")",
            ),
          )
        False -> unit
      }
    })
  let value = front_from_units_named("public", units, app().services)
  value.layout.vars
  |> list.map(fn(var) { #(var.name, var.from) })
  |> should.equal([
    #("www_origin", front.Origin("public")),
    #("auth_origin", front.AuthOrigin),
  ])
}

pub fn unreadable_var_name_is_exit_four_and_emits_safe_field_test() {
  let page =
    "Page(of: None, layout: layout.public, theme: None, "
    <> "vars: [Var(name: dynamic_name, from: Query(\"q\"))], "
    <> "sp: Frame(areas: [], placements: [], cols: [], rows: [], template: []), "
    <> "pc: None, tablet: None)"
  let files =
    synthetic_front_files_with_layout_and_page(empty_variable_layout(), page)
  let assert Ok(#(_, generated)) =
    list.find(files, fn(file) {
      file.0 == "public/src/gen/load/article/arg_slug/page.gleam"
    })
  string.contains(generated, "invalid_var_0: String") |> should.be_true
  string.contains(generated, "vars[0]") |> should.be_false

  let notes =
    front_notes(
      [
        layout_unit(empty_variable_layout()),
        source_unit(
          "pages/example/page",
          page_source(variable_page(
            "[Var(name: dynamic_name, from: Query(\"q\"))]",
            "",
          )),
        ),
      ],
      app().services,
    )
  assert_variable_note(
    notes,
    2,
    "pages/example/page",
    "Var の name は文字列リテラルではない",
  )
}

pub fn block_arg_without_var_is_exit_four_test() {
  let notes =
    variable_negative_notes(
      "arg_without_var",
      "pages/example/page",
      empty_variable_layout(),
      variable_page(
        "[]",
        "Fixed(area: \"page\", block: blocks.Card, cell: Flow)",
      ),
    )
  assert_variable_note(notes, 1, "pages/example/page", "Block Card Arg.slug")
}

pub fn path_source_without_matching_route_segment_is_exit_four_test() {
  let notes =
    variable_negative_notes(
      "path_without_segment",
      "pages/example/page",
      empty_variable_layout(),
      variable_page(
        "[Var(name: \"id\", from: Path(\"slug\"))]",
        "Fixed(area: \"page\", block: blocks.Card, cell: Flow)",
      ),
    )
  assert_variable_note(notes, 2, "pages/example/page", "Path(\"slug\")")
}

pub fn query_option_to_string_arg_is_exit_four_test() {
  let notes =
    variable_negative_notes(
      "query_to_string",
      "pages/example/page",
      empty_variable_layout(),
      variable_page(
        "[Var(name: \"term\", from: Query(\"term\"))]",
        "Fixed(area: \"page\", block: blocks.Card, cell: Flow)",
      ),
    )
  assert_variable_note(notes, 3, "pages/example/page", "Block Card Arg.term")
}

pub fn required_service_arg_without_block_arg_is_exit_four_test() {
  let notes =
    variable_negative_notes(
      "required_service_arg_missing",
      "pages/example/arg_slug/page",
      empty_variable_layout(),
      variable_page(
        "[Var(name: \"slug\", from: Path(\"slug\"))]",
        "Fixed(area: \"page\", block: blocks.Card, cell: Flow)",
      ),
    )
  assert_variable_note(
    notes,
    4,
    "pages/example/arg_slug/page",
    "Service.article_read Args.slug",
  )
}

pub fn layout_path_var_is_exit_four_test() {
  let notes =
    variable_negative_notes(
      "layout_path_var",
      "pages/example/page",
      "Layout(vars: [Var(name: \"id\", from: Path(\"id\"))], sp: Frame(areas: [], placements: [], cols: [], rows: [], template: []), pc: None, tablet: None)",
      variable_page("[]", ""),
    )
  assert_variable_note(notes, 5, "layout", "Layout に Path を置けない")
}

pub fn bundled_block_input_is_exit_four_test() {
  let notes =
    variable_negative_notes(
      "bundled_input",
      "pages/example/page",
      empty_variable_layout(),
      variable_page(
        "[]",
        "Fixed(area: \"page\", block: blocks.Card, cell: Flow)",
      ),
    )
  assert_variable_note(notes, 6, "pages/example/page", "Block Card In In")
}

pub fn page_of_service_without_placement_is_exit_four_test() {
  let notes =
    variable_negative_notes(
      "of_not_placed",
      "pages/example/page",
      empty_variable_layout(),
      variable_page_of("Some(service.ArticleRead)", "[]", ""),
    )
  assert_variable_note(
    notes,
    7,
    "pages/example/page",
    "Page.of Service.ArticleRead",
  )
}

pub fn unused_var_is_warning_only_test() {
  let notes =
    variable_negative_notes(
      "unused_var",
      "pages/example/page",
      empty_variable_layout(),
      variable_page("[Var(name: \"unused\", from: Query(\"q\"))]", ""),
    )
  notes
  |> list.any(fn(note) {
    note.class == stop.Warning && string.contains(note.text, "Var.unused")
  })
  |> should.be_true
  stop.worst(notes) |> should.equal(0)
}

pub fn page_of_does_not_bind_service_args_without_block_arg_test() {
  let assert Ok(fixture_units) =
    source.load(
      front_overlay_negative_fixture <> "/required_service_arg_missing",
    )
  let blocks =
    fixture_units
    |> list.filter(fn(unit) { string.starts_with(unit.path, "blocks/") })
  let page_path = "pages/example/arg_slug/page"
  let page =
    variable_page_of(
      "Some(service.ArticleRead)",
      "[Var(\"slug\", Path(\"slug\"))]",
      "Fixed(area: \"page\", block: blocks.Card, cell: Flow)",
    )
  let units =
    list.append(
      [
        layout_unit(empty_variable_layout()),
        source_unit(page_path, page_source(page)),
      ],
      blocks,
    )
  let value = front_from_units(units, app().services)
  let assert Ok(page_args) =
    list.find(value.page_service_args, fn(item) { item.page == page_path })
  page_args.services
  |> should.equal([front.ServiceArgs(service: "article_read", args: [])])
  assert_variable_note(
    front_notes(units, app().services),
    4,
    page_path,
    "Service.article_read Args.slug",
  )
}

fn variable_negative_notes(
  fixture_name: String,
  page_path: String,
  layout: String,
  page: String,
) -> List(stop.Note) {
  let assert Ok(fixture_units) =
    source.load(front_overlay_negative_fixture <> "/" <> fixture_name)
  let blocks =
    fixture_units
    |> list.filter(fn(unit) { string.starts_with(unit.path, "blocks/") })
  let units =
    list.append(
      [
        layout_unit(layout),
        source_unit(page_path, page_source(page)),
      ],
      blocks,
    )
  front_notes(units, app().services)
}

fn empty_variable_layout() -> String {
  "Layout(vars: [], sp: Frame(areas: [], placements: [], cols: [], rows: [], template: []), pc: None, tablet: None)"
}

fn variable_page(vars: String, placement: String) -> String {
  variable_page_of("None", vars, placement)
}

fn variable_page_of(of: String, vars: String, placement: String) -> String {
  let placements = case placement {
    "" -> "[]"
    _ -> "[" <> placement <> "]"
  }
  "Page(of: "
  <> of
  <> ", layout: layout.demo, theme: None, vars: "
  <> vars
  <> ", sp: Frame(areas: [], placements: "
  <> placements
  <> ", cols: [], rows: [], template: []), pc: None, tablet: None)"
}

fn assert_variable_note(
  notes: List(stop.Note),
  number: Int,
  context: String,
  detail: String,
) -> Nil {
  stop.worst(notes) |> should.equal(4)
  let conflicts = list.filter(notes, fn(note) { note.class == stop.Conflict })
  list.length(conflicts) |> should.equal(1)
  let assert [note] = conflicts
  string.contains(note.text, "demo/" <> context <> ": [変数 ")
  |> should.be_true
  string.contains(note.text, "[変数 " <> int.to_string(number) <> "]")
  |> should.be_true
  string.contains(note.text, detail) |> should.be_true
  string.contains(note.text, "\n") |> should.be_false
}

pub fn missing_sp_frame_is_exit_three_test() {
  let notes =
    front_notes(
      [
        layout_unit("Layout(pc: Some(Frame(areas: [], placements: [])))"),
      ],
      [],
    )
  assert_one_note(notes, stop.Missing, "sp: が無い")
  stop.worst(notes) |> should.equal(3)
}

pub fn nested_layout_is_exit_four_test() {
  let notes =
    front_notes(
      [
        layout_unit(
          "Layout(sp: Frame(areas: [], placements: []), pc: Some(Layout(sp: Frame(areas: [], placements: []))))",
        ),
      ],
      [],
    )
  assert_one_note(notes, stop.Conflict, "Layout の中に Layout")
  stop.worst(notes) |> should.equal(4)
}

fn overlay_negative_notes(
  fixture_name: String,
  areas: String,
  placements: String,
  template: String,
) -> List(stop.Note) {
  let assert Ok(fixture_units) =
    source.load(front_overlay_negative_fixture <> "/" <> fixture_name)
  let block_units =
    fixture_units
    |> list.filter(fn(unit) { string.starts_with(unit.path, "blocks/") })
  let units =
    list.append(
      [
        source_unit("layout", overlay_negative_layout()),
        source_unit(
          "pages/example/page",
          overlay_negative_page(areas, placements, template),
        ),
      ],
      block_units,
    )
  front.notes(front_from_units_named("negative", units, []), [])
}

fn overlay_negative_layout() -> String {
  "import framework/front.{type Layout, Frame, Layout}\n"
  <> "import gleam/option.{None}\n\n"
  <> "pub const negative: Layout(Nil, Nil) = Layout(\n"
  <> "  sp: Frame(areas: [], placements: [], cols: [], rows: [], template: []),\n"
  <> "  pc: None,\n"
  <> "  tablet: None,\n"
  <> "  vars: [],\n"
  <> ")\n"
}

fn overlay_negative_page(
  areas: String,
  placements: String,
  template: String,
) -> String {
  "import framework/front.{type Page, Area, Fixed, Flow, Frame, Page}\n"
  <> "import framework/front/css\n"
  <> "import gleam/option.{None}\n"
  <> "import blocks\n\n"
  <> "pub const page: Page(Nil, Nil) = Page(\n"
  <> "  of: None,\n"
  <> "  layout: None,\n"
  <> "  theme: None,\n"
  <> "  sp: Frame(\n"
  <> "    areas: ["
  <> areas
  <> "],\n"
  <> "    placements: ["
  <> placements
  <> "],\n"
  <> "    cols: [],\n"
  <> "    rows: [],\n"
  <> "    template: "
  <> template
  <> ",\n"
  <> "  ),\n"
  <> "  pc: None,\n"
  <> "  tablet: None,\n"
  <> "  vars: [],\n"
  <> ")\n"
}

fn assert_overlay_exit_four(notes: List(stop.Note), expected: String) -> Nil {
  stop.worst(notes) |> should.equal(4)
  let conflicts = list.filter(notes, fn(note) { note.class == stop.Conflict })
  list.length(conflicts) |> should.equal(1)
  let assert [note] = conflicts
  stop.code(note.class) |> should.equal(4)
  string.contains(stop.line(note), "[exit 4 宣言の矛盾]") |> should.be_true
  string.contains(note.text, expected) |> should.be_true
}

fn article_front() -> front.Front {
  let assert Ok(units) = source.load("fixtures/article/public")
  front_from_units_named("public", units, app().services)
}

fn front_from_units(
  units: List(source.Unit),
  services: List(model.Service),
) -> front.Front {
  front_from_units_named("demo", units, services)
}

fn front_from_units_named(
  face: String,
  units: List(source.Unit),
  services: List(model.Service),
) -> front.Front {
  let assert Ok(value) = front.read(face, units, services)
  value
}

fn synthetic_front_files_with_layout(
  layout_body: String,
) -> List(#(String, String)) {
  let assert Ok(face_units) = source.load("fixtures/article/public")
  let face_units =
    face_units
    |> list.filter(fn(unit) { unit.path != "layout" })
    |> list.append([source_unit("layout", layout_source(layout_body))])
  synthetic_front_files(face_units)
}

fn synthetic_front_files_with_blob_theme() -> List(#(String, String)) {
  let assert Ok(back_units) = source.load(fixture)
  let assert Ok(article_read) =
    list.find(back_units, fn(unit) { unit.path == "service/article_read" })
  let article_read_text =
    article_read.text
    |> string.replace(
      "import gleam/option.{type Option, None}",
      "import framework/blob.{type Blob}\nimport gleam/option.{type Option, None}",
    )
    |> string.replace(
      "background_image: Option(String)",
      "background_image: Option(Blob)",
    )
  let back_units =
    list.map(back_units, fn(unit) {
      case unit.path == "service/article_read" {
        True -> source_unit("service/article_read", article_read_text)
        False -> unit
      }
    })
  let assert Ok(test_app) = reader.read(back_units)
  let assert Ok(face_units) = source.load("fixtures/article/public")
  let assert Ok(front_model) =
    front.read_with_package("public", "public", face_units, test_app.services)
  let package =
    face.Package(
      name: "public",
      path: "fixtures/article/public",
      pages: face.UndeclaredPages,
      units: face_units,
    )
  front_emit.emit(
    test_app,
    back_units,
    package,
    front_model,
    hash.of(back_units),
  )
  |> list.map(fn(file) { #(file.path, file.text) })
}

fn synthetic_front_files_with_layout_and_page(
  layout_body: String,
  page_body: String,
) -> List(#(String, String)) {
  let assert Ok(face_units) = source.load("fixtures/article/public")
  let face_units =
    face_units
    |> list.filter(fn(unit) {
      unit.path != "layout" && unit.path != "pages/article/arg_slug/page"
    })
    |> list.append([
      source_unit("layout", layout_source(layout_body)),
      source_unit("pages/article/arg_slug/page", page_source(page_body)),
    ])
  synthetic_front_files(face_units)
}

fn layout_source(body: String) -> String {
  "import framework/front.{type Layout}\n\n"
  <> "pub const public: Layout(service.Service, blocks.Block) = "
  <> body
}

fn page_source(body: String) -> String {
  "import framework/front.{type Page}\n\n"
  <> "pub const page: Page(service.Service, blocks.Block) = "
  <> body
}

fn synthetic_front_files(
  face_units: List(source.Unit),
) -> List(#(String, String)) {
  let test_app = app()
  let model_ = front_from_units_named("public", face_units, test_app.services)
  let package =
    face.Package(
      name: "public",
      path: "fixtures/article/public",
      pages: face.UndeclaredPages,
      units: face_units,
    )
  let assert Ok(back_units) = source.load(fixture)
  front_emit.emit(test_app, back_units, package, model_, hash.of(back_units))
  |> list.map(fn(file) { #(file.path, file.text) })
}

fn front_notes(
  units: List(source.Unit),
  services: List(model.Service),
) -> List(stop.Note) {
  let assert Ok(fixture_units) = source.load("fixtures/article/public")
  let assert Ok(shell) =
    list.find(fixture_units, fn(unit) { unit.path == "shell" })
  let units = case list.find(units, fn(unit) { unit.path == "shell" }) {
    Ok(_) -> units
    Error(_) -> list.append(units, [shell])
  }
  front.notes(front_from_units(units, services), services)
}

fn layout_unit(body: String) -> source.Unit {
  source_unit(
    "layout",
    "pub const demo: Layout(service.Service, blocks.Block) = " <> body,
  )
}

fn source_unit(path: String, text: String) -> source.Unit {
  let assert Ok(module) = glance.module(text)
  source.Unit(path: path, text: text, module: module)
}

fn assert_one_note(
  notes: List(stop.Note),
  class: stop.Class,
  text: String,
) -> Nil {
  let assert [note] = notes
  note.class |> should.equal(class)
  string.contains(note.text, text) |> should.be_true
}

// ── yumemi-hw-1 ── 初期の相の綴りに依らない placeholder の数え ────────────────

/// 呼び手の入力の placeholder は最初の文字列 literal(初期の相)より前を数える。
/// 相が `'draft'` でない Entity(`'pending'` など)でも、相の後ろの `entered_*` を数えない。
pub fn create_sql_placeholder_count_ignores_the_phase_spelling_test() {
  create_sql_input_placeholder_count(
    "INSERT INTO app.order(a,b,phase,entered_pending)\n SELECT $1,$2::uuid,'pending',$3::timestamptz\n",
  )
  |> should.equal(2)
  create_sql_input_placeholder_count(
    " SELECT $1,$2,$3,$4,next_order.next_order,$5,'draft',$6::timestamptz",
  )
  |> should.equal(5)
  // 相の無い Entity は行の全部が呼び手の入力。
  create_sql_input_placeholder_count(
    "VALUES($1,$2,$3::boolean,$4) RETURNING id",
  )
  |> should.equal(4)
}
