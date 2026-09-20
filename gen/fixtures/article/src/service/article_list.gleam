//// Service list ── 公開済みの記事を新しい順に返す。カテゴリ別の件数も一緒に返す。
//// 集合レベル(パス変数0個)。読みは矢印を辿るだけでなくクエリ値でも書ける ──
//// 集計は都度クエリで、導出 Entity もマテビューも作らない(2026-09-04 人見裁定)。
//// クエリ値は名前付きの `pub const` として置き、生成器が名前ごとに型付きの read 関数を吐く。

// ★ src/service/article_list.gleam
import entity/article
import entity/category
import framework/effect.{type Effect, Read}
import framework/page.{type Cursor, type Page, type PageSize}
import framework/step.{type Start, type Step}
import gen/allow/article as allow
import gen/face.{type Face, Admin, Public}
import gen/query as q
import gen/reads/article_list as reads
import gen/root/article_list.{type Actor, type Root, type Service, Service}
import gleam/option.{type Option}

pub const effect: Effect = Read

pub const faces: List(Face) = [Public, Admin]

pub type Args {
  Args(limit: PageSize, cursor: Option(Cursor))
}

pub type Out {
  Out(page: Page(article.Article), counts: List(#(category.Category, Int)))
}

pub type Error

/// クエリ値の穴の名前。型は生成器が比較相手の列から導く(Limit → PageSize、Cursor → Option(Cursor))。
pub type P {
  Limit
  Cursor
}

/// ① 新しい順に、カーソルで刻む。業務の絞りが無いので where は空 ──
///    認可のフェーズ絞りは allow の `at` が注入して AND で交わる(下記)。
///    ArticleEnteredPublished は Property ではなくフェーズ到達の時刻 ──
///    「フェーズ列がそのまま履歴になる」(手順1)ので published_at は要らない。
pub const items: q.Select(P) = q.Select(
  from: q.Article,
  join: [],
  where: [],
  group: [],
  having: [],
  agg: [],
  along: [],
  with: [],
  order: [q.Desc(q.ArticleEnteredPublished)],
  limit: q.Paged(size: q.Param(Limit), after: q.Param(Cursor)),
)

/// ② カテゴリ別の件数。毎回数える。ここにも同じ `at` が注入されるので、
///    Anyone には公開済みの件数、Staff には全フェーズの件数が返る ──
///    呼び手によって数が変わるが、認可の宣言と必ず一致する。
///    `Via` は「関係先ごとに群を切る」── 結果の型は `List(#(Category, Int))`。
pub const counts: q.Select(P) = q.Select(
  from: q.Article,
  join: [],
  where: [],
  group: [q.Via(q.ArticleToCategory)],
  having: [],
  agg: [q.Count],
  along: [],
  with: [],
  order: [q.DescAgg(q.Count)],
  limit: q.NoLimit,
)

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

/// 集合レベルなので Root に個体は無い(`at` と `seed` だけ)。read は名前付きクエリ値ごとの生成関数。
pub fn logic(_by: Actor, _it: Root, args: Args) -> Step(Out, Error, Start) {
  use page <- reads.items(limit: args.limit, cursor: args.cursor)
  use counts <- reads.counts()
  step.done(Out(page: page, counts: counts))
}
