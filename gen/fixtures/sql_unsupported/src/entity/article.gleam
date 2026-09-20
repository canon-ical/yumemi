import entity/category.{type Category}
import framework/er.{type Has}

pub type Article {
  Article(id: Int, category: Has(Category))
}

pub fn key(it: Article) -> Int {
  it.id
}

pub const collection: String = "articles"
