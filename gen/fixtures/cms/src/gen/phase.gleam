//// GENERATED from entity declarations / edges [sha256:4d63034cce6e] — 手で編集しない

import entity/article

pub type ArticleStep {
  ArticleDraftToPublished
  ArticleDraftToScheduled
  ArticleScheduledToDraft
  ArticlePublishedToRetracted
}

pub fn article_from(step: ArticleStep) -> article.Phase {
  case step {
    ArticleDraftToPublished -> article.Draft
    ArticleDraftToScheduled -> article.Draft
    ArticleScheduledToDraft -> article.Scheduled
    ArticlePublishedToRetracted -> article.Published
  }
}

pub fn article_to(step: ArticleStep) -> article.Phase {
  case step {
    ArticleDraftToPublished -> article.Published
    ArticleDraftToScheduled -> article.Scheduled
    ArticleScheduledToDraft -> article.Draft
    ArticlePublishedToRetracted -> article.Retracted
  }
}
