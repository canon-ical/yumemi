//// glance regression fixture: Gleam permits a trailing comma after a list spread.

pub fn trailing_spread(rest: List(String)) -> List(String) {
  ["head", ..rest,]
}
