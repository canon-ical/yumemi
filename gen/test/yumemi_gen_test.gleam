//// リポ内 fixture ── 20-programming-model「まず実物から」の Article アプリ(★ 11 ファイル)。
//// 本文から機械的に写したもので、手を入れていない。生成が通ることと、
//// 20 が本文で名指しした ▲ の形(From / Arrow / 戻りの型)が出ることを見る。

import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import gleeunit/should
import yumemi_gen
import yumemi_gen/model
import yumemi_gen/naming
import yumemi_gen/reader
import yumemi_gen/source

const fixture = "fixtures/article"

pub fn main() {
  gleeunit.main()
}

fn app() -> model.App {
  let assert Ok(units) = source.load(fixture)
  let assert Ok(loaded) = reader.read(units)
  loaded
}

fn files() -> List(#(String, String)) {
  let assert Ok(generated) = yumemi_gen.generate(fixture)
  list.map(generated, fn(file) { #(file.path, file.text) })
}

fn text(path: String) -> String {
  let assert Ok(#(_, found)) =
    list.find(files(), fn(entry) { entry.0 == path })
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
  string.contains(found, "//// GENERATED from types.slug — 手で編集しない")
  |> should.be_true
  string.contains(found, "pub opaque type Slug {") |> should.be_true
  string.contains(found, "spec.validate(raw, types.slug)") |> should.be_true
}

// ── 束2 読みの語彙 ──────────────────────────────────────────────────────────

pub fn from_has_one_variant_per_entity_test() {
  let found = text("src/gen/query.gleam")
  string.contains(found, "pub type From {\n  Article\n  Category\n  Staff\n  Tag\n}")
  |> should.be_true
}

pub fn arrow_has_one_variant_per_relation_test() {
  let found = text("src/gen/query.gleam")
  string.contains(found, "pub type Arrow {\n  ArticleToCategory\n  ArticleToTags\n}")
  |> should.be_true
}

pub fn to_many_relation_is_not_a_column_test() {
  let found = text("src/gen/query.gleam")
  // multi(Tag) は中間表に居るので Field にしない。矢印にだけ出る。
  string.contains(found, "ArticleTags\n") |> should.be_false
  string.contains(found, "ArticleCategory\n") |> should.be_true
}

pub fn phase_and_arrival_columns_are_generated_test() {
  let found = text("src/gen/query.gleam")
  ["ArticlePhase", "ArticleEnteredDraft", "ArticleEnteredPublished",
   "ArticleEnteredRetracted"]
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
