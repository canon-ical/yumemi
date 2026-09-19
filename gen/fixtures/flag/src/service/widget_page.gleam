// ★ src/service/widget_page.gleam
//// Service widget_page ── 向きの混じった `order` で `Paged`。
//// gen-3 は列ごとの比較を組み合わせた keyset SQL を生成する。
//// NULL 境界とページ間の欠落は、生成文字列の検査とは別に SQL 実行で検証する。
import framework/effect.{type Effect, Read}
import framework/page.{type Cursor, type Page, type PageSize}
import framework/step.{type Start, type Step}
import gen/allow/widget as allow
import gen/query as q
import gen/reads/widget_page as reads
import gen/root/widget_page.{type Actor, type Root, type Service, Service}
import gleam/option.{type Option}

pub const effect: Effect = Read

pub type Args {
  Args(limit: PageSize, cursor: Option(Cursor))
}

pub type Out {
  Out(page: Page(Int))
}

pub type Error

pub type P {
  Limit
  Cursor
}

pub const service: Service(Args, Out, Error) = Service(
  allow: [
    allow.Clause(who: allow.Anyone, at: allow.AnyPhase, owner: allow.NoOwner),
  ],
  logic: logic,
)

pub const paged: q.Select(P) = q.Select(
  from: q.Widget,
  join: [],
  where: [],
  group: [],
  having: [],
  agg: [],
  along: [],
  with: [],
  order: [q.Asc(q.WidgetPlace), q.Desc(q.WidgetName)],
  limit: q.Paged(size: q.Param(Limit), after: q.Param(Cursor)),
)

pub fn logic(_by: Actor, _it: Root, args: Args) -> Step(Out, Error, Start) {
  use page <- reads.paged(limit: args.limit, cursor: args.cursor)
  step.done(Out(page: page))
}
