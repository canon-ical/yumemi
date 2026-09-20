//// リポ内 fixture ── 20-programming-model「まず実物から」の Article アプリ(★ 11 ファイル)。
//// 本文から機械的に写したもので、手を入れていない。生成が通ることと、
//// 20 が本文で名指しした ▲ の形(From / Arrow / 戻りの型)が出ることを見る。

import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import gleeunit/should
import yumemi_gen
import yumemi_gen/digest
import yumemi_gen/emit/hash
import yumemi_gen/emit/query
import yumemi_gen/model
import yumemi_gen/naming
import yumemi_gen/reader
import yumemi_gen/source
import yumemi_gen/stop

const fixture = "fixtures/article"

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

const entry_prefix_fixture = "fixtures/entry_prefix_validation"

const faces_missing_entry_fixture = "fixtures/faces_missing_entry"

const faces_empty_entries_fixture = "fixtures/faces_empty_entries"

const faces_unknown_fixture = "fixtures/faces_unknown"

const composite_root_route_fixture = "fixtures/composite_root_route"

const sql_unsupported_fixture = "fixtures/sql_unsupported"

const route_suffix_fixture = "fixtures/route_suffix"

const route_ambiguous_fixture = "fixtures/route_ambiguous"

const route_external_fixture = "fixtures/route_external"

const route_nested_fixture = "fixtures/route_nested"

pub fn main() {
  gleeunit.main()
}

fn app() -> model.App {
  let assert Ok(units) = source.load(fixture)
  let assert Ok(loaded) = reader.read(units)
  loaded
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

// ── 入力 ────────────────────────────────────────────────────────────────────

pub fn all_eleven_star_files_parse_test() {
  let assert Ok(units) = source.load(fixture)
  list.length(units) |> should.equal(11)
}

pub fn types_entities_services_counted_test() {
  let loaded = app()
  list.length(loaded.value_types) |> should.equal(5)
  list.length(loaded.entities) |> should.equal(4)
  list.length(loaded.services) |> should.equal(5)
}

pub fn lifecycle_read_from_edges_test() {
  let assert Some(article) = model.entity_by_name(app().entities, "Article")
  article.phases
  |> should.equal(["Draft", "Scheduled", "Published", "Retracted"])
  article.key_prop |> should.equal("slug")
  article.collection |> should.equal("articles")
}

pub fn article_http_route_table_has_seven_rows_test() {
  let face = text("src/gen/face.gleam")
  string.contains(face, "pub type Face {\n  Public\n  Admin\n}")
  |> should.be_true
  let http = text("src/gen/entry/http.gleam")
  [
    "Route(face: \"admin\", method: \"POST\", path: \"/api/admin/articles\", service: \"article_create\", path_keys: [], credential: Session),",
    "Route(face: \"public\", method: \"GET\", path: \"/api/articles\", service: \"article_list\", path_keys: [], credential: Session),",
    "Route(face: \"admin\", method: \"GET\", path: \"/api/admin/articles\", service: \"article_list\", path_keys: [], credential: Session),",
    "Route(face: \"public\", method: \"GET\", path: \"/api/articles/{slug}\", service: \"article_read\", path_keys: [\"slug\"], credential: Session),",
    "Route(face: \"admin\", method: \"GET\", path: \"/api/admin/articles/{slug}\", service: \"article_read\", path_keys: [\"slug\"], credential: Session),",
    "Route(face: \"admin\", method: \"POST\", path: \"/api/admin/articles/{slug}/publish\", service: \"article_publish\", path_keys: [\"slug\"], credential: Session),",
    "Route(face: \"admin\", method: \"POST\", path: \"/api/admin/articles/{slug}/retract\", service: \"article_retract\", path_keys: [\"slug\"], credential: Session),",
  ]
  |> list.each(fn(row) { string.contains(http, row) |> should.be_true })
  http
  |> string.split("\n")
  |> list.filter(fn(line) {
    string.starts_with(line, "  Route(face:")
    && string.contains(line, "path: \"")
  })
  |> list.length
  |> should.equal(7)
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
    "Route(face: \"test\", method: \"POST\", path: \"/test/free_spaces/add\", service: \"space_add\", path_keys: [], credential: Session),",
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
  // article_list は名前付きクエリ、他の4本は root Article の矢印。
  list.filter(paths, string.starts_with(_, "src/gen/reads/"))
  |> should.equal([
    "src/gen/reads/article_create.gleam",
    "src/gen/reads/article_list.gleam",
    "src/gen/reads/article_publish.gleam",
    "src/gen/reads/article_read.gleam",
    "src/gen/reads/article_retract.gleam",
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
  string.contains(read, "pub type Actor {") |> should.be_true
  string.contains(read, "Anonymous") |> should.be_true
  string.contains(read, "AsStaff(staff.Staff)") |> should.be_true

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
  ])
}

pub fn relation_presence_and_with_become_sql_test() {
  let related =
    text_of(relation_fixture, "db/queries/photo_filter/related.sql")
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
    string.starts_with(path, "db/queries/")
    && string.contains(path, "/to_")
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
  let album =
    text_of(relation_fixture, "db/queries/photo_read/to_album.sql")
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
  |> list.each(fn(entry) {
    let #(path, found) = entry
    case string.ends_with(path, ".sql") {
      True -> string.starts_with(found, "-- GENERATED ") |> should.be_true
      False -> string.starts_with(found, "//// GENERATED ") |> should.be_true
    }
  })
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
  string.contains(stage, "FROM app.photo e WHERE e.album_id=$1 FOR UPDATE")
  |> should.be_true
  let apply =
    text_of(relation_fixture, "db/queries/verb/reorder_photos.sql")
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
  |> list.filter(fn(entry) {
    string.starts_with(entry.0, "db/queries/verb/")
  })
  |> list.each(fn(entry) {
    string.starts_with(entry.1, "-- GENERATED from entity.")
    |> should.be_true
    string.contains(entry.1, "service.")
    |> should.be_false
  })
}

pub fn composite_key_is_present_in_signature_where_and_returning_test() {
  let update =
    text_of(flag_fixture, "db/queries/verb/update_chunk_text.sql")
  let delete = text_of(flag_fixture, "db/queries/verb/delete_chunk.sql")
  string.contains(update, "WHERE a=$1 AND b=$2 AND c=$3")
  |> should.be_true
  string.contains(update, "RETURNING a,b,c") |> should.be_true
  string.contains(delete, "WHERE a=$1 AND b=$2 AND c=$3")
  |> should.be_true
  string.contains(delete, "RETURNING a,b,c") |> should.be_true
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
    "INSERT INTO app.article(slug,title,body,version,\"order\",category_id)",
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
  let found =
    text_of(flag_fixture, "db/queries/widget_list/first_place.sql")
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
