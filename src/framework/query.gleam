//// Query shape. Entity-specific From, Field, Arrow, phase and key words are generated.

import gleam/option.{type Option}

pub type Operand(parameter, field, value) {
  Param(parameter)
  Num(Int)
  Str(String)
  At(value)
  Col(field)
}

pub type Cond(field, arrow, operand) {
  Eq(field, operand)
  Ne(field, operand)
  Lt(field, operand)
  Le(field, operand)
  Gt(field, operand)
  Ge(field, operand)
  In(field, operand)
  Contains(field, operand)
  IsNull(field)
  NotNull(field)
  Has(arrow, List(Cond(field, arrow, operand)))
  HasNone(arrow, List(Cond(field, arrow, operand)))
}

pub type Agg(field) {
  Count
  Sum(field)
  Min(field)
  Max(field)
  Avg(field)
}

pub type CondAgg(aggregate, operand) {
  AggGt(aggregate, operand)
  AggGe(aggregate, operand)
  AggLt(aggregate, operand)
  AggLe(aggregate, operand)
  AggEq(aggregate, operand)
}

pub type Unit {
  Day
  Week
  Month
}

pub type Group(field, arrow) {
  ByField(field)
  Bucket(field, Unit)
  Via(arrow)
}

pub type Order(field, aggregate) {
  Asc(field)
  Desc(field)
  AscAgg(aggregate)
  DescAgg(aggregate)
}

pub type Along(aggregate, group) {
  Rank(per: Option(group))
  Running(aggregate, per: Option(group))
}

pub type Limit(operand, group) {
  NoLimit
  Paged(size: operand, after: operand)
  First(Int)
  FirstPerGroup(Int, group)
}

pub type Select(from, arrow, cond, group, cond_agg, agg, along, order, limit) {
  Select(
    from: from,
    join: List(arrow),
    where: List(cond),
    group: List(group),
    having: List(cond_agg),
    agg: List(agg),
    along: List(along),
    with: List(arrow),
    order: List(order),
    limit: limit,
  )
}
