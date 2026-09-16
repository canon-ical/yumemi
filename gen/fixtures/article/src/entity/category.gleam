// ★ src/entity/category.gleam
//// Entity Category ── 記事の分類。Lifecycle は無い。
import gen/types/category_name.{type CategoryName}

pub type Category {
  Category(name: CategoryName)
}

/// 識別子。Property を1つ返す純関数で書く ── コンパイラが存在を検査し、生成器が本体を読む。
pub fn key(it: Category) -> CategoryName {
  it.name
}

/// 入口での集合名。英語の複数形は判断の余地があるので宣言する。
pub const collection: String = "categories"
