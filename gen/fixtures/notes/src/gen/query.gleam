//// GENERATED from entity declarations / named Select values [sha256:7e3f483b7578] — 手で編集しない

import entity/note
import gen/query/field
import gen/query/from
import gleam/option.{type Option}
import yumemi/er.{type Key}
import yumemi/time.{type Datetime}

/// From の実体は gen/query/from。名前空間を割るためだけに別 module にしてある。
pub type From =
  from.From

/// Field の実体は gen/query/field。
pub type Field =
  field.Field

/// 順向き(子 -> 親)は関係 Property 1 つにつき 1 本。末尾は `with:` に書かれた
/// Held の逆向き(親 -> 子の List)。
pub type Arrow

pub type Operand(p) {
  Param(p)
  Num(Int)
  Str(String)
  At(Datetime)
  KeyOfNote(Key(note.Note))
  Col(Field)
}

pub type Cond(p) {
  CurrentVersion(Field, Field)
  Eq(Field, Operand(p))
  Ne(Field, Operand(p))
  Lt(Field, Operand(p))
  Le(Field, Operand(p))
  Gt(Field, Operand(p))
  Ge(Field, Operand(p))
  In(Field, Operand(p))
  Contains(Field, Operand(p))
  IsNull(Field)
  NotNull(Field)
  IsTrue(Field)
  EqOrNull(Field, Operand(p))
  Has(Arrow, List(Cond(p)))
  HasNone(Arrow, List(Cond(p)))
}

pub type Agg {
  Count
  Sum(Field)
  Min(Field)
  Max(Field)
  Avg(Field)
}

pub type CondAgg(p) {
  AggGt(Agg, Operand(p))
  AggGe(Agg, Operand(p))
  AggLt(Agg, Operand(p))
  AggLe(Agg, Operand(p))
  AggEq(Agg, Operand(p))
}

pub type Unit {
  Day
  Week
  Month
}

pub type Group {
  ByField(Field)
  Bucket(Field, Unit)
  Via(Arrow)
}

pub type Order(p) {
  Nearest(Field, Operand(p))
  Asc(Field)
  Desc(Field)
  AscAgg(Agg)
  DescAgg(Agg)
}

pub type Along {
  Distance
  Rank(per: Option(Group))
  Running(Agg, per: Option(Group))
}

pub type Limit(p) {
  NoLimit
  Paged(size: Operand(p), after: Operand(p))
  First(Int)
  FirstPerGroup(Int, Group)
}

/// `Pick` は返す列を選ぶ口。`select` は `Select` を直に書き、行は選んだ列の record になる。
/// `columns` に with の子の列を混ぜると、その子も選んだ列だけの record になる。
pub type Select(p) {
  Select(
    from: From,
    join: List(Arrow),
    where: List(Cond(p)),
    group: List(Group),
    having: List(CondAgg(p)),
    agg: List(Agg),
    along: List(Along),
    with: List(Arrow),
    order: List(Order(p)),
    limit: Limit(p),
  )
  Pick(columns: List(Field), select: Select(p))
}
