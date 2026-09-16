// ★ src/service/article_create.gleam
//// Service create ── 記事を新規に作る。作られた記事は Lifecycle の先頭(Draft)から始まる。
//// 個体を指さない集合レベルの Service なので、Root に root 個体は入らない。
import entity/category
import entity/staff
import entity/tag
import framework/effect.{type Effect, Write}
import framework/er.{type Key}
import framework/step.{type Start, type Step}
import gen/allow/article as allow
import gen/draft/article.{type ArticleDraft, ArticleDraft}
import gen/root/article_create.{type Root, type Service, Service}
import gen/types/body.{type Body}
import gen/types/slug.{type Slug}
import gen/types/title.{type Title}
import gen/verb

pub const effect: Effect = Write

/// root の識別子と同じ Type のフィールドが無い ── パス変数0個 = 集合レベル。
/// 関係は `Key(_)`(相手の識別子)で受ける。Entity の値そのものは引数に取れない。
pub type Args {
  Args(
    slug: Slug,
    title: Title,
    body: Body,
    category: Key(category.Category),
    tags: List(Key(tag.Tag)),
  )
}

/// slug の重複と Category の不在は ER の規則(一意制約・RESTRICT)なので、ここには書かない ──
/// writes が落とし、生成器が `article_slug_taken` / `article_category_missing` を付ける。
pub type Error

pub const service: Service(Args, Slug, Error) = Service(
  allow: [allow.staff],
  logic: logic,
)

/// 手順書。基礎動詞を溜めて(apply)、末尾で確定する(done)。transaction は1つ。
pub fn logic(
  _by: staff.Staff,
  _it: Root,
  args: Args,
) -> Step(Slug, Error, Start) {
  use article <- step.apply(verb.create_article(ArticleDraft(
    slug: args.slug,
    title: args.title,
    body: args.body,
    category: args.category,
    tags: args.tags,
  )))
  step.done(article.slug)
}
