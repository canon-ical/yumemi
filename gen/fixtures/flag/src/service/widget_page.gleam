// ★ src/service/widget_page.gleam
//// Service widget_page ── 向きの混じった `order` で `Paged`。生成器は SQL を組めないので
//// `_diagnostics.txt` へ落ちる(残差 G1)。**このとき 0 で終わってはならない** ── reads の
//// 関数だけ在って SQL が無い状態は実行時に必ず落ちる不整合(柏木 P2-2)。
import framework/effect.{type Effect, Read}
import framework/page.{type Cursor, type Page, type PageSize}
import framework/step.{type Start, type Step}
import gen/query as q
import gen/reads/widget_page as reads
import gen/root/widget_page.{type Actor, type Root, type Service}
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

pub const paged: q.Select(P) = q.Select(
  from: q.Widget,
  join: [],
  where: [],
  group: [],
  having: [],
  agg: [],
  along: [],
  with: [],
  order: [q.Asc(q.WidgetOrder), q.Desc(q.WidgetName)],
  limit: q.Paged(size: q.Param(Limit), after: q.Param(Cursor)),
)

pub fn logic(_by: Actor, _it: Root, args: Args) -> Step(Out, Error, Start) {
  use page <- reads.paged(limit: args.limit, cursor: args.cursor)
  step.done(Out(page: page))
}
