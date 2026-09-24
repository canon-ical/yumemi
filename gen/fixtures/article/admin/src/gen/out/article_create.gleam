//// GENERATED from src/service/article_create.gleam [sha256:f1d1d3f20711] — 手で編集しない

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
