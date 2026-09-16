// ★ src/service/article_read.gleam
//// Service read ── 記事を1件読む。一般に見えるのは Published だけ。下書きと取り下げ済みは Staff にしか見えない。
import entity/article
import entity/category
import entity/tag
import framework/effect.{type Effect, Read}
import framework/step.{type Start, type Step}
import gen/allow/article as allow
import gen/reads/article_read as reads
import gen/root/article_read.{type Actor, type Root, type Service, Service}
import gen/types/slug.{type Slug}

pub const effect: Effect = Read

pub type Args {
  Args(slug: Slug)
}

/// 返す形。ここが入口の契約(JSON / MCP の output schema)の正本になる。
pub type Out {
  Out(
    article: article.Article,
    category: category.Category,
    tags: List(tag.Tag),
  )
}

/// 業務上の失敗が無い Service は構成子ゼロの型で書く ── 「失敗しない」が型で言える。
pub type Error

pub const service: Service(Args, Out, Error) = Service(
  allow: [
    allow.staff,
    allow.Clause(
      who: allow.Anyone,
      at: allow.Only([article.Published]),
      owner: allow.NoOwner,
    ),
  ],
  logic: logic,
)

/// allow に Staff と Anyone が混じるので、第1引数はこの Service 用に生成された
/// Actor sum(`Anonymous | AsStaff(staff.Staff)`)になる。allow に無い主体は variant に無い。
/// 矢印を辿る read は root 相対に生成された関数(`gen/reads/article_read`)── 存在しない矢印は関数が無い。
pub fn logic(_by: Actor, it: Root, _args: Args) -> Step(Out, Error, Start) {
  use category <- reads.to_category(it)
  use tags <- reads.to_tags(it)
  step.done(Out(article: it.article, category: category, tags: tags))
}
