//// GENERATED from entity declarations [sha256:5a7812900d2a] — 手で編集しない

import entity/article
import entity/category
import entity/tag
import gen/types/category_name.{type CategoryName}
import gen/types/slug.{type Slug}
import gen/types/tag_name.{type TagName}
import yumemi/er.{type Key}

pub fn article(id: Slug) -> Key(article.Article) {
  er.key(slug.to_string(id))
}

pub fn category(id: CategoryName) -> Key(category.Category) {
  er.key(category_name.to_string(id))
}

pub fn tag(id: TagName) -> Key(tag.Tag) {
  er.key(tag_name.to_string(id))
}
