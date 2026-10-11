//// Service page_resolve ── 数える口の器(`Store`)の resolve。event の path から業務の次元を返す(0.12)。
//// framework は Out の `section` で集計を割り(rollup_by)、`own` が真の event を数字から除く(exclude_when)。

// ★ src/service/page_resolve.gleam
import entity/article
import yumemi/effect.{type Effect, Read}
import yumemi/step.{type Start, type Step}
import gen/allow/article as allow
import gen/face.{type Face, Public}
import gen/root/page_resolve.{type Actor, type Root, type Service, Service}
import gleam/string

pub const effect: Effect = Read

pub const faces: List(Face) = [Public]

pub type Args {
  Args(path: String)
}

pub type Out {
  Out(section: String, own: Bool)
}

pub type Error

pub const service: Service(Args, Out, Error) = Service(
  allow: [
    allow.Clause(
      who: allow.Anyone,
      at: allow.Only([article.Published]),
      owner: allow.NoOwner,
    ),
  ],
  logic: logic,
)

/// 頁の頭の段を section に。`/status` は運営の頁として数字から除く
pub fn logic(_by: Actor, _it: Root, args: Args) -> Step(Out, Error, Start) {
  let section = case string.split(args.path, "/") {
    ["", head, ..] -> head
    _ -> ""
  }
  step.done(Out(section: section, own: section == "status"))
}
