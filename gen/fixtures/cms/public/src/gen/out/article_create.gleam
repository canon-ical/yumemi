//// GENERATED from src/service/article_create.gleam [sha256:d8788e77830b] — 手で編集しない

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
