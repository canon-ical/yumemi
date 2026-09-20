// ★ src/service/widget_list.gleam
//// Service widget_list ── 20:710 の `IsTrue` / `EqOrNull`(2026-09-16 人見)と、
//// 20:838 の既定2つ(`order: []` は key の ASC、Option の列の ASC は NULLS LAST)を
//// 1 Service で当てる。
import framework/effect.{type Effect, Read}
import framework/step.{type Start, type Step}
import gen/allow/widget as allow
import gen/face.{type Face, Test}
import gen/query as q
import gen/reads/widget_list as reads
import gen/root/widget_list.{type Actor, type Root, type Service, Service}
import gleam/option.{type Option}

pub const effect: Effect = Read

pub const faces: List(Face) = [Test]

pub type Args {
  Args(place: Option(Int))
}

pub type Out {
  Out(shown: List(Int))
}

pub type Error

pub type P {
  Place
}

pub const service: Service(Args, Out, Error) = Service(
  allow: [
    allow.Clause(who: allow.Anyone, at: allow.AnyPhase, owner: allow.NoOwner),
  ],
  logic: logic,
)

/// 真偽の列はそのまま条件、穴が NULL なら NULL の行に当たる(TOP と置き場を1本で引く)。
pub const shown: q.Select(P) = q.Select(
  from: q.Widget,
  join: [],
  where: [q.IsTrue(q.WidgetVisible), q.EqOrNull(q.WidgetPlace, q.Param(Place))],
  group: [],
  having: [],
  agg: [],
  along: [],
  with: [],
  order: [q.Asc(q.WidgetOrder)],
  limit: q.NoLimit,
)

/// `order: []` ── 既定は key の ASC(結果の順を実行ごとに変えないため)。
pub const all: q.Select(P) = q.Select(
  from: q.Widget,
  join: [],
  where: [],
  group: [],
  having: [],
  agg: [],
  along: [],
  with: [],
  order: [],
  limit: q.NoLimit,
)

/// Option の列の ASC は NULLS LAST。`First(1)` の戻りは `Option(R)`。
pub const first_place: q.Select(P) = q.Select(
  from: q.Widget,
  join: [],
  where: [],
  group: [],
  having: [],
  agg: [],
  along: [],
  with: [],
  order: [q.Asc(q.WidgetPlace)],
  limit: q.First(1),
)

/// 集約の戻りは `Option(...)`(空集合は NULL)、`Count` だけ `Int`。
pub const tallest: q.Select(P) = q.Select(
  from: q.Widget,
  join: [],
  where: [],
  group: [],
  having: [],
  agg: [q.Max(q.WidgetOrder)],
  along: [],
  with: [],
  order: [],
  limit: q.NoLimit,
)

pub fn logic(_by: Actor, _it: Root, args: Args) -> Step(Out, Error, Start) {
  use shown <- reads.shown(place: args.place)
  step.done(Out(shown: shown))
}
