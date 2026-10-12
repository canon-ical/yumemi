//// Service note_list ── 覚え書きを新しい順に、頁の大きさを呼び手が決めて刻む(`Paged(size: Param(..))`)。

// ★ src/service/note_list.gleam
import entity/note
import gen/allow/note as allow
import gen/face.{type Face, Api}
import gen/query as q
import gen/query/field
import gen/query/from
import gen/reads/note_list as reads
import gen/root/note_list.{type Actor, type Root, type Service, Service}
import gleam/option.{type Option}
import yumemi/effect.{type Effect, Read}
import yumemi/page.{type Cursor, type Page}
import yumemi/step.{type Start, type Step}

pub const effect: Effect = Read

pub const faces: List(Face) = [Api]

pub type Args {
  Args(limit: Int, cursor: Option(Cursor))
}

pub type Out {
  Out(page: Page(note.Note))
}

pub type Error

pub type P {
  Limit
  Cursor
}

pub const items: q.Select(P) = q.Select(
  from: from.Note,
  join: [],
  where: [],
  group: [],
  having: [],
  agg: [],
  along: [],
  with: [],
  order: [q.Desc(field.NoteCreatedAt)],
  limit: q.Paged(size: q.Param(Limit), after: q.Param(Cursor)),
)

pub const service: Service(Args, Out, Error) = Service(
  allow: [
    allow.Clause(who: allow.Anyone, at: allow.AnyPhase, owner: allow.NoOwner),
  ],
  logic: logic,
)

pub fn logic(_by: Actor, _it: Root, args: Args) -> Step(Out, Error, Start) {
  use page <- reads.items(limit: args.limit, cursor: args.cursor)
  step.done(Out(page: page))
}
