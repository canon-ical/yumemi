//// Service widget_list ── front の枠へ記事の行を返す集合レベルの読み。

// ★ src/service/widget_list.gleam
import entity/article
import framework/effect.{type Effect, Read}
import framework/step.{type Start, type Step}
import gen/allow/article as allow
import gen/face.{type Face, Admin, Public}
import gen/query as q
import gen/reads/widget_list as reads
import gen/root/widget_list.{type Actor, type Root, type Service, Service}
import gleam/list
import widget_key.{type WidgetKey}

pub const effect: Effect = Read

pub const faces: List(Face) = [Public, Admin]

pub type Args {
  Args(widget: WidgetKey)
}

pub type Out {
  Out(rows: List(Row))
}

pub type Row {
  Article(kind: String, article: article.Article)
  Summary(kind: String, article: article.Article)
}

pub type Error

pub type P {
  Items
}

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

pub fn logic(_by: Actor, _it: Root, args: Args) -> Step(Out, Error, Start) {
  use rows <- reads.items()
  let rows = case args.widget {
    widget_key.ArticleFeed ->
      list.map(rows, fn(row) { Article(kind: "Article", article: row.0) })
    widget_key.ArticleKinds ->
      list.map(rows, fn(row) { Summary(kind: "Summary", article: row.0) })
  }
  step.done(Out(rows: rows))
}
