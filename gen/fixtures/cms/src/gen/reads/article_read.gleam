//// GENERATED from service.article_read [sha256:2099dc390777] — 手で編集しない

import entity/category
import entity/tag
import gen/root/article_read.{type Root}
import gleam/list
import yumemi/er
import yumemi/io.{type Context, type Promise}
import yumemi/step.{type Step}

/// 矢印 ArticleToCategory(article.category -> category)。関係先の取得と復号は Context の契約 `relation`。
const to_category_relation = io.Relation(
  service: "article_read",
  query: "to_category",
  arrow: "ArticleToCategory",
  from: "article",
  prop: "category",
  target: "category",
)

pub fn to_category(
  it: Root,
  then: fn(category.Category) -> Step(out, err, state),
) -> Step(out, err, state) {
  step.read(
    fn(ctx) {
      io.relation_one(
        ctx,
        to_category_relation,
        er.to_string(er.of(it.article.category)),
      )
    },
    then,
  )
}

/// 矢印 ArticleToTags(article.tags -> tag)。関係先の取得と復号は Context の契約 `relation`。
const to_tags_relation = io.Relation(
  service: "article_read",
  query: "to_tags",
  arrow: "ArticleToTags",
  from: "article",
  prop: "tags",
  target: "tag",
)

pub fn to_tags(
  it: Root,
  then: fn(List(tag.Tag)) -> Step(out, err, state),
) -> Step(out, err, state) {
  step.read(
    fn(ctx) {
      io.relation_many(
        ctx,
        to_tags_relation,
        list.map(er.of_multi(it.article.tags), er.to_string),
      )
    },
    then,
  )
}
