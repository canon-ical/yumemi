//// Service publish ── 下書きを公開する。1 module 1 Service。
//// オーナーが読むのはこのファイル。ここに書かれていない判断は実装に存在しない。

// ★ src/service/article_publish.gleam
import entity/article
import entity/staff
import framework/effect.{type Effect, Write}
import framework/step.{type Start, type Step}
import gen/allow/article as allow
import gen/face.{type Face, Admin, Public}
import gen/phase
import gen/root/article_publish.{type Root, type Service, Service}
import gen/types/slug.{type Slug}
import gen/verb

pub const effect: Effect = Write

pub const faces: List(Face) = [Public, Admin]

/// 引数。root Entity の識別子と同じ Type のフィールドが URL に乗る。
pub type Args {
  Args(slug: Slug)
}

/// 業務エラー。variant 名がそのまま全入口のエラーコードになる。
pub type Error {
  AlreadyPublished
  AlreadyRetracted
}

pub const service: Service(Args, article.Article, Error) = Service(
  allow: [allow.staff],
  logic: logic,
)

/// 主体・root・引数 → 手順書。root(この slug の記事)は framework が読んで渡す ──
/// 居なければ Logic に届く前に「不在」。フェーズも `it.phase` に入っている。
/// allow が Staff だけなので、生成器は第1引数を staff.Staff に絞る(sum を case で割る必要が無い)。
pub fn logic(
  _by: staff.Staff,
  it: Root,
  _args: Args,
) -> Step(article.Article, Error, Start) {
  case it.phase {
    article.Draft -> {
      use _ <- step.apply(verb.advance_article(
        it.article.slug,
        phase.ArticleDraftToPublished,
      ))
      step.done(it.article)
    }
    article.Published -> step.fail(AlreadyPublished)
    article.Retracted -> step.fail(AlreadyRetracted)
  }
}
