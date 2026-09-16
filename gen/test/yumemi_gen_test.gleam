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
  article.phases |> should.equal(["Draft", "Published", "Retracted"])
  article.key_prop |> should.equal("slug")
  article.collection |> should.equal("articles")
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
    "ArticleEnteredPublished",
    "ArticleEnteredRetracted",
  ]
  |> list.each(fn(name) { string.contains(found, name) |> should.be_true })
}

// ── 束3 読みの器 ────────────────────────────────────────────────────────────

pub fn reads_are_emitted_per_service_with_named_queries_test() {
  let paths = list.map(files(), fn(entry) { entry.0 })
  // 名前付きクエリ値を持つのは article_list だけ。
  list.filter(paths, string.starts_with(_, "src/gen/reads/"))
  |> should.equal(["src/gen/reads/article_list.gleam"])
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

// ── 束4 読みの SQL ──────────────────────────────────────────────────────────

pub fn one_statement_per_named_query_test() {
  let paths = list.map(files(), fn(entry) { entry.0 })
  list.filter(paths, string.starts_with(_, "gen/sql/queries/"))
  |> list.sort(string.compare)
  |> should.equal([
    "gen/sql/queries/article_list/counts.sql",
    "gen/sql/queries/article_list/items.sql",
  ])
}

pub fn keyset_uses_the_order_columns_and_the_key_test() {
  let found = text("gen/sql/queries/article_list/items.sql")
  string.contains(found, "(a.entered_published,a.slug)<") |> should.be_true
  string.contains(found, "ORDER BY a.entered_published DESC,a.slug DESC")
  |> should.be_true
  // Paged は size + 1 件取って次の頁が在るかを見る
  string.contains(found, "LIMIT $1 + 1") |> should.be_true
}

pub fn group_becomes_group_by_test() {
  let found = text("gen/sql/queries/article_list/counts.sql")
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
  let found = text_of(flag_fixture, "gen/sql/queries/widget_list/shown.sql")
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
  let found = text_of(flag_fixture, "gen/sql/queries/widget_list/all.sql")
  string.contains(found, "ORDER BY w.id ASC") |> should.be_true
}

pub fn optional_column_asc_gets_nulls_last_test() {
  let found =
    text_of(flag_fixture, "gen/sql/queries/widget_list/first_place.sql")
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

// ── 出力が不整合なら 0 で終わらない(柏木 P2-2) ──────────────────────────────

pub fn mixed_direction_keyset_is_reported_not_silent_test() {
  let paths = list.map(files_of(flag_fixture), fn(entry) { entry.0 })
  // reads は出るが SQL は出ない ── この不整合を黙って 0 で終わらせない。
  list.contains(paths, "src/gen/reads/widget_page.gleam") |> should.be_true
  list.contains(paths, "gen/sql/queries/widget_page/paged.sql")
  |> should.be_false
  list.contains(paths, "_diagnostics.txt") |> should.be_true
}

pub fn the_exit_code_comes_from_the_worst_note_test() {
  let notes = notes_of(flag_fixture)
  list.length(notes) |> should.equal(1)
  stop.worst(notes) |> should.equal(1)
  let assert [note] = notes
  note.class |> should.equal(stop.NotImplemented)
  string.contains(note.text, "widget_page/paged") |> should.be_true
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
}
