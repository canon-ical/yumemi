import framework/er
import framework/page
import gleam/option.{type Option, None}

pub type Category {
  Category(name: String)
}

pub type Tag {
  Tag(name: String)
}

pub type Article {
  Article(
    slug: String,
    title: String,
    body: String,
    version: Int,
    order: Int,
    category: er.Has(String),
    tags: er.Multi(String),
  )
}

pub type ArticleRead {
  ArticleRead(
    article: Article,
    category: Category,
    tags: List(Tag),
    theme: Option(String),
  )
}

pub type ArticleList {
  ArticleList(page: page.Page(Article), counts: List(#(Category, Int)))
}

pub type WidgetRow {
  ArticleRow(kind: String, article: Article)
  SummaryRow(kind: String, article: Article)
}

pub type WidgetList {
  WidgetList(rows: List(WidgetRow))
}

pub type CreateOut {
  CreateOut(slug: String, phase: String)
}

pub type SavedOut {
  SavedOut(saved: Bool)
}

pub type UploadOut {
  UploadOut(key: er.Key(String), content_type: String)
}

@external(javascript, "./back_values_ffi.mjs", "row")
fn row(key: String) -> er.Row

pub fn article(version: Int) -> Article {
  Article(
    slug: "article",
    title: "本日の記事",
    body: "夜のシフトが得意な新人です。よろしくお願いします。",
    version: version,
    order: 0,
    category: er.from_row(row("news")),
    tags: er.multi_from_rows([row("fixture")]),
  )
}

pub fn article_read() -> ArticleRead {
  ArticleRead(
    article: article(1),
    category: Category("news"),
    tags: [Tag("fixture")],
    theme: None,
  )
}

pub fn article_list() -> ArticleList {
  ArticleList(page: page.Page(items: [], next: None), counts: [
    #(Category("fixture"), 1),
    #(Category("gleam"), 1),
    #(Category("cloudflare"), 1),
  ])
}

pub fn widget_list() -> WidgetList {
  WidgetList(rows: [ArticleRow(kind: "Article", article: article(1))])
}

pub fn widget_list_with_summary() -> WidgetList {
  WidgetList(rows: [
    ArticleRow(kind: "Article", article: article(1)),
    SummaryRow(kind: "Summary", article: article(2)),
  ])
}

pub fn upload_response() -> UploadOut {
  UploadOut(key: er.key("uploaded-image-key"), content_type: "image/png")
}

pub fn created() -> CreateOut {
  CreateOut(slug: "article", phase: "draft")
}

pub fn saved() -> SavedOut {
  SavedOut(saved: True)
}
