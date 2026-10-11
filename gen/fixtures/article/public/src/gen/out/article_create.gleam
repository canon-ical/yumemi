//// GENERATED from src/service/article_create.gleam [sha256:43db2627c6d8] — 手で編集しない

pub type Slug =
  String

pub type Phase {
  Draft
  Scheduled
  Published
  Retracted
}

pub type Out {
  Out(slug: Slug, phase: Phase)
}
